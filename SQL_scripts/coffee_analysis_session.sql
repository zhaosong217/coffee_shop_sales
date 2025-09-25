/*
**********************************************************************************
Analysis Session

In this section, we'll handle with two things:
1. Market Basket Analysis
    To discover which product combo is the most popular
2. Product price sensitivity analysis
    Under the same category or the same type to analysis 
    the selling of products with different prices)

Why it matters?
These two directly impact the sales and customer behavior, so we need to analyze them separately.
**********************************************************************************
*/

-- 1. Market Basket Analysis
/*
The first task in Market Basket Analysis is combining each transaction with the same date, same time and in the same store.
We can use the 'transaction' column we created in the pre-processing session.
*/

-- Combining product categories in the same transaction
SELECT
    transaction,
    store_id,
    store_location,
    STRING_AGG(product_category, ', ') AS product_cate_combo,
    SUM(revenue) AS revenue
FROM
    coffee_shop_sales
GROUP BY
    transaction,
    store_id,
    store_location,
    transaction
HAVING
    COUNT(product_category) > 1
ORDER BY
    transaction;

-- The top combo sellings
SELECT
    product_cate_combo,
    COUNT(product_cate_combo) AS combo_transaction,
    SUM(revenue) AS total_revenue,
    -- ATV here indicate the average transaction value of each combo transaction
    ROUND(SUM(revenue)::numeric/COUNT(product_cate_combo), 2) AS avg_transaction_value
FROM (
    SELECT
        STRING_AGG(product_category, ', ' ORDER BY product_category) AS product_cate_combo,
        SUM(revenue) AS revenue
    FROM
        coffee_shop_sales
    GROUP BY
        transaction
    HAVING
        COUNT(product_category) > 1
)
GROUP BY
    product_cate_combo
ORDER BY
    total_revenue DESC
LIMIT 7;

/*
Insights & Decision-makings:
1. The results show that Coffee & Bakery combo or Tea & Bakery combo 
is the most popular, which provided the topest revenue. Maybe we can
offer some discount or special promotion to these combo products.

For example, based on deeper research, put the tail selling products in Coffee
and Bakery together to create a combo product. This would decrease the 
stocks of these products, and increase the number of transactions.

2. We can dive into Coffee & Flavours combo to get the most popular product in this combo.
This indicates the desire flavour of the customers which can help us 
to adjust the menu, or developing new flavours to customers.

3. Coffee/Tea & Coffee beans is an interesting combo product.
It seems that the customers who buy coffee also buy coffee beans.
This may indicate that the customers are more interested in the quality of the coffee.
We can offer some coffee beans discount based on membership points program. 
*/

-- **********************************************************************************
-- 2. Product Price Sensitivity analysis
/*
Price sensitivity measures how much demand changes when the price of a product changes.
- If consumers react strongly to small price changes (buy less when prices rise, buy more when prices fall), 
    the product is highly price sensitive.
- If demand remains steady even after price changes, the product is considered price insensitive

Influencing Factors
- Type of product (necessities often less sensitive than luxuries)
- Brand reputation and perceived quality
- Consumer purchasing power
- Market competition and availability of alternatives
- Economic and social conditions

Influencing Factors (to be discussed in insights):
- Type of product (necessities often less sensitive than luxuries)
- Brand reputation and perceived quality
- Consumer purchasing power
- Market competition and availability of alternatives
- Economic and social conditions
- Concurrent promotions or events not captured in the dataset.
*/

-- First, let's check the price range of each product, 
-- filtering more than one unit price
SELECT
    product_detail,
    COUNT(DISTINCT unit_price) AS price_range
FROM
    coffee_shop_sales
GROUP BY
    product_detail
HAVING
    COUNT(DISTINCT unit_price) > 1;

-- Then, checking one of the products with more than one unit price: Chocolate Chip Biscotti
-- Display its daily sales quantity and unit price
SELECT
    transaction_date,
    product_detail,
    unit_price,
    SUM(transaction_qty) AS total_qty
FROM
    coffee_shop_sales
WHERE
    product_detail = 'Chocolate Chip Biscotti'
GROUP BY
    transaction_date,
    product_detail,
    unit_price
ORDER BY
    transaction_date;
