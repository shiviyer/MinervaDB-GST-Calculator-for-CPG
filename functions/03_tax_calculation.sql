-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: functions/03_tax_calculation.sql
-- Description: Core PL/pgSQL GST calculation engine for CPG industry
-- Brand: MinervaDB GST Calculator for CPG
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- TYPE: Result type for tax calculation
-- -------------------------------------------------------------------------
CREATE TYPE gst.tax_calculation_result AS (
      hsn_code            VARCHAR(8),
      supply_category     gst.supply_category,
      taxable_value       NUMERIC(17,2),
      cgst_rate           NUMERIC(7,4),
      cgst_amount         NUMERIC(17,2),
      sgst_rate           NUMERIC(7,4),
      sgst_amount         NUMERIC(17,2),
      igst_rate           NUMERIC(7,4),
      igst_amount         NUMERIC(17,2),
      utgst_rate          NUMERIC(7,4),
      utgst_amount        NUMERIC(17,2),
      cess_rate           NUMERIC(7,4),
      cess_amount         NUMERIC(17,2),
      total_tax_amount    NUMERIC(17,2),
      invoice_value       NUMERIC(17,2),
      is_igst             BOOLEAN,
      place_of_supply     CHAR(2),
      tax_regime          VARCHAR(30)
  );

-- -------------------------------------------------------------------------
-- FUNCTION: calculate_line_item_tax
-- Calculates GST for a single invoice line item
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.calculate_line_item_tax(
      p_hsn_code          VARCHAR(8),
      p_taxable_value     NUMERIC(17,2),
      p_seller_state      CHAR(2),
      p_buyer_state       CHAR(2),
      p_transaction_date  DATE DEFAULT CURRENT_DATE,
      p_is_ut_buyer       BOOLEAN DEFAULT FALSE,
      p_quantity          NUMERIC(15,4) DEFAULT 1
  )
RETURNS gst.tax_calculation_result
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_result            gst.tax_calculation_result;
    v_rate              RECORD;
    v_is_igst           BOOLEAN;
    v_cgst_rate         NUMERIC(7,4) := 0;
    v_sgst_rate         NUMERIC(7,4) := 0;
    v_igst_rate         NUMERIC(7,4) := 0;
    v_utgst_rate        NUMERIC(7,4) := 0;
    v_cess_rate         NUMERIC(7,4) := 0;
    v_cess_amount       NUMERIC(17,2) := 0;
    v_pos               CHAR(2);
