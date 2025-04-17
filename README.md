# Intermediate SQL - Sales Analysis

## Overview
Analysis of customer behavior, retention, and lifetime value for an e-commerce company to improve revenue and customer retention

# Tools Used
- **Database**: PostgreSQL (pgAdmin4)
- **Analysis Tools**: PostgreSQL (Datagrip for coding, VS Code for uploading repository), 
- **Visualization**: Tableau 

## Business Questions
1. **Customer Segmentation Analysis**: Who are our most valuable customers?
2. **Cohort Analysis**: How do different customer groups generate revenue?
3. **Retention Analysis**: Who hasn't purchased recently?

## Data Preparation
- join sales and customer data and aggregate sales data
    - calculate total_net_revenue and number of order for each customer and order date
- clean and format customer info
    trim and combine given name and surname into a cleaner full name
- calculate first purchase date that helps to group customers into cohorts year
- create a view of above for next analysis

**Query**: [0_create_view](/0_view.sql)
```sql
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


```


## Analysis Approach

### 1. Customer Segmentation Analysis
- To assign customers to High, Mid, and Low value segments based on lifetime value(LTV) percentile
    - High_Value : LTV > 75th percentile
    - Mid_Value : 25th percentile ≤ LTV ≤ 75th percentile
    - Low_Value: LTV < 25th percentile
- calculated key metrics: total ltv of each segment and average ltv of each customer in different segment


**Query**: [1_customer_segmentations.sql](/1_customer_segmentation.sql)
```sql
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

```

**Visualization:** 
![Customer_segmentation](/images/1_customer_segmentation.jpg)
From Tableau


**Key Findings**
- High_Value segment (25% of customers) contributes $143.99M (65.59%) of total revenue
- Mid_Value segment (50% of customers) contributes $70.90M (32.30%) of total revenue
- Low_Value segment (25% of customers) contributes $4.63M (2.11%) of total revenue


**Business Insights**
- High_value customers are most important, who nearly are driving two_thirds of total revenue
    - To retain these customers, company could invest more VIP programs and services, offer them with relevant high_value products, and encourage reviews and referrals from them
- Mid_value customers are most steady group
    - Focus on turn potential mid_value customers into high_value segment, identify trending items and make more price options, and offer rewards to customers who increased spend
- Low_value customers generates a very small portion of revenue 
    - control cost spending on this group 


### 2. Cohort Analysis
- Tracked revenue and customer count per cohorts
- Cohorts were grouped by year of first purchase (customers are buy most in first year purchase)
- Analyzed customer retention at a cohort level


**Query**: [2_cohort_analysis.sql](/2_cohort_analysis.sql)
```sql
SELECT cohort_year,
       COUNT(DISTINCT customerkey)                          AS total_customers,
       SUM(total_net_revenue)                               AS total_revenue,
       SUM(total_net_revenue) / COUNT(DISTINCT customerkey) AS customer_revenue
FROM cohort_analysis
WHERE orderdate = first_purchase_date -- because first day purchase contributes to most revenue of each customer
GROUP BY cohort_year


```

**Visualization:** 
![Cohort Analysis 1](/images/2_cohort_analysis_1.jpg)
![Cohort Analysis 2](/images/2_cohort_analysis_2.jpg)
From Tableau

**Key Findings:**
- Average Revenue per customer by first purchased year shows an alarming decreasing trend over time, reflected same on total revenue
    - 2022 - 2024 cohorts are consistently performing worse than earlier cohorts
    - Note: Although total revenue is high, this is due to a larger customer base, which is not reflective of customer value

**Business Insights**
- Values extracted from customers is decreasing overtime
- There is a drop in number of customers and revenue in 2023 and 2024, which is concerning
- With both lowering LTV and decreasing customer acquisition, the company is facing a potential revenue decline




### 3. Retention Analysis
- Divided customers into two category, active and churned
    - Active Customer: Customer who made a purchase within the last 6 months(datasets last updates from 2024-4-20)
    - Churned Customer: Customer who hasn't made a purchase in over 6 months
- Calculated number of customers in each category by cohort year


**Query**: [3_retention_analysis.sql](/3_retention_analysis.sql)
```sql
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
```

**Visualization:** 
![Total Customer Retention and Churn](/images/3_retention_analysis_1.jpg)
![Total Customer Retention and Churn by Cohort Year](/images/3_retention_analysis_2.jpg)

**Key Findings**
- Retention is consistently low across all cohort years, with churn rates exceeding 90% in most years, which suggesting retention issues are systemic rather than specific to certain years.
- Active customer percentages are relatively stable over the years (mostly between 8.3%–10.5%), hinting at a fixed pattern of customer behavior that without intervention, future cohorts will follow the same pattern

**Business Insights**
- Customer retention is a major issue: With over 90% of users churning in nearly every cohort, there's a clear need for better post-purchase engagement strategies
- Younger cohorts followed the same pattern, meaning that recent onboarding and marketing efforts may not be significantly improving long-term value
- Implementing automated re-engagement flows (email/SMS), loyalty programs, or personalized offers within 3–6 months post-purchase could help mitigate churn
- Track engagement earlier: Monitoring behavior within the first 1–3 months may help predict and prevent churn before it happens.


## Acknowledgements
This is the project guided by Luke Barousse's Intermediate SQL Course. 

Here's the Datasets used:
[Contoso Dataset](/contoso_100k.sql)