/*
From the result, we can get these info:
- Chocolate Chip Biscotti has a price range of 3.50 and 4.38
- Apart from monthly price hikes on 9th day, there are also some days at the hike.

So, in this case, we should use the Within-Day Elasticity of Demand 
to analyze the price sensitivity of Chocolate Chip Biscotti.
It directly measures how consumers respond to different price options.

Formula of Within-Day Elasticity of Demand:
PED = ( (Q_hike - Q_base) / ((Q_base + Q_hike) / 2) ) / ( (P_hike - P_base) / ((P_base + P_hike) / 2) )
    Where:
        Q_base = Quantity demanded before price change
        Q_hike = Quantity demanded after price change
        P_base = Price before change
        P_hike = Price after change

Interpretation:
- |PED| > 1: Elastic Demand (price sensitive) -> Consider lowering price for increased revenue, or raising price for increased profit margin on lower volume.
- |PED| < 1: Inelastic Demand (price insensitive) -> Consider raising price for increased revenue, or maintaining price stability.
- |PED| = 1: Unit Elastic Demand -> Total revenue remains constant with price changes.
*/
-- Now, let's dive into daily sales of Chocolate Chip Biscotti to calculate its arc elastic
-- within the same day, when price hikes from 3.50 to 4.38

-- Aggregation of daily sales quantity and unit price for Chocolate Chip Biscotti
WITH CCB_DailySales AS (
    SELECT
        transaction_date,
        product_detail,
        unit_price,
        SUM(transaction_qty) AS daily_total_qty
    FROM
        coffee_shop_sales
    WHERE
        product_detail = 'Chocolate Chip Biscotti'
    GROUP BY
        transaction_date, product_detail, unit_price
),
-- Comparing daily sales quantity and unit price for Chocolate Chip Biscotti
-- within the same day, when price hikes from 3.50 to 4.38
CCB_WithinDayPriceComparison AS (
    SELECT
        ds_base.transaction_date,
        ds_base.product_detail,
        ds_base.unit_price AS P_base,
        ds_base.daily_total_qty AS Q_base,
        ds_hike.unit_price AS P_hike,
        ds_hike.daily_total_qty AS Q_hike
    FROM
        CCB_DailySales ds_base
    JOIN
        CCB_DailySales ds_hike -- Joining with the same table to compare within the same day
    ON
        ds_base.transaction_date = ds_hike.transaction_date AND
        ds_base.product_detail = ds_hike.product_detail
    WHERE
        ds_base.unit_price = 3.50 AND ds_hike.unit_price = 4.38
)
-- Calculating Arc Elasticity of Demand for Chocolate Chip Biscotti
-- within the same day, when price hikes from 3.50 to 4.38
SELECT
    transaction_date,
    product_detail,
    'Price Hike' AS change_type,
    P_base,
    Q_base,
    P_hike,
    Q_hike,
    -- Arc Elasticity
    ROUND(
        ( (Q_hike - Q_base) / NULLIF(((Q_base + Q_hike) / 2.0), 0) ) /
        ( (P_hike - P_base) / NULLIF(((P_base + P_hike) / 2.0), 0) )
    , 4) AS price_elasticity
FROM
    CCB_WithinDayPriceComparison
WHERE
    Q_base > 0 AND Q_hike > 0 AND P_base != P_hike
ORDER BY
    transaction_date;

/*
Insights & Decision-makings:
1. All of the price elasticity of demand for Chocolate Chip Biscotti are negative (from -7.4621 to -2.2386).
The absolute values are all greater than 1, which means that Chocolate Chip Biscotti is highly price sensitive (elastic). 
A price increase leads to a proportionally larger decrease in sales.

2. It shows that on the day of the price increase, most consumers prefer to keep the original price products. 
This means that such an expensive pricing strategy may be ineffective.

3. If the sales volume after price increase is significantly reduced, it may even result in a loss of total revenue. 
It is suggested to re-evaluate the effectiveness of this short-term pricing strategy, or consider a more gentle price increase.

4. These elasticities are calculated under the assumption of "same day, multiple price options." 
Real price elasticities will also be influenced by various factors such as competitor behavior, marketing activities, 
and seasonal factors.


Important Considerations and Limitations:
- This analysis assumes that price is the *only* variable changing. 
    In reality, other factors like promotions, weather, competitor actions, or store-specific events could also influence demand.
- The dataset's time frame (Jan-Jun) provides limited seasonal insights beyond these months.
*/

