{{ config(
    materialized='view'
) }}

-- Import CTEs
with 

source_payment as (
    select * from {{ source('stripe', 'payment') }}
),

-- Logical CTEs


-- Final CTE

final as (
select 
    id as transaction_identifier,
    status as tx_status,
    amount / 100.0 as normalized_amount
from source_payment
where status = 'success'
)

select * from final