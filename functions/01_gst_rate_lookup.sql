-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: functions/01_gst_rate_lookup.sql
-- Description: GST rate resolution functions — HSN-based rate lookup with
--              chapter-level fallback, effective-date filtering, and caching
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- FUNCTION: get_gst_rate
-- Returns the applicable GST rate record for a given HSN code on a date.
-- Resolution order: 8-digit > 6-digit > 4-digit > 2-digit (chapter)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.get_gst_rate(
      p_hsn_code       VARCHAR(8),
      p_effective_date DATE DEFAULT CURRENT_DATE
  )
RETURNS TABLE (
      hsn_code        VARCHAR(8),
      cgst_rate       NUMERIC(7,4),
      sgst_rate       NUMERIC(7,4),
      igst_rate       NUMERIC(7,4),
      utgst_rate      NUMERIC(7,4),
      cess_rate       NUMERIC(7,4),
      cess_amount     NUMERIC(17,2),
      supply_category gst.supply_category,
      notification_ref VARCHAR(100),
      effective_from  DATE,
      effective_to    DATE
  )
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    -- Try exact match, then progressively shorter HSN prefixes
    RETURN QUERY
    WITH ranked AS (
          SELECT
              r.hsn_code,
              r.cgst_rate, r.sgst_rate, r.igst_rate, r.utgst_rate,
              r.cess_rate, r.cess_amount, r.supply_category,
              r.notification_ref, r.effective_from, r.effective_to,
              ROW_NUMBER() OVER (ORDER BY length(r.hsn_code) DESC) AS rn
          FROM gst.gst_rate_master r
          WHERE r.is_active = TRUE
            AND r.effective_from <= p_effective_date
            AND (r.effective_to IS NULL OR r.effective_to >= p_effective_date)
            AND p_hsn_code LIKE r.hsn_code || '%'
      )
    SELECT
        ranked.hsn_code, ranked.cgst_rate, ranked.sgst_rate,
        ranked.igst_rate, ranked.utgst_rate, ranked.cess_rate,
        ranked.cess_amount, ranked.supply_category,
        ranked.notification_ref, ranked.effective_from, ranked.effective_to
    FROM ranked
    WHERE rn = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'GST_RATE_NOT_FOUND: No active GST rate for HSN % on %',
            p_hsn_code, p_effective_date
            USING ERRCODE = 'P0001';
    END IF;
END;
$$;

COMMENT ON FUNCTION gst.get_gst_rate IS
    'Resolves GST rate for a HSN code using longest-prefix matching with effective-date filter.
     Resolution order: 8-digit -> 6-digit -> 4-digit -> 2-digit (chapter level).';

-- -------------------------------------------------------------------------
-- FUNCTION: get_gst_rate_by_category
-- Returns all HSN codes and rates for a CPG product category
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.get_gst_rate_by_category(
      p_cpg_category   VARCHAR(100),
      p_effective_date DATE DEFAULT CURRENT_DATE
  )
RETURNS TABLE (
      hsn_code         VARCHAR(8),
      hsn_description  VARCHAR(500),
      cpg_category     VARCHAR(100),
      cgst_rate        NUMERIC(7,4),
      igst_rate        NUMERIC(7,4),
      cess_rate        NUMERIC(7,4),
      supply_category  gst.supply_category
  )
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        h.hsn_code, h.hsn_description, h.cpg_category,
        r.cgst_rate, r.igst_rate, r.cess_rate, r.supply_category
    FROM gst.hsn_code_master h
    JOIN gst.gst_rate_master  r ON r.hsn_code = h.hsn_code
    WHERE h.cpg_category     = p_cpg_category
      AND h.is_active         = TRUE
      AND r.is_active         = TRUE
      AND r.effective_from   <= p_effective_date
      AND (r.effective_to IS NULL OR r.effective_to >= p_effective_date)
    ORDER BY h.hsn_code;
$$;

COMMENT ON FUNCTION gst.get_gst_rate_by_category IS
    'Returns all HSN codes and applicable GST rates for a CPG product category.';

-- -------------------------------------------------------------------------
-- FUNCTION: get_applicable_cess
-- Returns cess rate and/or specific cess amount for sin/demerit goods
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.get_applicable_cess(
      p_hsn_code       VARCHAR(8),
      p_taxable_value  NUMERIC(17,2),
      p_quantity       NUMERIC(15,4),
      p_effective_date DATE DEFAULT CURRENT_DATE
  )
