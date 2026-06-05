-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: triggers/01_invoice_triggers.sql
-- Description: Invoice validation, auto-calculation and GSTR period triggers
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- TRIGGER FUNCTION: trg_invoice_validate
-- Validates invoice before INSERT/UPDATE — GSTIN format, state codes, date range
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.trg_invoice_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Validate seller GSTIN format
    IF NEW.seller_gstin !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$' THEN
        RAISE EXCEPTION 'INVALID_SELLER_GSTIN: % does not match GSTIN format', NEW.seller_gstin
            USING ERRCODE = 'P0001';
    END IF;

    -- Validate buyer GSTIN if provided
    IF NEW.buyer_gstin IS NOT NULL AND
       NEW.buyer_gstin !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$' THEN
        RAISE EXCEPTION 'INVALID_BUYER_GSTIN: % does not match GSTIN format', NEW.buyer_gstin
            USING ERRCODE = 'P0001';
    END IF;

    -- Validate invoice date is not in the future (allow 1 day tolerance)
    IF NEW.invoice_date > CURRENT_DATE + INTERVAL '1 day' THEN
        RAISE EXCEPTION 'FUTURE_INVOICE_DATE: Invoice date % cannot be in the future', NEW.invoice_date
            USING ERRCODE = 'P0001';
    END IF;

    -- Validate invoice date is not older than 3 financial years
    IF NEW.invoice_date < CURRENT_DATE - INTERVAL '3 years' THEN
        RAISE EXCEPTION 'STALE_INVOICE_DATE: Invoice date % is too old (>3 years)', NEW.invoice_date
            USING ERRCODE = 'P0001';
    END IF;

    -- Credit/Debit notes must reference original invoice
    IF NEW.invoice_type IN ('CREDIT_NOTE','DEBIT_NOTE') AND NEW.original_invoice_no IS NULL THEN
        RAISE EXCEPTION 'MISSING_ORIGINAL_INVOICE: % must reference original invoice', NEW.invoice_type
            USING ERRCODE = 'P0001';
    END IF;

    -- Auto-set GSTR periods if not provided
    IF NEW.gstr1_period IS NULL THEN
        NEW.gstr1_period := TO_CHAR(NEW.invoice_date, 'MMYYYY');
    END IF;
    IF NEW.gstr3b_period IS NULL THEN
        NEW.gstr3b_period := TO_CHAR(NEW.invoice_date, 'MMYYYY');
    END IF;

    -- Determine inter-state flag from state codes
    IF NEW.seller_state_code IS NOT NULL AND NEW.place_of_supply IS NOT NULL THEN
        NEW.is_igst_applicable := (NEW.seller_state_code <> NEW.place_of_supply);
    END IF;

    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_invoice_before_insert_update
    BEFORE INSERT OR UPDATE ON gst.tax_invoice
    FOR EACH ROW
    EXECUTE FUNCTION gst.trg_invoice_validate();

COMMENT ON FUNCTION gst.trg_invoice_validate IS
    'Validates GST invoice before insert/update: GSTIN format, date range, required fields.
     Auto-sets gstr1_period, gstr3b_period and is_igst_applicable.';

