-- Import CTEs
with 

int_orders_enriched as (
    select * from {{ ref('int_orders__enriched') }}
),

stg_payment as (
    select * from {{ ref('stg_stripe__payment') }}
),    

int_payments as (
    select * from {{ ref('int_orders__pivoted_payments') }}
),

int_customer_orders as (
    select * from {{ ref('int_orders__grouped_by_customer') }}
),

int_benchmarks as (
    select * from {{ ref('int_payments__global_financial_benchmarks') }}
),



-- Final CTE
final as (
    select
        -- Since this is not a staging model, it would be ok to do a p* to select everything
        p.*,
        
        row_number() over (
            order by p.order_id
        ) as transaction_seq,
        
        row_number() over (
            partition by p.customer_id 
            order by p.order_id
        ) as customer_sales_seq,
        
        case 
            when int_customer_orders.first_order_date = p.order_placed_at
            then 'new'
            else 'return' 
        end as nvsr,
        
        sum(coalesce(p.total_amount_paid,0)) over (
            partition by p.customer_id 
            order by p.order_id
            rows between unbounded preceding and current row
        ) as cumulative_lifetime_value_to_date,
        
        int_customer_orders.first_order_date as fdos,
        
        case 
            when p.total_amount_paid > (
                select
                    global_average_payment_amount
                from int_benchmarks
            ) then 'premium_tier' 
            else 'standard_tier' 
        end as customer_value_segment

    from int_orders_enriched p
    left join int_customer_orders using (customer_id)
    order by p.order_id
)

select * from final