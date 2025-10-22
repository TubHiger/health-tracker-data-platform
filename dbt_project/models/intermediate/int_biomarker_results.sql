-- Intermediate: Enrich biomarkers with test and user info
{{
    config(
        materialized='view'
    )
}}

SELECT
    u.user_id,
    u.email,
    u.first_name,
    u.last_name,
    bt.test_id,
    bt.test_date,
    bt.lab_name,
    btype.biomarker_type_id,
    btype.loinc_code,
    btype.display_name as biomarker_name,
    btype.category,
    b.value_numeric,
    b.value_operator,
    b.value_text,
    b.unit,
    b.flag,
    -- Add helpful calculated fields
    CASE 
        WHEN b.flag IN ('Low', 'L') THEN 'Below Normal'
        WHEN b.flag IN ('High', 'H') THEN 'Above Normal'
        ELSE 'Normal'
    END as result_status
FROM {{ ref('stg_biomarkers') }} b
JOIN {{ ref('stg_blood_tests') }} bt ON b.test_id = bt.test_id
JOIN {{ ref('stg_users') }} u ON bt.user_id = u.user_id
JOIN {{ ref('stg_biomarker_types') }} btype ON b.biomarker_type_id = btype.biomarker_type_id