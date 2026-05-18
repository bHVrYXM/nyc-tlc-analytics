{{
    config(
        materialized = 'table',
        description  = 'Union of all three vehicle classes (yellow, green, HVFHV) on the '
                       'canonical schema. This is the single source of truth for all mart '
                       'models. HVFHV-specific fields (hvfhs_license_num, driver_pay, etc.) '
                       'are dropped here — they live in stg_hvfhv_trips for ad-hoc use.'
    )
}}

-- ── Yellow ────────────────────────────────────────────────────────────────────
with yellow as (

    select
        trip_id,
        vehicle_class,
        vendor_id,
        pickup_at,
        dropoff_at,
        cast(pickup_at as date)          as pickup_date,
        pickup_zone_id,
        dropoff_zone_id,
        passenger_count,
        trip_distance_miles,
        fare_amount,
        tip_amount,
        total_amount,
        payment_type,
        rate_code_id,
        -- Surcharges present in yellow/green; null for HVFHV
        extra,
        mta_tax,
        tolls_amount,
        improvement_surcharge,
        congestion_surcharge,
        airport_fee
    from {{ ref('stg_yellow_trips') }}

),

-- ── Green ─────────────────────────────────────────────────────────────────────
green as (

    select
        trip_id,
        vehicle_class,
        vendor_id,
        pickup_at,
        dropoff_at,
        cast(pickup_at as date)          as pickup_date,
        pickup_zone_id,
        dropoff_zone_id,
        passenger_count,
        trip_distance_miles,
        fare_amount,
        tip_amount,
        total_amount,
        payment_type,
        rate_code_id,
        extra,
        mta_tax,
        tolls_amount,
        improvement_surcharge,
        congestion_surcharge,
        airport_fee                      -- already nulled in staging for green
    from {{ ref('stg_green_trips') }}

),

-- ── HVFHV (Uber / Lyft) ───────────────────────────────────────────────────────
hvfhv as (

    select
        trip_id,
        vehicle_class,
        vendor_id,                       -- NULL; no vendor_id concept in HVFHV
        pickup_at,
        dropoff_at,
        cast(pickup_at as date)          as pickup_date,
        pickup_zone_id,
        dropoff_zone_id,
        passenger_count,                 -- NULL; not collected by HVFHV
        trip_distance_miles,
        fare_amount,                     -- mapped from base_passenger_fare in staging
        tip_amount,
        total_amount,
        cast(null as integer)            as payment_type,
        cast(null as integer)            as rate_code_id,
        -- Surcharge columns not directly available in HVFHV at this layer
        cast(null as double)             as extra,
        cast(null as double)             as mta_tax,
        tolls_amount,
        cast(null as double)             as improvement_surcharge,
        congestion_surcharge,
        airport_fee
    from {{ ref('stg_hvfhv_trips') }}

),

-- ── Union ─────────────────────────────────────────────────────────────────────
unified as (

    select * from yellow
    union all
    select * from green
    union all
    select * from hvfhv

),

-- ── Deduplication ─────────────────────────────────────────────────────────────
-- TLC parquet files contain a small number of exact duplicate rows (same trip
-- appearing in adjacent monthly files). We keep the first occurrence per
-- (trip_id, vehicle_class) and discard the rest.
-- QUALIFY is DuckDB-native syntax — clean and efficient for this pattern.
deduped as (

    select *
    from unified
    qualify row_number() over (
        partition by trip_id, vehicle_class
        order by pickup_at
    ) = 1

)

select * from deduped
