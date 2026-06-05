-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: data/01_gst_rates_seed.sql
-- Description: GST rate master seed data (additional rates beyond CPG core set)
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
--
-- NOTE: The core CPG GST rate seed data (50+ CPG HSN codes + their rates) is
-- included in data/02_hsn_codes_cpg.sql for maintainability and cohesion.
--
-- This file provides:
--   1. Any additional/overriding rate entries not in 02_hsn_codes_cpg.sql
--   2. Chapter-level catch-all rates for future HSN sub-classifications
--   3. Composition scheme rate entries
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- Chapter-level catch-all rates (for HSN codes not explicitly mapped)
-- These serve as fallback when get_gst_rate() can't find an exact 4/6/8-digit match
-- -------------------------------------------------------------------------

-- Ensure HSN master has chapter entries before inserting rates
-- Chapter 04 (Dairy) - 0% default (specific products override below)
INSERT INTO gst.gst_rate_master
    (hsn_code, cgst_rate, sgst_rate, igst_rate, cess_rate, supply_category, notification_ref)
SELECT '04', 0, 0, 0, 0, 'NIL_RATED', 'GST Notification 2/2017 - Dairy default'
WHERE EXISTS (SELECT 1 FROM gst.hsn_code_master WHERE hsn_code = '0401')
  AND NOT EXISTS (SELECT 1 FROM gst.gst_rate_master WHERE hsn_code = '04')
ON CONFLICT DO NOTHING;

-- Chapter 10 (Cereals) - 0% default
INSERT INTO gst.gst_rate_master
    (hsn_code, cgst_rate, sgst_rate, igst_rate, cess_rate, supply_category, notification_ref)
SELECT '10', 0, 0, 0, 0, 'NIL_RATED', 'GST Notification 2/2017 - Cereals default'
WHERE EXISTS (SELECT 1 FROM gst.hsn_code_master WHERE hsn_code = '1001')
  AND NOT EXISTS (SELECT 1 FROM gst.gst_rate_master WHERE hsn_code = '10')
ON CONFLICT DO NOTHING;

-- Chapter 19 (Prepared foods) - 12% default
INSERT INTO gst.gst_rate_master
    (hsn_code, cgst_rate, sgst_rate, igst_rate, cess_rate, supply_category, notification_ref)
SELECT '19', 6, 6, 12, 0, 'TAXABLE', 'GST Schedule II 12% - Chapter 19 default'
WHERE EXISTS (SELECT 1 FROM gst.hsn_code_master WHERE hsn_code = '1905')
  AND NOT EXISTS (SELECT 1 FROM gst.gst_rate_master WHERE hsn_code = '19')
ON CONFLICT DO NOTHING;

-- Chapter 33 (Personal care) - 18% default
INSERT INTO gst.gst_rate_master
    (hsn_code, cgst_rate, sgst_rate, igst_rate, cess_rate, supply_category, notification_ref)
SELECT '33', 9, 9, 18, 0, 'TAXABLE', 'GST Schedule III 18% - Chapter 33 default'
WHERE EXISTS (SELECT 1 FROM gst.hsn_code_master WHERE hsn_code = '3304')
  AND NOT EXISTS (SELECT 1 FROM gst.gst_rate_master WHERE hsn_code = '33')
ON CONFLICT DO NOTHING;

-- Chapter 34 (Detergents/soap) - 18% default
INSERT INTO gst.gst_rate_master
    (hsn_code, cgst_rate, sgst_rate, igst_rate, cess_rate, supply_category, notification_ref)
SELECT '34', 9, 9, 18, 0, 'TAXABLE', 'GST Schedule III 18% - Chapter 34 default'
WHERE EXISTS (SELECT 1 FROM gst.hsn_code_master WHERE hsn_code = '3401')
  AND NOT EXISTS (SELECT 1 FROM gst.gst_rate_master WHERE hsn_code = '34')
ON CONFLICT DO NOTHING;

-- -------------------------------------------------------------------------
-- Verify rate data completeness
-- -------------------------------------------------------------------------
DO $$
DECLARE
    v_hsn_count  INT;
    v_rate_count INT;
    v_unmapped   INT;
BEGIN
    SELECT COUNT(*) INTO v_hsn_count  FROM gst.hsn_code_master WHERE is_active = TRUE;
    SELECT COUNT(*) INTO v_rate_count FROM gst.gst_rate_master  WHERE is_active = TRUE;
    SELECT COUNT(*) INTO v_unmapped
    FROM gst.hsn_code_master h
    WHERE h.is_active = TRUE
      AND NOT EXISTS (
                  SELECT 1 FROM gst.gst_rate_master r
                  WHERE r.is_active = TRUE
                    AND h.hsn_code LIKE r.hsn_code || '%'
                );

    RAISE NOTICE 'GST Rate Data: % HSN codes, % rate entries, % unmapped HSN codes',
        v_hsn_count, v_rate_count, v_unmapped;

    IF v_unmapped > 0 THEN
        RAISE WARNING 'WARNING: % HSN codes have no rate mapping', v_unmapped;
    ELSE
        RAISE NOTICE 'All HSN codes have rate mappings';
    END IF;
END;
$$;
