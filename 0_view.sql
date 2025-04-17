create view cohort_analysis as
WITH customer_revenue AS (
    SELECT s.customerkey,
           s.orderdate,
           SUM((((s.quantity)::DOUBLE PRECISION * s.unitprice) * s.exchangerate)) AS total_net_revenue,
           COUNT(*)                                                               AS number_of_order,
           c.countryfull,
           c.age,
           c.givenname,
           c.surname
    FROM (sales s
             LEFT JOIN customer c ON ((s.customerkey = c.customerkey)))
    GROUP BY s.customerkey, s.orderdate, c.countryfull, c.age, c.givenname, c.surname
    ORDER BY s.customerkey
)
SELECT customerkey,
       orderdate,
       total_net_revenue,
       number_of_order,
       countryfull,
       age,
       CONCAT(TRIM(BOTH FROM givenname), ' ', TRIM(BOTH FROM surname))   AS cleaned_name,
       MIN(orderdate) OVER (PARTITION BY customerkey)                    AS first_purchase_date,
       EXTRACT(YEAR FROM MIN(orderdate) OVER (PARTITION BY customerkey)) AS cohort_year
FROM customer_revenue cr;

