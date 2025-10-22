-- Staging: Biomarkers with standardized values
{{
    config(
        materialized='view'
    )
}}

SELECT
    b.biomarker_id,
    b.test_id,
    b.biomarker_type_id,
    -- Combine numeric and text values into single field
    COALESCE(
        CONCAT(b.value_operator, b.value_numeric::text),
        b.value_text
    ) as value_display,
    b.value_numeric,
    b.value_operator,
    b.value_text,
    b.unit,
    b.flag,
    b.created_at
FROM {{ source('public', 'biomarkers') }} b