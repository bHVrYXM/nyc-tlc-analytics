-- Singular test: no trip should have a pickup_at in the future.
--
-- A future pickup timestamp indicates either upstream data corruption,
-- a timezone handling bug, or a mis-cast column. Catching it here prevents
-- bad rows from silently inflating date-range metrics on the dashboard.
--
-- Returns future-dated rows — any result = test failure.

select
    trip_id,
    vehicle_class,
    pickup_at,
    current_timestamp                   as checked_at,
    datediff('hour', current_timestamp, pickup_at) as hours_in_future

from {{ ref('fct_trips') }}
where pickup_at > current_timestamp
