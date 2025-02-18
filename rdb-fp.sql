-- task 1.1 - create needed schema
-- -------------------------------
create schema if not exists pandemic;

-- task 1.2 - set needed schema as default
-- ---------------------------------------
use pandemic;

-- tasks 1.3 - import with wizard
-- -------------------------------------------------------------
-- import with wizard was successfully (all 10521 rows) only if we set the type of columns with disease data as text
-- check quantity of rows
select count(*) from infectious_cases;
-- and check type of data in each columns
describe infectious_cases;

-- tasks 1.4 - overview the table after import with wizard
-- -------------------------------------------------------------
select * from infectious_cases limit 20;

-- there is problem - all columns with disease statistic are text data type, but we need numeric data type for different calculations.
-- so we need modify data type of selected columns from text to double

-- before columns modification we need converting data in columns to suitable type, for which we need replace "" to null value
update infectious_cases set Number_yaws = null where Number_yaws = "";
update infectious_cases set polio_cases = null where polio_cases = "";
update infectious_cases set cases_guinea_worm = null where cases_guinea_worm = "";
update infectious_cases set Number_rabies = null where Number_rabies = "";
update infectious_cases set Number_malaria = null where Number_malaria = "";
update infectious_cases set Number_hiv = null where Number_hiv = "";
update infectious_cases set Number_tuberculosis = null where Number_tuberculosis = "";
update infectious_cases set Number_smallpox = null where Number_smallpox = "";
update infectious_cases set Number_cholera_cases = null where Number_cholera_cases = "";
update infectious_cases set Code = null where Code = "";

-- and now we can do the columns modification
ALTER TABLE infectious_cases 
	MODIFY COLUMN Number_yaws double,
	MODIFY COLUMN polio_cases double,
	MODIFY COLUMN cases_guinea_worm double,
	MODIFY COLUMN Number_rabies double,
	MODIFY COLUMN Number_malaria double,
	MODIFY COLUMN Number_hiv double,
	MODIFY COLUMN Number_tuberculosis double,
	MODIFY COLUMN Number_smallpox double,
	MODIFY COLUMN Number_cholera_cases double;

-- check modification result
describe pandemic.infectious_cases;
-- all right!

-- task 2 - normalize table to 3NF
-- -------------------------------
-- for 3NF normalization we need move data about entity/code to the separate table with creating primary key, and move main data to the another separate table, link two new tables with relation

-- step 0 - to choose which column to select for the formation of the entity/code directory, find in which of the columns there are no empty values
select count(*)  from infectious_cases where Entity is null;
select count(*)  from infectious_cases where infectious_cases.Code is null;
-- Entity column has no empty values
-- Code column has 1128 empty values
-- so choose Entity column for formation foreign key

-- step 1 - copying entity/code data to new table (entity/code reference table)
CREATE TABLE if not exists infectious_cases_entity AS 
select distinct Entity, Code from infectious_cases;

-- step 2 - adding primary key column
ALTER TABLE infectious_cases_entity 
ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY;

-- step 3 - copying main data to another new table
CREATE TABLE if not exists infectious_cases_data  AS 
select 
	Entity, Year, Number_yaws, polio_cases, cases_guinea_worm, Number_rabies, Number_malaria, Number_hiv, Number_tuberculosis, Number_smallpox, Number_cholera_cases
from infectious_cases;

-- step 4 - adding column for foreighn key
ALTER TABLE infectious_cases_data 
ADD COLUMN entity_id INT;

-- step 5 - filling id column from entity/code reference table
UPDATE infectious_cases_data as mt
SET entity_id = (
    SELECT rt.id
    FROM infectious_cases_entity as rt 
    WHERE mt.Entity = rt.Entity
);

-- step 6 - dropping entity column
ALTER TABLE infectious_cases_data 
DROP COLUMN Entity;

-- step 7 - setting data table foreign key
ALTER TABLE infectious_cases_data 
ADD CONSTRAINT fk_data_entity 
FOREIGN KEY (entity_id) 
REFERENCES infectious_cases_entity (id);

-- step 8 - setting data table primary key
ALTER TABLE infectious_cases_data 
ADD CONSTRAINT pk_id_year
PRIMARY KEY (entity_id, Year);

-- task 3 - data analyze
-- ---------------------
select 
	e.Entity,
	round(avg(d.Number_rabies), 1) as avg_rabies,
	round(min(d.Number_rabies), 1) as min_rabies,
	round(max(d.Number_rabies), 1) as max_rabies
from infectious_cases_data as d
left join infectious_cases_entity as e on e.id = d.entity_id
group by e.Entity
order by avg_rabies desc
limit 10;

-- task 4 - data analyze
-- ---------------------
select
	CONCAT(Year, '-01-01') as year_start,
    CURDATE() as now,
    TIMESTAMPDIFF(YEAR, CONCAT(Year, '-01-01'), CURDATE()) as year_diff
from infectious_cases_data;

-- task 5.1 - create function
-- --------------------------
-- defining the function
DELIMITER //
CREATE FUNCTION CalculateYearDiff(year int)
RETURNS INT
DETERMINISTIC 
NO SQL
BEGIN
    DECLARE result INT;
    SET result = TIMESTAMPDIFF(year, CONCAT(year, '-01-01'), CURDATE());
    RETURN result;
END //
DELIMITER ;

-- checking the function working
select
	CONCAT(Year, '-01-01') as year_start,
    CURDATE() as now,
    CalculateYearDiff(Year) as year_diff
from infectious_cases_data;

-- task 5.2 - create alternative function
-- --------------------------------------
-- defining the function
DELIMITER //
CREATE FUNCTION divide_func(divided double, divider int)
RETURNS double
DETERMINISTIC 
NO SQL
BEGIN
    DECLARE result double;
    SET result = divided / divider;
    RETURN result;
END //
DELIMITER ;

select
	Year,
    round(sum(Number_rabies), 1) as year_qty,
    round(divide_func(sum(Number_rabies), 12), 1) as month_qty,
    round(divide_func(sum(Number_rabies), 2), 1) as half_year_qty,
    round(divide_func(sum(Number_rabies), 4), 1) as qtr_qty
from infectious_cases_data
group by Year
having year_qty is not null
order by Year;

