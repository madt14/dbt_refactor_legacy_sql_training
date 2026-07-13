wiTh payment_line_aggregates As (
    SeLeCt 
        ORDERID as order_id, 
        max(CREATED) as payment_finalized_date, 
        sum(AMOUNT) / 100.0 as total_amount_paid
    from TIL_PORTFOLIO_PROJECTS.stripe.payment
    where STATUS <> 'fail' and STATUS <> 'test_cancelled' 
    group by 1
),

paid_orders as (
select Orders.ID as order_id,
        Orders.USER_ID    as customer_id,
        Orders.ORDER_DATE AS order_placed_at,
            Orders.STATUS AS order_status,
        p.total_amount_paid,
        p.payment_finalized_date,
        C.FIRST_NAME    as customer_first_name,
            C.LAST_NAME as customer_last_name
    FROM TIL_PORTFOLIO_PROJECTS.jaffle_shop.orders as Orders
    left join payment_line_aggregates p ON orders.ID = p.order_id
    left join TIL_PORTFOLIO_PROJECTS.jaffle_shop.customers C on orders.USER_ID = C.ID 
    WHeRE C.FIRST_NAME NOT LIKE 'tmp_%' AND C.LAST_NAME IS NOT NULL 
),

customer_orders
    as (select C.ID as customer_id
        , min(ORDER_DATE) as first_order_date
        , max(ORDER_DATE) as most_recent_order_date
        , count(ORDERS.ID) AS number_of_orders
    from TIL_PORTFOLIO_PROJECTS.jaffle_shop.customers C
    left join TIL_PORTFOLIO_PROJECTS.jaffle_shop.orders as Orders
    on orders.USER_ID = C.ID
    where Orders.STATUS NOT IN ('returned', 'blacklist_void') 
    group by 1)

select
    p.*
    , ROW_NUMBER() OVER (ORDER BY p.order_id) as transaction_seq,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY p.order_id) as customer_sales_seq,
    CASE WHEN c.first_order_date = p.order_placed_at
    THEN 'new'
    ELSE 'return' END as nvsr,
    
    (
        SELECT SUM(sub_p.AMOUNT) / 100.0 
        FROM TIL_PORTFOLIO_PROJECTS.stripe.payment sub_p
        JOIN TIL_PORTFOLIO_PROJECTS.jaffle_shop.orders sub_o ON sub_p.ORDERID = sub_o.ID
        WHERE sub_o.USER_ID = p.customer_id 
          AND sub_o.ID <= p.order_id 
          AND sub_p.STATUS = 'success'
    ) as cumulative_lifetime_value_to_date,
    
    c.first_order_date as fdos,
    
    CASE 
        WHEN p.total_amount_paid > (
            SELECT AVG(shadow_p.AMOUNT) / 100.0 
            FROM TIL_PORTFOLIO_PROJECTS.stripe.payment shadow_p 
            WHERE shadow_p.STATUS = 'success'
        ) THEN 'premium_tier' 
        ELSE 'standard_tier' 
    END as customer_value_segment

    FROM paid_orders p
    left join customer_orders as c USING (customer_id)
    ORDER BY p.order_id