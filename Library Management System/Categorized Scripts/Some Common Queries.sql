-- distinct books_available_in_library for rent
select * from book_details where id in (select distinct book_details_id from book_inventory where availability like 'Available');

-- show available book copy ids by book_title
CALL `library_management_system`.`available_book_copies`('Gilead');

CALL `library_management_system`.`available_book_copies`(<{book_title char(255)}>);



-- users who are eligible to rent a book
select * from readers where id in (select reader_id from rent_table where id not in (select rent_id from fines where book_rent_status like 'Not returned' OR fine_payment_status like 'Unpaid'));

-- readers who have rented a book and not returned yet
select rbu.reader_id,ra.reader_name, datediff(curdate(),rt.rent_date) rented_days from rented_books_users rbu 
left join rent_table rt on rbu.rent_id = rt.id
left join readers ra on rt.reader_id = ra.id;

-- readers with pending dues 
select * from readers_with_pending_dues;