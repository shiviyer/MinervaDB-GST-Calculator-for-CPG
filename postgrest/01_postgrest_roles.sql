-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: postgrest/01_postgrest_roles.sql
-- Description: PostgREST role setup, JWT claims handling, API security layer
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
--
-- ARCHITECTURE: API-First with PostgREST
-- ========================================
-- This file sets up the PostgREST-compatible role hierarchy and security layer.
-- PostgREST uses PostgreSQL roles directly for authentication/authorization.
--
-- Role hierarchy:
--   authenticator        — PostgREST connection role (LOGIN, no schema perms)
--   gst_readonly         — Anonymous/read-only JWT claims
--   gst_user             — Authenticated user (can create invoices, record ITC)
--   gst_admin            — Full admin (rate management, filing status updates)
--
-- JWT claims expected (in 'request.jwt.claims' PostgreSQL setting):
--   { "role": "gst_user", "gstin": "27AABCU9603R1ZX", "sub": "user-uuid" }
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- Create authenticator role (PostgREST connects as this role)
-- -------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'CHANGE_ME_IN_PRODUCTION';
    END IF;
END
$$;

-- Allow authenticator to switch to API roles
GRANT gst_readonly TO authenticator;
GRANT gst_user     TO authenticator;
GRANT gst_admin    TO authenticator;

-- -------------------------------------------------------------------------
-- FUNCTION: set_session_context
-- Called by PostgREST as db-pre-request hook
-- Extracts JWT claims and sets session-level GUCs for RLS and audit
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.set_session_context()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_claims   JSONB;
    v_gstin    TEXT;
    v_user_id  TEXT;
    v_role     TEXT;
BEGIN
    -- Get JWT claims set by PostgREST
    v_claims  := current_setting('request.jwt.claims', TRUE)::JSONB;
    v_gstin   := v_claims->>'gstin';
    v_user_id := v_claims->>'sub';
    v_role    := v_claims->>'role';

    -- Set app-level GUCs for audit trail
    IF v_user_id IS NOT NULL THEN
        PERFORM set_config('app.current_user',    v_user_id, TRUE);
    END IF;
    IF v_gstin IS NOT NULL THEN
        PERFORM set_config('app.current_gstin',   v_gstin,   TRUE);
    END IF;
    PERFORM set_config('app.application_name', 'PostgREST-GST-API', TRUE);
EXCEPTION WHEN OTHERS THEN
    -- Ignore errors (e.g., unauthenticated requests have no claims)
    NULL;
END;
$$;

COMMENT ON FUNCTION gst.set_session_context IS
    'PostgREST pre-request hook. Extracts JWT claims (gstin, sub, role) into session GUCs
     for audit trail and Row-Level Security. Configure as db-pre-request in postgrest.conf.';

-- -------------------------------------------------------------------------
-- Row-Level Security (RLS) for multi-tenant GSTIN isolation
-- -------------------------------------------------------------------------

-- Enable RLS on tax_invoice (tenants can only see their own invoices)
ALTER TABLE gst.tax_invoice         ENABLE ROW LEVEL SECURITY;
ALTER TABLE gst.invoice_line_item   ENABLE ROW LEVEL SECURITY;
ALTER TABLE gst.itc_ledger          ENABLE ROW LEVEL SECURITY;
ALTER TABLE gst.gstr_filing_log     ENABLE ROW LEVEL SECURITY;

-- Policy: gst_user can only see invoices where they are seller or buyer
CREATE POLICY policy_invoice_tenant ON gst.tax_invoice
    FOR ALL
    TO gst_user
    USING (
          seller_gstin = current_setting('app.current_gstin', TRUE)
          OR buyer_gstin  = current_setting('app.current_gstin', TRUE)
      );

-- Policy: line items follow the parent invoice's GSTIN
CREATE POLICY policy_line_item_tenant ON gst.invoice_line_item
    FOR ALL
    TO gst_user
    USING (
          invoice_id IN (
              SELECT invoice_id FROM gst.tax_invoice
              WHERE seller_gstin = current_setting('app.current_gstin', TRUE)
                 OR buyer_gstin  = current_setting('app.current_gstin', TRUE)
          )
      );

