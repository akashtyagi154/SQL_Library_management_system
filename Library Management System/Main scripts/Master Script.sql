-- Drops entire Database if it already exists and create entire schema again
DROP 
  database if exists Library_management_system;
CREATE DATABASE if not exists Library_management_system;
USE Library_management_system;
drop 
  table if exists book_details;
create table book_details (
  id int primary key auto_increment, 
  book_title varchar(255) unique, 
  author_name varchar(255), 
  year_of_publishing date, 
  language_in varchar(255), 
  category varchar(255), 
  total_number_of_copies int default(1) check(total_number_of_copies > 0)
);
alter table 
  book_details auto_increment = 100000;
drop 
  table if exists book_inventory;
create table book_inventory (
  book_id int primary key auto_increment, 
  book_details_id int, 
  availability enum('Available', 'Rented'), 
  foreign key (book_details_id) references book_details(id)
);
alter table 
  book_inventory auto_increment = 10000000;
drop 
  table if exists readers;
create table readers (
  id int auto_increment primary key, 
  reader_name varchar(255), 
  age int, 
  lib_join_date date, 
  contact_no varchar(50) unique, 
  address text
);
alter table 
  readers auto_increment = 10000;
drop 
  table if exists rent_table;
create table rent_table (
  id int primary key auto_increment, 
  book_id int, 
  reader_id int, 
  rent_date date, 
  return_date date default(null), 
  due_date date null, 
  foreign key (book_id) references book_inventory(book_id), 
  foreign key (reader_id) references readers(id)
);
alter table 
  rent_table auto_increment = 50000;
drop 
  table if exists rented_book_users;
create table rented_books_users (
  rent_id int unique, book_id int unique, 
  reader_id int unique
);
drop 
  table if exists fines;
create table fines (
  id int auto_increment primary key, 
  rent_id int unique, 
  overdue_days int default(0) check(overdue_days > 0), 
  fine_amount int default(overdue_days * 5), 
  fine_payment_status enum('Paid', 'Unpaid') default('Unpaid'), 
  book_rent_status enum('Returned', 'Not returned'), 
  foreign key (rent_id) references rent_table(id)
);
alter table 
  fines auto_increment = 5000;
drop 
  table if exists readers_with_pending_dues;
create table readers_with_pending_dues (
  reader_name varchar(255), 
  reader_id int unique, 
  fine_id int unique, 
  fine_amount int
);
drop 
  table if exists fine_payments;
create table fine_payments(
  payment_id int auto_increment primary key, 
  fine_id int unique, 
  fine_amount int, 
  book_rent_status varchar(50) check(book_rent_status like 'Returned') not null
);
alter table 
  fine_payments auto_increment = 1000;

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

USE `library_management_system`;
DROP procedure IF EXISTS `available_book_copies`;

DELIMITER $$
USE `library_management_system`$$
CREATE PROCEDURE `available_book_copies` (book_title char(255))
BEGIN	
select * from book_inventory where book_inventory.book_details_id in (select distinct id from book_details where book_details.book_title like book_title);
END$$

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

-- Stored Precedures
USE `library_management_system`;
DROP 
  procedure IF EXISTS `library_management_system`.`update_inventory_by_book_title`;
DELIMITER $$ 
USE `library_management_system` $$ CREATE PROCEDURE `library_management_system`.`update_inventory_by_book_title` (
  title char(255), 
  quantity int
) BEGIN 
update 
  book_details 
set 
  total_number_of_copies = quantity + total_number_of_copies 
where 
  book_title like title 
limit 
  1;
insert book_inventory(book_details_id, availability) with recursive book_inventory_update as (
  select 
    (
      select 
        id 
      from 
        book_details 
      where 
        book_title like title 
      limit 
        1
    ) book_details_id, 
    'Available' availability, 
    1 as n 
  union 
  select 
    (
      select 
        id 
      from 
        book_details 
      where 
        book_title like title 
      limit 
        1
    ), 
    'Available', 
    n + 1 
  from 
    book_inventory_update 
  where 
    n < quantity
) 
select 
  book_details_id, 
  availability 
from 
  book_inventory_update;
END$$ 
DELIMITER ;
DROP 
  procedure IF EXISTS `library_management_system`.`add_new_book`;
