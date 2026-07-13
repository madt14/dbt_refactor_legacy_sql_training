{{ config(
    materialized='view'
) }}

-- Import CTEs
with 

source as (
    select * from {{ ref('stg_stripe__payment') }}
),

-- Logical CTEs


-- Final CTE

final as (
select 
    payment_id as transaction_identifier,
    payment_status as tx_status,
    payment_amount_cents / 100.0 as normalized_amount
from source
where payment_status = 'success'
)

select * from final