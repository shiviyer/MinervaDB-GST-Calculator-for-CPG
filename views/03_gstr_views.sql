-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: views/03_gstr_views.sql
-- Description: GSTR return filing views for GSTR-1, GSTR-2B reconciliation, GSTR-3B
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- VIEW: v_gstr1_b2b
-- GSTR-1 B2B invoices ready for filing
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_gstr1_b2b AS
SELECT
    ti.seller_gstin,
    ti.gstr1_period,
    ti.buyer_gstin                  AS ctin,
    ti.invoice_number               AS inum,
    ti.invoice_date                 AS idt,
    ti.invoice_value                AS val,
    ti.place_of_supply              AS pos,
    ti.is_reverse_charge            AS rchrg,
    li.line_number                  AS item_num,
    li.taxable_value                AS txval,
    CASE WHEN ti.is_igst_applicable THEN li.igst_rate
         ELSE (li.cgst_rate + li.sgst_rate) END AS rate,
    li.igst_amount                  AS iamt,
    li.cgst_amount                  AS camt,
    li.sgst_amount                  AS samt,
    li.cess_amount                  AS csamt
FROM gst.tax_invoice ti
JOIN gst.invoice_line_item li ON li.invoice_id = ti.invoice_id AND li.invoice_date = ti.invoice_date
WHERE ti.supply_type = 'B2B'
  AND ti.invoice_type IN ('TAX_INVOICE','BILL_OF_SUPPLY')
  AND ti.is_cancelled = FALSE;

COMMENT ON VIEW gst.v_gstr1_b2b IS 'GSTR-1 Table 4: B2B invoices (business to registered buyers).';

-- -------------------------------------------------------------------------
-- VIEW: v_gstr1_b2cs_summary
-- GSTR-1 B2CS aggregated summary (Table 7)
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_gstr1_b2cs_summary AS
SELECT
    ti.seller_gstin,
    ti.gstr1_period,
    ti.place_of_supply              AS pos,
    'INTRA'                         AS sply_tp,
    li.cgst_rate + li.sgst_rate     AS rate,
    SUM(li.taxable_value)           AS txval,
    SUM(li.igst_amount)             AS iamt,
    SUM(li.cgst_amount)             AS camt,
    SUM(li.sgst_amount)             AS samt,
    SUM(li.cess_amount)             AS csamt
FROM gst.tax_invoice ti
JOIN gst.invoice_line_item li ON li.invoice_id = ti.invoice_id AND li.invoice_date = ti.invoice_date
WHERE ti.supply_type = 'B2C_SMALL'
  AND ti.is_cancelled = FALSE
GROUP BY ti.seller_gstin, ti.gstr1_period, ti.place_of_supply, li.cgst_rate + li.sgst_rate;

COMMENT ON VIEW gst.v_gstr1_b2cs_summary IS 'GSTR-1 Table 7: B2CS aggregated summary.';

-- -------------------------------------------------------------------------
-- VIEW: v_gstr1_cdnr
-- GSTR-1 Credit/Debit notes for registered persons (Table 9)
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_gstr1_cdnr AS
SELECT
    ti.seller_gstin,
    ti.gstr1_period,
    ti.buyer_gstin                  AS ctin,
    CASE ti.invoice_type
        WHEN 'CREDIT_NOTE' THEN 'C'
        WHEN 'DEBIT_NOTE'  THEN 'D'
    END                             AS ntty,
    ti.invoice_number               AS nt_num,
    ti.invoice_date                 AS nt_dt,
    ti.invoice_value                AS val,
    ti.taxable_value                AS txval,
    ti.igst_amount                  AS iamt,
    ti.cgst_amount                  AS camt,
    ti.sgst_amount                  AS samt,
    ti.cess_amount                  AS csamt
FROM gst.tax_invoice ti
WHERE ti.invoice_type IN ('CREDIT_NOTE','DEBIT_NOTE')
  AND ti.buyer_gstin IS NOT NULL
  AND ti.is_cancelled = FALSE;

