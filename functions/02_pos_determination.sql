-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: functions/02_pos_determination.sql
-- Description: Place of Supply determination per GST Act Sections 10-13
-- Brand: MinervaDB GST Calculator for CPG
-- =============================================================================

SET search_path TO gst, public;

CREATE OR REPLACE FUNCTION gst.determine_place_of_supply(
      p_seller_state      CHAR(2),
      p_buyer_state       CHAR(2),
      p_delivery_state    CHAR(2)  DEFAULT NULL,
      p_supply_type       VARCHAR  DEFAULT 'GOODS'
  )
RETURNS CHAR(2)
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
AS $$
DECLARE
    v_pos   CHAR(2);
BEGIN
    IF p_supply_type = 'GOODS' THEN
        v_pos := COALESCE(p_delivery_state, p_buyer_state);
    ELSIF p_supply_type = 'SERVICES' THEN
        v_pos := COALESCE(p_buyer_state, p_seller_state);
    ELSE
        v_pos := COALESCE(p_delivery_state, p_buyer_state);
    END IF;
    RETURN v_pos;
END;
$$;

COMMENT ON FUNCTION gst.determine_place_of_supply IS
    'Determines Place of Supply per IGST Act Sections 10-13. Returns 2-letter state code.';

CREATE OR REPLACE FUNCTION gst.is_inter_state_supply(
      p_seller_gstin      VARCHAR(15),
      p_buyer_state       CHAR(2)
  )
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_seller_state  CHAR(2);
BEGIN
    SELECT state_code INTO v_seller_state
    FROM gst.company_gstin
    WHERE gstin = p_seller_gstin
    LIMIT 1;

    IF v_seller_state IS NULL THEN
        SELECT state_code INTO v_seller_state
        FROM gst.state_master
        WHERE gst_state_code = LEFT(p_seller_gstin, 2)
        LIMIT 1;
    END IF;

    IF v_seller_state IS NULL THEN
        RAISE EXCEPTION 'Cannot determine seller state for GSTIN: %', p_seller_gstin;
    END IF;

    RETURN v_seller_state <> p_buyer_state;
END;
$$;

COMMENT ON FUNCTION gst.is_inter_state_supply IS
    'Returns TRUE if supply is inter-state (IGST), FALSE if intra-state (CGST+SGST)';

CREATE OR REPLACE FUNCTION gst.get_supply_type_for_invoice(
      p_buyer_gstin       VARCHAR(15),
      p_buyer_state       CHAR(2),
      p_seller_state      CHAR(2),
      p_invoice_value     NUMERIC(17,2),
      p_is_export         BOOLEAN DEFAULT FALSE,
      p_is_sez            BOOLEAN DEFAULT FALSE
  )
RETURNS gst.supply_type
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
AS $$
DECLARE
    v_is_b2b BOOLEAN;
BEGIN
    IF p_is_export THEN RETURN 'EXPORT_WITHOUT_IGST'::gst.supply_type; END IF;
    IF p_is_sez    THEN RETURN 'SEZ_WITHOUT_IGST'::gst.supply_type; END IF;

    v_is_b2b := p_buyer_gstin IS NOT NULL
                AND p_buyer_gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$';

    IF v_is_b2b THEN RETURN 'B2B'::gst.supply_type; END IF;

    IF p_seller_state <> p_buyer_state AND p_invoice_value > 250000 THEN
        RETURN 'B2C_LARGE'::gst.supply_type;
    END IF;

    RETURN 'B2C_SMALL'::gst.supply_type;
END;
$$;

COMMENT ON FUNCTION gst.get_supply_type_for_invoice IS
    'Classifies GST supply type: B2B, B2C_LARGE, B2C_SMALL, EXPORT, SEZ etc.';

CREATE OR REPLACE FUNCTION gst.validate_gstin(p_gstin VARCHAR(15))
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
AS $$
DECLARE
    v_chars      TEXT := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    v_product    INT  := 0;
    v_factor     INT;
    v_code_point INT;
    v_checksum   INT;
    v_expected   CHAR(1);
    i            INT;
BEGIN
    IF p_gstin IS NULL OR length(p_gstin) <> 15 THEN RETURN FALSE; END IF;
    IF p_gstin !~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$' THEN
        RETURN FALSE;
    END IF;
    IF LEFT(p_gstin, 2)::INT NOT BETWEEN 1 AND 99 THEN RETURN FALSE; END IF;

    FOR i IN 1..14 LOOP
        v_factor     := CASE WHEN i % 2 = 1 THEN 1 ELSE 2 END;
        v_code_point := position(substring(p_gstin FROM i FOR 1) IN v_chars) - 1;
        v_product    := v_product + (v_code_point * v_factor) / 36
                      + (v_code_point * v_factor) % 36;
    END LOOP;

    v_checksum := (36 - (v_product % 36)) % 36;
    v_expected := substring(v_chars FROM v_checksum + 1 FOR 1);
    RETURN substring(p_gstin FROM 15 FOR 1) = v_expected;
END;
$$;

COMMENT ON FUNCTION gst.validate_gstin IS
    'Validates GSTIN format and Luhn checksum. Returns TRUE if valid.';