DELIMITER $$ 
CREATE PROCEDURE `library_management_system`.`add_new_book` (
  book_title char(255), 
  author_name char(255), 
  
  date_released year, 
  language_in char(255), 
  category char(255)
) BEGIN insert ignore into book_details(
  book_title, author_name, 
  year_of_publishing, language_in, category
) 
values 
  (
    book_title, author_name,
    year_of_publishing, language_in, category
  );
END $$ 
DELIMITER ;
DROP 
  procedure IF EXISTS `library_management_system`.`add_new_reader`;
DELIMITER $$ 
USE `library_management_system` $$ CREATE PROCEDURE `library_management_system`.`add_new_reader` (
  reader_name char(255), 
  age int, 
  lib_join_date date, 
  contact_no char(50), 
  address text
) BEGIN insert ignore into readers(
  reader_name, age, lib_join_date, contact_no, 
  address
) 
values 
  (
    reader_name, age, lib_join_date, contact_no, 
    address
  );
END $$ 
DELIMITER ;

USE `library_management_system`;
DROP 
  procedure IF EXISTS `rent_a_book`;
DELIMITER $$ 
USE `library_management_system` $$ CREATE PROCEDURE `rent_a_book` (book int, reader int) BEGIN if book not in (select 
    r.book_id 
  from 
    rent_table r
  where 
    r.return_date is null)
and
reader not in (select 
    r.reader_id 
  from 
    rent_table r
  where 
    r.return_date is null) then insert ignore into rent_table(book_id, reader_id, rent_date) 
values 
  (
    book, 
    reader, 
    curdate()
  );
end if;
END $$ 
DELIMITER ;
USE `library_management_system`;
DROP 
  procedure IF EXISTS `take_payment`;
DELIMITER $$ 
USE `library_management_system` $$ CREATE PROCEDURE `take_payment` (fine_id int) BEGIN insert ignore into fine_payments(fine_id) 
values 
  (fine_id);
END $$  
DELIMITER ;
USE `library_management_system`;
DROP 
  procedure IF EXISTS `midnight_data_refresh`;

DELIMITER $$ 
USE `library_management_system` $$ CREATE PROCEDURE `midnight_data_refresh` () BEGIN -- insert new fines
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
DELIMITER ;
USE `library_management_system`;
DROP 
  procedure IF EXISTS `return_a_book`;
DELIMITER $$ 
USE `library_management_system` $$ CREATE PROCEDURE `return_a_book` (rent_id int) BEGIN 
update 
  rent_table 
set 
  return_date = curdate() 
where 
  id = rent_id;
END $$ 
DELIMITER ;


USE `library_management_system`;
DROP procedure IF EXISTS `dummy_rent_transaction`;

DELIMITER $$
USE `library_management_system`$$
CREATE PROCEDURE `dummy_rent_transaction`(
book_id int,
reader_id int,
rent_date date,
return_days date,
inp_id int
)
BEGIN
SET 
  SQL_SAFE_UPDATES = 0;
insert ignore into rent_table(book_id,reader_id,rent_date) values (book_id,reader_id,rent_date);
update rent_table r set return_date = return_days where r.id = inp_id;
SET 
  SQL_SAFE_UPDATES = 1;
END$$

DELIMITER ;

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


