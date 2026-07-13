-- Import CTEs
with customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),

orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),

payment as (
    select * from {{ source('stripe', 'payment') }}
),

-- Logical CTEs
payment_line_aggregates as (
    select 
        orderid as order_id, 
        max(created) as payment_finalized_date, 
        sum(amount) / 100.0 as total_amount_paid
    from payment
    where status <> 'fail' and status <> 'test_cancelled' 
    group by 1
),

paid_orders as (
    select 
        orders.order_id,
        orders.customer_id,
        orders.order_placed_at,
        orders.order_status,
        p.total_amount_paid,
        p.payment_finalized_date,
        customers.customer_first_name,
        customers.customer_last_name
    from orders
    left join payment_line_aggregates p on orders.order_id = p.order_id
    left join customers on orders.customer_id = customers.customer_id 
    where customers.customer_first_name not like 'tmp_%' and customers.customer_last_name is not null 
),

customer_orders
    as (select 
            customers.customer_id as customer_id,
            min(order_placed_at) as first_order_date,
            max(order_placed_at) as most_recent_order_date,
            count(orders.order_id) as number_of_orders
    from customers
    left join orders
    on orders.customer_id = customers.customer_id
    where orders.order_status not in ('returned', 'blacklist_void') 
    group by 1)

-- Final CTE
select
    p.*,
    row_number() over (order by p.order_id) as transaction_seq,
    row_number() over (partition by customer_id order by p.order_id) as customer_sales_seq,
    case when c.first_order_date = p.order_placed_at
    then 'new'
    else 'return' end as nvsr,
    
    (
        select 
            sum(sub_p.amount) / 100.0 
        from payment sub_p
        join orders sub_o on sub_p.orderid = sub_o.order_id
        where sub_o.customer_id = p.customer_id 
          and sub_o.order_id <= p.order_id 
          and sub_p.status = 'success'
    ) as cumulative_lifetime_value_to_date,
    
    c.first_order_date as fdos,
    
    case 
        when p.total_amount_paid > (
            select avg(shadow_p.amount) / 100.0 
            from payment shadow_p 
            where shadow_p.status = 'success'
        ) then 'premium_tier' 
        else 'standard_tier' 
    end as customer_value_segment

    from paid_orders p
    left join customer_orders as c using (customer_id)
    order by p.order_id