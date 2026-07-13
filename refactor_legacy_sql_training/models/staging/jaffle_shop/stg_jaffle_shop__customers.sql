with

source as (
    select * from {{ source('jaffle_shop', 'customers') }}
),

transformed as (
    select
        id as customer_id,
        first_name as customer_first_name,
        last_name as customer_last_name,
    from source
    where first_name not like 'tmp_%'
        and last_name is not null
)

select * from transformed