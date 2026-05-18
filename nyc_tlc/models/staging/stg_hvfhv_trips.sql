with source as (

    select * from {{ source('tlc_raw', 'fhvhv_tripdata') }}

),

cast_columns as (

    select
        -- Surrogate key
        -- HVFHV has no VendorID; hvfhs_license_num fills that role
        {{ dbt_utils.generate_surrogate_key([
            'hvfhs_license_num',
            'pickup_datetime',
            'dropoff_datetime',
            'PULocationID',
            'DOLocationID',
            'base_passenger_fare'
        ]) }}                                            as trip_id,

        -- Canonical timestamp columns
        cast(pickup_datetime  as timestamp)             as pickup_at,
        cast(dropoff_datetime as timestamp)             as dropoff_at,

        -- Canonical zone columns
        cast(PULocationID as integer)                   as pickup_zone_id,
        cast(DOLocationID as integer)                   as dropoff_zone_id,

        -- Canonical fare columns
        -- HVFHV separates base fare from surcharges; base_passenger_fare
        -- is the closest analog to fare_amount in yellow/green
        cast(base_passenger_fare as double)             as fare_amount,
        cast(tips                as double)             as tip_amount,
        cast(
            base_passenger_fare
            + coalesce(tolls, 0)
            + coalesce(bcf, 0)
            + coalesce(sales_tax, 0)
            + coalesce(congestion_surcharge, 0)
            + coalesce(airport_fee, 0)
            + coalesce(tips, 0)
        as double)                                      as total_amount,

        -- Canonical identity columns
        -- Map license number to a consistent vendor_id integer for mart joins;
        -- the raw license string is preserved as hvfhs_license_num
        cast(null as integer)                           as vendor_id,
        'hvfhv'                                         as vehicle_class,

        -- No passenger count in HVFHV data
        cast(null as integer)                           as passenger_count,

        -- Additional columns retained for marts
        cast(trip_miles           as double)            as trip_distance_miles,
        cast(trip_time            as integer)           as trip_time_seconds,
        cast(hvfhs_license_num    as varchar)           as hvfhs_license_num,
        cast(dispatching_base_num as varchar)           as dispatching_base_num,
        cast(originating_base_num as varchar)           as originating_base_num,
        cast(request_datetime     as timestamp)         as request_at,
        cast(on_scene_datetime    as timestamp)         as on_scene_at,
        cast(tolls                as double)            as tolls_amount,
        cast(bcf                  as double)            as bcf,
        cast(sales_tax            as double)            as sales_tax,
        cast(congestion_surcharge as double)            as congestion_surcharge,
        cast(airport_fee          as double)            as airport_fee,
        cast(driver_pay           as double)            as driver_pay,
        cast(shared_request_flag  as varchar)           as shared_request_flag,
        cast(shared_match_flag    as varchar)           as shared_match_flag,
        cast(access_a_ride_flag   as varchar)           as access_a_ride_flag,
        cast(wav_request_flag     as varchar)           as wav_request_flag,
        cast(wav_match_flag       as varchar)           as wav_match_flag

    from source

),

filtered as (

    select * from cast_columns
    where
        pickup_at        < dropoff_at
        and fare_amount  >= 0
        and total_amount >= 0
        and trip_distance_miles > 0
        and pickup_zone_id  is not null
        and dropoff_zone_id is not null

)

select * from filtered
