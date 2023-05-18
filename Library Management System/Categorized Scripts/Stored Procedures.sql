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

USE `library_management_system`;
DROP procedure IF EXISTS `available_book_copies`;

DELIMITER $$
USE `library_management_system`$$
CREATE PROCEDURE `available_book_copies` (book_title char(255))
BEGIN
select * from book_inventory where book_inventory.book_details_id in (select distinct id from book_details where book_details.book_title like book_title);
END$$

DELIMITER ;


