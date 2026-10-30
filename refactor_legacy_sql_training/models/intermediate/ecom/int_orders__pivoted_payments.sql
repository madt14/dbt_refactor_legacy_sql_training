with

payment as (
    select * from {{ ref('stg_stripe__payment') }}
),
pivoted as (
    select 
        order_id, 
        max(case when payment_status = 'success' then payment_created_at end) as payment_finalized_date, 

        sum(case when payment_status = 'success' then payment_amount_cents else 0 end) / 100.0 as total_amount_paid,
        sum(case when payment_status = 'fail' then payment_amount_cents else 0 end) / 100.0 as total_amount_failed
    from payment
    group by 1
)

select * from pivoted