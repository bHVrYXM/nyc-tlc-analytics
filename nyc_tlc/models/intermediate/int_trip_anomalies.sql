{{
    config(
        materialized = 'table',
        description  = 'Row-level anomaly detail: trips that failed at least one quality check '
                       'in staging, with the first failure reason labelled. Unlike '
                       'stg_trip_reject_audit (which gives aggregate counts), this model '
                       'preserves individual rejected rows so the dashboard Data Quality page '
                       'can show real examples and regulator personas can inspect them.'
    )
}}

-- ── Yellow anomalies ──────────────────────────────────────────────────────────
with yellow_raw as (

    select
        'yellow'                                            as vehicle_class,
        cast(VendorID             as integer)               as vendor_id,
        cast(tpep_pickup_datetime as timestamp)             as pickup_at,
        cast(tpep_dropoff_datetime as timestamp)            as dropoff_at,
        cast(PULocationID         as integer)               as pickup_zone_id,
        cast(DOLocationID         as integer)               as dropoff_zone_id,
        cast(fare_amount          as double)                as fare_amount,
        cast(total_amount         as double)                as total_amount,
        cast(trip_distance        as double)                as trip_distance_miles,

        -- Rejection flags (true = this row fails this check)
        (cast(tpep_pickup_datetime as timestamp)
            >= cast(tpep_dropoff_datetime as timestamp)
         or tpep_pickup_datetime is null
         or tpep_dropoff_datetime is null)                  as failed_timestamp,
        (cast(fare_amount  as double) < 0)                  as failed_neg_fare,
        (cast(total_amount as double) < 0)                  as failed_neg_total,
        (cast(trip_distance as double) <= 0
         or trip_distance is null)                          as failed_zero_distance,
        (PULocationID is null)                              as failed_null_pickup_zone,
        (DOLocationID is null)                              as failed_null_dropoff_zone

    from {{ source('tlc_raw', 'yellow_tripdata') }}

),

yellow_anomalies as (

    select
        vehicle_class,
        vendor_id,
        pickup_at,
        dropoff_at,
        pickup_zone_id,
        dropoff_zone_id,
        fare_amount,
        total_amount,
        trip_distance_miles,
        -- Label the first (most severe) failure reason
        case
            when failed_timestamp        then 'invalid_timestamps'
            when failed_null_pickup_zone then 'null_pickup_zone'
            when failed_null_dropoff_zone then 'null_dropoff_zone'
            when failed_neg_fare         then 'negative_fare'
            when failed_neg_total        then 'negative_total'
            when failed_zero_distance    then 'zero_distance'
        end                                                 as rejection_reason
    from yellow_raw
    where
        failed_timestamp
        or failed_neg_fare
        or failed_neg_total
        or failed_zero_distance
        or failed_null_pickup_zone
        or failed_null_dropoff_zone

),

-- ── Green anomalies ───────────────────────────────────────────────────────────
green_raw as (

    select
        'green'                                             as vehicle_class,
        cast(VendorID              as integer)              as vendor_id,
        cast(lpep_pickup_datetime  as timestamp)            as pickup_at,
        cast(lpep_dropoff_datetime as timestamp)            as dropoff_at,
        cast(PULocationID          as integer)              as pickup_zone_id,
        cast(DOLocationID          as integer)              as dropoff_zone_id,
        cast(fare_amount           as double)               as fare_amount,
        cast(total_amount          as double)               as total_amount,
        cast(trip_distance         as double)               as trip_distance_miles,

        (cast(lpep_pickup_datetime as timestamp)
            >= cast(lpep_dropoff_datetime as timestamp)
         or lpep_pickup_datetime is null
         or lpep_dropoff_datetime is null)                  as failed_timestamp,
        (cast(fare_amount  as double) < 0)                  as failed_neg_fare,
        (cast(total_amount as double) < 0)                  as failed_neg_total,
        (cast(trip_distance as double) <= 0
         or trip_distance is null)                          as failed_zero_distance,
        (PULocationID is null)                              as failed_null_pickup_zone,
        (DOLocationID is null)                              as failed_null_dropoff_zone

    from {{ source('tlc_raw', 'green_tripdata') }}

),