BEGIN
    -- Validate inputs
    IF p_hsn_code IS NULL OR length(p_hsn_code) < 4 THEN
        RAISE EXCEPTION 'Invalid HSN code: %', p_hsn_code;
    END IF;
    IF p_taxable_value < 0 THEN
        RAISE EXCEPTION 'Taxable value cannot be negative: %', p_taxable_value;
    END IF;

    -- Determine Place of Supply
    v_pos := gst.determine_place_of_supply(p_seller_state, p_buyer_state);

    -- Determine if IGST applies (inter-state or UT)
    v_is_igst := (p_seller_state <> v_pos) OR p_is_ut_buyer;

    -- Look up GST rate for HSN code (most specific match first)
    SELECT
        r.cgst_rate, r.sgst_rate, r.igst_rate, r.utgst_rate,
        r.cess_rate, r.cess_amount, r.supply_category
    INTO v_rate
    FROM gst.gst_rate_master r
    WHERE r.hsn_code = p_hsn_code
      AND r.is_active = TRUE
      AND r.effective_from <= p_transaction_date
      AND (r.effective_to IS NULL OR r.effective_to >= p_transaction_date)
    ORDER BY length(r.hsn_code) DESC
    LIMIT 1;

    -- If no exact match, try chapter-level (4-digit HSN)
    IF NOT FOUND THEN
        SELECT
            r.cgst_rate, r.sgst_rate, r.igst_rate, r.utgst_rate,
            r.cess_rate, r.cess_amount, r.supply_category
        INTO v_rate
        FROM gst.gst_rate_master r
        WHERE r.hsn_code = LEFT(p_hsn_code, 4)
          AND r.is_active = TRUE
          AND r.effective_from <= p_transaction_date
          AND (r.effective_to IS NULL OR r.effective_to >= p_transaction_date)
        ORDER BY length(r.hsn_code) DESC
        LIMIT 1;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No GST rate found for HSN code: % as of %', p_hsn_code, p_transaction_date;
    END IF;

    -- Build result
    v_result.hsn_code        := p_hsn_code;
    v_result.supply_category := v_rate.supply_category;
    v_result.taxable_value   := p_taxable_value;
    v_result.is_igst         := v_is_igst;
    v_result.place_of_supply := v_pos;

    -- Apply rates based on supply type
    IF v_rate.supply_category IN ('EXEMPTED', 'NIL_RATED', 'NON_GST') THEN
        -- No tax applies
        v_result.cgst_rate   := 0; v_result.cgst_amount  := 0;
        v_result.sgst_rate   := 0; v_result.sgst_amount  := 0;
        v_result.igst_rate   := 0; v_result.igst_amount  := 0;
        v_result.utgst_rate  := 0; v_result.utgst_amount := 0;
        v_result.cess_rate   := 0; v_result.cess_amount  := 0;
        v_result.tax_regime  := v_rate.supply_category::TEXT;
    ELSIF v_rate.supply_category = 'ZERO_RATED' THEN
        -- Zero rated (exports, SEZ) - IGST at 0%
        v_result.igst_rate   := 0; v_result.igst_amount  := 0;
        v_result.cgst_rate   := 0; v_result.cgst_amount  := 0;
        v_result.sgst_rate   := 0; v_result.sgst_amount  := 0;
        v_result.utgst_rate  := 0; v_result.utgst_amount := 0;
        v_result.cess_rate   := 0; v_result.cess_amount  := 0;
        v_result.tax_regime  := 'ZERO_RATED';
    ELSIF v_is_igst THEN
        -- Inter-state: IGST only
        v_result.igst_rate   := v_rate.igst_rate;
        v_result.igst_amount := ROUND(p_taxable_value * v_rate.igst_rate / 100, 2);
        v_result.cgst_rate   := 0; v_result.cgst_amount  := 0;
        v_result.sgst_rate   := 0; v_result.sgst_amount  := 0;
        -- UTGST if union territory buyer
        IF p_is_ut_buyer THEN
            v_result.utgst_rate  := v_rate.utgst_rate;
            v_result.utgst_amount:= ROUND(p_taxable_value * v_rate.utgst_rate / 100, 2);
            v_result.igst_rate   := 0; v_result.igst_amount := 0;
            v_result.tax_regime  := 'UTGST';
        ELSE
            v_result.utgst_rate  := 0; v_result.utgst_amount := 0;
            v_result.tax_regime  := 'IGST';
        END IF;
    ELSE
        -- Intra-state: CGST + SGST
        v_result.cgst_rate   := v_rate.cgst_rate;
        v_result.cgst_amount := ROUND(p_taxable_value * v_rate.cgst_rate / 100, 2);
        v_result.sgst_rate   := v_rate.sgst_rate;
        v_result.sgst_amount := ROUND(p_taxable_value * v_rate.sgst_rate / 100, 2);
        v_result.igst_rate   := 0; v_result.igst_amount  := 0;
        v_result.utgst_rate  := 0; v_result.utgst_amount := 0;
        v_result.tax_regime  := 'CGST_SGST';
    END IF;

    -- Compensation Cess (applies in addition to other taxes)
    v_result.cess_rate   := v_rate.cess_rate;
    v_result.cess_amount := ROUND(p_taxable_value * v_rate.cess_rate / 100, 2)
                          + ROUND(v_rate.cess_amount * p_quantity, 2);  -- specific cess

    -- Total tax and invoice value
    v_result.total_tax_amount := COALESCE(v_result.cgst_amount, 0)
                               + COALESCE(v_result.sgst_amount, 0)
                               + COALESCE(v_result.igst_amount, 0)
                               + COALESCE(v_result.utgst_amount, 0)
                               + COALESCE(v_result.cess_amount, 0);
    v_result.invoice_value    := p_taxable_value + v_result.total_tax_amount;

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION gst.calculate_line_item_tax IS
    'Calculates CGST/SGST/IGST/UTGST/Cess for a single CPG invoice line item based on HSN code and place of supply';

-- -------------------------------------------------------------------------
-- FUNCTION: calculate_invoice_tax
-- Main entry point: calculates full GST for a CPG transaction
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.calculate_invoice_tax(
      p_seller_gstin      VARCHAR(15),
      p_buyer_gstin       VARCHAR(15),
      p_hsn_code          VARCHAR(8),
      p_supply_value      NUMERIC(17,2),
      p_seller_state      CHAR(2),
      p_buyer_state       CHAR(2),
      p_transaction_dt    DATE DEFAULT CURRENT_DATE,
      p_discount          NUMERIC(17,2) DEFAULT 0,
      p_quantity          NUMERIC(15,4) DEFAULT 1
  )
RETURNS gst.tax_calculation_result
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_result            gst.tax_calculation_result;
    v_taxable_value     NUMERIC(17,2);
    v_buyer_reg         gst.registration_type;
    v_is_ut             BOOLEAN := FALSE;
    v_ut_states         CHAR(2)[] := ARRAY['DD','DN','CH','AN','LD','JK','LA'];
BEGIN
    -- Validate GSTINs
    IF p_seller_gstin !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$' THEN
        RAISE EXCEPTION 'Invalid seller GSTIN format: %', p_seller_gstin;
    END IF;

    -- Calculate taxable value after discount
    v_taxable_value := GREATEST(p_supply_value - COALESCE(p_discount, 0), 0);

    -- Check if buyer is in Union Territory
    v_is_ut := p_buyer_state = ANY(v_ut_states);

    -- Look up buyer registration type
    SELECT registration_type INTO v_buyer_reg
    FROM gst.party_master
    WHERE gstin = p_buyer_gstin
    LIMIT 1;

    -- Delegate to line item calculation
    v_result := gst.calculate_line_item_tax(
              p_hsn_code          => p_hsn_code,
              p_taxable_value     => v_taxable_value,
              p_seller_state      => p_seller_state,
              p_buyer_state       => p_buyer_state,
              p_transaction_date  => p_transaction_dt,
              p_is_ut_buyer       => v_is_ut,
              p_quantity          => p_quantity
          );

    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION gst.calculate_invoice_tax IS
    'Main GST calculation entry point for CPG B2B/B2C transactions. Returns full tax breakdown.';

