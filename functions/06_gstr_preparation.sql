-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: functions/06_gstr_preparation.sql
-- Description: GSTR-1, GSTR-3B, GSTR-9 data preparation functions
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- FUNCTION: prepare_gstr1_data
-- Prepares GSTR-1 return data for a GSTIN and filing period
-- Returns structured JSON matching GSTN API schema
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.prepare_gstr1_data(
      p_gstin      VARCHAR(15),
      p_tax_period CHAR(7)        -- MMYYYY e.g. '062026'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_b2b       JSONB;
    v_b2cl      JSONB;
    v_b2cs      JSONB;
    v_cdnr      JSONB;  -- Credit/Debit notes to registered
    v_cdnur     JSONB;  -- Credit/Debit notes to unregistered
    v_exp       JSONB;  -- Exports
    v_hsn_sum   JSONB;  -- HSN summary
    v_doc_issue JSONB;  -- Document issuance summary
    v_total_tax NUMERIC(17,2);
BEGIN
    -- B2B: Invoices to registered buyers
    SELECT jsonb_agg(jsonb_build_object(
          'ctin',    ti.buyer_gstin,
          'inv', jsonb_build_array(jsonb_build_object(
              'inum',  ti.invoice_number,
              'idt',   TO_CHAR(ti.invoice_date, 'DD-MM-YYYY'),
              'val',   ti.invoice_value,
              'pos',   ti.place_of_supply,
              'rchrg', CASE WHEN ti.is_reverse_charge THEN 'Y' ELSE 'N' END,
              'itms',  (
                  SELECT jsonb_agg(jsonb_build_object(
                      'num',   li.line_number,
                      'itm_det', jsonb_build_object(
                          'txval', li.taxable_value,
                          'rt',    CASE WHEN ti.is_igst_applicable
                                        THEN li.igst_rate
                                        ELSE (li.cgst_rate + li.sgst_rate) END,
                          'iamt',  li.igst_amount,
                          'camt',  li.cgst_amount,
                          'samt',  li.sgst_amount,
                          'csamt', li.cess_amount
                      )
                  ))
                  FROM gst.invoice_line_item li
                  WHERE li.invoice_id = ti.invoice_id
                    AND li.invoice_date = ti.invoice_date
              )
          ))
      ))
    INTO v_b2b
    FROM gst.tax_invoice ti
    WHERE ti.seller_gstin = p_gstin
      AND ti.gstr1_period = p_tax_period
      AND ti.supply_type = 'B2B'
      AND ti.invoice_type IN ('TAX_INVOICE', 'BILL_OF_SUPPLY')
      AND ti.is_cancelled = FALSE;

    -- B2CL: Large B2C invoices (inter-state, value > 2.5 lakh)
    SELECT jsonb_agg(jsonb_build_object(
              'pos',  ti.place_of_supply,
              'inv',  jsonb_build_array(jsonb_build_object(
                  'inum', ti.invoice_number,
                  'idt',  TO_CHAR(ti.invoice_date, 'DD-MM-YYYY'),
                  'val',  ti.invoice_value,
                  'itms', jsonb_build_array(jsonb_build_object(
                      'num', 1,
                      'itm_det', jsonb_build_object(
                          'txval', ti.taxable_value,
                          'rt',    CASE WHEN ti.is_igst_applicable
                                        THEN (SELECT igst_rate FROM gst.invoice_line_item
                                              WHERE invoice_id = ti.invoice_id LIMIT 1)
                                        ELSE 0 END,
                          'iamt',  ti.igst_amount,
                          'csamt', ti.cess_amount
                      )
                  ))
              ))
          ))
    INTO v_b2cl
    FROM gst.tax_invoice ti
    WHERE ti.seller_gstin = p_gstin
      AND ti.gstr1_period = p_tax_period
      AND ti.supply_type = 'B2C_LARGE'
      AND ti.is_cancelled = FALSE;

    -- B2CS: Small B2C summary (intra-state or small inter-state)
    SELECT jsonb_agg(jsonb_build_object(
              'sply_tp', 'INTRA',
              'pos',     s.place_of_supply,
              'typ',     'OE',
              'rt',      s.rate,
              'txval',   s.txval,
              'iamt',    s.iamt,
              'camt',    s.camt,
              'samt',    s.samt,
              'csamt',   s.csamt
          ))
    INTO v_b2cs
    FROM (
              SELECT
                  ti.place_of_supply,
                  li.cgst_rate + li.sgst_rate AS rate,
                  SUM(li.taxable_value)    AS txval,
                  SUM(li.igst_amount)      AS iamt,
                  SUM(li.cgst_amount)      AS camt,
                  SUM(li.sgst_amount)      AS samt,
                  SUM(li.cess_amount)      AS csamt
              FROM gst.tax_invoice ti
              JOIN gst.invoice_line_item li
                   ON li.invoice_id = ti.invoice_id AND li.invoice_date = ti.invoice_date
              WHERE ti.seller_gstin = p_gstin
                AND ti.gstr1_period = p_tax_period
                AND ti.supply_type = 'B2C_SMALL'
                AND ti.is_cancelled = FALSE
              GROUP BY ti.place_of_supply, li.cgst_rate + li.sgst_rate
          ) s;

    -- CDNR: Credit/Debit notes to registered parties
    SELECT jsonb_agg(jsonb_build_object(
              'ctin', ti.buyer_gstin,
              'nt',   jsonb_build_array(jsonb_build_object(
                  'ntty',  CASE ti.invoice_type
                             WHEN 'CREDIT_NOTE' THEN 'C'
                             WHEN 'DEBIT_NOTE'  THEN 'D'
                           END,
                  'nt_num', ti.invoice_number,
                  'nt_dt',  TO_CHAR(ti.invoice_date, 'DD-MM-YYYY'),
                  'val',    ti.invoice_value,
                  'ntty',   CASE ti.invoice_type WHEN 'CREDIT_NOTE' THEN 'C' ELSE 'D' END,
                  'itms',   jsonb_build_array(jsonb_build_object(
                      'num', 1,
                      'itm_det', jsonb_build_object(
                          'txval', ti.taxable_value,
                          'rt',    0,
                          'iamt',  ti.igst_amount,
                          'camt',  ti.cgst_amount,
                          'samt',  ti.sgst_amount,
                          'csamt', ti.cess_amount
                      )
                  ))
              ))
          ))
    INTO v_cdnr
    FROM gst.tax_invoice ti
    WHERE ti.seller_gstin = p_gstin
      AND ti.gstr1_period = p_tax_period
      AND ti.invoice_type IN ('CREDIT_NOTE', 'DEBIT_NOTE')
      AND ti.buyer_gstin IS NOT NULL
      AND ti.is_cancelled = FALSE;

    -- Exports
    SELECT jsonb_agg(jsonb_build_object(
              'exp_typ', CASE ti.export_type
                           WHEN 'WITH_IGST'    THEN 'WPAY'
                           WHEN 'WITHOUT_IGST' THEN 'WOPAY'
                           ELSE 'WOPAY'
                         END,
              'inv', jsonb_build_array(jsonb_build_object(
                  'inum',    ti.invoice_number,
                  'idt',     TO_CHAR(ti.invoice_date, 'DD-MM-YYYY'),
                  'val',     ti.invoice_value,
                  'sbpcode', ti.port_code,
                  'sbnum',   ti.shipping_bill_no,
                  'sbdt',    TO_CHAR(ti.shipping_bill_date, 'DD-MM-YYYY'),
                  'itms',    jsonb_build_array(jsonb_build_object(
                      'txval', ti.taxable_value,
                      'rt',    0,
                      'iamt',  ti.igst_amount
                  ))
              ))
          ))
    INTO v_exp
    FROM gst.tax_invoice ti
    WHERE ti.seller_gstin = p_gstin
      AND ti.gstr1_period = p_tax_period
      AND ti.supply_type IN ('EXPORT_WITH_IGST','EXPORT_WITHOUT_IGST')
      AND ti.is_cancelled = FALSE;

    -- HSN Summary
    SELECT jsonb_build_object(
              'hsn_sc', jsonb_agg(jsonb_build_object(
                  'num',  ROW_NUMBER() OVER (ORDER BY li.hsn_code),
                  'hsn_sc', li.hsn_code,
                  'uqc',  li.uom,
                  'qty',  SUM(li.quantity),
                  'val',  SUM(li.gross_amount),
                  'txval', SUM(li.taxable_value),
                  'iamt',  SUM(li.igst_amount),
                  'camt',  SUM(li.cgst_amount),
                  'samt',  SUM(li.sgst_amount),
                  'csamt', SUM(li.cess_amount)
              ))
          )
    INTO v_hsn_sum
    FROM gst.invoice_line_item li
    JOIN gst.tax_invoice ti ON ti.invoice_id = li.invoice_id AND ti.invoice_date = li.invoice_date
    WHERE ti.seller_gstin = p_gstin
      AND ti.gstr1_period = p_tax_period
      AND ti.is_cancelled = FALSE
    GROUP BY li.hsn_code, li.uom;

    RETURN jsonb_build_object(
              'gstin',      p_gstin,
              'fp',         p_tax_period,
              'gt',         (SELECT SUM(invoice_value) FROM gst.tax_invoice
                             WHERE seller_gstin = p_gstin AND gstr1_period = p_tax_period
                               AND is_cancelled = FALSE),
              'cur_gt',     (SELECT SUM(invoice_value) FROM gst.tax_invoice
                             WHERE seller_gstin = p_gstin AND gstr1_period = p_tax_period
                               AND is_cancelled = FALSE),
              'b2b',        COALESCE(v_b2b,  '[]'::JSONB),
              'b2cl',       COALESCE(v_b2cl, '[]'::JSONB),
              'b2cs',       COALESCE(v_b2cs, '[]'::JSONB),
              'cdnr',       COALESCE(v_cdnr, '[]'::JSONB),
              'cdnur',      COALESCE(v_cdnur,'[]'::JSONB),
              'exp',        COALESCE(v_exp,  '[]'::JSONB),
              'hsn',        COALESCE(v_hsn_sum, '{}'::JSONB)
          );
END;
$$;

COMMENT ON FUNCTION gst.prepare_gstr1_data IS
    'Prepares GSTR-1 return JSON payload for a GSTIN and tax period.
     Output conforms to GSTN API v1.1 schema for direct filing integration.';

-- -------------------------------------------------------------------------
-- FUNCTION: prepare_gstr3b_data
-- Prepares GSTR-3B summary for a GSTIN and filing period
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.prepare_gstr3b_data(
      p_gstin      VARCHAR(15),
      p_tax_period CHAR(7)
  )
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_outward   RECORD;
    v_itc       RECORD;
BEGIN
    -- Outward supplies summary
    SELECT
        COALESCE(SUM(CASE WHEN supply_type = 'B2B' THEN taxable_value ELSE 0 END),0) AS taxable_b2b,
        COALESCE(SUM(CASE WHEN supply_type IN ('B2C_LARGE','B2C_SMALL') THEN taxable_value ELSE 0 END),0) AS taxable_b2c,
        COALESCE(SUM(CASE WHEN supply_type IN ('EXPORT_WITH_IGST','EXPORT_WITHOUT_IGST')
                            THEN taxable_value ELSE 0 END),0) AS zero_rated,
        COALESCE(SUM(cgst_amount),0) AS total_cgst,
        COALESCE(SUM(sgst_amount),0) AS total_sgst,
        COALESCE(SUM(igst_amount),0) AS total_igst,
        COALESCE(SUM(cess_amount),0) AS total_cess,
        COALESCE(SUM(invoice_value),0) AS total_value
    INTO v_outward
    FROM gst.tax_invoice
    WHERE seller_gstin = p_gstin
      AND gstr3b_period = p_tax_period
      AND is_cancelled = FALSE
      AND invoice_type IN ('TAX_INVOICE','DEBIT_NOTE');

    -- ITC summary from purchase ledger
    SELECT
        COALESCE(SUM(CASE WHEN tax_head = 'IGST' AND eligibility = 'ELIGIBLE'
                                THEN credit_amount ELSE 0 END),0) AS itc_igst,
        COALESCE(SUM(CASE WHEN tax_head = 'CGST' AND eligibility = 'ELIGIBLE'
                                THEN credit_amount ELSE 0 END),0) AS itc_cgst,
        COALESCE(SUM(CASE WHEN tax_head = 'SGST' AND eligibility = 'ELIGIBLE'
                                THEN credit_amount ELSE 0 END),0) AS itc_sgst,
        COALESCE(SUM(CASE WHEN tax_head = 'CESS' AND eligibility = 'ELIGIBLE'
                                THEN credit_amount ELSE 0 END),0) AS itc_cess
    INTO v_itc
    FROM gst.itc_ledger
    WHERE gstin = p_gstin
      AND tax_period = p_tax_period
      AND transaction_type = 'INWARD_SUPPLY';

    RETURN jsonb_build_object(
              'gstin',      p_gstin,
              'ret_period', p_tax_period,
              'sup_details', jsonb_build_object(
                  'osup_det', jsonb_build_object(
                      'txval',  v_outward.taxable_b2b + v_outward.taxable_b2c,
                      'iamt',   v_outward.total_igst,
                      'camt',   v_outward.total_cgst,
                      'samt',   v_outward.total_sgst,
                      'csamt',  v_outward.total_cess
                  ),
                  'osup_zero', jsonb_build_object(
                      'txval',  v_outward.zero_rated,
                      'iamt',   0,
                      'camt',   0,
                      'samt',   0,
                      'csamt',  0
                  )
              ),
              'itc_elg', jsonb_build_object(
                  'itc_avl', jsonb_build_array(
                      jsonb_build_object(
                          'ty',    'IMPG',
                          'iamt',  v_itc.itc_igst,
                          'camt',  v_itc.itc_cgst,
                          'samt',  v_itc.itc_sgst,
                          'csamt', v_itc.itc_cess
                      )
                  )
              ),
              'intr_ltfee', jsonb_build_object(
                  'intr_details', jsonb_build_object(
                      'iamt', 0, 'camt', 0, 'samt', 0, 'csamt', 0
                  )
              )
          );
END;
$$;

COMMENT ON FUNCTION gst.prepare_gstr3b_data IS
    'Prepares GSTR-3B summary JSON for a GSTIN and period.
     Covers outward supply totals and ITC eligible amounts.';

-- -------------------------------------------------------------------------
-- Grant privileges
-- -------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION gst.prepare_gstr1_data(VARCHAR, CHAR)  TO gst_user, gst_readonly;
GRANT EXECUTE ON FUNCTION gst.prepare_gstr3b_data(VARCHAR, CHAR) TO gst_user, gst_readonly;
