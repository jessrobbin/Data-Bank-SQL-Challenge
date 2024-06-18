--1. What is the unique count and total amount for each transaction type?
  
;select
txn_type
, count(*) as Transaction_Count
, sum(txn_amount) as Total_Amounts
from customer_transactions
group by txn_type

--2. What is the average total historical deposit counts and amounts for all customers?
  
; with cte as
(select 
  customer_id
, avg(txn_amount) as Total_Deposit_Amount
, count(*) as Transaction_Count
from customer_transactions
where txn_type = 'deposit'
group by customer_id )
select
avg(Total_Deposit_Amount)
, avg(Transaction_Count)
from cte

--3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
  
; with counts as (
    select
  customer_id
, DATE_PART('month', txn_date) as month
, SUM( CASE WHEN txn_type = 'deposit' then 1 else 0 end) as deposits
, SUM( CASE WHEN txn_type <> 'deposit' then 1 else 0 end) as purchase_or_withdrawal
from customer_transactions
group by customer_id, month
having deposits > 1 AND purchase_or_withdrawal=1
)
select
month
, count (distinct customer_id)
from counts
group by month

--4. What is the closing balance for each customer at the end of the month?
  
; with cte as (
 select
    customer_id
, date_trunc('month', txn_date) as month_no
, sum(
   (CASE WHEN txn_type = 'deposit' then txn_amount else 0 end) - (CASE WHEN txn_type <> 'deposit' THEN TXN_AMOUNT else 0 end)) as balance
, row_number() OVER(partition by customer_id order by month_no asc) as rn
, sum(balance) OVER(partition by customer_id order by month_no asc) as running_sum
from customer_transactions
group by customer_id, month_no
)
select 
customer_id
, date_from_parts(
        year(month_no), month(month_no), 
            (CASE WHEN month(month_no) = 1 THEN '31'
            WHEN month(month_no) = 2 THEN '28'
            WHEN month(month_no) = 3 THEN '31'
            WHEN month(month_no) = 4 THEN '30'
            END
)) as eom_day
, running_sum as eom_balance
from cte

--5.What is the percentage of customers who increase their closing balance by more than 5%?
  
; with cte as (
 select
    customer_id
, date_trunc('month', txn_date) as month_no
, sum(
   (CASE WHEN txn_type = 'deposit' then txn_amount else 0 end) - (CASE WHEN txn_type <> 'deposit' THEN TXN_AMOUNT else 0 end)) as balance
, row_number() OVER(partition by customer_id order by month_no asc) as rn
, sum(balance) OVER(partition by customer_id order by month_no asc) as running_sum
from customer_transactions
group by customer_id, month_no
) 
, closing_balances as (
select 
 customer_id
, month_no
, LAST_DAY(month_no) as eom_day
, last_day(dateadd('month', -1, eom_day)) as prev_eom
, running_sum as eom_balance
from cte ) 
 ,percent_inc as (
select 
cb1.customer_id
,cb1.eom_day
,cb1.eom_balance
,cb2.eom_day as prev_eom
,cb2.eom_balance as prev_month_closing_balance
, ((cb1.eom_balance - cb2.eom_balance)/cb2.eom_balance) as balance_percent_diff
from closing_balances as cb1
inner join closing_balances as cb2 on cb1.prev_eom = cb2.eom_day AND cb1.customer_id = cb2.customer_id
where cb2.eom_balance <>0  AND balance_percent_diff >= 0.05
 )
select
count (distinct customer_id)
from percent_inc


