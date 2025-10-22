# Health Tracker Data Platform

A normalized PostgreSQL database with dbt transformations for tracking blood test results over time.

## 🎯 Project Overview

This data platform enables:
- Multi-user blood test tracking
- LOINC-standardized biomarker storage
- Time-series analysis of health metrics
- AI-powered biomarker mapping and normalization

## 🏗️ Architecture

**Tech Stack:**
- **Database:** PostgreSQL 14+
- **Transformations:** dbt (data build tool)
- **Standards:** LOINC medical coding

**Data Layers:**
1. **Raw Layer:** Normalized transactional tables (users, blood_tests, biomarkers)
2. **Staging:** Clean, typed views with business naming
3. **Intermediate:** Enriched with joins and calculated fields
4. **Marts:** Aggregated analytical tables for reporting

## 📊 Database Schema

**Core Tables:**
- `users` - User accounts and profiles
- `blood_tests` - Test metadata and uploads
- `biomarkers` - Individual test results
- `biomarker_types` - LOINC-standardized definitions
- `biomarker_mappings` - AI-learned name mappings

**Key Features:**
- ✅ Highly normalized (3NF)
- ✅ LOINC code integration
- ✅ Time-series optimized indexes
- ✅ Soft delete support
- ✅ Multi-user architecture

## 🚀 Setup Instructions

### Prerequisites
- PostgreSQL 14+
- Python 3.9+
- dbt-core and dbt-postgres

### Database Setup

1. Create database:
```bash
createdb health_tracker
```

2. Run schema:
```bash
psql -d health_tracker -f database/schema.sql
```

### dbt Setup

1. Install dbt:
```bash
pip install dbt-core dbt-postgres
```

2. Configure profile:
```bash
cp dbt_project/profiles.yml.example ~/.dbt/profiles.yml
# Edit ~/.dbt/profiles.yml with your credentials
```

3. Run transformations:
```bash
cd dbt_project
dbt run
```

4. Generate docs:
```bash
dbt docs generate
dbt docs serve
```

## 📈 Analytics Models

**Staging Models:**
- `stg_users` - Clean user data
- `stg_blood_tests` - Processed tests
- `stg_biomarkers` - Standardized results
- `stg_biomarker_types` - LOINC definitions

**Marts:**
- `mart_biomarker_trends` - Time-series with change calculations
- `mart_user_health_summary` - User-level aggregations
- `mart_biomarker_statistics` - Statistical summaries per biomarker

## 🎓 Design Decisions

**Why LOINC?**
- Industry-standard medical coding system
- Enables cross-lab comparison
- 90,000+ standardized test codes

**Why Normalize?**
- Eliminates data duplication
- Easy to add new biomarker types
- Maintains referential integrity

**Why Separate value_numeric and value_text?**
- Handles both quantitative (14.5) and qualitative (Negative) results
- Enables statistical analysis on numeric values
- Stores operators (<, >) for threshold values

**Time-Series Optimization:**
- Composite indexes on (user_id, biomarker_type_id, test_date)
- Window functions for trend calculation
- Efficient lookups for 100K+ records

## 📸 Data Lineage

<img width="1503" height="709" alt="Screenshot 2025-10-21 at 10 22 47 PM" src="https://github.com/user-attachments/assets/c983dc45-d760-4dd9-b040-6e1431a22b9a" />


## 👤 Author

Built by Aigerim as a portfolio project demonstrating:
- Database design and normalization
- Healthcare data standards (LOINC)
- dbt transformations and documentation
- Time-series data modeling
