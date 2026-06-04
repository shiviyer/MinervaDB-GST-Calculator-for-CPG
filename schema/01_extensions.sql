-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: schema/01_extensions.sql
-- Description: Required PostgreSQL extensions for GST Calculator
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

-- Enable UUID generation for primary keys
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable cryptographic functions for GSTIN checksum validation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enable GiST index support for range queries on tax periods
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Enable unaccent for name normalization (party names, address fields)
CREATE EXTENSION IF NOT EXISTS "unaccent";

-- Create dedicated GST schema
CREATE SCHEMA IF NOT EXISTS gst;

-- Set search path
ALTER DATABASE minervadb_gst_cpg SET search_path TO gst, public;

-- Create roles for access control
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gst_admin') THEN
        CREATE ROLE gst_admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gst_user') THEN
        CREATE ROLE gst_user NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gst_readonly') THEN
        CREATE ROLE gst_readonly NOLOGIN;
    END IF;
END
$$;

-- Grant schema privileges
GRANT ALL ON SCHEMA gst TO gst_admin;
GRANT USAGE ON SCHEMA gst TO gst_user;
GRANT USAGE ON SCHEMA gst TO gst_readonly;

COMMENT ON SCHEMA gst IS 'MinervaDB GST Calculator for CPG - Core GST schema for India CPG industry';
