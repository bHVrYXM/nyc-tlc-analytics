{{
    config(
        materialized = 'table',
        description  = 'Payment type dimension — maps TLC integer codes to human-readable '
                       'labels. Yellow and green taxis use these codes; HVFHV does not '
                       '(payment is handled by the app). Code 0 is used as a catch-all '
                       'for HVFHV trips joined to this dimension.'
    )
}}

-- Source: TLC data dictionary
-- https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf
select
    payment_type_id,
    payment_label,
    is_cashless
from (
    values
        (1, 'Credit Card',      true ),
        (2, 'Cash',             false),
        (3, 'No Charge',        false),
        (4, 'Dispute',          false),
        (5, 'Unknown',          false),
        (6, 'Voided Trip',      false),
        -- Code 0 used for HVFHV trips where payment_type is null
        (0, 'N/A (Rideshare)',  true )
) as t(payment_type_id, payment_label, is_cashless)
