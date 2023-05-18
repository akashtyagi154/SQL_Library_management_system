drop 
  event if exists fine_classifier;
delimiter $$ 
create event fine_classifier on schedule every 1 day starts (
  current_date() + interval 23 hour + interval 59 minute
) do BEGIN -- insert new fines
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
  
drop 
  table if exists readers_with_pending_dues;
create table readers_with_pending_dues (
  reader_name varchar(255), 
  reader_id int unique, 
  fine_id int unique, 
  fine_amount int
);
-- add readers_with_pending_dues
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
  fi.fine_payment_status like 'Unpaid' 
  and fi.rent_id = re.id 
  and re.reader_id = ra.id;
END $$ 
delimiter ;
show events ;
