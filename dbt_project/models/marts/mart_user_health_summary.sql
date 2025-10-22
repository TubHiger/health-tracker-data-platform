-- Mart: User health summary with latest values
{{
    config(
        materialized='table'
    )
}}

SELECT
    user_id,
    first_name,
    last_name,
    email,
    COUNT(DISTINCT test_id) as total_tests,
    MAX(test_date) as latest_test_date,
    COUNT(DISTINCT biomarker_type_id) as unique_biomarkers_tracked,
    COUNT(CASE WHEN flag IN ('High', 'H', 'Low', 'L') THEN 1 END) as abnormal_results_count
FROM {{ ref('int_biomarker_results') }}
GROUP BY user_id, first_name, last_name, email