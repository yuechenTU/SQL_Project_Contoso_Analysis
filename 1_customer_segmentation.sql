WITH customer_ltv      AS (SELECT customerkey,
                                  cleaned_name,
                                  SUM(total_net_revenue) AS total_LTV
                           FROM cohort_analysis
                           GROUP BY customerkey,
                                    cleaned_name),
     customer_segments AS (SELECT PERCENTILE_CONT(0.25) WITHIN GROUP ( ORDER BY total_LTV ) AS ltv_25th_percentile,
                                  PERCENTILE_CONT(0.75) WITHIN GROUP ( ORDER BY total_LTV ) AS ltv_75th_percentile
                           FROM customer_ltv),
     segment_values    AS (SELECT c.*,
                                  CASE
                                      WHEN c.total_LTV < cs.ltv_25th_percentile
                                          THEN '1 - Low_Value'
                                      WHEN c.total_LTV <= cs.ltv_75th_percentile
                                          THEN '2 - Mid_Value'
                                      ELSE '3 - High_Value'
                                      END AS customer_segment
                           FROM customer_ltv c,
                                customer_segments cs)

SELECT customer_segment,
       SUM(total_ltv)                      AS total_ltv_of_segment,
       COUNT(customerkey)                  AS customer_count,
       SUM(total_ltv) / COUNT(customerkey) AS avg_ltv
FROM segment_values
GROUP BY customer_segment
ORDER BY customer_segment DESC