-- -------------------------------------------------------------------------
-- FUNCTION: calculate_invoice_tax_bulk
-- Bulk calculation for multi-line CPG invoices
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.calculate_invoice_tax_bulk(
      p_seller_gstin      VARCHAR(15),
      p_buyer_gstin       VARCHAR(15),
      p_seller_state      CHAR(2),
      p_buyer_state       CHAR(2),
      p_transaction_dt    DATE,
      p_lines             JSONB   -- Array of {hsn_code, taxable_value, quantity, discount}
  )
RETURNS TABLE (
      line_number         INT,
      hsn_code            VARCHAR(8),
      taxable_value       NUMERIC(17,2),
      cgst_rate           NUMERIC(7,4),
      cgst_amount         NUMERIC(17,2),
      sgst_rate           NUMERIC(7,4),
      sgst_amount         NUMERIC(17,2),
      igst_rate           NUMERIC(7,4),
      igst_amount         NUMERIC(17,2),
      cess_rate           NUMERIC(7,4),
      cess_amount         NUMERIC(17,2),
      total_tax_amount    NUMERIC(17,2),
      line_total          NUMERIC(17,2),
      tax_regime          VARCHAR(30)
  )
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_line              JSONB;
    v_line_num          INT := 0;
    v_calc              gst.tax_calculation_result;
BEGIN
    FOR v_line IN SELECT jsonb_array_elements(p_lines)
    LOOP
        v_line_num := v_line_num + 1;

        v_calc := gst.calculate_invoice_tax(
                      p_seller_gstin   => p_seller_gstin,
                      p_buyer_gstin    => p_buyer_gstin,
                      p_hsn_code       => (v_line->>'hsn_code')::VARCHAR(8),
                      p_supply_value   => (v_line->>'taxable_value')::NUMERIC(17,2),
                      p_seller_state   => p_seller_state,
                      p_buyer_state    => p_buyer_state,
                      p_transaction_dt => p_transaction_dt,
                      p_discount       => COALESCE((v_line->>'discount')::NUMERIC(17,2), 0),
                      p_quantity       => COALESCE((v_line->>'quantity')::NUMERIC(15,4), 1)
                  );

        line_number      := v_line_num;
        hsn_code         := v_calc.hsn_code;
        taxable_value    := v_calc.taxable_value;
        cgst_rate        := v_calc.cgst_rate;
        cgst_amount      := v_calc.cgst_amount;
        sgst_rate        := v_calc.sgst_rate;
        sgst_amount      := v_calc.sgst_amount;
        igst_rate        := v_calc.igst_rate;
        igst_amount      := v_calc.igst_amount;
        cess_rate        := v_calc.cess_rate;
        cess_amount      := v_calc.cess_amount;
        total_tax_amount := v_calc.total_tax_amount;
        line_total       := v_calc.invoice_value;
        tax_regime       := v_calc.tax_regime;

        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION gst.calculate_invoice_tax_bulk IS
    'Bulk GST calculation for multi-line CPG invoices. Accepts JSONB array of line items.';

-- -------------------------------------------------------------------------
-- FUNCTION: get_effective_gst_rate
-- Returns the current effective GST rate for an HSN code
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.get_effective_gst_rate(
      p_hsn_code          VARCHAR(8),
      p_as_of_date        DATE DEFAULT CURRENT_DATE
  )
RETURNS TABLE (
      hsn_code            VARCHAR(8),
      total_gst_rate      NUMERIC(7,4),
      cgst_rate           NUMERIC(7,4),
      sgst_rate           NUMERIC(7,4),
      igst_rate           NUMERIC(7,4),
      cess_rate           NUMERIC(7,4),
      supply_category     gst.supply_category,
      effective_from      DATE,
      effective_to        DATE,
      notification_ref    VARCHAR(100)
  )
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        r.hsn_code,
        r.cgst_rate + r.sgst_rate + r.cess_rate AS total_gst_rate,
        r.cgst_rate,
        r.sgst_rate,
        r.igst_rate,
        r.cess_rate,
        r.supply_category,
        r.effective_from,
        r.effective_to,
        r.notification_ref
    FROM gst.gst_rate_master r
    WHERE r.hsn_code = p_hsn_code
      AND r.is_active = TRUE
      AND r.effective_from <= p_as_of_date
      AND (r.effective_to IS NULL OR r.effective_to >= p_as_of_date)
    ORDER BY length(r.hsn_code) DESC
    LIMIT 1;
$$;

COMMENT ON FUNCTION gst.get_effective_gst_rate IS
    'Returns the effective GST rate for an HSN code on a given date';
