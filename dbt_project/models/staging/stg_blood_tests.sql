-- Staging: Clean blood tests
{{
    config(
        materialized='view'
    )
}}

SELECT
    test_id,
    user_id,
    test_date,
    lab_name,
    uploaded_at,
    pdf_filename,
    status
FROM {{ source('public', 'blood_tests') }}
WHERE deleted_at IS NULL
    AND status = 'processed'