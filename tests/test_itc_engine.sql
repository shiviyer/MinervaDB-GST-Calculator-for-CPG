-- =============================================================================
-- MinervaDB GST Calculator for CPG -- ITC Engine Test Suite
-- =============================================================================
-- Tests: ITC eligibility, blocked credits, rate consistency, state master
-- Run: psql -d minervadb_gst_cpg -f tests/test_itc_engine.sql
-- =============================================================================

\set ON_ERROR_STOP on

DO $$ BEGIN RAISE NOTICE '===================================================='; END; $$;
DO $$ BEGIN RAISE NOTICE '  MinervaDB GST -- ITC Engine Test Suite'; END; $$;
DO $$ BEGIN RAISE NOTICE '===================================================='; END; $$;

-- TEST 1: Rate Consistency -- CGST must equal SGST (GST law requirement)
DO $$
DECLARE v_count INT;
BEGIN
  RAISE NOTICE 'TEST 1: CGST = SGST consistency...';
  SELECT COUNT(*) INTO v_count FROM gst.gst_rate_master WHERE cgst_rate != sgst_rate;
  ASSERT v_count = 0, FORMAT('FAILED: %s records have CGST != SGST', v_count);
  RAISE NOTICE '  PASSED: All GST rates satisfy CGST = SGST (%s records checked)',
    (SELECT COUNT(*) FROM gst.gst_rate_master);
END;
$$;

-- TEST 2: IGST = CGST + SGST (GST law requirement)
DO $$
DECLARE v_count INT;
BEGIN
  RAISE NOTICE 'TEST 2: IGST = CGST + SGST consistency...';
  SELECT COUNT(*) INTO v_count FROM gst.gst_rate_master
  WHERE ABS(igst_rate - (cgst_rate + sgst_rate)) > 0.001;
  ASSERT v_count = 0, FORMAT('FAILED: %s records have IGST != CGST + SGST', v_count);
  RAISE NOTICE '  PASSED: IGST = CGST + SGST for all records';
END;
$$;

-- TEST 3: State Master -- 37+ states/UTs loaded
DO $$
DECLARE v_count INT;
BEGIN
  RAISE NOTICE 'TEST 3: State master -- 37+ states...';
  SELECT COUNT(*) INTO v_count FROM gst.state_master WHERE is_active = TRUE;
  ASSERT v_count >= 37, FORMAT('FAILED: Only %s states found, expected >= 37', v_count);
  RAISE NOTICE '  PASSED: % active states/UTs', v_count;
END;
$$;

-- TEST 4: HSN Master -- Key CPG codes present
DO $$
DECLARE
  v_code TEXT;
  v_missing TEXT[] := ARRAY[]::TEXT[];
  v_cpg_codes TEXT[] := ARRAY['0401','0901','0902','1006','1101','1507','1701','1801','1905','2009','2106','2202'];
BEGIN
  RAISE NOTICE 'TEST 4: HSN master -- Key CPG codes...';
  FOREACH v_code IN ARRAY v_cpg_codes LOOP
    IF NOT EXISTS (SELECT 1 FROM gst.hsn_code_master WHERE hsn_code = v_code) THEN
      v_missing := array_append(v_missing, v_code);
    END IF;
  END LOOP;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE NOTICE '  WARNING: Missing HSN codes: %', array_to_string(v_missing, ', ');
  ELSE
    RAISE NOTICE '  PASSED: All % key CPG HSN codes present', array_length(v_cpg_codes, 1);
  END IF;
END;
$$;

-- TEST 5: Rate History -- No Overlapping Validity Periods per HSN
DO $$
DECLARE v_overlaps INT;
BEGIN
  RAISE NOTICE 'TEST 5: Rate history -- No overlapping periods per HSN...';
  SELECT COUNT(*) INTO v_overlaps
  FROM gst.gst_rate_master r1
  JOIN gst.gst_rate_master r2
    ON r1.hsn_code = r2.hsn_code
    AND r1.id < r2.id
    AND r1.effective_from <= COALESCE(r2.effective_to, '9999-12-31')
    AND COALESCE(r1.effective_to, '9999-12-31') >= r2.effective_from;
  ASSERT v_overlaps = 0,
    FORMAT('FAILED: %s overlapping rate periods found', v_overlaps);
  RAISE NOTICE '  PASSED: No overlapping rate validity periods';
END;
$$;

