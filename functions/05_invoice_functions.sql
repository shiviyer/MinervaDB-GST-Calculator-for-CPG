-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: functions/05_invoice_functions.sql
-- Description: Invoice creation, validation, cancellation, credit/debit notes
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- FUNCTION: generate_invoice_number
-- Generates a sequential GST-compliant invoice number
-- Format: GSTIN_PREFIX/FY/SERIES/SEQUENCE (max 16 chars per GST rule)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.generate_invoice_number(
      p_seller_gstin  VARCHAR(15),
      p_invoice_type  gst.invoice_type DEFAULT 'TAX_INVOICE',
      p_invoice_date  DATE DEFAULT CURRENT_DATE
  )
RETURNS VARCHAR(50)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_fy        VARCHAR(5);
    v_prefix    VARCHAR(4);
    v_seq       BIGINT;
    v_series    VARCHAR(2);
BEGIN
    -- Financial Year in format YYYY (e.g., 2526 for Apr-2025 to Mar-2026)
    v_fy := CASE
        WHEN EXTRACT(MONTH FROM p_invoice_date) >= 4
        THEN LPAD(EXTRACT(YEAR FROM p_invoice_date)::TEXT, 2, '0')
             || LPAD((EXTRACT(YEAR FROM p_invoice_date) + 1)::TEXT, 2, '0')
        ELSE LPAD((EXTRACT(YEAR FROM p_invoice_date) - 1)::TEXT, 2, '0')
             || LPAD(EXTRACT(YEAR FROM p_invoice_date)::TEXT, 2, '0')
    END;

    v_prefix := SUBSTRING(p_seller_gstin, 3, 4); -- 4 chars from PAN

    v_series := CASE p_invoice_type
        WHEN 'TAX_INVOICE'    THEN 'TI'
        WHEN 'CREDIT_NOTE'    THEN 'CN'
        WHEN 'DEBIT_NOTE'     THEN 'DN'
        WHEN 'BILL_OF_SUPPLY' THEN 'BS'
        ELSE 'OT'
    END;

    -- Atomic sequence per seller+FY+type
    SELECT COALESCE(MAX(
              CAST(REGEXP_REPLACE(invoice_number, '[^0-9]', '', 'g') AS BIGINT)
          ), 0) + 1
    INTO v_seq
    FROM gst.tax_invoice
    WHERE seller_gstin = p_seller_gstin
      AND invoice_type = p_invoice_type
      AND EXTRACT(YEAR FROM invoice_date) = EXTRACT(YEAR FROM p_invoice_date);

    RETURN v_prefix || '/' || v_fy || '/' || v_series || '/' || LPAD(v_seq::TEXT, 6, '0');
END;
$$;

COMMENT ON FUNCTION gst.generate_invoice_number IS
    'Generates GST-compliant invoice numbers. Format: PAN4/FY/TYPE/SEQ. Max 16 chars.';

-- -------------------------------------------------------------------------
-- FUNCTION: create_tax_invoice
-- Creates a complete GST tax invoice with auto-calculated taxes
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.create_tax_invoice(
      p_seller_gstin    VARCHAR(15),
      p_buyer_gstin     VARCHAR(15),
      p_buyer_name      VARCHAR(200),
      p_buyer_state     CHAR(2),
      p_invoice_date    DATE DEFAULT CURRENT_DATE,
      p_invoice_type    gst.invoice_type DEFAULT 'TAX_INVOICE',
      p_is_rcm          BOOLEAN DEFAULT FALSE,
      p_created_by      VARCHAR(100) DEFAULT NULL,
      -- JSON array of line items:
    -- [{"hsn_code":"1905","product_desc":"Biscuits","qty":100,"unit_price":50,"discount":0,"uom":"KGS"}]
    p_line_items      JSONB DEFAULT '[]'::JSONB
  )
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_invoice_id      UUID := uuid_generate_v4();
    v_invoice_no      VARCHAR(50);
    v_seller_state    CHAR(2);
    v_pos             CHAR(2);
    v_is_igst         BOOLEAN;
    v_supply_type     gst.supply_type;
    v_line            JSONB;
    v_line_no         SMALLINT := 1;
    v_tax_result      gst.tax_calculation_result;
    v_gross           NUMERIC(17,2);
    v_discount        NUMERIC(17,2);
    v_taxable         NUMERIC(17,2);
    v_total_taxable   NUMERIC(17,2) := 0;
    v_total_cgst      NUMERIC(17,2) := 0;
    v_total_sgst      NUMERIC(17,2) := 0;
    v_total_igst      NUMERIC(17,2) := 0;
    v_total_cess      NUMERIC(17,2) := 0;
    v_invoice_value   NUMERIC(17,2) := 0;
