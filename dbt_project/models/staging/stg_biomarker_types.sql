-- Staging: Biomarker type definitions
{{
    config(
        materialized='view'
    )
}}

SELECT
    biomarker_type_id,
    loinc_code,
    loinc_long_name,
    display_name,
    category,
    typical_unit,
    common_aliases,
    description
FROM {{ source('public', 'biomarker_types') }}