{{
    config(
        materialized         = 'incremental',
        incremental_strategy = 'delete+insert',
        unique_key           = ['trip_id', 'vehicle_class']
    )
}}
{#
  Incremental strategy: on each run, only process pickup_dates newer than
  the latest date already in the table (with a 1-day buffer for late arrivals).
  Description lives in _core_models.yml.
#}

with trips as (

    select * from {{ ref('int_trips_unified') }}

    {% if is_incremental() %}
        -- On incremental runs, only process dates we haven't seen yet.
        -- The +1-day buffer guards against late-arriving records.
        where pickup_date > (
            select max(pickup_date) - interval '1' day from {{ this }}
        )
    {% endif %}

),

pickup_zones as (
    select location_id, zone_name as pickup_zone_name, borough as pickup_borough
    from {{ ref('dim_zones') }}
),

dropoff_zones as (
    select location_id, zone_name as dropoff_zone_name, borough as dropoff_borough
    from {{ ref('dim_zones') }}
),

vehicle_classes as (
    select vehicle_class, display_name as vehicle_display_name, is_rideshare
    from {{ ref('dim_vehicle_class') }}
),

final as (

    select
        -- Keys
        t.trip_id,
        t.vehicle_class,
        t.vendor_id,

        -- Timestamps + derived date fields
        t.pickup_at,
        t.dropoff_at,
        t.pickup_date,
        extract(hour from t.pickup_at)::integer     as pickup_hour,
        extract(isodow from t.pickup_at)::integer   as pickup_dow,
        datediff('minute', t.pickup_at, t.dropoff_at) as trip_duration_minutes,

        -- Zone keys + denormalized labels
        t.pickup_zone_id,
        t.dropoff_zone_id,
        pz.pickup_zone_name,
        pz.pickup_borough,
        dz.dropoff_zone_name,
        dz.dropoff_borough,

        -- Passenger
        t.passenger_count,

        -- Distance
        t.trip_distance_miles,
        -- Derived: fare per mile (null-safe)
        case
            when t.trip_distance_miles > 0
            then round(t.fare_amount / t.trip_distance_miles, 4)
        end                                          as fare_per_mile,

        -- Fares
        t.fare_amount,
        t.tip_amount,
        t.total_amount,
        -- Tip rate as % of fare (null-safe; excluded when fare = 0)
        case
            when t.fare_amount > 0
            then round(100.0 * t.tip_amount / t.fare_amount, 2)
        end                                          as tip_pct,

        -- Payment (null for HVFHV — coalesce to 0 for dim join)
        coalesce(t.payment_type, 0)                  as payment_type_id,
        t.rate_code_id,

        -- Surcharges
        t.tolls_amount,
        t.congestion_surcharge,
        t.airport_fee,
        t.extra,
        t.mta_tax,
        t.improvement_surcharge,

        -- Vehicle class metadata
        vc.vehicle_display_name,
        vc.is_rideshare

    from trips t
    left join pickup_zones  pz on t.pickup_zone_id  = pz.location_id
    left join dropoff_zones dz on t.dropoff_zone_id = dz.location_id
    left join vehicle_classes vc on t.vehicle_class = vc.vehicle_class

)

select * from final