BEGIN
    -- Validate seller GSTIN
    IF NOT gst.validate_gstin(p_seller_gstin) THEN
        RAISE EXCEPTION 'INVALID_GSTIN: Seller GSTIN checksum failed: %', p_seller_gstin;
    END IF;

    -- Determine seller state from GSTIN prefix
    SELECT state_code INTO v_seller_state
    FROM gst.state_master
    WHERE gst_state_code = LEFT(p_seller_gstin, 2);

    IF v_seller_state IS NULL THEN
        RAISE EXCEPTION 'UNKNOWN_STATE: Cannot resolve state for GSTIN %', p_seller_gstin;
    END IF;

    -- Determine POS and inter/intra state
    v_pos     := gst.determine_place_of_supply(v_seller_state, p_buyer_state);
    v_is_igst := (v_seller_state <> v_pos);

    -- Generate invoice number
    v_invoice_no := gst.generate_invoice_number(p_seller_gstin, p_invoice_type, p_invoice_date);

    -- Insert invoice header
    INSERT INTO gst.tax_invoice (
              invoice_id, invoice_number, invoice_date, invoice_type,
              seller_gstin, buyer_gstin, buyer_name, buyer_state_code,
              seller_state_code, place_of_supply, is_reverse_charge, is_igst_applicable,
              gstr1_period, created_by
          ) VALUES (
              v_invoice_id, v_invoice_no, p_invoice_date, p_invoice_type,
              p_seller_gstin, p_buyer_gstin, p_buyer_name, p_buyer_state,
              v_seller_state, v_pos, p_is_rcm, v_is_igst,
              TO_CHAR(p_invoice_date, 'MMYYYY'), p_created_by
          );

    -- Process each line item
    FOR v_line IN SELECT * FROM jsonb_array_elements(p_line_items) LOOP
        v_gross    := ROUND((v_line->>'qty')::NUMERIC * (v_line->>'unit_price')::NUMERIC, 2);
        v_discount := COALESCE((v_line->>'discount')::NUMERIC, 0);
        v_taxable  := v_gross - v_discount;

        -- Calculate tax for this line
        v_tax_result := gst.calculate_line_item_tax(
                      p_hsn_code       => v_line->>'hsn_code',
                      p_taxable_value  => v_taxable,
                      p_seller_state   => v_seller_state,
                      p_buyer_state    => p_buyer_state,
                      p_transaction_date => p_invoice_date,
                      p_quantity       => (v_line->>'qty')::NUMERIC
                  );

        INSERT INTO gst.invoice_line_item (
                      invoice_id, invoice_date, line_number,
                      product_code, product_description, hsn_code,
                      uom, quantity, unit_price, gross_amount, discount_amount, taxable_value,
                      cgst_rate, cgst_amount, sgst_rate, sgst_amount,
                      igst_rate, igst_amount, utgst_rate, utgst_amount,
                      cess_rate, cess_amount, total_tax_amount, line_total, supply_category
                  ) VALUES (
                      v_invoice_id, p_invoice_date, v_line_no,
                      v_line->>'product_code', v_line->>'product_desc',
                      v_line->>'hsn_code',
                      COALESCE(v_line->>'uom', 'NOS'),
                      (v_line->>'qty')::NUMERIC, (v_line->>'unit_price')::NUMERIC,
                      v_gross, v_discount, v_taxable,
                      v_tax_result.cgst_rate,  v_tax_result.cgst_amount,
                      v_tax_result.sgst_rate,  v_tax_result.sgst_amount,
                      v_tax_result.igst_rate,  v_tax_result.igst_amount,
                      v_tax_result.utgst_rate, v_tax_result.utgst_amount,
                      v_tax_result.cess_rate,  v_tax_result.cess_amount,
                      v_tax_result.total_tax_amount,
                      v_taxable + v_tax_result.total_tax_amount,
                      v_tax_result.supply_category
                  );

        v_total_taxable := v_total_taxable + v_taxable;
        v_total_cgst    := v_total_cgst   + v_tax_result.cgst_amount;
        v_total_sgst    := v_total_sgst   + v_tax_result.sgst_amount;
        v_total_igst    := v_total_igst   + v_tax_result.igst_amount;
        v_total_cess    := v_total_cess   + v_tax_result.cess_amount;
        v_line_no := v_line_no + 1;
    END LOOP;

    v_invoice_value := v_total_taxable + v_total_cgst + v_total_sgst + v_total_igst + v_total_cess;

    -- Update invoice header totals
    UPDATE gst.tax_invoice SET
        taxable_value    = v_total_taxable,
        cgst_amount      = v_total_cgst,
        sgst_amount      = v_total_sgst,
        igst_amount      = v_total_igst,
        cess_amount      = v_total_cess,
        total_tax_amount = v_total_cgst + v_total_sgst + v_total_igst + v_total_cess,
        invoice_value    = v_invoice_value,
        supply_type      = gst.get_supply_type_for_invoice(
                                  p_buyer_gstin, p_buyer_state, v_seller_state, v_invoice_value)
    WHERE invoice_id = v_invoice_id AND invoice_date = p_invoice_date;

    RETURN jsonb_build_object(
              'invoice_id',     v_invoice_id,
              'invoice_number', v_invoice_no,
              'invoice_date',   p_invoice_date,
              'taxable_value',  v_total_taxable,
              'cgst_amount',    v_total_cgst,
              'sgst_amount',    v_total_sgst,
              'igst_amount',    v_total_igst,
              'cess_amount',    v_total_cess,
              'invoice_value',  v_invoice_value,
              'is_igst',        v_is_igst,
              'place_of_supply', v_pos
          );
