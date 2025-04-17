WITH
    churned_tb AS (SELECT
                       customerkey,
                       cleaned_name,
                       first_purchase_date,
                       cohort_year,
                       MAX(orderdate)                                 AS last_purchase_date, -- find out the most recent purchase of each customer
                       CASE
                           WHEN MAX(orderdate) < (SELECT MAX(orderdate) FROM sales)::DATE - INTERVAL '6 months'
                               THEN 'CHURN'
                               ELSE 'ACTIVE'
                       END                                            AS customer_status,    -- last_purchase_date is in last six month considered as active
                       '2024-04-20'::DATE - first_purchase_date::DATE AS "period_being_customer(days)"
                   FROM
                       cohort_analysis
                   GROUP BY
                       customerkey,
                       first_purchase_date, -- first_purchase_date, cleaned_name, and cohort year are the same for each customer key
                       cleaned_name,
                       cohort_year
                   HAVING
                       first_purchase_date < (SELECT MAX(orderdate) FROM sales)::DATE - INTERVAL '6 months'
                   -- filter out new customers who cannot be qualified as churned
                   ORDER BY
                       customerkey)

SELECT
    customer_status,
    cohort_year,
    COUNT(customerkey)                                                                           AS num_customer,
    SUM(COUNT(customerkey)) OVER (PARTITION BY cohort_year)                                      AS total_customers,
    ROUND(COUNT(customerkey) / SUM(COUNT(customerkey)) OVER (PARTITION BY cohort_year) * 100, 2) AS "rate(%)"
FROM
    churned_tb
GROUP BY
    cohort_year,
    customer_status