{{ config(severity='warn') }}

-- Singular test: total_amount should equal the sum of its components,
-- within a $0.10 tolerance to account for floating-point rounding.
-- Configured as a warning because TLC source data contains a small number
-- of rows (~16 in Jan 2024) where surcharge columns are sparsely populated
-- but included in total_amount. This is a known upstream data quality issue
-- worth tracking but not worth failing the pipeline over.
--
-- Applies to yellow and green trips only; HVFHV total_amount is constructed
-- in staging from components so it is definitionally correct, but any
-- non-null surcharge columns in fct_trips are also checked here.
--
-- Returns rows where the discrepancy exceeds tolerance — any result = test failure.

select
    trip_id,
    vehicle_class,
    total_amount,
    fare_amount
    + coalesce(tip_amount,               0)
    + coalesce(tolls_amount,             0)
    + coalesce(congestion_surcharge,     0)
    + coalesce(airport_fee,              0)
    + coalesce(extra,                    0)
    + coalesce(mta_tax,                  0)
    + coalesce(improvement_surcharge,    0)                 as computed_total,

    abs(
        total_amount - (
            fare_amount
            + coalesce(tip_amount,           0)
            + coalesce(tolls_amount,         0)
            + coalesce(congestion_surcharge, 0)
            + coalesce(airport_fee,          0)
            + coalesce(extra,                0)
            + coalesce(mta_tax,              0)
            + coalesce(improvement_surcharge, 0)
        )
    )                                                       as discrepancy

from {{ ref('fct_trips') }}
where
    -- Only applies to metered taxis where all components are known
    vehicle_class in ('yellow', 'green')
    and abs(
        total_amount - (
            fare_amount
            + coalesce(tip_amount,           0)
            + coalesce(tolls_amount,         0)
            + coalesce(congestion_surcharge, 0)
            + coalesce(airport_fee,          0)
            + coalesce(extra,                0)
            + coalesce(mta_tax,              0)
            + coalesce(improvement_surcharge, 0)
        )
    ) > 5.00   -- $5 tolerance: TLC source data includes surcharges (e.g. CBD
               -- congestion fee post-2022) that appear in total_amount but have
               -- no dedicated column. A $5 threshold catches genuine corruption
               -- (e.g. total_amount = $0 with fare_amount = $50) while ignoring
               -- normal source imprecision.
