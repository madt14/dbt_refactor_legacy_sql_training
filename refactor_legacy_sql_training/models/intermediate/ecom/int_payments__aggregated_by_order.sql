with

payment as (
    select * from {{ ref('stg_stripe__payment') }}
),
aggregated as (
    select 
        order_id, 
        max(payment_created_at) as payment_finalized_date, 
        sum(payment_amount_cents) / 100.0 as total_amount_paid
    from payment
    WHERE payment_status = 'success'
    group by 1
)

select * from aggregated