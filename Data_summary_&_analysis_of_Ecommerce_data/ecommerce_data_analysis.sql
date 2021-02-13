------ Data exploration of the Ecommerce dataset -----
	
	--- Data downloaded from kaggle (https://www.kaggle.com/lissetteg/ecommerce-dataset) -----------
		
		--- Data was imported via RPostgreSQL -------


														--- Observing the raw data-----

select
*
from
ecommerce_data
limit 10;

													----- Data editing and cleaning -----


----- Trimming and editing the character field (Description and Country) and updating it in the dataset


--1. Trimming spaces and editing the word cases for consistency


update ecommerce_data
set "Description" = trim(initcap("Description"))
;
commit;

update ecommerce_data
set "Country" = trim(initcap("Country"))
;
commit;


--2. Adding 'Data_not_available' to empty Description field cells


update ecommerce_data
set "Description" = 'Data_not_available'
where "Description" = ''
;
commit;


-- Converting the InvoiceDate field from text (default) to date


ALTER TABLE ecommerce_data 
ALTER COLUMN "InvoiceDate" TYPE DATE using "InvoiceDate"::DATE;
commit;


												---- Basic Data Profiling of the Ecommerce data -----


---1. Obtaining the data types of different fields in the dataset


select
column_name,
data_type
from
information_schema."columns"
where table_name = 'ecommerce_data'
;

 
---2. Total row counts having non-null values in the data


select
sum(case when "InvoiceNo" is not null then 1 else 0 end) as Invoice_not_null_count,
sum(case when "Description" is not null then 1 else 0 end) as Description_not_null_count,
sum(case when "CustomerID" is not null then 1 else 0 end) as Customer_not_null_count,
sum(case when "StockCode" is not null then 1 else 0 end) as StockCode_not_null_count,
sum(case when "Quantity" is not null then 1 else 0 end) as Quantity_not_null_count,
sum(case when "UnitPrice" is not null then 1 else 0 end) as UnitPrice_not_null_count,
sum(case when "InvoiceDate" is not null then 1 else 0 end) as Date_not_null_count,
sum(case when "Country" is not null then 1 else 0 end) as Country_not_null_count
FROM ecommerce_data;


-- There seem to be empty rows in the CustomerID field suggesting no information available----


---3. Distinct counts of some important fields 


select
count(distinct "Country") as Countries,
count(distinct "CustomerID") as Customers,
count(distinct "Description") as Description_items
from
ecommerce_data
where "InvoiceDate" >= '2011-01-01'
;


---- Data summarization is provided in different parts of the base report and hence not done separately as part of Data Profiling 
  

												----- Base report for ecommerce data ------

 ----- Exploring the table

select
*
from
ecommerce_data
limit 10
;
        
--- Number of rows-----

select
count(*)
from
ecommerce_data
;


-----1. Exploring and summarsing the revenue generated (KPI) for the year 2011


---- Creating a temporary table for generating the revenue summary based on different fields


create temp table revenue_item_type as (
SELECT 
dense_rank () over (order by sum("UnitPrice" * "Quantity")::numeric desc) as item_rank,
initcap("Description") as Item_description,
"Country" as Country,
round(sum("UnitPrice" * "Quantity")::numeric,3) AS revenue
  FROM ecommerce_data
  where "CustomerID" is not null and "InvoiceDate" >= '2011-01-01'
  group by "Description","Country"
  order by revenue desc
  );
  
 ---- a1.1 Revenue by Item type (Description)
 
  SELECT 
Item_description as Items,
revenue as Revenue
  FROM revenue_item_type
  order by Revenue Desc
; 
 
 ---- a1.2 Top 20 items generating the maximum revenue
   
  SELECT 
Item_description as items, 
revenue as Revenue
  FROM revenue_item_type
  limit 20
  ;
 
 ---- a2.1 Revenue by Country
 
 SELECT 
dense_rank() over (order by sum(revenue) desc) as country_rank,
 Country,
round(sum(revenue)::numeric,2) as revenue
  FROM revenue_item_type
  where Country <> 'Unspecified'
  group by Country
  order by sum(revenue) desc;
  
 
 ---- a2.2 Top 10 countries generating the maximum revenue
 
 SELECT 
country_rank,
 Country,
 revenue
 from
(select
dense_rank() over (order by sum(revenue) desc) as country_rank,
 Country,
sum(revenue) as revenue
  FROM revenue_item_type
  group by Country
  order by sum(revenue) desc) subq
  limit 10
  ;
  
 
 ----- 3. Weekly Revenue -------
 
 
 SELECT 
 DATE_TRUNC('week', "InvoiceDate") :: DATE AS delivr_week,
 round(sum("UnitPrice" * "Quantity")::numeric,3) AS revenue
 FROM ecommerce_data
 where DATE_TRUNC('year',"InvoiceDate")::date  >= '2011-01-01'
 group by delivr_week
 order by delivr_week
 ;


 ----- 4. Monthly revenue for the year 2011 -------


-- 4.1 --- Average revenue (overall)


with avg_monthly_revenue as (
  SELECT
     DATE_TRUNC('month', "InvoiceDate") :: DATE AS delivr_month,
     round(sum("UnitPrice" * "Quantity")::numeric,3) AS revenue
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01'
 group by delivr_month
 order by delivr_month)
SELECT
    round(avg(coalesce(revenue,0)),2) as avg_monthly_revenue
FROM avg_monthly_revenue
;


-- 4.2 Monthly avgerage revenue for the year 2011---

 SELECT 
 months_2011,
 revenue
 from(
 select
 to_char("InvoiceDate",'FMMonth') as months_2011,
  DATE_TRUNC('month', "InvoiceDate") :: DATE as delivr_month,
  round(sum("UnitPrice" * "Quantity")::numeric,3) AS revenue
 FROM ecommerce_data
 where "InvoiceDate" >= '2011-01-01'
 group by months_2011,delivr_month
 ) subq
order by delivr_month;


----- 5. Revenue by Quarters for the year 2011


SELECT 
to_char("InvoiceDate",'"Q"Q YYYY') as deliver_quarter,
  round(sum("UnitPrice" * "Quantity")::numeric,3) AS revenue
 FROM ecommerce_data
 where DATE_TRUNC('year',"InvoiceDate")::date  >= '2011-01-01'
 group by deliver_quarter
 having round(sum("UnitPrice" * "Quantity")::numeric,3) > 0
 order by deliver_quarter
 ;

 ----- 5.b Quarterly revenue by country for the year 2011
 
select
country,
sum(case when deliver_quarter = 'Q1 2011' then revenue end) as Quarter_1,
sum (case when deliver_quarter = 'Q2 2011' then revenue end) as Quarter_2,
sum (case when deliver_quarter = 'Q3 2011' then revenue end) as Quarter_3,
sum (case when deliver_quarter = 'Q4 2011' then revenue end) as Quarter_4
from (
SELECT 
"Country" as country,
to_char("InvoiceDate",'"Q"Q YYYY') as deliver_quarter,
  round(sum("UnitPrice" * "Quantity")::numeric,3) AS revenue
 FROM ecommerce_data
 where DATE_TRUNC('year',"InvoiceDate")::date  >= '2011-01-01'
 group by deliver_quarter,country
 having round(sum("UnitPrice" * "Quantity")::numeric,3) > 0
 order by deliver_quarter) subq
group by deliver_quarter,country;
  

----- 6. Montly growth (rate) in revenue for the year 2011 ------


with monthly_data as (
select
date_trunc('month',"InvoiceDate")::date as months,
round(sum("UnitPrice" * "Quantity")::numeric,3) as revenue
from
ecommerce_data
where "InvoiceDate" >= '2011-01-01'
group by months
order by months),
monthly_lag_data as (
select
months,
revenue,
greatest(lag(revenue) over (order by months),1) as lag_revenue
from
monthly_data)
select
months,
revenue,
(revenue - lag_revenue)::numeric/ lag_revenue as Growth_rate
from
monthly_lag_data 
;


------ 7. Five best items based on revenue for each month in the year 2011 ----


with ranking_goods_revenue as (
SELECT
    "Description" as description,
    DATE_TRUNC('month', "InvoiceDate") :: DATE as delivr_month,
    to_char("InvoiceDate",'FMMonth YYYY') as months,
    round(SUM("UnitPrice" * "Quantity")::numeric,3) AS revenue
  FROM ecommerce_data
 where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY description,delivr_month,months
  ORDER BY revenue  desc)
  select sub_q.* 
  from
 (select
 description as Product_name,
  months as Month,
  dense_rank() over (partition by delivr_month order by revenue desc) as Rank,
  revenue
  from
  ranking_goods_revenue) sub_q
  where Rank <=5
  ;

													--------- User related metrics for the year 2011 ---------
 
 --1. New Customer registrations per month ----
 
WITH reg_dates AS (
  SELECT
    "CustomerID",
    MIN("InvoiceDate")::date AS reg_date
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01'
  GROUP BY "CustomerID"),
  regs AS (
  select
   DATE_TRUNC('month', reg_date) :: DATE as reg_month,
   COUNT(DISTINCT "CustomerID") AS regs
  FROM reg_dates
  GROUP BY reg_month)
SELECT
  to_char(reg_month, 'FMMonth') AS reg_month_2011,
  regs
FROM regs
ORDER BY extract ('month' from reg_month) ASC; 


--- Distinct Customers added each month in the year 2011 (presented as Cumulative sum)

WITH reg_dates AS (
  SELECT
    "CustomerID",
    MIN("InvoiceDate")::date AS reg_date
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01'
  GROUP BY "CustomerID"),
  regs AS (
  select
   DATE_TRUNC('month', reg_date) :: DATE as reg_month,
   COUNT(DISTINCT "CustomerID") AS regs
  FROM reg_dates
  GROUP BY reg_month)
SELECT
  to_char(reg_month, 'FMMonth') AS reg_month,
  regs,
  SUM(regs) OVER (ORDER BY reg_month ASC) AS customer_no_cumulative
FROM regs
ORDER BY extract ('month' from reg_month) ASC; 


--- Comparing Montly Average Customers of the current and previous months in the year 2011

 with mau AS (
  SELECT
    DATE_TRUNC('month', "InvoiceDate") :: DATE AS reg_month,
    COUNT(DISTINCT "CustomerID") AS current_customer_count
  from ecommerce_data
  where "InvoiceDate" >= '2011-01-01'
  GROUP BY reg_month)
SELECT
  to_char(reg_month,'FMMonth') as months_2011,
  current_customer_count,
  COALESCE(
    LAG(current_customer_count) OVER (ORDER BY reg_month ASC),
  0) AS previous_customer_count
FROM mau
ORDER BY reg_month ASC;


------ Monthly Growth rate in number of customers

 with mau AS (
  SELECT
    DATE_TRUNC('month', "InvoiceDate") :: DATE AS reg_month,
    COUNT(DISTINCT "CustomerID") AS current_customer_count
  from ecommerce_data
  WHERE "InvoiceDate" >= '2011-01-01'
  GROUP BY reg_month),
  mau_with_lag AS (
  SELECT
    reg_month,
    current_customer_count,
    COALESCE(
      LAG (current_customer_count) over (order by reg_month),
    1) AS previous_customer_count
  FROM mau)
select
current_customer_count,
    TO_CHAR(reg_month,'FMMonth YYYY') as month, 
   (current_customer_count -  previous_customer_count)::numeric/ previous_customer_count AS growth_rate
FROM mau_with_lag
ORDER BY reg_month;


------ Monthly Retention Rate of Customers

WITH user_monthly_activity AS (
  SELECT DISTINCT
    DATE_TRUNC('month',"InvoiceDate") :: DATE AS delivr_month,
    "CustomerID" as user_id
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01')
SELECT
  previous.delivr_month,
  ROUND(
    COUNT(DISTINCT current.user_id) :: NUMERIC /
    GREATEST(COUNT(DISTINCT previous.user_id), 1),
  2) AS retention_rate
FROM user_monthly_activity AS previous
LEFT JOIN user_monthly_activity AS current
ON previous.user_id = current.user_id
AND previous.delivr_month = (current.delivr_month - INTERVAL '1 month')
GROUP BY previous.delivr_month
ORDER BY previous.delivr_month ASC;


												---------------- Unit Economics -------------------

------- Overall average revenue per customer 
 

with avg_rev_customer as  (
  SELECT
    "CustomerID",
    SUM("UnitPrice" * "Quantity") AS revenue
  FROM ecommerce_data
  where "CustomerID" is not null and "InvoiceDate" >= '2011-01-01'
  GROUP BY "CustomerID")
SELECT ROUND(avg(revenue) :: numeric, 2) AS avg_revenue_per_customer
FROM avg_rev_customer;


------ Average revenue per customer for each month in the year 2011 


WITH avg_rev_cust_month AS (
  SELECT
    DATE_TRUNC('month', "InvoiceDate") :: DATE AS month,
    SUM("UnitPrice" * "Quantity") AS revenue,
    COUNT(DISTINCT "CustomerID") AS users
  from ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  group by month)
SELECT
 to_char(month, 'FMMonth YYYY') as month_2011,
 ROUND(
    revenue :: NUMERIC / GREATEST(users, 1),
  2) AS avg_revenue_customer
FROM avg_rev_cust_month
ORDER BY month ASC;


------ Average revenue per customer for each country 


--a. Average revenue and number of customers for each country 

select
"Country" as country,
round(sum("UnitPrice" * "Quantity")::numeric,2) as revenue,
count(distinct "CustomerID") as customers
from
ecommerce_data
where "InvoiceDate" >= '2011-01-01' and "Country" not like 'Unspecified' and "CustomerID" is not null
group by country
order by customers desc
;

--b. Average revenue per customer for each country

with avg_rev_cust_country as (
select
"Country" as country,
round(sum("UnitPrice" * "Quantity")::numeric,2) as revenue,
count(distinct "CustomerID") as customers
from
ecommerce_data
where "InvoiceDate" >= '2011-01-01' and "Country" not like 'Unspecified' and "CustomerID" is not null
group by country
order by customers desc
)
select
trim(country) as country_name,
revenue as revenue_country,
customers as customer_number,
round(revenue::numeric/greatest(customers,1),2) as avg_rev_cust_country
from
avg_rev_cust_country
order by avg_rev_cust_country desc
;


										--------------- Customer trends using categorization and bucketing --------------------


---a. Number of customers  with their corresponding number of orders 


 with customer_orders as (
 SELECT
    "CustomerID",
    COUNT(DISTINCT "InvoiceNo") AS number_of_orders
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY "CustomerID"
  order by "CustomerID"
  )
  select
  number_of_orders,
  count(distinct "CustomerID") as customer_number
  from
 customer_orders
  group by number_of_orders
  order by number_of_orders
   ;
   
 ----b. Revenue classes and respective number of customers
 
 --b1. based on Single revenue class
 
  WITH customer_revenues AS (
  SELECT
    "CustomerID",
     SUM("UnitPrice" * "Quantity") AS revenue
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY "CustomerID")
SELECT
  trunc(revenue :: NUMERIC, -3) AS revenue_category,
  COUNT(DISTINCT "CustomerID") AS customers
FROM customer_revenues
GROUP BY revenue_category
ORDER BY revenue_category ASC;

--b2. based on Revenue class intervals

 WITH customer_revenues AS (
  SELECT
    "CustomerID",
     SUM("UnitPrice" * "Quantity") AS revenue
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY "CustomerID"),  
bins AS (
      SELECT generate_series(0,300000, 50000) AS lower_class,
             generate_series(50000,350000, 50000) AS upper_class)
SELECT lower_class, upper_class, count(revenue) as customer_number
  FROM bins
  LEFT JOIN customer_revenues
  ON revenue >= lower_class 
 AND revenue <= upper_class
GROUP BY lower_class, upper_class
ORDER BY lower_class;
 

----------------------- Observing Customer trends based on revenue and order (numbers) buckets --------------

-- For generating buckets, revenue distribution trends are first observed by using some aggregate measures

--1. Based on Revenue

	--a1. Generating a temporary table 

drop table if exists customer_revenues;

create temp table customer_revenues as (
  SELECT
   "CustomerID" as customer_id,
     SUM("UnitPrice" * "Quantity") AS revenue
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY "CustomerID")

  
  --a2. Obtaining some aggregate measures for generating buckets

  select
  round(min(revenue)::numeric,2) as min_revenue,
  round(percentile_cont(0.50) within group (order by revenue):: numeric,2) as median_revenue,
  round(avg(revenue)::numeric,2) as avg_revenue,
  round(max(revenue)::numeric,2) as max_revenue
  from
  customer_revenues;  

  --a3. Three buckets are created based on the aggregates obtained above 

SELECT
  CASE
    WHEN revenue <= 672 THEN 'Low-revenue users'
    WHEN revenue >= 672.1 and revenue <= 2110 THEN 'Mid-revenue users'
    when revenue >= 2110.1 then 'High-revenue users'
    END AS revenue_group,
  count (distinct customer_id) as customers
FROM customer_revenues
GROUP BY revenue_group
order by customers desc;


--2. Based on number of orders

--a1. Creating a temporary table 

drop table if exists customer_orders;

create temp table customer_orders as (
 SELECT
    "CustomerID" as customer_id,
    COUNT(DISTINCT "InvoiceNo") AS orders_count
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY "CustomerID"
  order by "CustomerID"
  )
  
 --a2. Obtaining some aggregate measures for generating buckets

  select
  round(min(orders_count)::numeric,2) as min_count,
  round(percentile_cont(0.50) within group (order by orders_count):: numeric,2) as median_count,
  round(percentile_cont(0.75) within group (order by orders_count):: numeric,2) as seventyfive_percentile_count,
  round(avg(orders_count)::numeric,2) as avg_count,
  round(max(orders_count)::numeric,2) as max_count
  from
  customer_orders;   
  
 
   --a3. Three buckets are created based on the aggregates obtained above 
  
SELECT
  CASE
    WHEN orders_count <= 3 THEN 'Low-orders users'
    WHEN orders_count > 3 and orders_count <= 10   THEN 'Mid-orders users'
    ELSE 'High-orders users'
  END AS order_number_group,
  count (distinct customer_id) AS customers
FROM customer_orders
GROUP BY order_number_group
order by customers desc;


   