-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: views/01_tax_summary_views.sql
-- Description: Tax liability dashboards and summary views
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- VIEW: v_invoice_tax_summary
-- Real-time tax liability summary per invoice
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_invoice_tax_summary AS
SELECT
    ti.invoice_id,
    ti.invoice_number,
    ti.invoice_date,
    ti.invoice_type,
    ti.supply_type,
    ti.seller_gstin,
    cg.legal_name                       AS seller_name,
    ti.buyer_gstin,
    COALESCE(pm.party_name, ti.buyer_name) AS buyer_name,
    ti.buyer_state_code,
    ti.seller_state_code,
    ti.place_of_supply,
    ti.is_igst_applicable               AS is_igst,
    ti.is_reverse_charge                AS is_rcm,
    ti.taxable_value,
    ti.cgst_amount,
    ti.sgst_amount,
    ti.igst_amount,
    ti.utgst_amount,
    ti.cess_amount,
    ti.total_tax_amount,
    ti.invoice_value,
    ti.trade_discount,
    ti.gstr1_period,
    ti.gstr3b_period,
    ti.is_cancelled,
    ti.created_at
FROM gst.tax_invoice ti
LEFT JOIN gst.company_gstin cg ON cg.gstin = ti.seller_gstin
LEFT JOIN gst.party_master   pm ON pm.gstin = ti.buyer_gstin
WHERE ti.is_cancelled = FALSE;

COMMENT ON VIEW gst.v_invoice_tax_summary IS
    'Non-cancelled invoice summary with seller/buyer names resolved. Primary reporting view.';

-- -------------------------------------------------------------------------
-- VIEW: v_monthly_tax_liability
-- Month-wise outward tax liability summary per GSTIN
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_monthly_tax_liability AS
SELECT
    ti.seller_gstin,
    ti.gstr1_period                         AS tax_period,
    COUNT(*)                                AS invoice_count,
    SUM(ti.taxable_value)                   AS total_taxable_value,
    SUM(ti.cgst_amount)                     AS total_cgst,
    SUM(ti.sgst_amount)                     AS total_sgst,
    SUM(ti.igst_amount)                     AS total_igst,
    SUM(ti.cess_amount)                     AS total_cess,
    SUM(ti.total_tax_amount)                AS total_tax,
    SUM(ti.invoice_value)                   AS total_invoice_value,
    SUM(CASE WHEN ti.supply_type = 'B2B'         THEN ti.taxable_value ELSE 0 END) AS b2b_taxable,
    SUM(CASE WHEN ti.supply_type = 'B2C_LARGE'   THEN ti.taxable_value ELSE 0 END) AS b2cl_taxable,
    SUM(CASE WHEN ti.supply_type = 'B2C_SMALL'   THEN ti.taxable_value ELSE 0 END) AS b2cs_taxable,
    SUM(CASE WHEN ti.supply_type LIKE 'EXPORT%'  THEN ti.taxable_value ELSE 0 END) AS export_taxable,
    SUM(CASE WHEN ti.supply_type LIKE 'SEZ%'     THEN ti.taxable_value ELSE 0 END) AS sez_taxable
FROM gst.tax_invoice ti
WHERE ti.is_cancelled = FALSE
  AND ti.invoice_type IN ('TAX_INVOICE', 'BILL_OF_SUPPLY')
GROUP BY ti.seller_gstin, ti.gstr1_period;

COMMENT ON VIEW gst.v_monthly_tax_liability IS
    'Month-wise GST outward tax liability summary broken down by supply category.';

-- -------------------------------------------------------------------------
-- VIEW: v_hsn_wise_summary
-- HSN-code level sales and tax summary
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW gst.v_hsn_wise_summary AS
SELECT
    ti.seller_gstin,
    ti.gstr1_period                   AS tax_period,
    li.hsn_code,
    hm.hsn_description,
    hm.cpg_category,
    li.uom,
    SUM(li.quantity)                  AS total_quantity,
    SUM(li.taxable_value)             AS total_taxable_value,
    SUM(li.cgst_amount)               AS total_cgst,
    SUM(li.sgst_amount)               AS total_sgst,
    SUM(li.igst_amount)               AS total_igst,
    SUM(li.cess_amount)               AS total_cess,
    SUM(li.total_tax_amount)          AS total_tax,
    SUM(li.line_total)                AS total_line_value,
    li.cgst_rate + li.sgst_rate       AS total_gst_rate
FROM gst.invoice_line_item li
JOIN gst.tax_invoice ti ON ti.invoice_id = li.invoice_id AND ti.invoice_date = li.invoice_date
LEFT JOIN gst.hsn_code_master hm ON hm.hsn_code = li.hsn_code
WHERE ti.is_cancelled = FALSE
GROUP BY
    ti.seller_gstin, ti.gstr1_period,
    li.hsn_code, hm.hsn_description, hm.cpg_category,
    li.uom, li.cgst_rate + li.sgst_rate;

COMMENT ON VIEW gst.v_hsn_wise_summary IS
    'HSN-code level supply and tax summary. Used for HSN appendix in GSTR-1 and GSTR-9.';

-- -------------------------------------------------------------------------
-- MATERIALIZED VIEW: mv_gstr3b_tax_liability
-- Pre-aggregated GSTR-3B tax liability (refreshed before filing)
-- -------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS gst.mv_gstr3b_tax_liability AS
SELECT
    ti.seller_gstin                         AS gstin,
    ti.gstr3b_period                        AS tax_period,
    SUM(CASE WHEN supply_type IN ('B2B','B2C_LARGE','B2C_SMALL')
                THEN ti.taxable_value ELSE 0 END)  AS taxable_outward,
    SUM(CASE WHEN supply_type LIKE 'EXPORT%'
                THEN ti.taxable_value ELSE 0 END)  AS zero_rated_outward,
    SUM(ti.cgst_amount)                     AS cgst_payable,
    SUM(ti.sgst_amount)                     AS sgst_payable,
    SUM(ti.igst_amount)                     AS igst_payable,
    SUM(ti.cess_amount)                     AS cess_payable,
    SUM(ti.total_tax_amount)                AS total_tax_payable
FROM gst.tax_invoice ti
WHERE ti.is_cancelled = FALSE
  AND ti.invoice_type IN ('TAX_INVOICE','DEBIT_NOTE')
GROUP BY ti.seller_gstin, ti.gstr3b_period
WITH DATA;

CREATE UNIQUE INDEX idx_mv_gstr3b ON gst.mv_gstr3b_tax_liability (gstin, tax_period);

COMMENT ON MATERIALIZED VIEW gst.mv_gstr3b_tax_liability IS
    'Pre-aggregated GSTR-3B outward tax liability. Refresh with REFRESH MATERIALIZED VIEW CONCURRENTLY.';

-- -------------------------------------------------------------------------
-- Grant privileges
-- -------------------------------------------------------------------------
GRANT SELECT ON gst.v_invoice_tax_summary     TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_monthly_tax_liability   TO gst_user, gst_readonly;
GRANT SELECT ON gst.v_hsn_wise_summary        TO gst_user, gst_readonly;
GRANT SELECT ON gst.mv_gstr3b_tax_liability   TO gst_user, gst_readonly;
