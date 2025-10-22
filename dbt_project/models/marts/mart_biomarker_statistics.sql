-- Mart: Statistical analysis per biomarker per user
{{
    config(
        materialized='table'
    )
}}

SELECT
    user_id,
    biomarker_type_id,
    biomarker_name,
    loinc_code,
    category,
    unit,
    COUNT(*) as measurement_count,
    MIN(value_numeric) as min_value,
    MAX(value_numeric) as max_value,
    AVG(value_numeric) as avg_value,
    STDDEV(value_numeric) as std_deviation,
    MIN(test_date) as first_measurement_date,
    MAX(test_date) as latest_measurement_date
FROM {{ ref('int_biomarker_results') }}
WHERE value_numeric IS NOT NULL
GROUP BY user_id, biomarker_type_id, biomarker_name, loinc_code, category, unit
HAVING COUNT(*) > 0