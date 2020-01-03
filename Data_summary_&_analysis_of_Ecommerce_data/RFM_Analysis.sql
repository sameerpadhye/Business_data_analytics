											------- Recency Frequency Monetary analysis -------

											
											
                                                --- Adpoted from the following resources

--1. http://www.silota.com/docs/recipes/sql-recency-frequency-monetary-rfm-customer-analysis.html 

--2. https://www.putler.com/rfm-analysis/#targetText=RFM%20analysis%20is%20based%20on,how%20much%20did%20they%20buy. 
								
    
-- The eCommerce dataset used generating the base report has been used here as well (https://www.kaggle.com/lissetteg/ecommerce-dataset) --											
											
											
											------- 1. Recency Frequency Monetary analysis with 11 customer segments -------
											
											
-- Obtaining the base data for frequency and monetary analysis along with the date of most recent purchase
  
 create temp table rfm_base_data as ( SELECT
    "CustomerID" as customer_id,
    max("InvoiceDate")::Date as most_recent_date,
    count(distinct "InvoiceDate") as counts_freq,
    sum("Quantity" * "UnitPrice")::numeric as monetary
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY "CustomerID"
  );
  
-- To get the days since the last purchase, the latest date from the dataset is obtained
 
    (select max("InvoiceDate")::Date from ecommerce_data); 

-- Using the above value, days since the last purchase for obtaining recency score is calculated
  
create temp table rfm_date_diff as (
 select
customer_id,
date_part('day',date_diff_age) as date_diff
from(
select
customer_id,
 age('2011-12-09'::Date, most_recent_date) as date_diff_age
  from
 rfm_base_data)subq
 );
 
 -- Combining the two tables to get a combined data to calculate the recency, frequency and monetary values
  
 create temp table rfm_comb_base_data as (select
 r.customer_id,
 r.counts_freq,
 r.monetary,
 rd.date_diff
 from
 rfm_base_data as r
 join
 rfm_date_diff as rd
  on r.customer_id=rd.customer_id)
  ;
  
  -- Obtaining the RFM scores
  
      select
  customer_id, 
  rfm_recency,
  rfm_freq,
  rfm_monetary,
  date_diff,
  counts_freq,
  monetary,
  rfm_recency*100 + rfm_freq*10 + rfm_monetary as rfm_combined
  from(
  select
  customer_id,
  date_diff,
  counts_freq,
  monetary,
  ntile(5) over (order by date_diff desc) as rfm_recency,
  ntile(5) over (order by counts_freq) as rfm_freq,
  ntile(5) over (order by monetary) as rfm_monetary
  from
  rfm_comb_base_data)as subq
  order by rfm_combined desc
  ;

 -- Obtaining the Customer segments based on the RFM scores
      
  select
customer_id,
rfm_recency*100 + rfm_freq*10 + rfm_monetary as rfm_combined,
case 
when (rfm_recency between 4 and 5) and (rfm_freq between 4 and 5 and rfm_monetary between 4 and 5) then 'Champions'
when (rfm_recency between 2 and 5) and (rfm_freq between 2 and 5 and rfm_monetary between 2 and 5) then 'Loyal Customers'
when (rfm_recency between 3 and 5) and (rfm_freq between 1 and 3 and rfm_monetary between 1 and 3) then 'Potential Loyalist'
when (rfm_recency between 4 and 5) and (rfm_freq between 0 and 1 and rfm_monetary between 0 and 1) then 'Recent Customers'
when (rfm_recency between 3 and 4) and (rfm_freq between 0 and 1 and rfm_monetary between 0 and 1) then 'Promising'
when (rfm_recency between 2 and 3) and (rfm_freq between 2 and 3 and rfm_monetary between 2 and 3) then 'Customers Needing Attention'
when (rfm_recency between 2 and 3) and (rfm_freq between 0 and 2 and rfm_monetary between 0 and 2) then 'About To Sleep'
when (rfm_recency between 0 and 2) and (rfm_freq between 2 and 5 and rfm_monetary between 2 and 5) then 'At Risk'
when (rfm_recency between 0 and 1) and (rfm_freq between 4 and 5 and rfm_monetary between 4 and 5) then 'Cant Lose Them'
when (rfm_recency between 1 and 2) and (rfm_freq between 1 and 2 and rfm_monetary between 1 and 2) then 'Hibernating'
when (rfm_recency between 0 and 2) and (rfm_freq between 0 and 2 and rfm_monetary between 0 and 2) then 'Lost'
else 'other' end as customer_segments
  from(
  select
  customer_id,
  date_diff,
  counts_freq,
  monetary,
  ntile(5) over (order by date_diff desc) as rfm_recency,
  ntile(5) over (order by counts_freq) as rfm_freq,
  ntile(5) over (order by monetary) as rfm_monetary
  from
  rfm_comb_base_data)as subq
  order by rfm_combined desc
  ;
  
  
									-------2. Recency Frequency Monetary analysis with 3 customer segments -------
								 
                                                ----https://www.owox.com/blog/use-cases/rfm-analysis/------						
											
--a. Creating a temporary table for base data
								
  create temporary table rfm_base_data as (
  select
    "CustomerID" as customer_id,
    max("InvoiceDate")::Date as latest_date,
    count(distinct "InvoiceDate") as counts_freq,
    sum("Quantity" * "UnitPrice")::numeric as monetary
  FROM ecommerce_data
  where "InvoiceDate" >= '2011-01-01' and "CustomerID" is not null
  GROUP BY "CustomerID"
  order by monetary desc
  )

 --a2. Creating a CTE using the base data table generating RFM scores and customer segments

with rfm_analysis_3 as (
  select
  customer_id,
  latest_date,
  counts_freq,
  monetary,
  ntile(3) over (order by latest_date) as rfm_recency,
  ntile(3) over (order by counts_freq) as rfm_freq,
  ntile(3) over (order by monetary) as rfm_monetary
  from
  rfm_base_data
  order by customer_id)
  -- Customer segements based on RFM scores
  select
  customer_id, 
  counts_freq,
  monetary,
  rfm_recency,
  rfm_freq,
  rfm_monetary,
  rfm_recency*100 + rfm_freq*10 + rfm_monetary as rfm_combined,
case 
when (rfm_recency = 1) then 'Long_standing_customer'
when (rfm_recency = 2) then 'Relatively_recent_customer'
when (rfm_recency = 3) then 'Recent_customer' end as recency_segmenet,
case 
when (rfm_freq = 1) then 'Purchases_rarely'
when (rfm_freq = 2) then 'Purchases_infrequently'
when (rfm_freq = 3) then 'Purchases_frequently'end as frequency_segment,
case 
when (rfm_monetary = 1) then 'Low_value_purchases'
when (rfm_monetary = 2) then 'Average_value_purchases'
when (rfm_monetary = 3) then 'High_value_purchases' 
end as monetary_segment
from
rfm_analysis_3
order by rfm_combined desc
  ;
  
   