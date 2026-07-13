sElEcT 
    ID As transaction_identifier,
    STATUS as Tx_StAtUs,
    AMOUNT / 100.0 As normalized_amount
fRoM TIL_PORTFOLIO_PROJECTS.stripe.payment
WhErE STATUS = 'success'