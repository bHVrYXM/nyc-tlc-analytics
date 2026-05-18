{{
    config(
        materialized = 'table',
        description  = 'Row-level reject audit — counts raw rows, valid rows, and per-reason rejection counts per source. Individual reason counts can sum to more than rejected_rows because a single row can fail multiple checks simultaneously.'
    )
}}

-- ── Yellow ────────────────────────────────────────────────────────────────────
with yellow_raw as (

    select
        count(*)                                                                as total_rows,
        count(*) filter (
            where cast(tpep_pickup_datetime as timestamp)
               >= cast(tpep_dropoff_datetime as timestamp)
               or tpep_pickup_datetime is null
               or tpep_dropoff_datetime is null
        )                                                                       as failed_timestamp,
        count(*) filter (where cast(fare_amount  as double) < 0)               as failed_neg_fare,
        count(*) filter (where cast(total_amount as double) < 0)               as failed_neg_total,
        count(*) filter (
            where cast(trip_distance as double) <= 0
               or trip_distance is null
        )                                                                       as failed_zero_distance,
        count(*) filter (where PULocationID is null)                           as failed_null_pickup_zone,
        count(*) filter (where DOLocationID is null)                           as failed_null_dropoff_zone
    from {{ source('tlc_raw', 'yellow_tripdata') }}

),

yellow_valid as (
    select count(*) as valid_rows from {{ ref('stg_yellow_trips') }}
),

-- ── Green ─────────────────────────────────────────────────────────────────────
green_raw as (

    select
        count(*)                                                                as total_rows,
        count(*) filter (
            where cast(lpep_pickup_datetime as timestamp)
               >= cast(lpep_dropoff_datetime as timestamp)
               or lpep_pickup_datetime is null
               or lpep_dropoff_datetime is null
        )                                                                       as failed_timestamp,
        count(*) filter (where cast(fare_amount  as double) < 0)               as failed_neg_fare,
        count(*) filter (where cast(total_amount as double) < 0)               as failed_neg_total,
        count(*) filter (
            where cast(trip_distance as double) <= 0
               or trip_distance is null
        )                                                                       as failed_zero_distance,
        count(*) filter (where PULocationID is null)                           as failed_null_pickup_zone,
        count(*) filter (where DOLocationID is null)                           as failed_null_dropoff_zone
    from {{ source('tlc_raw', 'green_tripdata') }}

),

green_valid as (
    select count(*) as valid_rows from {{ ref('stg_green_trips') }}
),

-- ── HVFHV ─────────────────────────────────────────────────────────────────────
hvfhv_raw as (

    select
        count(*)                                                                as total_rows,
        count(*) filter (
            where cast(pickup_datetime  as timestamp)
               >= cast(dropoff_datetime as timestamp)
               or pickup_datetime  is null
               or dropoff_datetime  is null
        )                                                                       as failed_timestamp,
        count(*) filter (where cast(base_passenger_fare as double) < 0)        as failed_neg_fare,
        -- HVFHV has no pre-computed total_amount; reconstruct it to check sign
        count(*) filter (
            where (
                coalesce(cast(base_passenger_fare as double), 0)
                + coalesce(cast(tolls             as double), 0)
                + coalesce(cast(bcf               as double), 0)
                + coalesce(cast(sales_tax         as double), 0)
                + coalesce(cast(congestion_surcharge as double), 0)
                + coalesce(cast(airport_fee       as double), 0)
                + coalesce(cast(tips              as double), 0)
            ) < 0
        )                                                                       as failed_neg_total,
        count(*) filter (
            where cast(trip_miles as double) <= 0
               or trip_miles is null
        )                                                                       as failed_zero_distance,
        count(*) filter (where PULocationID is null)                           as failed_null_pickup_zone,
        count(*) filter (where DOLocationID is null)                           as failed_null_dropoff_zone
    from {{ source('tlc_raw', 'fhvhv_tripdata') }}

),

hvfhv_valid as (
    select count(*) as valid_rows from {{ ref('stg_hvfhv_trips') }}
),

-- ── Union ─────────────────────────────────────────────────────────────────────
summary as (

    select
        'yellow'                                        as vehicle_class,
        y.total_rows,
        yv.valid_rows,
        y.total_rows - yv.valid_rows                   as rejected_rows,
        round(100.0 * (y.total_rows - yv.valid_rows)
            / nullif(y.total_rows, 0), 2)              as rejection_pct,
        y.failed_timestamp,
        y.failed_neg_fare,
        y.failed_neg_total,
        y.failed_zero_distance,
        y.failed_null_pickup_zone,
        y.failed_null_dropoff_zone
    from yellow_raw y
    cross join yellow_valid yv

    union all

    select
        'green',
        g.total_rows,
        gv.valid_rows,
        g.total_rows - gv.valid_rows,
        round(100.0 * (g.total_rows - gv.valid_rows)
            / nullif(g.total_rows, 0), 2),
        g.failed_timestamp,
        g.failed_neg_fare,
        g.failed_neg_total,
        g.failed_zero_distance,
        g.failed_null_pickup_zone,
        g.failed_null_dropoff_zone
    from green_raw g
    cross join green_valid gv

    union all

    select
        'hvfhv',
        h.total_rows,
        hv.valid_rows,
        h.total_rows - hv.valid_rows,
        round(100.0 * (h.total_rows - hv.valid_rows)
            / nullif(h.total_rows, 0), 2),
        h.failed_timestamp,
        h.failed_neg_fare,
        h.failed_neg_total,
        h.failed_zero_distance,
        h.failed_null_pickup_zone,
        h.failed_null_dropoff_zone
    from hvfhv_raw h
    cross join hvfhv_valid hv

)

select * from summary
