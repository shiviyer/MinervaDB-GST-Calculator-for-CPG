-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: schema/02_enums_domains.sql
-- Description: Custom types, enums, and domains for GST data integrity
-- Brand: MinervaDB GST Calculator for CPG
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- ENUM: GST transaction types
-- -------------------------------------------------------------------------
CREATE TYPE gst.supply_type AS ENUM (
      'B2B',          -- Business to Business
    'B2C_LARGE',    -- Business to Consumer (invoice value > 2.5 lakh)
    'B2C_SMALL',    -- Business to Consumer (invoice value <= 2.5 lakh)
    'EXPORT_WITH_IGST',
      'EXPORT_WITHOUT_IGST',
      'SEZ_WITH_IGST',
      'SEZ_WITHOUT_IGST',
      'DEEMED_EXPORT',
      'RCM'           -- Reverse Charge Mechanism
);

-- -------------------------------------------------------------------------
-- ENUM: Tax types
-- -------------------------------------------------------------------------
CREATE TYPE gst.tax_type AS ENUM (
      'CGST',     -- Central GST (intra-state)
    'SGST',     -- State GST (intra-state)
    'IGST',     -- Integrated GST (inter-state)
    'UTGST',    -- Union Territory GST
    'CESS'      -- Compensation Cess (on sin goods)
);

-- -------------------------------------------------------------------------
-- ENUM: Invoice types
-- -------------------------------------------------------------------------
CREATE TYPE gst.invoice_type AS ENUM (
      'TAX_INVOICE',
      'BILL_OF_SUPPLY',   -- For exempted/composition supplies
    'CREDIT_NOTE',
      'DEBIT_NOTE',
      'REFUND_VOUCHER',
      'PAYMENT_VOUCHER',  -- RCM inward supplies
    'DELIVERY_CHALLAN'
  );

-- -------------------------------------------------------------------------
-- ENUM: GST registration types
-- -------------------------------------------------------------------------
CREATE TYPE gst.registration_type AS ENUM (
      'REGULAR',
      'COMPOSITION',
      'UNREGISTERED',
      'SEZ_UNIT',
      'SEZ_DEVELOPER',
      'EMBASSY',
      'DEEMED_EXPORTER',
      'ISD'   -- Input Service Distributor
);

-- -------------------------------------------------------------------------
-- ENUM: Supply category for CPG
-- -------------------------------------------------------------------------
CREATE TYPE gst.supply_category AS ENUM (
      'TAXABLE',
      'ZERO_RATED',       -- Exports and SEZ
    'EXEMPTED',         -- Exempt under GST law
    'NIL_RATED',        -- Nil rate applicable
    'NON_GST'           -- Non-GST supply
);

-- -------------------------------------------------------------------------
-- ENUM: GSTR return types
-- -------------------------------------------------------------------------
CREATE TYPE gst.return_type AS ENUM (
      'GSTR1',
      'GSTR2A',
      'GSTR2B',
      'GSTR3B',
      'GSTR9',
      'GSTR9C'
  );

-- -------------------------------------------------------------------------
-- ENUM: ITC eligibility
-- -------------------------------------------------------------------------
CREATE TYPE gst.itc_eligibility AS ENUM (
      'ELIGIBLE',
      'INELIGIBLE_SECTION_17_5',   -- Blocked credits
    'INELIGIBLE_EXEMPT_SUPPLY',  -- Used for exempt supply
    'PROVISIONAL',
      'REVERSED'
  );

-- -------------------------------------------------------------------------
-- ENUM: Payment mode
-- -------------------------------------------------------------------------
CREATE TYPE gst.payment_mode AS ENUM (
      'CASH_LEDGER',
      'CREDIT_LEDGER',
      'BOTH'
  );

-- -------------------------------------------------------------------------
-- DOMAIN: GSTIN (15-character alphanumeric with format validation)
-- -------------------------------------------------------------------------
CREATE DOMAIN gst.gstin AS VARCHAR(15)
    CHECK (
          VALUE ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'
      );

COMMENT ON DOMAIN gst.gstin IS 
    'Valid Indian GSTIN: 2-digit state code + 10-digit PAN + 1-digit entity + Z + 1-digit checksum';

-- -------------------------------------------------------------------------
-- DOMAIN: HSN code (4, 6, or 8 digits for CPG products)
-- -------------------------------------------------------------------------
CREATE DOMAIN gst.hsn_code AS VARCHAR(8)
    CHECK (
          VALUE ~ '^[0-9]{4}([0-9]{2}([0-9]{2})?)?$'
      );

COMMENT ON DOMAIN gst.hsn_code IS 
    'HSN code: 4-digit chapter.heading, 6-digit with subheading, or 8-digit with tariff item';

-- -------------------------------------------------------------------------
-- DOMAIN: GST rate (0 to 100 percent with 4 decimal precision)
-- -------------------------------------------------------------------------
CREATE DOMAIN gst.tax_rate AS NUMERIC(7,4)
    CHECK (VALUE >= 0 AND VALUE <= 100);

-- -------------------------------------------------------------------------
-- DOMAIN: Indian state code (2-letter abbreviation)
-- -------------------------------------------------------------------------
CREATE DOMAIN gst.state_code AS CHAR(2)
    CHECK (VALUE ~ '^[A-Z]{2}$');

-- -------------------------------------------------------------------------
-- DOMAIN: Monetary amounts (up to 15 digits with 2 decimal places)
-- -------------------------------------------------------------------------
CREATE DOMAIN gst.rupee_amount AS NUMERIC(17,2)
    CHECK (VALUE >= 0);

-- -------------------------------------------------------------------------
-- DOMAIN: Signed monetary amounts (can be negative for credit notes)
-- -------------------------------------------------------------------------
CREATE DOMAIN gst.rupee_amount_signed AS NUMERIC(17,2);

COMMENT ON DOMAIN gst.rupee_amount IS 'Non-negative INR amount with 2 decimal precision';
COMMENT ON DOMAIN gst.rupee_amount_signed IS 'Signed INR amount (negative for credit notes/reversals)';