END;
$$;

COMMENT ON FUNCTION gst.create_tax_invoice IS
    'Creates a complete GST invoice with auto-calculated CGST/SGST/IGST/Cess.
     Accepts JSON array of line items. Returns invoice summary as JSON.';

-- -------------------------------------------------------------------------
-- FUNCTION: cancel_invoice
-- Cancels an invoice within the same GSTR-1 period (pre-filing only)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.cancel_invoice(
      p_invoice_id        UUID,
      p_invoice_date      DATE,
      p_cancellation_reason TEXT,
      p_cancelled_by      VARCHAR(100) DEFAULT NULL
  )
RETURNS BOOLEAN
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_gstr1_period CHAR(7);
    v_filing_status VARCHAR(20);
BEGIN
    SELECT gstr1_period INTO v_gstr1_period
    FROM gst.tax_invoice
    WHERE invoice_id = p_invoice_id AND invoice_date = p_invoice_date
      AND is_cancelled = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND: Invoice % not found or already cancelled', p_invoice_id;
    END IF;

    -- Check if GSTR-1 already filed for this period
    SELECT filing_status INTO v_filing_status
    FROM gst.gstr_filing_log
    WHERE tax_period = v_gstr1_period AND return_type = 'GSTR1'
    LIMIT 1;

    IF v_filing_status IN ('FILED', 'SUBMITTED') THEN
        RAISE EXCEPTION 'FILED_PERIOD: Cannot cancel invoice in filed period %. Use credit note instead.', v_gstr1_period;
    END IF;

    UPDATE gst.tax_invoice SET
        is_cancelled       = TRUE,
        cancelled_at       = NOW(),
        cancellation_reason = p_cancellation_reason,
        updated_at         = NOW()
    WHERE invoice_id = p_invoice_id AND invoice_date = p_invoice_date;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION gst.cancel_invoice IS
    'Cancels an invoice. Blocks cancellation if GSTR-1 is already filed for the period.
     For post-filing corrections, use credit notes instead.';

-- -------------------------------------------------------------------------
-- FUNCTION: create_credit_note
-- Creates a credit note against an original invoice
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.create_credit_note(
      p_original_invoice_id UUID,
      p_original_invoice_date DATE,
      p_reason              TEXT,
      p_credit_line_items   JSONB,   -- same format as create_tax_invoice line items
    p_created_by          VARCHAR(100) DEFAULT NULL
  )
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_orig   RECORD;
    v_result JSONB;
BEGIN
    SELECT seller_gstin, buyer_gstin, buyer_name, buyer_state_code, invoice_number
    INTO   v_orig
    FROM   gst.tax_invoice
    WHERE  invoice_id = p_original_invoice_id
      AND  invoice_date = p_original_invoice_date
      AND  is_cancelled = FALSE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND: Original invoice % not found', p_original_invoice_id;
    END IF;

    -- Create credit note using same invoice creation function
    v_result := gst.create_tax_invoice(
              p_seller_gstin  => v_orig.seller_gstin,
              p_buyer_gstin   => v_orig.buyer_gstin,
              p_buyer_name    => v_orig.buyer_name,
              p_buyer_state   => v_orig.buyer_state_code,
              p_invoice_date  => CURRENT_DATE,
              p_invoice_type  => 'CREDIT_NOTE',
              p_created_by    => p_created_by,
              p_line_items    => p_credit_line_items
          );

    -- Link back to original invoice
    UPDATE gst.tax_invoice SET
        original_invoice_id => p_original_invoice_id,
        original_invoice_no => v_orig.invoice_number,
        original_invoice_dt => p_original_invoice_date
    WHERE invoice_id = (v_result->>'invoice_id')::UUID
      AND invoice_date = CURRENT_DATE;

    RETURN v_result || jsonb_build_object(
              'note_type', 'CREDIT_NOTE',
              'original_invoice_id', p_original_invoice_id,
              'original_invoice_no', v_orig.invoice_number,
              'reason', p_reason
          );
END;
$$;