-- -------------------------------------------------------------------------
-- TRIGGER FUNCTION: trg_invoice_line_validate
-- Validates line items — negative values, zero taxable amounts, HSN format
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.trg_invoice_line_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- No negative quantities or prices
    IF NEW.quantity <= 0 THEN
        RAISE EXCEPTION 'INVALID_QUANTITY: Line % quantity must be positive', NEW.line_number
            USING ERRCODE = 'P0001';
    END IF;
    IF NEW.unit_price < 0 THEN
        RAISE EXCEPTION 'INVALID_UNIT_PRICE: Line % unit_price cannot be negative', NEW.line_number
            USING ERRCODE = 'P0001';
    END IF;
    IF NEW.taxable_value < 0 THEN
        RAISE EXCEPTION 'INVALID_TAXABLE_VALUE: Line % taxable_value cannot be negative', NEW.line_number
            USING ERRCODE = 'P0001';
    END IF;

    -- HSN code must be at least 4 digits
    IF NEW.hsn_code IS NULL OR length(trim(NEW.hsn_code)) < 4 THEN
        RAISE EXCEPTION 'INVALID_HSN_CODE: Line % HSN code must be at least 4 digits', NEW.line_number
            USING ERRCODE = 'P0001';
    END IF;

    -- Ensure CGST = SGST (GST law requirement)
    IF NEW.cgst_rate != NEW.sgst_rate AND NEW.igst_rate = 0 THEN
        RAISE EXCEPTION 'CGST_SGST_MISMATCH: Line % CGST rate % must equal SGST rate %',
            NEW.line_number, NEW.cgst_rate, NEW.sgst_rate
            USING ERRCODE = 'P0001';
    END IF;

    -- Calculate line total
    NEW.total_tax_amount := NEW.cgst_amount + NEW.sgst_amount + NEW.igst_amount
                           + NEW.utgst_amount + NEW.cess_amount;
    NEW.line_total := NEW.taxable_value + NEW.total_tax_amount;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_line_item_before_insert_update
    BEFORE INSERT OR UPDATE ON gst.invoice_line_item
    FOR EACH ROW
    EXECUTE FUNCTION gst.trg_invoice_line_validate();

COMMENT ON FUNCTION gst.trg_invoice_line_validate IS
    'Validates invoice line items: positive quantities/prices, HSN format, CGST=SGST rule.
     Auto-calculates total_tax_amount and line_total.';

-- -------------------------------------------------------------------------
-- TRIGGER FUNCTION: trg_prevent_filed_invoice_modification
-- Prevents modification of invoices in filed GSTR-1 periods
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.trg_prevent_filed_invoice_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_filing_status VARCHAR(20);
BEGIN
    -- Allow cancellation flag to be set
    IF OLD.is_cancelled = FALSE AND NEW.is_cancelled = TRUE THEN
        SELECT filing_status INTO v_filing_status
        FROM gst.gstr_filing_log
        WHERE gstin = OLD.seller_gstin AND tax_period = OLD.gstr1_period
          AND return_type = 'GSTR1';

        IF v_filing_status IN ('FILED','SUBMITTED') THEN
            RAISE EXCEPTION 'FILED_PERIOD_LOCKED: Cannot cancel invoice in filed period %. Issue credit note.',
                OLD.gstr1_period USING ERRCODE = 'P0002';
        END IF;
    END IF;

    -- Block core field changes on filed invoices
    IF OLD.gstr1_period IS NOT NULL THEN
        SELECT filing_status INTO v_filing_status
        FROM gst.gstr_filing_log
        WHERE gstin = OLD.seller_gstin AND tax_period = OLD.gstr1_period
          AND return_type = 'GSTR1';

        IF v_filing_status IN ('FILED','SUBMITTED') AND
           (OLD.taxable_value != NEW.taxable_value OR
            OLD.igst_amount   != NEW.igst_amount   OR
            OLD.cgst_amount   != NEW.cgst_amount   OR
            OLD.sgst_amount   != NEW.sgst_amount) THEN
            RAISE EXCEPTION 'FILED_PERIOD_LOCKED: Cannot modify tax amounts for filed period %',
                OLD.gstr1_period USING ERRCODE = 'P0002';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_invoice_filed_period_lock
    BEFORE UPDATE ON gst.tax_invoice
    FOR EACH ROW
    EXECUTE FUNCTION gst.trg_prevent_filed_invoice_modification();

COMMENT ON FUNCTION gst.trg_prevent_filed_invoice_modification IS
    'Prevents modification of tax-critical fields on invoices in FILED GSTR-1 periods.
     Enforces GST compliance — amendments must go through credit/debit notes.';
