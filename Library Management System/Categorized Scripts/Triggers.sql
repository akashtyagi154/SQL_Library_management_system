-- Triggers
drop 
  trigger if exists add_new_book_to_inventory_list;   
create trigger add_new_book_to_inventory_list 
after 
  insert on book_details for each row insert ignore into book_inventory(book_details_id, availability) 
values 
  (new.id, 'Available');

drop 
  trigger if exists add_new_book_supplies;
DELIMITER $$ 
create trigger add_new_book_supplies before 
update 
  on book_details for each row 
set 
  new.total_number_of_copies = (
    old.total_number_of_copies + new.total_number_of_copies
  ) 
where 
  old.id = new.id;
DELIMITER ;

drop 
  trigger if exists rent_a_book;
DELIMITER $$ 
create trigger rent_a_book before insert on rent_table for each row BEGIN 
SET 
  SQL_SAFE_UPDATES = 0;
set 
  new.due_date = date_add(new.rent_date, interval 7 day);
update 
  fines 
set 
  book_rent_status = (
    select 
      case when return_date is not null then 'Returned' else 'Not returned' end book_rent_status 
    from 
      rent_table 
    where 
      rent_table.id = new.id
  ) 
where 
  fines.rent_id = new.id;
SET 
  SQL_SAFE_UPDATES = 1;
END $$ 
DELIMITER ;

drop 
  trigger if exists add_book_to_rented;
DELIMITER $$ 
create trigger add_book_to_rented 
after 
  insert on rent_table for each row BEGIN insert ignore into rented_books_users(rent_id, book_id, reader_id) 
values 
  (
    new.id, new.book_id, new.reader_id
  );
END $$ 
DELIMITER ;

drop 
  trigger if exists update_available_availability;
DELIMITER $$ 
create trigger update_available_availability before 
update 
  on rent_table for each row BEGIN 
delete from 
  rented_books_users rbu 
where 
  rbu.rent_id = old.id;
if (new.return_date is not null) then 
update 
  book_inventory bin 
set 
  availability = 'Available' 
where 
  bin.book_id = old.book_id;
end if;

-- if (
--   not exists (
--     select 
--       rent_id 
--     from 
--       fines 
--     where 
--       rent_id = old.id
--   ) 
--   and (
--     select 
--       datediff(
--         curdate(), 
--         due_date
--       ) 
--     from 
--       rent_table 
--     where 
--       id = old.id
--   )> 0
-- ) then insert ignore into fines(rent_id, overdue_days) with new_rent_fine as (
--   select 
--     id, 
--     datediff(
--       curdate(), 
--       due_date
--     ) overdue_days 
--   from 
--     rent_table 
--   where 
--     (
--       return_date is null 
--       and datediff(
--         curdate(), 
--         due_date
--       )>= 1
--     ) 
--     or (
--       return_date is not null 
--       and datediff(return_date, due_date)>= 1
--     ) 
--   order by 
--     overdue_days desc
-- ) 
-- select 
--   * 
-- from 
--   new_rent_fine;
-- end if;
update 
  fines 
set 
  book_rent_status = (
    select 
      (
        case when return_date is not null then 'Returned' else 'Not Returned' end
      ) 
    from 
      rent_table 
    where 
      rent_table.id = OLD.id
  ) 
where 
  fines.rent_id = old.id;
update 
  fines 
set 
  fine_amount = (
    select 
      datediff(new.return_date, due_date)* 5 
    from 
      rent_table 
    where 
      fines.rent_id = old.id
  ) 
where 
  fines.rent_id = old.id;
END $$ 
DELIMITER ;


  
drop 
  trigger if exists update_rented_availability;
DELIMITER $$ 
create trigger update_rented_availability before insert on rent_table for each row BEGIN 
update 
  book_inventory bi 
set 
  availability = 'Rented' 
where 
  bi.book_id = new.book_id;
END $$ 
DELIMITER ;
drop 
  trigger if exists transfer_book_to_rented;

DELIMITER $$ 
CREATE TRIGGER transfer_book_to_rented 
AFTER 
  INSERT ON rent_table for each row BEGIN 
UPDATE 
  book_details 
SET 
  total_number_of_copies = total_number_of_copies - 1 
WHERE 
  id = new.book_id;
END $$ 
DELIMITER ;

drop 
  trigger if exists update_payment_status;
Delimiter $$ 
create trigger update_payment_status before insert on fine_payments for each row begin 
SET 
  SQL_SAFE_UPDATES = 0;