/*
Additional Analytics:
From the arc elasticity of demand results, it seems that Chocolate Chip Biscotti is price insensitive, 
price up, sales down. This may casue the loss of total revenue.
But, is it real?
Let's design an experiment to verify it.

Hypothsis:
If the unit price keep the same (3.50), the sales revenue should higher than original(base 3.50 and hike 4.38).

Method:
1. Calculate the mode of sales quantity when price is 3.50.
2. Calculate the original revenue of Chocolate Chip Biscotti when there ara two prices.
3. Calculate the revenue of Chocolate Chip Biscotti when price is 3.50 and sales quantity is the mode of sales quantity.
4. Compare the revenue of Chocolate Chip Biscotti when price is 3.50 and sales quantity is the mode of sales quantity with the original revenue.
*/

WITH temp AS (
    SELECT
        transaction_date,
        product_detail,
        unit_price,
        SUM(transaction_qty) AS total_qty
    FROM
        coffee_shop_sales
    WHERE
        product_detail = 'Chocolate Chip Biscotti' AND
        unit_price = 3.50
    GROUP BY
        transaction_date,
        product_detail,
        unit_price
),
-- When price is 3.50, find out the mode of sales in these days
CCB_mode_sales AS (
    SELECT
        total_qty,
        COUNT(total_qty) AS frequency
    FROM
        temp
    GROUP BY
        total_qty
    ORDER BY
        frequency DESC
    LIMIT 1
),
-- Result, the mode of sales is 8 when price is 3.50
-- Calculate the average of sales quantity when price is 3.50
CCB_avg_sales AS (
    SELECT
        SUM(total_qty)::NUMERIC/COUNT(DISTINCT transaction_date) AS avg_sales
    FROM
        temp
    GROUP BY
        product_detail
),
-- Calculate the original revenue of Chocolate Chip Biscotti when there ara two prices
-- Filter out the dates when Chocolate Chip Biscotti has two different prices
CCB_price_change_dates AS (
    SELECT
        transaction_date
    FROM
        coffee_shop_sales
    WHERE
        product_detail = 'Chocolate Chip Biscotti'
    GROUP BY
        transaction_date
    HAVING
        COUNT(DISTINCT unit_price) > 1
),
-- Calculate the original revenue of Chocolate Chip Biscotti when there are two different prices
CCB_original_revenue AS (
    SELECT
        transaction_date,
        product_detail,
        unit_price,
        SUM(transaction_qty) AS total_qty,
        unit_price * SUM(transaction_qty) AS revenue
    FROM
        coffee_shop_sales
    WHERE
        product_detail = 'Chocolate Chip Biscotti'
        AND transaction_date IN (SELECT transaction_date FROM CCB_price_change_dates)
    GROUP BY
        transaction_date,
        product_detail,
        unit_price
    ORDER BY
        transaction_date ASC
)
-- Calculate the revenue of both
SELECT
    SUM(revenue) AS total_original_revenue,
    (SELECT total_qty FROM CCB_mode_sales) * 3.50 * COUNT(DISTINCT transaction_date) AS revenue_with_mode,
    ROUND((SELECT avg_sales FROM CCB_avg_sales) * 3.50 * COUNT(DISTINCT transaction_date), 2) AS revenue_with_avg
FROM
    CCB_original_revenue
GROUP BY
    product_detail;

/*
Marvellous result:
322.96(original) vs 252.00(keep 3.50 with mode of sales) vs 331.88(keep 3.50 with average of sales)

When selected the mode sales quantity, the total original revenue of Chocolate Chip Biscotti
is higher than the total revenue when price is 3.50!
However, when selected the average of sales quantity, the total original revenue of Chocolate Chip Biscotti
is slightly lower than the total revenue when price is 3.50!

So, the hypothesis is incorrect. The original pricing strategy is more robust.
However, this validation result based on the mode number and average of sales quantity with the days of 3.50 unit price.
The result would be various with other statistics, such as median, or machine learning model.
Creating a predicalbe machine learning model could be a direction of further analysis.
*/
