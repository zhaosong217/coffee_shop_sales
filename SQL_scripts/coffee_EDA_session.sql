/*
**********************************************************************************
Exploratory Data Analysis Session

In this section, we will explore the data to gain insights and understand
the patterns and trends in the dataset.

It includes the following aspects:
1. Store Performance Comparison
    - Total revenue
    - Total transaction quantity
    - Average transaction value (ATV)
    - Peak vs Off-peak transaction time
    - Month-on-Month vs Quarter-on-Quarter by store
2. Product Performance Comparison
    - Top-selling vs bottom-selling products (by transaction and revenue)
    - Average quantity of each transaction
    - Product category performance
    - Product type performance
**********************************************************************************
*/

-- 1. Store Performance Comparison
-- Total revenue, transaction quantity and ATV
SELECT
    store_id,
    store_location,
    SUM(revenue) AS total_revenue,
    SUM(transaction_qty) AS total_transactions,
    ROUND(SUM(revenue)::NUMERIC/COUNT(DISTINCT transaction),3) AS avg_transaction_value
FROM
    coffee_shop_sales
GROUP BY
    store_id,
    store_location
ORDER BY
    total_revenue DESC;

-- 1.2 Peak vs Off-peak transaction hour
SELECT
    month,
    day_of_week,
    hour,
    store_location,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue
FROM
    coffee_shop_sales
GROUP BY
    month,
    day_of_week,
    hour,
    store_location
ORDER BY
    TO_DATE(month, 'Month'),
    CASE LOWER(day_of_week)
        WHEN 'monday'    THEN 1
        WHEN 'tuesday'   THEN 2
        WHEN 'wednesday' THEN 3
        WHEN 'thursday'  THEN 4
        WHEN 'friday'    THEN 5
        WHEN 'saturday'  THEN 6
        WHEN 'sunday'    THEN 7
        ELSE 8
    END,
    hour;

-- 1.3 Month-on-Month vs Quarter-on-Quarter
-- MoM per store
WITH store_monthly_revenue AS (
    SELECT
        store_id,
        store_location,
        month,
        SUM(revenue) AS total_revenue
    FROM
        coffee_shop_sales
    GROUP BY
        store_id,
        store_location,
        month
)
SELECT
    store_id,
    store_location,
    month,
    total_revenue,
    LAG(total_revenue) OVER (PARTITION BY store_id ORDER BY TO_DATE(month, 'Month')) AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (PARTITION BY store_id ORDER BY TO_DATE(month, 'Month')))::NUMERIC /
        LAG(total_revenue) OVER (PARTITION BY store_id ORDER BY TO_DATE(month, 'Month')),
        3) AS mom_revenue_growth
FROM
    store_monthly_revenue
ORDER BY
    store_id,
    TO_DATE(month, 'Month');

-- adding quarter column for better gethering
ALTER TABLE coffee_shop_sales
ADD COLUMN quarter VARCHAR(2);

UPDATE coffee_shop_sales
SET quarter = CASE
                WHEN month IN ('January', 'February', 'March') THEN 'Q1'
                WHEN month IN ('April', 'May', 'June') THEN 'Q2'
            END;

-- quarter-on-quarter per store
WITH store_quarterly_revenue AS (
    SELECT
        store_id,
        store_location,
        quarter,
        SUM(revenue) AS total_revenue
    FROM
        coffee_shop_sales
    GROUP BY
        store_id,
        store_location,
        quarter
)
SELECT
    store_id,
    store_location,
    quarter,
    total_revenue,
    LAG(total_revenue) OVER (PARTITION BY store_id ORDER BY quarter) AS prev_quarter_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (PARTITION BY store_id ORDER BY quarter))::NUMERIC /
        LAG(total_revenue) OVER (PARTITION BY store_id ORDER BY quarter),
        3) AS qtr_revenue_growth
FROM
    store_quarterly_revenue
ORDER BY
    store_id,
    quarter;

-- **********************************************************************************

-- 2. Product Performance Comparison
-- 2.0 Top-selling vs bottom-selling products (by transaction and revenue)
SELECT
    RANK() OVER (PARTITION BY product_category 
        ORDER BY SUM(revenue) DESC, COUNT(transaction_id) DESC) 
        AS rank_by_revenue,
    product_detail,
    product_category,
    COUNT(DISTINCT transaction_id) AS total_transactions,
    SUM(revenue) AS total_revenue
FROM
    coffee_shop_sales
GROUP BY
    product_category,
    product_detail;

-- 2.1 Average quantity per transaction 
-- by each store
SELECT
    store_id,
    store_location,
    ROUND(SUM(transaction_qty)::NUMERIC/COUNT(DISTINCT transaction),3) AS avg_transaction_qty
FROM
    coffee_shop_sales
GROUP BY
    store_id,
    store_location;

-- by each day of week and hour
SELECT
    store_location,
    month,
    day_of_week,
    hour,
    ROUND(SUM(transaction_qty)::NUMERIC/COUNT(DISTINCT transaction),3) AS avg_transaction_qty
FROM
    coffee_shop_sales