set 
  new.book_rent_status = (
    select 
      book_rent_status 
    from 
      fines 
    where 
      fines.id = new.fine_id
  );
set 
  new.fine_amount = (
    select 
      fine_amount 
    from 
      fines 
    where 
      fines.id = new.fine_id
  );
delete from 
  readers_with_pending_dues r 
where 
  r.fine_id = new.fine_id;
update 
  fines 
set 
  fines.fine_payment_status = 'Paid' 
where 
  fines.id = new.fine_id;
SET 
  SQL_SAFE_UPDATES = 1;

-- insert new fines
insert ignore into fines(rent_id, overdue_days) with new_rent_fine as (
  select 
    id, 
    datediff(
      curdate(), 
      due_date
    ) overdue_days 
  from 
    rent_table 
  where 
    (
      return_date is null 
      and datediff(
        curdate(), 
        due_date
      )>= 1
    ) 
    or (
      return_date is not null 
      and datediff(return_date, due_date)>= 1
    ) 
  order by 
    overdue_days desc
) 
select 
  * 
from 
  new_rent_fine;



-- update old fine amount and overdue status
drop 
  temporary table if exists fines_to_update;
create temporary table fines_to_update 
select 
  f.id, 
  (case 
  when r.return_date is not null then datediff(
    r.return_date, 
    r.due_date
  )
  else datediff(
    curdate(), 
    r.due_date
  ) end)
     updated_overdue_days 
from 
  fines f, 
  rent_table r 
where 
  f.rent_id = r.id 
  and f.fine_payment_status like 'Unpaid' 
  and datediff(
    curdate(), 
    r.due_date
  )> 1;
update 
  fines f 
  inner join fines_to_update u 
set 
  f.overdue_days = u.updated_overdue_days 
where 
  f.id = u.id;

end $$ 
DELIMITER ;

drop 
  trigger if exists update_book_rent_status_in_fines;
delimiter $$
create trigger update_book_rent_status_in_fines before insert on fines for each row begin 
set 
  new.book_rent_status = (
    select 
      (
        case when return_date is not null then 'Returned' else 'Not Returned' end
      ) 
    from 
      rent_table 
    where 
      rent_table.id = new.rent_id
  );
if (
  select 
    return_date 
  from 
    rent_table 
  where 
    rent_table.id = new.rent_id
) is not null then 
set 
  new.fine_amount = (
    select 
      datediff(return_date, due_date)* 5 
    from 
      rent_table r 
    where 
      r.id = new.rent_id
  );
else 
set 
  new.fine_amount = (
    select 
      datediff(
        curdate(), 
        due_date
      )* 5 
    from 
      rent_table r 
    where 
      r.id = new.rent_id
  );
end if;
insert ignore into readers_with_pending_dues(
  reader_name, reader_id, fine_id, fine_amount
) 
select 
  ra.reader_name, 
  ra.id, 
  fi.id, 
  fi.fine_amount 
from 
  fines fi, 
  rent_table re, 
  readers ra 
where 
  fine_payment_status like 'Unpaid' 
  and fi.rent_id = re.id 
  and re.reader_id = ra.id;
update 
  readers_with_pending_dues 
set 
  fine_amount = (
    select 
      fine_amount 
    from 
      fines 
    where 
      fines.id = new.id
  ) 
where 
  fine_id = new.id;
end $$ 
delimiter ;

drop 
  trigger if exists update_book_rent_status_in_fines_update;
delimiter $$ 
create trigger update_book_rent_status_in_fines_update before 
update 
  on fines for each row begin 
set 
  new.book_rent_status = (
    select 
      (
        case when return_date is not null then 'Returned' else 'Not Returned' end
      ) 
    from 
      rent_table 
    where 
      rent_table.id = old.rent_id
  );
if (
  select 
    return_date 
  from 
    rent_table 
  where 
    rent_table.id = old.rent_id
) is not null then 
set 
  new.fine_amount = (
    select 
      datediff(return_date, due_date)* 5 
    from 
      rent_table r 
    where 
      r.id = old.rent_id
  );
else 
set 
  new.fine_amount = (
    select 
      datediff(
        curdate(), 
        due_date
      )* 5 
    from 
      rent_table r 
    where 
      r.id = old.rent_id
  );
end if;
update 
  readers_with_pending_dues 
set 
  fine_amount = (
    select 
      fine_amount 
    from 
      fines 
    where 
      fines.id = old.id
  ) 
where 
  fine_id = old.id;
end $$ 
delimiter ;