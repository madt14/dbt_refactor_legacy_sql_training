with

source as (
    select * from {{ source('stripe', 'payment') }}
),
transformed as (
    select
        id AS payment_id,
        orderid AS order_id,
        status AS payment_status,
        amount AS payment_amount_cents,
        created AS payment_created_at
    from source
    where status <> 'test_cancelled'
) 

select * from transformed