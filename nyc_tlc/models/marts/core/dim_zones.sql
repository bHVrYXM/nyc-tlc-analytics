{{
    config(
        materialized = 'table',
        description  = 'Taxi zone dimension — one row per TLC location_id. Enriches the '
                       'raw lookup with a borough_group that collapses granular boroughs '
                       'into analytical groupings used by the dashboard heatmap.'
    )
}}

with zones as (

    select * from {{ ref('stg_zone_lookup') }}

)

select
    location_id,
    zone_name,
    borough,
    service_zone,

    -- Analytical grouping used by dashboard heatmap and equity analysis
    -- Airports get their own group because their fare profile is an outlier
    case
        when zone_name ilike '%airport%'
          or zone_name ilike '%jfk%'
          or zone_name ilike '%laguardia%'
          or zone_name ilike '%newark%'    then 'Airport'
        when borough = 'Manhattan'         then 'Manhattan'
        when borough = 'Brooklyn'          then 'Brooklyn'
        when borough = 'Queens'            then 'Queens'
        when borough = 'Bronx'             then 'Bronx'
        when borough = 'Staten Island'     then 'Staten Island'
        else 'Other / Unknown'
    end                                    as borough_group

from zones
