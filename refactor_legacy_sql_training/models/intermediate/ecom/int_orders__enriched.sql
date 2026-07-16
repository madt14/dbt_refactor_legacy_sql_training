{{
  config(
    materialized = 'ephemeral',
    )
}}

with

-- Staging CTEs

stg_customers as (
    select * from {{ ref('stg_jaffle_shop__customers') }}
),

stg_orders as (
    select * from {{ ref('stg_jaffle_shop__orders') }}
),

int_payments as (
    select * from {{ ref('int_payments__aggregated_by_order') }}
),

-- Logical CTEs

enriched as (
    select 
        stg_orders.order_id,
        stg_orders.customer_id,
        stg_orders.order_placed_at,
        stg_orders.order_status,
        int_payments.total_amount_paid,
        int_payments.payment_finalized_date,
        stg_customers.customer_first_name,
        stg_customers.customer_last_name
    from stg_orders
    left join int_payments on stg_orders.order_id = int_payments.order_id
    left join stg_customers on stg_orders.customer_id = stg_customers.customer_id 
)

-- Select Statement

select * from enriched