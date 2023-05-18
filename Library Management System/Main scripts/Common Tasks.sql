-- add new book to library, will add only 1 copy
CALL `library_management_system`.`add_new_book`(<{book_title char(255)}>, <{author_name char(255)}>, <{date_released year}>, <{language_in char(255)}>, <{category char(255)}>);

-- add new copies of already available books in library
CALL `library_management_system`.`update_inventory_by_book_title`(<{title char(255)}>, <{quantity int}>);

-- add new reader
CALL `library_management_system`.`add_new_reader`(<{reader_name char(255)}>, <{age int}>, <{lib_join_date date}>, <{contact_no char(50)}>, <{address text}>);

-- rent a book with book_copy_id and reader id
CALL `library_management_system`.`rent_a_book`(<{book int}>, <{reader int}>);

-- return a book back to library with rent id with which it was borrowed
CALL `library_management_system`.`return_a_book`(<{rent_id int}>);

-- take payment with fine_id for fines pending in fines table only
CALL `library_management_system`.`take_payment`(<{fine_id int}>);