COMMENT ON VIEW gst.v_gstr1_cdnr IS 'GSTR-1 Table 9: Credit/Debit notes to registered recipients.';

-- -------------------------------------------------------------------------
-- VIEW: v_gstr3b_outward_summary
-- GSTR-3B Table 3.1 — Outward supply details
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_gstr3b_outward_summary AS
SELECT
    ti.seller_gstin                 AS gstin,
    ti.gstr3b_period                AS tax_period,
    -- Taxable outward supplies (3.1a)
    SUM(CASE WHEN ti.supply_type IN ('B2B','B2C_LARGE','B2C_SMALL')
               THEN ti.taxable_value ELSE 0 END) AS taxable_outward,
    SUM(CASE WHEN ti.supply_type IN ('B2B','B2C_LARGE','B2C_SMALL')
               THEN ti.igst_amount   ELSE 0 END) AS taxable_igst,
    SUM(CASE WHEN ti.supply_type IN ('B2B','B2C_LARGE','B2C_SMALL')
               THEN ti.cgst_amount   ELSE 0 END) AS taxable_cgst,
    SUM(CASE WHEN ti.supply_type IN ('B2B','B2C_LARGE','B2C_SMALL')
               THEN ti.sgst_amount   ELSE 0 END) AS taxable_sgst,
    SUM(CASE WHEN ti.supply_type IN ('B2B','B2C_LARGE','B2C_SMALL')
               THEN ti.cess_amount   ELSE 0 END) AS taxable_cess,
    -- Zero-rated exports (3.1b)
    SUM(CASE WHEN ti.supply_type IN ('EXPORT_WITH_IGST','EXPORT_WITHOUT_IGST','SEZ_WITH_IGST','SEZ_WITHOUT_IGST')
               THEN ti.taxable_value ELSE 0 END) AS zero_rated,
    SUM(CASE WHEN ti.supply_type IN ('EXPORT_WITH_IGST','SEZ_WITH_IGST')
               THEN ti.igst_amount   ELSE 0 END) AS zero_rated_igst,
    -- RCM (3.1d)
    SUM(CASE WHEN ti.is_reverse_charge THEN ti.taxable_value ELSE 0 END) AS rcm_taxable,
    SUM(CASE WHEN ti.is_reverse_charge THEN ti.igst_amount   ELSE 0 END) AS rcm_igst
FROM gst.tax_invoice ti
WHERE ti.is_cancelled = FALSE
  AND ti.invoice_type IN ('TAX_INVOICE','DEBIT_NOTE')
GROUP BY ti.seller_gstin, ti.gstr3b_period;

COMMENT ON VIEW gst.v_gstr3b_outward_summary IS
    'GSTR-3B Table 3.1: Outward supply summary. Used for monthly tax payment filing.';

-- -------------------------------------------------------------------------
-- VIEW: v_gstr_filing_status
-- Filing status dashboard for all returns
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_gstr_filing_status AS
SELECT
    fl.gstin,
    fl.return_type,
    fl.tax_period,
    fl.filing_status,
    fl.arn,
    fl.filed_at,
    fl.total_taxable,
    fl.total_igst,
    fl.total_cgst,
    fl.total_sgst,
    fl.total_cess,
    fl.tax_paid_cash,
    fl.tax_paid_credit,
    fl.late_fee,
    fl.interest,
    fl.created_at,
    fl.updated_at
FROM gst.gstr_filing_log fl
ORDER BY fl.gstin, fl.return_type, fl.tax_period DESC;

COMMENT ON VIEW gst.v_gstr_filing_status IS
    'Filing status dashboard for all GSTR returns across GSTINs.';

-- -------------------------------------------------------------------------
-- Grant privileges
-- -------------------------------------------------------------------------
GRANT SELECT ON gst.v_gstr1_b2b            TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_gstr1_b2cs_summary   TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_gstr1_cdnr           TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_gstr3b_outward_summary TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_gstr_filing_status   TO gst_user, gst_readonly;
