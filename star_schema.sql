-- Olist E-Commerce: Star Schema SQL
-- Extracted from the SQL transformations in notebooks/olist_cohort_analysis.ipynb
-- Run after loading the source tables into SQLite as stg_customers, stg_orders,
-- stg_payments, and stg_reviews.

-- 1. Customer and payment dimensions
DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer AS
SELECT customer_unique_id AS customer_key,
       MAX(customer_state) AS state,
       MAX(customer_city) AS city
FROM stg_customers
GROUP BY customer_unique_id;

DROP TABLE IF EXISTS dim_payment_type;
CREATE TABLE dim_payment_type AS
SELECT ROW_NUMBER() OVER (ORDER BY payment_type) AS payment_type_key,
       payment_type
FROM (SELECT DISTINCT payment_type FROM stg_payments);

-- 2. Date dimension (generated in Python in the notebook)
-- The notebook generates dates from 2016-09-01 through 2018-12-31
-- and writes the resulting dataframe to dim_date.

-- 3. Orders fact table
DROP TABLE IF EXISTS fact_orders;
CREATE TABLE fact_orders AS
WITH pay AS (
    SELECT order_id,
           SUM(payment_value) AS payment_value,
           MAX(payment_installments) AS installments,
           COUNT(*) AS n_payments
    FROM stg_payments
    GROUP BY order_id
),
main_type AS (
    SELECT order_id, payment_type
    FROM (
        SELECT order_id, payment_type,
               ROW_NUMBER() OVER (
                   PARTITION BY order_id ORDER BY payment_value DESC
               ) AS rn
        FROM stg_payments
    )
    WHERE rn = 1
),
rev AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM stg_reviews
    GROUP BY order_id
)
SELECT o.order_id,
       c.customer_unique_id AS customer_key,
       DATE(o.order_purchase_timestamp) AS date_key,
       pt.payment_type_key,
       o.order_status,
       p.payment_value,
       p.installments,
       p.n_payments,
       r.review_score,
       julianday(o.order_delivered_customer_date)
         - julianday(o.order_purchase_timestamp) AS delivery_days
FROM stg_orders o
JOIN stg_customers c ON c.customer_id = o.customer_id
LEFT JOIN pay p ON p.order_id = o.order_id
LEFT JOIN main_type m ON m.order_id = o.order_id
LEFT JOIN dim_payment_type pt ON pt.payment_type = m.payment_type
LEFT JOIN rev r ON r.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable');
