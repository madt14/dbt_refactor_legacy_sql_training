-- Import CTEs
with customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),

orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),

payment as (
    select * from {{ ref('stg_stripe__payment') }}
),    

int_payments as (
    select * from {{ ref('int_payments__aggregated_by_order') }}
),

int_customer_orders as (
    select * from {{ ref('int_orders__grouped_by_customer') }}
),

-- Logical CTEs
paid_orders as (
    select 
        orders.order_id,
        orders.customer_id,
        orders.order_placed_at,
        orders.order_status,
        int_payments.total_amount_paid,
        int_payments.payment_finalized_date,
        customers.customer_first_name,
        customers.customer_last_name
    from orders
    left join int_payments on orders.order_id = int_payments.order_id
    left join customers on orders.customer_id = customers.customer_id 
),


-- Final CTE
final as (
    select
        paid_orders.order_id,
        paid_orders.customer_id,
        paid_orders.order_placed_at,
        paid_orders.order_status,
        paid_orders.total_amount_paid,
        paid_orders.payment_finalized_date,
        paid_orders.customer_first_name,
        paid_orders.customer_last_name,
        row_number() over (order by paid_orders.order_id) as transaction_seq,
        row_number() over (partition by customer_id order by paid_orders.order_id) as customer_sales_seq,
        case when int_customer_orders.first_order_date = paid_orders.order_placed_at
        then 'new'
        else 'return' end as nvsr,
        
        (
            select 
                sum(sub_p.payment_amount_cents) / 100.0 
            from payment sub_p
            join orders sub_o on sub_p.order_id = sub_o.order_id
            where sub_o.customer_id = paid_orders.customer_id 
            and sub_o.order_id <= paid_orders.order_id 
            and sub_p.payment_status = 'success'
        ) as cumulative_lifetime_value_to_date,
        
        int_customer_orders.first_order_date as fdos,
        
        case 
            when paid_orders.total_amount_paid > (
                select avg(shadow_p.payment_amount_cents) / 100.0 
                from payment shadow_p 
                where shadow_p.payment_status = 'success'
            ) then 'premium_tier' 
            else 'standard_tier' 
        end as customer_value_segment

    from paid_orders
    left join int_customer_orders using (customer_id)
    order by paid_orders.order_id
)

select * from final