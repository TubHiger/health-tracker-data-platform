-- Staging: Clean users table
{{
    config(
        materialized='view'
    )
}}

SELECT
    user_id,
    email,
    first_name,
    last_name,
    date_of_birth,
    gender,
    created_at,
    updated_at
FROM {{ source('public', 'users') }}
WHERE deleted_at IS NULL