COMMENT ON FUNCTION gst.create_credit_note IS
    'Creates a GST credit note linked to an original invoice.
     Used for sales returns, price corrections, and post-supply discounts.';

-- -------------------------------------------------------------------------
-- FUNCTION: get_invoice_summary
-- Returns a full invoice summary with line items (for display/printing)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.get_invoice_summary(
      p_invoice_id   UUID,
      p_invoice_date DATE
  )
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_header RECORD;
    v_lines  JSONB;
    v_seller RECORD;
    v_buyer  RECORD;
BEGIN
    SELECT * INTO v_header
    FROM gst.tax_invoice
    WHERE invoice_id = p_invoice_id AND invoice_date = p_invoice_date;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND: %', p_invoice_id;
    END IF;

    SELECT jsonb_agg(jsonb_build_object(
              'line_number',       li.line_number,
              'product_code',      li.product_code,
              'product_description', li.product_description,
              'hsn_code',          li.hsn_code,
              'uom',               li.uom,
              'quantity',          li.quantity,
              'unit_price',        li.unit_price,
              'gross_amount',      li.gross_amount,
              'discount_amount',   li.discount_amount,
              'taxable_value',     li.taxable_value,
              'cgst_rate',         li.cgst_rate,
              'cgst_amount',       li.cgst_amount,
              'sgst_rate',         li.sgst_rate,
              'sgst_amount',       li.sgst_amount,
              'igst_rate',         li.igst_rate,
              'igst_amount',       li.igst_amount,
              'cess_rate',         li.cess_rate,
              'cess_amount',       li.cess_amount,
              'line_total',        li.line_total
          ) ORDER BY li.line_number)
    INTO v_lines
    FROM gst.invoice_line_item li
    WHERE li.invoice_id = p_invoice_id AND li.invoice_date = p_invoice_date;

    SELECT legal_name, trade_name, address_line1, city, pincode, gstin
    INTO v_seller
    FROM gst.company_gstin
    WHERE gstin = v_header.seller_gstin LIMIT 1;

    SELECT party_name, trade_name, address_line1, city, pincode, gstin
    INTO v_buyer
    FROM gst.party_master
    WHERE gstin = v_header.buyer_gstin LIMIT 1;

    RETURN jsonb_build_object(
              'invoice_id',      v_header.invoice_id,
              'invoice_number',  v_header.invoice_number,
              'invoice_date',    v_header.invoice_date,
              'invoice_type',    v_header.invoice_type,
              'supply_type',     v_header.supply_type,
              'place_of_supply', v_header.place_of_supply,
              'is_igst',         v_header.is_igst_applicable,
              'is_rcm',          v_header.is_reverse_charge,
              'seller', jsonb_build_object(
                  'gstin', v_header.seller_gstin,
                  'name',  COALESCE(v_seller.trade_name, v_seller.legal_name),
                  'address', v_seller.address_line1,
                  'city',  v_seller.city
              ),
              'buyer', jsonb_build_object(
                  'gstin', v_header.buyer_gstin,
                  'name',  COALESCE(v_buyer.trade_name, v_buyer.party_name, v_header.buyer_name),
                  'state', v_header.buyer_state_code
              ),
              'taxable_value',    v_header.taxable_value,
              'cgst_amount',      v_header.cgst_amount,
              'sgst_amount',      v_header.sgst_amount,
              'igst_amount',      v_header.igst_amount,
              'cess_amount',      v_header.cess_amount,
              'total_tax_amount', v_header.total_tax_amount,
              'invoice_value',    v_header.invoice_value,
              'line_items',       v_lines,
              'is_cancelled',     v_header.is_cancelled,
              'gstr1_period',     v_header.gstr1_period,
              'created_at',       v_header.created_at
          );
END;
$$;

COMMENT ON FUNCTION gst.get_invoice_summary IS
    'Returns complete invoice JSON including header, seller, buyer, line items and tax summary.
     Used for invoice display, printing, and API responses.';

-- -------------------------------------------------------------------------
-- Grant execute privileges
-- -------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION gst.generate_invoice_number(VARCHAR, gst.invoice_type, DATE)  TO gst_user;
GRANT EXECUTE ON FUNCTION gst.create_tax_invoice(VARCHAR,VARCHAR,VARCHAR,CHAR,DATE,gst.invoice_type,BOOLEAN,VARCHAR,JSONB) TO gst_user;
GRANT EXECUTE ON FUNCTION gst.cancel_invoice(UUID, DATE, TEXT, VARCHAR)                  TO gst_user;
GRANT EXECUTE ON FUNCTION gst.create_credit_note(UUID, DATE, TEXT, JSONB, VARCHAR)       TO gst_user;
GRANT EXECUTE ON FUNCTION gst.get_invoice_summary(UUID, DATE)                            TO gst_user, gst_readonly;
