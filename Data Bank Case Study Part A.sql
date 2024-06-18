--1. How many unique nodes are there on the Data Bank system?
; Select
count(distinct node_id) as distinct_node_count
from customer_nodes

--2. What is the number of nodes per region?Select
; Select
region_name
, count(distinct node_id) as distinct_node_count
from customer_nodes
join regions on regions.region_id = customer_nodes.region_id
group by region_name


--3. How many customers are allocated to each region?
; select
region_name
, count(distinct customer_id) as customer_count
from customer_nodes
join regions on regions.region_id = customer_nodes.region_id
group by region_name

--4. How many days on average are customers reallocated to a different node?
; with date_diff as (
select 
customer_id,
node_id,
sum(datediff('days',start_date, end_date)) as days
from customer_nodes
where year(end_date) <> 9999
group by customer_id, node_id
)
select 
round(avg(days), 0)
from date_diff

--What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
; with date_diff as (
select 
region_name,
customer_id,
node_id,
sum(datediff('days',start_date, end_date)) as days_in_node
from customer_nodes
join regions on regions.region_id = customer_nodes.region_id
where year(end_date) <> 9999
group by customer_id, node_id, region_name
), ordered_rows as (
SELECT *
, ROW_NUMBER() OVER(PARTITION BY region_name ORDER BY days_in_node) as rn
from date_diff
), max_rows as (
select
region_name
, max(rn) as max_rn
from ordered_rows
group by region_name
)

select 
o.region_name
, CASE 
WHEN rn = ROUND(mr.max_rn /2,0) THEN 'Median'
WHEN rn = ROUND(mr.max_rn * 0.8,0) THEN '80th Percentile'
WHEN rn = ROUND(mr.max_rn * 0.95,0) THEN '95th Percentile'
END as metric
, days_in_node as value
from ordered_rows as o
inner join max_rows as mr on mr.region_name = o.region_name
WHERE rn IN (
    ROUND(mr.max_rn /2,0),
    ROUND(mr.max_rn * 0.8,0),
     ROUND(mr.max_rn * 0.95,0)
)
;
WITH DAYS_IN_NODE AS (
    SELECT 
    region_name,
    customer_id,
    node_id,
    SUM(DATEDIFF('days',start_date,end_date)) as days_in_node
    FROM customer_nodes as C
    INNER JOIN regions as R on R.REGION_ID = C.region_id
    WHERE end_date <> '9999-12-31'
    GROUP BY region_name,
    customer_id,
    node_id
)
,ORDERED AS (
SELECT 
region_name,
days_in_node,
ROW_NUMBER() OVER(PARTITION BY region_name ORDER BY days_in_node) as rn
FROM DAYS_IN_NODE
)
,MAX_ROWS as (
SELECT 
region_name,
MAX(rn) as max_rn
FROM ORDERED
GROUP BY region_name
)

SELECT O.region_name
,CASE 
WHEN rn = ROUND(M.max_rn /2,0) THEN 'Median'
WHEN rn = ROUND(M.max_rn * 0.8,0) THEN '80th Percentile'
WHEN rn = ROUND(M.max_rn * 0.95,0) THEN '95th Percentile'
END as metric,
days_in_node as value
FROM ORDERED as O
INNER JOIN MAX_ROWS as M on M.region_name = O.region_name
WHERE rn IN (
    ROUND(M.max_rn /2,0),
    ROUND(M.max_rn * 0.8,0),
     ROUND(M.max_rn * 0.95,0)
)
