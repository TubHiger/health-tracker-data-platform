-- ============================================
-- Health Tracker Database Schema
-- PostgreSQL DDL with LOINC Integration
-- ============================================

-- Enable UUID extension (useful for secure IDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- TABLE: users
-- Stores user account information
-- ============================================
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    gender VARCHAR(20) CHECK (gender IN ('Male', 'Female', 'Other', 'Prefer not to say')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL  -- Soft delete support
);

-- Index for fast email lookups (login)
CREATE INDEX idx_users_email ON users(email);

-- Index for active users only
CREATE INDEX idx_users_active ON users(user_id) WHERE deleted_at IS NULL;

COMMENT ON TABLE users IS 'User accounts and profile information';
COMMENT ON COLUMN users.password_hash IS 'Bcrypt hashed password';
COMMENT ON COLUMN users.deleted_at IS 'Timestamp for soft deletes - NULL means active user';

-- ============================================
-- TABLE: blood_tests
-- Stores metadata about each uploaded test
-- ============================================
CREATE TABLE blood_tests (
    test_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    test_date DATE NOT NULL,
    lab_name VARCHAR(200),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    pdf_filename VARCHAR(255),
    pdf_storage_path VARCHAR(500),
    raw_text TEXT,
    status VARCHAR(20) DEFAULT 'processed' CHECK (status IN ('pending', 'processed', 'failed', 'archived')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);

-- Index for user's tests ordered by date (most common query)
CREATE INDEX idx_blood_tests_user_date ON blood_tests(user_id, test_date DESC) WHERE deleted_at IS NULL;

-- Index for uploaded date
CREATE INDEX idx_blood_tests_uploaded ON blood_tests(uploaded_at DESC);

COMMENT ON TABLE blood_tests IS 'Blood test metadata and uploaded documents';
COMMENT ON COLUMN blood_tests.test_date IS 'Date when blood was drawn (not upload date)';
COMMENT ON COLUMN blood_tests.raw_text IS 'Full extracted text from Docling for reprocessing';
COMMENT ON COLUMN blood_tests.status IS 'Processing status of the test';

-- ============================================
-- TABLE: biomarker_types
-- Reference table with LOINC standardization
-- ============================================
CREATE TABLE biomarker_types (
    biomarker_type_id SERIAL PRIMARY KEY,
    loinc_code VARCHAR(10) UNIQUE,
    loinc_long_name VARCHAR(255),
    display_name VARCHAR(100) NOT NULL,
    category VARCHAR(100),
    typical_unit VARCHAR(20),
    common_aliases TEXT[],
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for LOINC code lookups
CREATE INDEX idx_biomarker_types_loinc ON biomarker_types(loinc_code);

-- Index for category filtering
CREATE INDEX idx_biomarker_types_category ON biomarker_types(category);

-- GIN index for array search on aliases (fast "contains" queries)
CREATE INDEX idx_biomarker_types_aliases ON biomarker_types USING GIN(common_aliases);

COMMENT ON TABLE biomarker_types IS 'Standardized biomarker definitions using LOINC codes';
COMMENT ON COLUMN biomarker_types.loinc_code IS 'Official LOINC code (e.g., 718-7 for Hemoglobin)';
COMMENT ON COLUMN biomarker_types.display_name IS 'User-friendly name displayed in UI';
COMMENT ON COLUMN biomarker_types.common_aliases IS 'Array of alternative names from different labs';

-- ============================================
-- TABLE: biomarkers
-- Actual test results/values
-- ============================================
CREATE TABLE biomarkers (
    biomarker_id SERIAL PRIMARY KEY,
    test_id INTEGER NOT NULL REFERENCES blood_tests(test_id) ON DELETE CASCADE,
    biomarker_type_id INTEGER NOT NULL REFERENCES biomarker_types(biomarker_type_id),
    value_numeric DECIMAL(10,2),
    value_operator VARCHAR(2) CHECK (value_operator IN ('<', '>', '<=', '>=', NULL)),
    value_text VARCHAR(100),
    unit VARCHAR(20),
    flag VARCHAR(20) CHECK (flag IN ('Low', 'High', 'Normal', 'Abnormal', 'H', 'L', NULL)),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT value_check CHECK (
        value_numeric IS NOT NULL OR value_text IS NOT NULL
    )
);

-- Critical index for time-series queries
CREATE INDEX idx_biomarkers_timeseries ON biomarkers(biomarker_type_id, test_id);

-- Index for fetching all biomarkers for a test
CREATE INDEX idx_biomarkers_test ON biomarkers(test_id);

-- Composite index for user trend queries
CREATE INDEX idx_biomarkers_user_type ON biomarkers(test_id, biomarker_type_id);

COMMENT ON TABLE biomarkers IS 'Individual biomarker test results';
COMMENT ON COLUMN biomarkers.value_numeric IS 'Numeric value (e.g., 14.5 for Hemoglobin)';
COMMENT ON COLUMN biomarkers.value_operator IS 'Operator for threshold values (e.g., < for <13.5)';
COMMENT ON COLUMN biomarkers.value_text IS 'Text results (e.g., Negative, Positive)';
COMMENT ON COLUMN biomarkers.flag IS 'Lab-provided flag indicating abnormal results';

-- ============================================
-- TABLE: biomarker_mappings
-- AI-assisted mapping from raw PDF names to standardized types
-- ============================================
CREATE TABLE biomarker_mappings (
    mapping_id SERIAL PRIMARY KEY,
    raw_name VARCHAR(200) NOT NULL,
    biomarker_type_id INTEGER NOT NULL REFERENCES biomarker_types(biomarker_type_id),
    loinc_code VARCHAR(10),
    confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    user_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(raw_name, biomarker_type_id)
);

-- Index for fast lookup when parsing new PDFs
CREATE INDEX idx_mappings_raw_name ON biomarker_mappings(raw_name);

-- Index for verification queries
CREATE INDEX idx_mappings_unverified ON biomarker_mappings(user_verified) WHERE user_verified = FALSE;

COMMENT ON TABLE biomarker_mappings IS 'Learned mappings from lab-specific names to standardized types';
COMMENT ON COLUMN biomarker_mappings.raw_name IS 'Exact name as it appears in PDF (e.g., "Glucose, Fasting")';
COMMENT ON COLUMN biomarker_mappings.confidence_score IS 'AI confidence in mapping (0.0-1.0)';
COMMENT ON COLUMN biomarker_mappings.user_verified IS 'Whether user confirmed this mapping is correct';

-- ============================================
-- VIEWS: Convenient queries
-- ============================================

-- View: Latest test for each user
CREATE VIEW user_latest_tests AS
SELECT DISTINCT ON (user_id)
    user_id,
    test_id,
    test_date,
    lab_name,
    uploaded_at
FROM blood_tests
WHERE deleted_at IS NULL
ORDER BY user_id, test_date DESC;

COMMENT ON VIEW user_latest_tests IS 'Most recent blood test for each user';

-- View: Biomarker trends (denormalized for analytics)
CREATE VIEW biomarker_trends AS
SELECT 
    u.user_id,
    u.email,
    bt.test_id,
    bt.test_date,
    bt.lab_name,
    btype.biomarker_type_id,
    btype.loinc_code,
    btype.display_name,
    btype.category,
    b.value_numeric,
    b.value_operator,
    b.value_text,
    b.unit,
    b.flag
FROM biomarkers b
JOIN blood_tests bt ON b.test_id = bt.test_id
JOIN users u ON bt.user_id = u.user_id
JOIN biomarker_types btype ON b.biomarker_type_id = btype.biomarker_type_id
WHERE bt.deleted_at IS NULL AND u.deleted_at IS NULL;

COMMENT ON VIEW biomarker_trends IS 'Denormalized view for time-series analysis and charting';

-- ============================================
-- FUNCTIONS: Useful utilities
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_blood_tests_updated_at BEFORE UPDATE ON blood_tests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_biomarker_types_updated_at BEFORE UPDATE ON biomarker_types
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SAMPLE DATA: For testing (optional)
-- ============================================

-- Insert sample biomarker types (top common tests)
INSERT INTO biomarker_types (loinc_code, loinc_long_name, display_name, category, typical_unit, common_aliases) VALUES
('718-7', 'Hemoglobin [Mass/volume] in Blood', 'Hemoglobin', 'Complete Blood Count', 'g/dL', ARRAY['Hgb', 'HGB', 'Hb', 'Hemoglobin']),
('789-8', 'Erythrocytes [#/volume] in Blood', 'RBC Count', 'Complete Blood Count', 'million/cmm', ARRAY['RBC', 'Red Blood Cells', 'Erythrocytes']),
('4544-3', 'Hematocrit [Volume Fraction] of Blood', 'Hematocrit', 'Complete Blood Count', '%', ARRAY['Hct', 'HCT', 'Packed Cell Volume']),
('787-2', 'MCV [Entitic volume]', 'MCV', 'Complete Blood Count', 'fL', ARRAY['Mean Corpuscular Volume']),
('785-6', 'MCH [Entitic mass]', 'MCH', 'Complete Blood Count', 'pg', ARRAY['Mean Corpuscular Hemoglobin']),
('786-4', 'MCHC [Mass/volume]', 'MCHC', 'Complete Blood Count', 'g/dL', ARRAY['Mean Corpuscular Hemoglobin Concentration']),
('6690-2', 'Leukocytes [#/volume] in Blood', 'WBC Count', 'Complete Blood Count', '/cmm', ARRAY['WBC', 'White Blood Cells', 'Leukocytes']),
('770-8', 'Neutrophils/100 leukocytes in Blood', 'Neutrophils', 'Complete Blood Count', '%', ARRAY['Neutrophils', 'Neut']),
('736-9', 'Lymphocytes/100 leukocytes in Blood', 'Lymphocytes', 'Complete Blood Count', '%', ARRAY['Lymphocytes', 'Lymph']),
('713-8', 'Eosinophils/100 leukocytes in Blood', 'Eosinophils', 'Complete Blood Count', '%', ARRAY['Eosinophils', 'Eos']),
('5905-5', 'Monocytes/100 leukocytes in Blood', 'Monocytes', 'Complete Blood Count', '%', ARRAY['Monocytes', 'Mono']),
('704-7', 'Basophils/100 leukocytes in Blood', 'Basophils', 'Complete Blood Count', '%', ARRAY['Basophils', 'Baso']),
('777-3', 'Platelets [#/volume] in Blood', 'Platelet Count', 'Complete Blood Count', '/cmm', ARRAY['Platelets', 'PLT']),
('32623-1', 'Platelet mean volume [Entitic volume] in Blood', 'MPV', 'Complete Blood Count', 'fL', ARRAY['Mean Platelet Volume']),
('2345-7', 'Glucose [Mass/volume] in Serum or Plasma', 'Glucose', 'Metabolic Panel', 'mg/dL', ARRAY['Blood Glucose', 'Blood Sugar', 'Glu']),
('2093-3', 'Cholesterol [Mass/volume] in Serum or Plasma', 'Total Cholesterol', 'Lipid Panel', 'mg/dL', ARRAY['Cholesterol', 'Total Chol', 'Chol']),
('2571-8', 'Triglyceride [Mass/volume] in Serum or Plasma', 'Triglycerides', 'Lipid Panel', 'mg/dL', ARRAY['TG', 'Trig']),
('2085-9', 'Cholesterol in HDL [Mass/volume] in Serum or Plasma', 'HDL Cholesterol', 'Lipid Panel', 'mg/dL', ARRAY['HDL', 'Good Cholesterol']),
('13457-7', 'Cholesterol in LDL [Mass/volume] in Serum or Plasma', 'LDL Cholesterol', 'Lipid Panel', 'mg/dL', ARRAY['LDL', 'Bad Cholesterol']);

COMMENT ON TABLE biomarker_types IS 'Seeded with common lab tests using LOINC codes';