CALL `library_management_system`.`add_new_book`('Gilead','Marilynne Robinson',2004,'English','Fiction');
CALL `library_management_system`.`add_new_book`('The One Tree','Stephen R. Donaldson',1982,'English','American fiction');
CALL `library_management_system`.`add_new_book`('Rage of angels','Sidney Sheldon',1993,'English','Fiction');
CALL `library_management_system`.`add_new_book`('The Four Loves','Clive Staples Lewis',2002,'English','Christian life');
CALL `library_management_system`.`add_new_book`('The Problem of Pain','Clive Staples Lewis',2002,'English','Christian life');
CALL `library_management_system`.`add_new_book`('An Autobiography','Agatha Christie',1977,'English','Authors, English');
CALL `library_management_system`.`add_new_book`('Empires of the Monsoon','Richard Hall',1998,'English','Africa, East');
CALL `library_management_system`.`add_new_book`('The Gap Into Madness','Stephen R. Donaldson',1994,'English','Hyland, Morn (Fictitious character)');
CALL `library_management_system`.`add_new_book`('Master of the Game','Sidney Sheldon',1982,'English','Adventure stories');
CALL `library_management_system`.`add_new_book`('If Tomorrow Comes','Sidney Sheldon',1994,'English','Adventure stories');
CALL `library_management_system`.`add_new_book`('Assassins Apprentice','Robin Hobb',1996,'English','American fiction');
CALL `library_management_system`.`add_new_book`('Warhost of Vastmark','Janny Wurts',1995,'English','Fiction');
CALL `library_management_system`.`add_new_book`('The Once and Future King','Terence Hanbury White',1996,'English','Arthurian romances');
CALL `library_management_system`.`add_new_book`('Murder in LaMut','Raymond E. Feist;Joel Rosenberg',2003,'English','Adventure stories');
CALL `library_management_system`.`add_new_book`('Jimmy the Hand','Raymond E. Feist;S. M. Stirling',2003,'English','Fantasy fiction');
CALL `library_management_system`.`add_new_book`('Well of Darkness','Margaret Weis;Tracy Hickman',2001,'English','');
CALL `library_management_system`.`add_new_book`('Witness for the Prosecution & Selected Plays','Agatha Christie',1995,'English','English drama');
CALL `library_management_system`.`add_new_book`('The Little House','Philippa Gregory',1998,'English','Country life');
CALL `library_management_system`.`add_new_book`('Mystical Paths','Susan Howatch',1996,'English','English fiction');
CALL `library_management_system`.`add_new_book`('Glittering Images','Susan Howatch',1996,'English','English fiction');
CALL `library_management_system`.`add_new_book`('Glamorous Powers','Susan Howatch',1996,'English','Clergy');
CALL `library_management_system`.`add_new_book`('The Mad Ship','Robin Hobb',2000,'English','Fantasy fiction');
CALL `library_management_system`.`add_new_book`('Post Captain','Patrick OBrian',1996,'English','Aubrey, Jack (Fictitious character)');
CALL `library_management_system`.`add_new_book`('The Reverse of the Medal','Patrick OBrian',1997,'English','Adventure stories');
CALL `library_management_system`.`add_new_book`('Miss Marple','Agatha Christie',1997,'English','Detective and mystery stories, English');
CALL `library_management_system`.`add_new_book`('The Years of Rice and Salt','Kim Stanley Robinson','2003','English','Black Death');
CALL `library_management_system`.`add_new_book`('Spares','Michael Marshall Smith',1998,'English','Human cloning');
CALL `library_management_system`.`add_new_book`('Gravity','Tess Gerritsen',2004,'English','Science fiction');
CALL `library_management_system`.`add_new_book`('The Wise Woman','Philippa Gregory',2002,'English','Great Britain');
CALL `library_management_system`.`add_new_book`('Girls Night in','Jessica Adams;Chris Manby;Fiona Walker',2000,'English','American fiction');
CALL `library_management_system`.`add_new_book`('The White Album','Joan Didion',1993,'English','American essays');
CALL `library_management_system`.`add_new_book`('The Bonesetters Daughter','Amy Tan',2001,'English','China');
CALL `library_management_system`.`add_new_book`('The Lexus and the Olive Tree','Thomas L. Friedman',2000,'English','Capitalism');
CALL `library_management_system`.`add_new_book`('Tis','Frank McCourt',2000,'English','Ireland');
CALL `library_management_system`.`add_new_book`('Ocean Star Express','Mark Haddon;Peter Sutton',2002,'English','Juvenile Fiction');
CALL `library_management_system`.`add_new_book`('A Small Pinch of Weather','Joan Aiken',2000,'English','Childrens stories, English');
CALL `library_management_system`.`add_new_book`('The Princess of the Chalet School','Elinor Mary Brent-Dyer',2000,'English','Juvenile Fiction');
CALL `library_management_system`.`add_new_book`('Koko','Peter Straub',2001,'English','Male friendship');
CALL `library_management_system`.`add_new_book`('Tree and Leaf','John Ronald Reuel Tolkien',2001,'English','Literary Collections');
CALL `library_management_system`.`add_new_book`('Partners in Crime','Agatha Christie',2001,'English','Beresford, Tommy (Fictitious character)');
CALL `library_management_system`.`add_new_book`('Murder in Mesopotamia','Agatha Christie',2001,'English','Detective and mystery stories');
CALL `library_management_system`.`add_new_book`('The Lord of the Rings, the Return of the King','Jude Fisher',2003,'English','Imaginary wars and battles');
CALL `library_management_system`.`add_new_book`('All Families are Psychotic','Douglas Coupland',2002,'English','Dysfunctional families');
CALL `library_management_system`.`add_new_book`('Death in the Clouds','Agatha Christie',2001,'English','Detective and mystery stories');
CALL `library_management_system`.`add_new_book`('Appointment with Death','Agatha Christie',2001,'English','Detective and mystery stories');
CALL `library_management_system`.`add_new_book`('Halloween Party','Agatha Christie',2001,'English','Poirot, Hercule (Fictitious character)');
CALL `library_management_system`.`add_new_book`('Hercule Poirots Christmas','Agatha Christie',2001,'English','Christmas stories');
CALL `library_management_system`.`add_new_book`('The Big Four','Agatha Christie',2002,'English','Detective and mystery stories');