GROUP BY
    store_location,
    month,
    day_of_week,
    hour
ORDER BY
    CASE LOWER(day_of_week)
        WHEN 'monday'    THEN 1
        WHEN 'tuesday'   THEN 2
        WHEN 'wednesday' THEN 3
        WHEN 'thursday'  THEN 4
        WHEN 'friday'    THEN 5
        WHEN 'saturday'  THEN 6
        WHEN 'sunday'    THEN 7
        ELSE 8
    END,
    hour;

-- 2.2 Transactions, revenue and ATV of each product category
SELECT
    product_category,
    COUNT(DISTINCT product_type) AS total_product_types,
    COUNT(DISTINCT product_detail) AS total_products,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC/SUM(transaction_qty),3) AS avg_transaction_value
FROM
    coffee_shop_sales
GROUP BY
    product_category
ORDER BY
    total_revenue DESC;

ALTER TABLE coffee_shop_sales
ADD COLUMN category VARCHAR(20);

UPDATE coffee_shop_sales
SET category = CASE
        WHEN product_category IN ('Coffee', 'Tea', 'Loose Tea', 'Drinking Chocolate', 'Flavours') THEN 'Beverages'
        WHEN product_category IN ('Bakery', 'Packaged Chocolate') THEN 'Snacks'
        ELSE 'Merchandise'
    END;
/*
From the results, we can see that coffee and tea provide the most 
revenue and transactions.

For a cafe shop, the more general product categories are beverages, snacks and merchandies.
Next, let's combine them to check the performances of them.

Beverages:
Coffee, Tea, Loose Tea, Drinking Chocolate and Flavours

Snacks:
Bakery, Packaged Chocolate

Merchandies:
Coffee beans, Branded
*/
SELECT
    RANK() OVER (PARTITION BY category ORDER BY SUM(revenue) DESC) AS rank_by_revenue,
    category,
    product_detail,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value    
FROM
    coffee_shop_sales
GROUP BY
    category,
    product_detail;

-- 2.3 Product type performance
/*
From the results before, we know that beverages are the major revenue contributors.
Next, let's break down the performance of each product type in beverages category.
*/
SELECT
    product_type,
    COUNT(DISTINCT product_detail) AS total_products,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_category IN ('Coffee', 'Tea', 'Loose Tea', 'Drinking Chocolate', 'Flavours')
GROUP BY
    product_type
ORDER BY
    total_revenue DESC;
/*
Funny things that there are obviously top 3 product types in beverages category:
1. Barista Espresso (revenue over 91k)
2. Brewed Chai tea & Hot chocolate & Gourmet brewed coffee (revenue over 70k)
3. Brewed Black tea & Brewed herbal tea (revenue over 47k)

Let's dive into more deeper to get the most popular product 
in this top 3 product types of beverages
*/

-- top products of beverages
SELECT
    product_detail,
    product_type,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue
FROM
    coffee_shop_sales
WHERE
    product_type IN ('Barista Espresso', 'Brewed Chai tea', 'Hot chocolate', 
    'Gourmet brewed coffee', 'Brewed Black tea', 'Brewed herbal tea')
GROUP BY
    product_detail,
    product_type
ORDER BY
    total_revenue DESC;

-- bottom products of beverages
SELECT
    product_detail,
    product_type,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_type IN ('Chai tea', 'Herbal tea',
    'Black tea', 'Green tea')
GROUP BY
    product_detail,
    product_type
ORDER BY
    total_revenue ASC;

-- Then, is about the Snacks category
SELECT
    product_type,
    product_category,
    COUNT(DISTINCT product_detail) AS total_products,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_category IN ('Bakery', 'Packaged Chocolate')
GROUP BY
    product_category,
    product_type
ORDER BY
    total_revenue DESC;

-- Bakery offers the most revenue in snacks category.
-- Dive into Bakery and Packaged Chocolate respectively.
-- Bakery
SELECT
    product_detail,
    product_type,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_category = 'Bakery'
GROUP BY
    product_detail,
    product_type
ORDER BY
    total_revenue DESC;

-- Packaged Chocolate
SELECT
    product_detail,
    product_type,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_category = 'Packaged Chocolate'
GROUP BY
    product_detail,
    product_type
ORDER BY
    total_revenue DESC;


-- Last, is about the Merchandies category
SELECT
    product_detail,
    product_type,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_category IN ('Coffee beans', 'Branded')
GROUP BY
    product_detail,
    product_type
ORDER BY
    total_revenue DESC;

-- Coffee beans
SELECT
    product_detail,
    product_type,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_category = 'Coffee beans'
GROUP BY
    product_detail,
    product_type
ORDER BY
    total_revenue DESC;

-- Branded
SELECT
    product_detail,
    product_type,
    SUM(transaction_qty) AS total_transactions,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue)::NUMERIC / SUM(transaction_qty), 3) AS avg_transaction_value
FROM
    coffee_shop_sales
WHERE
    product_category = 'Branded'
GROUP BY
    product_detail,
    product_type
ORDER BY
    total_revenue DESC;