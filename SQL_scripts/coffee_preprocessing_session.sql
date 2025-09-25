-- the general overview of this table
SELECT * FROM coffee_shop_sales
LIMIT 10;

-- checking the total rows: 149116
SELECT COUNT(*) FROM coffee_shop_sales;

-- checking the duplicated of transaction_id: no duplicated
SELECT
    transaction_id,
    COUNT(*)
FROM
    coffee_shop_sales
GROUP BY
    transaction_id
HAVING 
    COUNT(*) > 1;

-- checking the NULL value: no NULL value
SELECT
    *
FROM
    coffee_shop_sales
WHERE
    transaction_id IS NULL
    OR transaction_date IS NULL
    OR transaction_time IS NULL
    OR transaction_qty IS NULL
    OR store_id IS NULL
    OR store_location IS NULL
    OR product_id IS NULL
    OR unit_price IS NULL
    OR product_category IS NULL
    OR product_type IS NULL
    OR product_detail IS NULL;

-- checking the outliers: no outliers
SELECT
    *
FROM 
    coffee_shop_sales
WHERE
    transaction_qty <= 0
    OR unit_price <= 0;

-- checking the date range: 2023-01-01 TO 2023-06-30
SELECT 
    MIN(transaction_date),
    MAX(transaction_date)
FROM 
    coffee_shop_sales;

SELECT
    DISTINCT store_id,
    store_location
FROM 
    coffee_shop_sales;

-- checking the shops and shops' id
SELECT
    DISTINCT store_id,
    store_location
FROM
    coffee_shop_sales;
/*
**********************************************************************************
Basic Information:

1. Contains 11 columns include:
transaction_id: the unique identifier for each transaction
transaction_date: the date when the transaction occurred
transaction_time: the time when the transaction occurred
transaction_qty: the quantity of items in the transaction
store_id: the unique identifier for the store where the transaction occurred
store_location: the location of the store where the transaction occurred
product_id: the unique identifier for the product
unit_price: the price of a single unit of the product
product_category: the category of the product
product_type: the category or type of the product
product_detail: the name of the product

2. Contains 149,116 rows without duplicated.

3. No NULL value in any column.

4. No outlier in transaction_qty and unit_price.

5. Records sales from 2023-01-01 to 2023-06-30.

6. There are 3 stores in the dataset: Astoria(id-3), Lower Manhattan(id-5) 
and Hell's Kitchen(id-8)
**********************************************************************************
*/

/*
**********************************************************************************
Pre-processing Session

Because we need to know the sales on monthly, day of week and hourly perspectives,
we should extract month, day of week, and hour from transaction_date and 
transaction_time respectively.
**********************************************************************************
*/

-- adding month, day_of_week and hour columns
ALTER TABLE coffee_shop_sales
ADD COLUMN month INT,
ADD COLUMN day_of_week INT,
ADD COLUMN hour INT;

-- updating month, day_of_week and hour columns
UPDATE coffee_shop_sales
SET month = EXTRACT(MONTH FROM transaction_date),
    day_of_week = EXTRACT(DOW FROM transaction_date),
    hour = EXTRACT(HOUR FROM transaction_time);

-- modify month and day_of_week to more readable format
-- cause the date range is from 2023-01-01 to 2023-06-30,
-- we just need to modify month name from January to June.
ALTER TABLE coffee_shop_sales
ALTER COLUMN month TYPE VARCHAR(20),
ALTER COLUMN day_of_week TYPE VARCHAR(20);

UPDATE coffee_shop_sales
SET month = CASE month
                WHEN '1' THEN 'January'
                WHEN '2' THEN 'February'
                WHEN '3' THEN 'March'
                WHEN '4' THEN 'April'
                WHEN '5' THEN 'May'
                WHEN '6' THEN 'June'
            END,
    day_of_week = CASE day_of_week
                    WHEN '0' THEN 'Sunday'
                    WHEN '1' THEN 'Monday'
                    WHEN '2' THEN 'Tuesday'
                    WHEN '3' THEN 'Wednesday'
                    WHEN '4' THEN 'Thursday'
                    WHEN '5' THEN 'Friday'
                    WHEN '6' THEN 'Saturday'
                END;

-- to be convinient, we can simply calculate the revenue of each transaction
ALTER TABLE coffee_shop_sales
ADD COLUMN revenue NUMERIC(10,2);

UPDATE coffee_shop_sales
SET revenue = transaction_qty * unit_price;

-- checking the duplicated of transaction_date, transaction_time in the same store_id
SELECT
    transaction_date,
    transaction_time,
    store_id,
    COUNT(*) AS time_count
FROM
    coffee_shop_sales
GROUP BY
    transaction_date,
    transaction_time,
    store_id
HAVING
    COUNT(*) > 1
ORDER BY
    transaction_date ASC,
    transaction_time ASC,
    store_id ASC;
/*
Normally, the transaction_id indicates the unique identifier for each transaction, and
each transaction may contain several products. 

However, in this case, each transaction_id only contains one product. So, 
we need to combine the transaction_date, transaction_time and store_id 
as a real transaction identifier.
*/

ALTER TABLE coffee_shop_sales
ADD COLUMN transaction VARCHAR(255);

UPDATE coffee_shop_sales
SET transaction = transaction_date || ' ' || transaction_time || ' ' || store_id;
