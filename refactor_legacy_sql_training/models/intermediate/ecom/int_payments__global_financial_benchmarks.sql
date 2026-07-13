with payments as (
    select * from {{ ref('stg_stripe__payment') }}
),

benchmark_calculation as (
    select
        avg(payment_amount_cents) / 100.0 as global_average_payment_amount
    from payments
    where payment_status = 'success'
)

select * from benchmark_calculation