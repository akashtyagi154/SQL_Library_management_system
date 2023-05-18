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
  year_of_publishing year, 
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