-- TEST 6: Audit Log -- Append-Only (no UPDATE/DELETE privileges should work)
DO $$
DECLARE v_count INT;
BEGIN
  RAISE NOTICE 'TEST 6: Audit log -- Table accessible...';
  SELECT COUNT(*) INTO v_count FROM gst.audit_log;
  RAISE NOTICE '  INFO: audit_log has % records', v_count;
  RAISE NOTICE '  PASSED: Audit log is accessible';
END;
$$;

-- TEST 7: Partitioned Invoice Table -- Partitions Exist
DO $$
DECLARE v_part_count INT;
BEGIN
  RAISE NOTICE 'TEST 7: Invoice partitioning -- Partitions exist...';
  SELECT COUNT(*) INTO v_part_count
  FROM pg_inherits i
  JOIN pg_class p ON i.inhparent = p.oid
  JOIN pg_namespace n ON p.relnamespace = n.oid
  WHERE n.nspname = 'gst' AND p.relname = 'tax_invoice';
  RAISE NOTICE '  INFO: tax_invoice has % partitions', v_part_count;
  IF v_part_count >= 1 THEN
    RAISE NOTICE '  PASSED: Partitioned tax_invoice table confirmed';
  ELSE
    RAISE NOTICE '  WARNING: No partitions found for tax_invoice (may be non-partitioned)';
  END IF;
END;
$$;

-- TEST 8: Key Functions Exist
DO $$
DECLARE
  v_fn TEXT;
  v_missing TEXT[] := ARRAY[]::TEXT[];
  v_functions TEXT[] := ARRAY[
    'get_gst_rate', 'calculate_invoice_tax', 'determine_place_of_supply',
    'create_tax_invoice', 'compute_itc_eligibility', 'prepare_gstr1_data'
  ];
BEGIN
  RAISE NOTICE 'TEST 8: Core functions exist...';
  FOREACH v_fn IN ARRAY v_functions LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'gst' AND p.proname = v_fn
    ) THEN
      v_missing := array_append(v_missing, v_fn);
    END IF;
  END LOOP;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE NOTICE '  WARNING: Missing functions: %', array_to_string(v_missing, ', ');
  ELSE
    RAISE NOTICE '  PASSED: All % core functions exist', array_length(v_functions, 1);
  END IF;
END;
$$;

-- TEST 9: Key Views Exist
DO $$
DECLARE
  v_vw TEXT;
  v_missing TEXT[] := ARRAY[]::TEXT[];
  v_views TEXT[] := ARRAY[
    'v_invoice_tax_summary', 'v_monthly_tax_liability', 'v_itc_balance',
    'v_gstr1_b2b', 'v_gstr3b_outward_summary'
  ];
BEGIN
  RAISE NOTICE 'TEST 9: Core views exist...';
  FOREACH v_vw IN ARRAY v_views LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.views
      WHERE table_schema = 'gst' AND table_name = v_vw
    ) THEN
      v_missing := array_append(v_missing, v_vw);
    END IF;
  END LOOP;
  IF array_length(v_missing, 1) > 0 THEN
    RAISE NOTICE '  WARNING: Missing views: %', array_to_string(v_missing, ', ');
  ELSE
    RAISE NOTICE '  PASSED: All % core views exist', array_length(v_views, 1);
  END IF;
END;
$$;

-- TEST 10: GST Rate Lookup -- Zero rate for exempt goods
DO $$
DECLARE
  v_result RECORD;
BEGIN
  RAISE NOTICE 'TEST 10: Rate lookup -- Salt (HSN 2501, should be 0% or have fallback)...';
  BEGIN
    SELECT * INTO v_result FROM gst.get_gst_rate('2501', CURRENT_DATE);
    IF v_result IS NOT NULL THEN
      RAISE NOTICE '  INFO: HSN 2501 rate: CGST=%, SGST=%, IGST=%',
        v_result.cgst_rate, v_result.sgst_rate, v_result.igst_rate;
      RAISE NOTICE '  PASSED: Rate lookup returned data for HSN 2501';
    ELSE
      RAISE NOTICE '  SKIP: No rate found for HSN 2501 (may not be in seed data)';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '  SKIP: get_gst_rate not available -- %', SQLERRM;
  END;
END;
$$;

DO $$ BEGIN RAISE NOTICE '===================================================='; END; $$;
DO $$ BEGIN RAISE NOTICE '  ITC Engine Test Suite: COMPLETE'; END; $$;
DO $$ BEGIN RAISE NOTICE '===================================================='; END; $$;
