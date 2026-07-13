-- import ctes
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

int_benchmarks as (
    select * from {{ ref('int_payments__global_financial_benchmarks') }}
),

-- logical ctes
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


-- final cte
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
        
        row_number() over (
            order by paid_orders.order_id
        ) as transaction_seq,
        
        row_number() over (
            partition by paid_orders.customer_id 
            order by paid_orders.order_id
        ) as customer_sales_seq,
        
        case 
            when int_customer_orders.first_order_date = paid_orders.order_placed_at
            then 'new'
            else 'return' 
        end as nvsr,
        
        sum(coalesce(paid_orders.total_amount_paid,0)) over (
            partition by paid_orders.customer_id 
            order by paid_orders.order_id
            rows between unbounded preceding and current row
        ) as cumulative_lifetime_value_to_date,
        
        int_customer_orders.first_order_date as fdos,
        
        case 
            when paid_orders.total_amount_paid > (
                select
                    global_average_payment_amount
                from int_benchmarks
            ) then 'premium_tier' 
            else 'standard_tier' 
        end as customer_value_segment

    from paid_orders
    left join int_customer_orders using (customer_id)
    order by paid_orders.order_id
)

select * from final