CALL `library_management_system`.`add_new_reader`('Tony Stark', 42, '2023-01-10', '12345678','Meghalaya');
CALL `library_management_system`.`add_new_reader`('Thor', 100, '2022-03-25', '910111213','Asgard');
CALL `library_management_system`.`add_new_reader`('Antman', 48, '2022-12-10', '1415161718','Quantum Realm');
CALL `library_management_system`.`add_new_reader`('Spiderman', 16, '2023-02-01', '1920212223','Queens,New York');
CALL `library_management_system`.`add_new_reader`('Hulk', 45, '2022-07-09', '242526627','Kolkata, India');
CALL `library_management_system`.`add_new_reader`('Captain America', 70, '2022-04-15', '2829303132','Brooklyn, new York');
CALL `library_management_system`.`add_new_reader`('Scarlett Witch', 38, '2022-11-17', '33343536','Serbia');
CALL `library_management_system`.`add_new_reader`('Black Widow', 40, '2022-09-24', '37383940','Russia');
CALL `library_management_system`.`add_new_reader`('Dr Strange', 52, '2022-05-22', '41424344','Mirrow world');
CALL `library_management_system`.`add_new_reader`('Dr Octo', 65, '2022-02-04', '45464748','Other universe');
CALL `library_management_system`.`add_new_reader`('Black Panther', 47, '2022-12-08', '49505152','Wakanda');
CALL `library_management_system`.`add_new_reader`('Quick Silver', 25, '2022-11-17', '53545556','Serbia');
CALL `library_management_system`.`add_new_reader`('Akash Tyagi', 26, curdate(), '8586060424','Ghaziabad');


CALL `library_management_system`.`dummy_rent_transaction`(10000000,10000,'2023-01-10','2023-01-13',50000);
CALL `library_management_system`.`dummy_rent_transaction`(10000001,10001,'2022-03-25',null,null); 
CALL `library_management_system`.`dummy_rent_transaction`(10000002,10002,'2022-12-10','2022-12-16',50002);
CALL `library_management_system`.`dummy_rent_transaction`(10000003,10003,'2023-02-01','2023-02-10',50003);
CALL `library_management_system`.`dummy_rent_transaction`(10000004,10004,'2022-07-09','2022-07-14',50004);
CALL `library_management_system`.`dummy_rent_transaction`(10000005,10005,'2022-04-15','2022-04-19',50005);
CALL `library_management_system`.`dummy_rent_transaction`(10000006,10006,'2022-11-17','2022-11-27',50006);
CALL `library_management_system`.`dummy_rent_transaction`(10000007,10007,'2022-09-24','2022-09-27',50007);
CALL `library_management_system`.`dummy_rent_transaction`(10000008,10008,'2022-05-22','2022-05-25',50008);
CALL `library_management_system`.`dummy_rent_transaction`(10000009,10009,'2022-02-04','2022-02-14',50009);
CALL `library_management_system`.`dummy_rent_transaction`(10000010,10010,'2022-12-08','2022-12-10',50010);
CALL `library_management_system`.`dummy_rent_transaction`(10000011,10011,'2022-11-17','2022-11-26',50011);

CALL `library_management_system`.`midnight_data_refresh`();
CALL `library_management_system`.`take_payment`(5001);
CALL `library_management_system`.`take_payment`(5002);
CALL `library_management_system`.`take_payment`(5004);

CALL `library_management_system`.`rent_a_book`(10000000, 10012);
CALL `library_management_system`.`return_a_book`(50012);