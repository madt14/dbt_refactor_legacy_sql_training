{{ config(
    materialized='view'
) }}

WITH source_payment AS (
    SELECT * FROM {{ source('stripe', 'payment') }}
)

sElEcT 
    ID As transaction_identifier,
    STATUS as Tx_StAtUs,
    AMOUNT / 100.0 As normalized_amount
fRoM source_payment
WhErE STATUS = 'success'