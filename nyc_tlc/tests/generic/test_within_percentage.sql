{% test within_percentage(model, column_name, compare_column, threshold_pct=10) %}
-- Generic test: asserts that `column_name` is within `threshold_pct`% of
-- `compare_column` for every row in the model.
--
-- Usage in a YAML schema file:
--
--   columns:
--     - name: total_amount
--       tests:
--         - within_percentage:
--             compare_column: computed_total
--             threshold_pct: 5   # default is 10%
--
-- Returns rows where the deviation exceeds the threshold — any result = failure.

select
    *,
    abs({{ column_name }} - {{ compare_column }})
        / nullif(abs({{ compare_column }}), 0) * 100       as deviation_pct

from {{ model }}
where
    {{ compare_column }} is not null
    and {{ column_name }}  is not null
    and abs({{ column_name }} - {{ compare_column }})
        / nullif(abs({{ compare_column }}), 0) * 100
        > {{ threshold_pct }}

{% endtest %}
