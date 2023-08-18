select * from sales
select * from product
select * from customer

--cleaning and arranging data for future--
drop table if exists d;
create temp table d as select split_part(order_id, '-',1) as country_code,
(extract(year from ship_date)) as year,initcap(to_char(ship_date, 'month')) as ship_month
,upper(to_char(order_date, 'month')) as order_month, order_id
from sales

/*sum sales by ship mode with min sales in 2017*/
select sum(sales), ship_mode from sales where sales>
(select min(sales) from sales where order_date between '2017-1-1' and '2017-12-31')
group by ship_mode

/*using cte customer name, avg and then sum sales by customer product
and avg then max profit by ship mode with order id and sales less than sum profit and 
include age category that start with A, min age and not like a in ending*/
with cte as (select c.customer_name,s.ship_mode,s.order_date, avg(s.sales) over(partition
by c.customer_name)
as avg_sales, max(s.profit) over(order by s.ship_mode rows between
					2 preceding and current row) as 
max_profit,s.product_id,c.age from customer as c inner join sales as s using(customer_id))

--applying cte, case, where subquery
select split_part(cte.customer_name,' ',1) as first_name, split_part(cte.customer_name,' ',2)
as surname, age,p.sub_category,
order_date, max_profit, sum(max_profit) 
over(order by p.product_id rows between 3 preceding and current row) as sum_max,
 avg_sales, case when age>=18 and age<=30 then 'YOUTH'
when age>=31 and age<=40 then 'YOUNG'
when age>=41 and age<=50 then 'YOUTHFUL'
else 'HAPPY' end as age_category
from cte inner join product as p using(product_id) where customer_name like 'A%' 
and age >
(select min(age) from customer where customer_name not like '%a') order by max_profit desc
limit 20

--average sales, average profit by category and sub_category
select p.category, p.sub_category, avg(s.sales) as avg_sales, avg(s.profit) as av_profit
from sales as s inner join product as p using (product_id) group by cube(category,sub_category)

--city in united states with the highest sale, discount and profit in 2014
select c.state, max(s.sales) as max_sales, max(s.discount) as max_discount,
max(s.profit) as max_profit
from sales as s inner join customer as c using(customer_id)
where ship_date between '2014-01-01' and '2014-12-31' group by state order by state desc

--highest products sales
select p.category, max(s.sales) as max_sales from sales as s inner join
product as p using(product_id) group by
category

--under 20 age with the highest sales and profit in West region
select c.age, max(s.sales) as max, max(s.profit) as max_profit from sales as s inner join
customer as c using(customer_id) where age<= (select max(age) from customer where 
region = 'West' and age<=20) group by age order by age desc;

--order and ship date with the highest avg profit
select order_date, ship_date, round(avg(profit)) as avg_profit from sales
group by order_date, ship_date
having max(profit) >=(select 
AVG(profit) from sales) order by order_date desc, ship_date desc


--highest quantity for each sub category
select p.sub_category, max(s.quantity) as max_quantity from sales as s inner join 
product as p using(product_id) group by sub_category

--customer_id and product_id that meet requirement
select c.customer_id from customer as c inner join sales as s using(customer_id)
where age<=20 and profit <=500
union
select product_id from product


--total highest discount of product in each region
with cte as (select max(sales.discount) as max_discount,p.category, sales.customer_id
from sales inner join product as p using(product_id) group by category, customer_id)
select c.region, sum(cte.max_discount) as sum_discount from customer as c inner join cte
using(customer_id) group by region

--states with the lowest avg profit and sales
select c.state, round(avg(s.profit)) as avg_profit, 
round(avg(s.sales)) as avg_sales from sales as s
inner join customer as c using(customer_id) group by state having avg(profit)<= max(profit)
and avg(sales) <= max(profit)

--customer names like B min age
select customer_name, min(age) as min_age from customer where customer_name like 'A%'
group by customer_name

---avg sales minus discount divided by profit of each quantity
select quantity, (avg(sales)-avg(discount)/avg(profit))
		as agg from sales group by quantity

--month with the highest discount
select d.ship_month, max(s.discount) as max_discount from sales as s left join d
using(order_id) group by ship_month

--month with the lowest discount
select d.ship_month, min(s.discount) as min_discount from sales as s left join d
using(order_id) group by ship_month


--month with the hightest sales and profit
select d.ship_month, max(s.sales) as max_sales, max(profit) as max_profit
from sales as s left join d
using(order_id) group by ship_month


---segment with the highest profit
select c.segment, max(s.profit) as max_profit from sales as s left join customer as c
using(customer_id) group by segment

--recent average profit and oldest average profit by month
with cte as (select avg(profit) as avg_profit, order_id from sales group by order_id)
select d.ship_month, max(cte.avg_profit)
as max_profit, min(cte.avg_profit) as min_profit from cte 
inner join d using(order_id) group by ship_month

---recent sales and oldest sales
with cte as (select (sales), order_id from sales)
select d.ship_month, max(cte.sales)
as max_sales, min(cte.sales) as min_sales from cte 
inner join d using(order_id) group by ship_month


---recent discount and oldest discount
with cte as (select (discount), order_id from sales)
select d.ship_month, max(cte.discount)
as max_discount, min(cte.discount) as min_discount from cte 
inner join d using(order_id) group by ship_month

--using cte to find max of avg profit and total profit
with cte as (select distinct avg(profit-discount) over(partition by customer_id) as avg_profit,
sum(profit) over(rows between 3 preceding and current row) 
as sum_profit,customer_id from sales)

select c.customer_name, max(cte.avg_profit) as max_profit, max(cte.sum_profit) as max_sumprofit
from cte inner join customer as c using (customer_id) group by customer_name

--max profit and sales in year, month and ship mode
with cte as (select initcap(to_char(order_date, 'month')) as order_month,
extract('year' from ship_date) as year, customer_id, profit,sales from sales),

an as (select avg(s.sales + s.profit) over(partition by ship_mode) as avg_total,
c.customer_name, s.ship_mode,
customer_id from sales as s inner join customer as c using(customer_id))

select distinct an.customer_name, an.ship_mode,(cte.order_month), cte.year,
max(profit) over(partition by ship_mode) as max_profit,
max(sales) over(partition by ship_mode) as max_sales,
an.avg_total from cte inner join
an using(customer_id) order by year desc 

--sales of furniture
select p.category, sum(s.profit) as sum_profit from sales as s
inner join product as p using(product_id) where category = 'Furniture'
group by category

--profit and sales of office supplies
select p.category, sum(s.profit) as sum_profit, sum(sales) as sum_sales from sales as s
inner join product as p using(product_id) where category = 'Office Supplies'
group by category

--part one of product_name
select upper(split_part(p.product_name,' ',1)) as first_product, p.sub_category
, s.sales from product as p inner join sales as s using(product_id)
where category = 'Technology'