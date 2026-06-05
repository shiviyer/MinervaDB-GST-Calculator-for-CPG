-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: views/02_itc_views.sql
-- Description: ITC ledger and utilization views
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- VIEW: v_itc_balance
-- Current ITC balance per GSTIN and tax head
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_itc_balance AS
SELECT
    il.gstin,
    il.tax_period,
    SUM(CASE WHEN il.tax_head = 'IGST' AND il.transaction_type IN ('INWARD_SUPPLY','ISD_CREDIT')
               THEN il.credit_amount ELSE 0 END)
  - SUM(CASE WHEN il.tax_head = 'IGST' AND il.transaction_type IN ('UTILIZATION','REVERSAL')
               THEN il.debit_amount ELSE 0 END)  AS igst_balance,
    SUM(CASE WHEN il.tax_head = 'CGST' AND il.transaction_type IN ('INWARD_SUPPLY','ISD_CREDIT')
               THEN il.credit_amount ELSE 0 END)
  - SUM(CASE WHEN il.tax_head = 'CGST' AND il.transaction_type IN ('UTILIZATION','REVERSAL')
               THEN il.debit_amount ELSE 0 END)  AS cgst_balance,
    SUM(CASE WHEN il.tax_head = 'SGST' AND il.transaction_type IN ('INWARD_SUPPLY','ISD_CREDIT')
               THEN il.credit_amount ELSE 0 END)
  - SUM(CASE WHEN il.tax_head = 'SGST' AND il.transaction_type IN ('UTILIZATION','REVERSAL')
               THEN il.debit_amount ELSE 0 END)  AS sgst_balance,
    SUM(CASE WHEN il.tax_head = 'CESS' AND il.transaction_type IN ('INWARD_SUPPLY','ISD_CREDIT')
               THEN il.credit_amount ELSE 0 END)
  - SUM(CASE WHEN il.tax_head = 'CESS' AND il.transaction_type IN ('UTILIZATION','REVERSAL')
               THEN il.debit_amount ELSE 0 END)  AS cess_balance
FROM gst.itc_ledger il
WHERE il.eligibility = 'ELIGIBLE'
GROUP BY il.gstin, il.tax_period;

COMMENT ON VIEW gst.v_itc_balance IS
    'Net ITC balance per GSTIN per period (credits minus utilization/reversals).';

-- -------------------------------------------------------------------------
-- VIEW: v_itc_monthly_summary
-- Month-wise ITC availed, utilized and reversed
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_itc_monthly_summary AS
SELECT
    il.gstin,
    il.tax_period,
    -- ITC Availed
    SUM(CASE WHEN il.transaction_type = 'INWARD_SUPPLY' AND il.tax_head = 'IGST'
               THEN il.credit_amount ELSE 0 END)  AS igst_availed,
    SUM(CASE WHEN il.transaction_type = 'INWARD_SUPPLY' AND il.tax_head = 'CGST'
               THEN il.credit_amount ELSE 0 END)  AS cgst_availed,
    SUM(CASE WHEN il.transaction_type = 'INWARD_SUPPLY' AND il.tax_head = 'SGST'
               THEN il.credit_amount ELSE 0 END)  AS sgst_availed,
    SUM(CASE WHEN il.transaction_type = 'INWARD_SUPPLY' AND il.tax_head = 'CESS'
               THEN il.credit_amount ELSE 0 END)  AS cess_availed,
    -- ITC Utilized
    SUM(CASE WHEN il.transaction_type = 'UTILIZATION' AND il.tax_head = 'IGST'
               THEN il.debit_amount ELSE 0 END)   AS igst_utilized,
    SUM(CASE WHEN il.transaction_type = 'UTILIZATION' AND il.tax_head = 'CGST'
               THEN il.debit_amount ELSE 0 END)   AS cgst_utilized,
    SUM(CASE WHEN il.transaction_type = 'UTILIZATION' AND il.tax_head = 'SGST'
               THEN il.debit_amount ELSE 0 END)   AS sgst_utilized,
    -- ITC Reversed
    SUM(CASE WHEN il.transaction_type = 'REVERSAL' THEN il.debit_amount ELSE 0 END) AS total_reversed,
    -- Ineligible
    SUM(CASE WHEN il.eligibility != 'ELIGIBLE' THEN il.credit_amount ELSE 0 END)    AS ineligible_itc
FROM gst.itc_ledger il
GROUP BY il.gstin, il.tax_period;

COMMENT ON VIEW gst.v_itc_monthly_summary IS
    'Month-wise ITC availed, utilized, and reversed per GSTIN.';

-- -------------------------------------------------------------------------
-- VIEW: v_itc_blocked_credits
-- Section 17(5) blocked credits for disclosure
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_itc_blocked_credits AS
SELECT
    il.gstin,
    il.tax_period,
    il.document_number,
    il.document_date,
    il.supplier_gstin,
    il.tax_head,
    il.credit_amount,
    il.eligibility,
    il.remarks
FROM gst.itc_ledger il
WHERE il.eligibility = 'INELIGIBLE_SECTION_17_5'
ORDER BY il.gstin, il.tax_period, il.document_date;

COMMENT ON VIEW gst.v_itc_blocked_credits IS
    'All Section 17(5) blocked credits for GSTR-3B Table 4D disclosure.';

-- -------------------------------------------------------------------------
-- Grant privileges
-- -------------------------------------------------------------------------
GRANT SELECT ON gst.v_itc_balance          TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_itc_monthly_summary  TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_itc_blocked_credits  TO gst_user, gst_readonly;
