-- Mart: Biomarker trends over time for each user
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
    test_date,
    value_numeric,
    unit,
    flag,
    result_status,
    -- Calculate trend metrics
    LAG(value_numeric) OVER (
        PARTITION BY user_id, biomarker_type_id 
        ORDER BY test_date
    ) as previous_value,
    value_numeric - LAG(value_numeric) OVER (
        PARTITION BY user_id, biomarker_type_id 
        ORDER BY test_date
    ) as change_from_previous,
    ROW_NUMBER() OVER (
        PARTITION BY user_id, biomarker_type_id 
        ORDER BY test_date DESC
    ) as test_sequence
FROM {{ ref('int_biomarker_results') }}
WHERE value_numeric IS NOT NULL