SELECT cohort_year,
       COUNT(DISTINCT customerkey)                          AS total_customers,
       SUM(total_net_revenue)                               AS total_revenue,
       SUM(total_net_revenue) / COUNT(DISTINCT customerkey) AS customer_revenue
FROM cohort_analysis
WHERE orderdate = first_purchase_date -- because first day purchase contributes to most revenue of each customer
GROUP BY cohort_year