RETURNS TABLE (
      cess_rate        NUMERIC(7,4),
      cess_amount_unit NUMERIC(17,2),
      total_cess       NUMERIC(17,2),
      cess_type        VARCHAR(20)   -- 'AD_VALOREM', 'SPECIFIC', 'HYBRID'
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_rate_rec RECORD;
    v_ad_valorem_cess NUMERIC(17,2) := 0;
    v_specific_cess   NUMERIC(17,2) := 0;
BEGIN
    SELECT r.cess_rate, r.cess_amount
    INTO   v_rate_rec
    FROM   gst.gst_rate_master r
    WHERE  r.hsn_code = p_hsn_code
      AND  r.is_active = TRUE
      AND  r.effective_from <= p_effective_date
      AND  (r.effective_to IS NULL OR r.effective_to >= p_effective_date)
    ORDER BY length(r.hsn_code) DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 0::NUMERIC(7,4), 0::NUMERIC(17,2), 0::NUMERIC(17,2), 'NONE'::VARCHAR(20);
        RETURN;
    END IF;

    v_ad_valorem_cess := ROUND((p_taxable_value * v_rate_rec.cess_rate / 100), 2);
    v_specific_cess   := ROUND(p_quantity * v_rate_rec.cess_amount, 2);

    RETURN QUERY
    SELECT
        v_rate_rec.cess_rate,
        v_rate_rec.cess_amount,
        v_ad_valorem_cess + v_specific_cess,
        CASE
            WHEN v_rate_rec.cess_rate > 0 AND v_rate_rec.cess_amount > 0 THEN 'HYBRID'
            WHEN v_rate_rec.cess_rate > 0 THEN 'AD_VALOREM'
            WHEN v_rate_rec.cess_amount > 0 THEN 'SPECIFIC'
            ELSE 'NONE'
        END::VARCHAR(20);
END;
$$;

COMMENT ON FUNCTION gst.get_applicable_cess IS
    'Calculates cess for sin goods: ad-valorem (%), specific (per unit), or hybrid.
     Used for tobacco, aerated drinks, pan masala under the Cess Act.';

-- -------------------------------------------------------------------------
-- FUNCTION: lookup_hsn_for_product
-- Suggests HSN codes for a CPG product based on description search
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.lookup_hsn_for_product(
      p_product_desc   TEXT,
      p_limit          INT DEFAULT 10
  )
RETURNS TABLE (
      hsn_code        VARCHAR(8),
      hsn_description VARCHAR(500),
      cpg_category    VARCHAR(100),
      cgst_rate       NUMERIC(7,4),
      igst_rate       NUMERIC(7,4)
  )
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        h.hsn_code, h.hsn_description, h.cpg_category,
        r.cgst_rate, r.igst_rate
    FROM gst.hsn_code_master h
    JOIN gst.gst_rate_master  r ON r.hsn_code = h.hsn_code
    WHERE h.is_active = TRUE
      AND r.is_active = TRUE
      AND (
              to_tsvector('english', unaccent(h.hsn_description))
              @@ plainto_tsquery('english', unaccent(p_product_desc))
            OR h.hsn_description ILIKE '%' || p_product_desc || '%'
        )
    ORDER BY
        CASE WHEN h.hsn_description ILIKE p_product_desc || '%' THEN 0 ELSE 1 END,
        h.hsn_code
    LIMIT p_limit;
$$;

COMMENT ON FUNCTION gst.lookup_hsn_for_product IS
    'Full-text and ILIKE search for HSN codes by product description. Used for classification assistance.';

-- -------------------------------------------------------------------------
-- FUNCTION: get_rate_history
-- Returns rate change history for an HSN code (useful for audits)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.get_rate_history(
      p_hsn_code VARCHAR(8)
  )
RETURNS TABLE (
      hsn_code        VARCHAR(8),
      cgst_rate       NUMERIC(7,4),
      igst_rate       NUMERIC(7,4),
      cess_rate       NUMERIC(7,4),
      supply_category gst.supply_category,
      notification_ref VARCHAR(100),
      effective_from  DATE,
      effective_to    DATE
  )
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        r.hsn_code, r.cgst_rate, r.igst_rate, r.cess_rate,
        r.supply_category, r.notification_ref,
        r.effective_from, r.effective_to
    FROM gst.gst_rate_master r
    WHERE r.hsn_code = p_hsn_code
    ORDER BY r.effective_from DESC;
$$;

COMMENT ON FUNCTION gst.get_rate_history IS
    'Returns complete rate change history for an HSN code for audit and compliance purposes.';

-- -------------------------------------------------------------------------
-- Grant execute privileges
-- -------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION gst.get_gst_rate(VARCHAR, DATE)              TO gst_user, gst_readonly;
GRANT EXECUTE ON FUNCTION gst.get_gst_rate_by_category(VARCHAR, DATE)  TO gst_user, gst_readonly;
GRANT EXECUTE ON FUNCTION gst.get_applicable_cess(VARCHAR, NUMERIC, NUMERIC, DATE) TO gst_user, gst_readonly;
GRANT EXECUTE ON FUNCTION gst.lookup_hsn_for_product(TEXT, INT)        TO gst_user, gst_readonly;
GRANT EXECUTE ON FUNCTION gst.get_rate_history(VARCHAR)                TO gst_user, gst_readonly;
