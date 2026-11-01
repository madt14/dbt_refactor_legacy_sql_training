with
customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),

customer_orders as (
    select * from {{ ref('int_orders__grouped_by_customer') }}
),

orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),

payments as (
    select * from {{ ref('int_orders__pivoted_payments') }}
),

customer_payments as (
    select
        orders.customer_id,
        sum(payments.total_amount_paid) as customer_lifetime_value
    from orders
    left join payments on orders.order_id = payments.order_id
    group by 1
),

final as (
select
    customers.customer_id,
    customers.customer_first_name,
    customers.customer_last_name,
    customer_orders.first_order_date,
    customer_orders.most_recent_order_date,
    coalesce(customer_orders.number_of_orders,0) as number_of_orders,
    coalesce(customer_payments.customer_lifetime_value, 0) AS customer_lifetime_value,

    case
        when coalesce(customer_orders.number_of_orders,0) = 0 then 'prospect'
        when coalesce(customer_payments.customer_lifetime_value, 0) >= 100.00 then 'vip'
        else 'standard'
    end as customer_segment

from customers
left join customer_orders on customers.customer_id = customer_orders.customer_id
left join customer_payments on customers.customer_id = customer_payments.customer_id
)

select * from final