-- Policy: ITC ledger limited to own GSTIN
CREATE POLICY policy_itc_tenant ON gst.itc_ledger
    FOR ALL
    TO gst_user
    USING (gstin = current_setting('app.current_gstin', TRUE));

-- Policy: GSTR filing log limited to own GSTIN
CREATE POLICY policy_gstr_filing_tenant ON gst.gstr_filing_log
    FOR ALL
    TO gst_user
    USING (gstin = current_setting('app.current_gstin', TRUE));

-- gst_admin bypasses RLS (BYPASSRLS privilege)
ALTER ROLE gst_admin BYPASSRLS;

-- gst_readonly gets unrestricted read (or create separate policy if needed)
CREATE POLICY policy_invoice_readonly ON gst.tax_invoice
    FOR SELECT
    TO gst_readonly
    USING (TRUE);

CREATE POLICY policy_line_item_readonly ON gst.invoice_line_item
    FOR SELECT
    TO gst_readonly
    USING (TRUE);

CREATE POLICY policy_itc_readonly ON gst.itc_ledger
    FOR SELECT
    TO gst_readonly
    USING (TRUE);

CREATE POLICY policy_gstr_filing_readonly ON gst.gstr_filing_log
    FOR SELECT
    TO gst_readonly
    USING (TRUE);

-- -------------------------------------------------------------------------
-- API-optimized views for PostgREST (prefixed with api_ for clarity)
-- These views enforce column-level projections suitable for REST responses
-- -------------------------------------------------------------------------

CREATE OR REPLACE VIEW gst.api_invoices AS
SELECT
    invoice_id,
    invoice_number,
    invoice_date,
    invoice_type,
    supply_type,
    seller_gstin,
    buyer_gstin,
    buyer_name,
    buyer_state_code,
    place_of_supply,
    is_igst_applicable  AS is_igst,
    is_reverse_charge   AS is_rcm,
    taxable_value,
    cgst_amount,
    sgst_amount,
    igst_amount,
    cess_amount,
    total_tax_amount,
    invoice_value,
    gstr1_period,
    is_cancelled,
    created_at,
    updated_at
FROM gst.tax_invoice;

CREATE OR REPLACE VIEW gst.api_line_items AS
SELECT
    line_item_id,
    invoice_id,
    invoice_date,
    line_number,
    product_code,
    product_description,
    hsn_code,
    uom,
    quantity,
    unit_price,
    gross_amount,
    discount_amount,
    taxable_value,
    cgst_rate,  cgst_amount,
    sgst_rate,  sgst_amount,
    igst_rate,  igst_amount,
    cess_rate,  cess_amount,
    total_tax_amount,
    line_total,
    supply_category
FROM gst.invoice_line_item;

CREATE OR REPLACE VIEW gst.api_hsn_rates AS
SELECT
    h.hsn_code,
    h.hsn_description,
    h.cpg_category,
    h.cpg_sub_category,
    h.uom,
    r.cgst_rate,
    r.sgst_rate,
    r.igst_rate,
    r.cess_rate,
    r.cess_amount,
    r.supply_category,
    r.notification_ref,
    r.effective_from,
    r.effective_to
FROM gst.hsn_code_master h
JOIN gst.gst_rate_master  r ON r.hsn_code = h.hsn_code
WHERE h.is_active = TRUE AND r.is_active = TRUE;

-- Grant API views to roles
GRANT SELECT ON gst.api_invoices   TO gst_user, gst_readonly;
GRANT SELECT ON gst.api_line_items TO gst_user, gst_readonly;
GRANT SELECT ON gst.api_hsn_rates  TO gst_user, gst_readonly;

COMMENT ON VIEW gst.api_invoices   IS 'PostgREST API view: invoice list with RLS applied';
COMMENT ON VIEW gst.api_line_items IS 'PostgREST API view: invoice line items with RLS applied';
COMMENT ON VIEW gst.api_hsn_rates  IS 'PostgREST API view: combined HSN + rate lookup';
