with source as (

    select * from {{ source('tlc_raw', 'yellow_tripdata') }}

),

cast_columns as (

    select
        -- Surrogate key (used for dedup detection in marts)
        {{ dbt_utils.generate_surrogate_key([
            'VendorID',
            'tpep_pickup_datetime',
            'tpep_dropoff_datetime',
            'PULocationID',
            'DOLocationID',
            'total_amount'
        ]) }}                                            as trip_id,

        -- Canonical timestamp columns
        cast(tpep_pickup_datetime  as timestamp)        as pickup_at,
        cast(tpep_dropoff_datetime as timestamp)        as dropoff_at,

        -- Canonical zone columns
        cast(PULocationID as integer)                   as pickup_zone_id,
        cast(DOLocationID as integer)                   as dropoff_zone_id,

        -- Canonical fare columns
        cast(fare_amount          as double)            as fare_amount,
        cast(tip_amount           as double)            as tip_amount,
        cast(total_amount         as double)            as total_amount,

        -- Canonical identity columns
        cast(VendorID             as integer)           as vendor_id,
        'yellow'                                        as vehicle_class,

        -- Canonical passenger column
        cast(passenger_count      as integer)           as passenger_count,

        -- Additional columns retained for marts
        cast(trip_distance        as double)            as trip_distance_miles,
        cast(RatecodeID           as integer)           as rate_code_id,
        cast(payment_type         as integer)           as payment_type,
        cast(extra                as double)            as extra,
        cast(mta_tax              as double)            as mta_tax,
        cast(tolls_amount         as double)            as tolls_amount,
        cast(improvement_surcharge as double)           as improvement_surcharge,
        cast(congestion_surcharge as double)            as congestion_surcharge,
        cast(Airport_fee          as double)            as airport_fee,
        cast(store_and_fwd_flag   as varchar)           as store_and_fwd_flag

    from source

),

filtered as (

    -- Drop obvious garbage rows; counts of what was dropped are in
    -- stg_trip_reject_audit so the rejection rate becomes a case-study data point.
    select * from cast_columns
    where
        pickup_at        < dropoff_at          -- valid trip duration
        and fare_amount  >= 0                  -- non-negative fare
        and total_amount >= 0                  -- non-negative total
        and trip_distance_miles > 0            -- non-zero distance
        and pickup_zone_id  is not null
        and dropoff_zone_id is not null

)

select * from filtered
