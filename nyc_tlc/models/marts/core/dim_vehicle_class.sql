{{
    config(
        materialized = 'table',
        description  = 'Vehicle class dimension — static seed of the three TLC vehicle classes. '
                       'Provides display labels and grouping flags for dashboard filters.'
    )
}}

-- Static reference — no upstream dependency needed.
-- If new vehicle classes are added, extend this model.
select
    vehicle_class,
    display_name,
    is_rideshare
from (
    values
        ('yellow', 'Yellow Taxi',       false),
        ('green',  'Green Taxi',        false),
        ('hvfhv',  'Uber / Lyft (TNC)', true )
) as t(vehicle_class, display_name, is_rideshare)
