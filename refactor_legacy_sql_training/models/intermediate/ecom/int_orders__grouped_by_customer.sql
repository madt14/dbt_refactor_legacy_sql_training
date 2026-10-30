with
customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),

orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }} 
),
customer_aggregations as (
    select 
        customers.customer_id,
        min(order_placed_at) as first_order_date,
        max(order_placed_at) as most_recent_order_date,

        -- Pivoted conditional count replaces the exclusionary WHERE clause
        SUM(case when orders.order_status not in ('returned', 'blacklist_void') then 1 else 0 end) as number_of_orders
    from customers
    left join orders
    on orders.customer_id = customers.customer_id
    group by 1
)

select * from customer_aggregations