green_anomalies as (

    select
        vehicle_class,
        vendor_id,
        pickup_at,
        dropoff_at,
        pickup_zone_id,
        dropoff_zone_id,
        fare_amount,
        total_amount,
        trip_distance_miles,
        case
            when failed_timestamp         then 'invalid_timestamps'
            when failed_null_pickup_zone  then 'null_pickup_zone'
            when failed_null_dropoff_zone then 'null_dropoff_zone'
            when failed_neg_fare          then 'negative_fare'
            when failed_neg_total         then 'negative_total'
            when failed_zero_distance     then 'zero_distance'
        end                                                 as rejection_reason
    from green_raw
    where
        failed_timestamp
        or failed_neg_fare
        or failed_neg_total
        or failed_zero_distance
        or failed_null_pickup_zone
        or failed_null_dropoff_zone

),

-- ── HVFHV anomalies ───────────────────────────────────────────────────────────
hvfhv_raw as (

    select
        'hvfhv'                                             as vehicle_class,
        cast(null as integer)                               as vendor_id,
        cast(pickup_datetime  as timestamp)                 as pickup_at,
        cast(dropoff_datetime as timestamp)                 as dropoff_at,
        cast(PULocationID     as integer)                   as pickup_zone_id,
        cast(DOLocationID     as integer)                   as dropoff_zone_id,
        cast(base_passenger_fare as double)                 as fare_amount,
        cast(
            coalesce(cast(base_passenger_fare   as double), 0)
            + coalesce(cast(tolls               as double), 0)
            + coalesce(cast(bcf                 as double), 0)
            + coalesce(cast(sales_tax           as double), 0)
            + coalesce(cast(congestion_surcharge as double), 0)
            + coalesce(cast(airport_fee         as double), 0)
            + coalesce(cast(tips                as double), 0)
        as double)                                          as total_amount,
        cast(trip_miles as double)                          as trip_distance_miles,

        (cast(pickup_datetime  as timestamp)
            >= cast(dropoff_datetime as timestamp)
         or pickup_datetime  is null
         or dropoff_datetime is null)                       as failed_timestamp,
        (cast(base_passenger_fare as double) < 0)           as failed_neg_fare,
        ((
            coalesce(cast(base_passenger_fare   as double), 0)
            + coalesce(cast(tolls               as double), 0)
            + coalesce(cast(bcf                 as double), 0)
            + coalesce(cast(sales_tax           as double), 0)
            + coalesce(cast(congestion_surcharge as double), 0)
            + coalesce(cast(airport_fee         as double), 0)
            + coalesce(cast(tips                as double), 0)
        ) < 0)                                              as failed_neg_total,
        (cast(trip_miles as double) <= 0
         or trip_miles is null)                             as failed_zero_distance,
        (PULocationID is null)                              as failed_null_pickup_zone,
        (DOLocationID is null)                              as failed_null_dropoff_zone

    from {{ source('tlc_raw', 'fhvhv_tripdata') }}

),

hvfhv_anomalies as (

    select
        vehicle_class,
        vendor_id,
        pickup_at,
        dropoff_at,
        pickup_zone_id,
        dropoff_zone_id,
        fare_amount,
        total_amount,
        trip_distance_miles,
        case
            when failed_timestamp         then 'invalid_timestamps'
            when failed_null_pickup_zone  then 'null_pickup_zone'
            when failed_null_dropoff_zone then 'null_dropoff_zone'
            when failed_neg_fare          then 'negative_fare'
            when failed_neg_total         then 'negative_total'
            when failed_zero_distance     then 'zero_distance'
        end                                                 as rejection_reason
    from hvfhv_raw
    where
        failed_timestamp
        or failed_neg_fare
        or failed_neg_total
        or failed_zero_distance
        or failed_null_pickup_zone
        or failed_null_dropoff_zone

)

-- ── Union all anomalies ───────────────────────────────────────────────────────
select * from yellow_anomalies
union all
select * from green_anomalies
union all
select * from hvfhv_anomalies
