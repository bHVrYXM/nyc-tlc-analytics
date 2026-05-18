{{
    config(
        materialized = 'table',
        description  = 'Date spine covering the full data range (2024-01-01 to 2024-03-31 '
                       'for the dev dataset; extend the range_end macro arg for production). '
                       'Provides calendar attributes that power every time-series chart in '
                       'the dashboard without requiring dashboard-side date math.'
    )
}}

-- Generate one row per date in the range.
-- dbt_utils.date_spine handles this cleanly; adjust range as data grows.
with date_spine as (

    {{ dbt_utils.date_spine(
        datepart = "day",
        start_date = "cast('2023-12-01' as date)",
        end_date   = "cast('2025-01-01' as date)"
    ) }}

),

enriched as (

    select
        cast(date_day as date)                      as date_day,

        -- Calendar attributes
        extract(year  from date_day)::integer        as year,
        extract(month from date_day)::integer        as month,
        extract(day   from date_day)::integer        as day_of_month,

        -- ISO day of week: 1 = Monday, 7 = Sunday
        extract(isodow from date_day)::integer       as day_of_week,
        strftime(date_day, '%A')                     as day_name,
        strftime(date_day, '%B')                     as month_name,

        -- Week / quarter
        extract(week    from date_day)::integer      as week_of_year,
        extract(quarter from date_day)::integer      as quarter,

        -- Useful flags
        extract(isodow from date_day) >= 6           as is_weekend,

        -- Fiscal / analytical periods
        date_trunc('week',  date_day)::date          as week_start,
        date_trunc('month', date_day)::date          as month_start

    from date_spine

)

select * from enriched
