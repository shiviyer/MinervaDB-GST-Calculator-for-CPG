-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: functions/04_itc_engine.sql
-- Description: Input Tax Credit (ITC) computation, eligibility and utilization
-- Brand: MinervaDB GST Calculator for CPG
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- FUNCTION: compute_itc_eligibility
-- Determines if ITC can be claimed on a purchase invoice
-- Based on Section 16, 17(5) of CGST Act
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.compute_itc_eligibility(
      p_hsn_code          VARCHAR(8),
      p_supplier_gstin    VARCHAR(15),
      p_buyer_gstin       VARCHAR(15),
      p_invoice_date      DATE,
      p_invoice_value     NUMERIC(17,2),
      p_supply_category   gst.supply_category DEFAULT 'TAXABLE'
  )
RETURNS gst.itc_eligibility
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_chapter       CHAR(2);
    v_buyer_reg     gst.registration_type;
BEGIN
    -- Composition dealers cannot claim ITC
    SELECT registration_type INTO v_buyer_reg
    FROM gst.party_master
    WHERE gstin = p_buyer_gstin
    LIMIT 1;

    IF v_buyer_reg = 'COMPOSITION' THEN
        RETURN 'INELIGIBLE_SECTION_17_5'::gst.itc_eligibility;
    END IF;

    -- Zero-rated, exempted, nil-rated: no ITC on exempt supplies used for exempt output
    IF p_supply_category IN ('EXEMPTED', 'NIL_RATED', 'NON_GST') THEN
        RETURN 'INELIGIBLE_EXEMPT_SUPPLY'::gst.itc_eligibility;
    END IF;

    -- Section 17(5) blocked credits by HSN chapter
    v_chapter := LEFT(p_hsn_code, 2);

    -- Motor vehicles (Ch 87) - blocked unless used for specified purposes
    IF v_chapter = '87' AND LEFT(p_hsn_code, 4) IN ('8702','8703','8704','8711') THEN
        RETURN 'INELIGIBLE_SECTION_17_5'::gst.itc_eligibility;
    END IF;

    -- Food & beverages for personal consumption (Ch 21, 22) - blocked
    -- Note: CPG manufacturers can claim ITC when it's for business purpose
    -- This is a simplified rule; actual determination needs business context
    -- Foods for employees/personal use are blocked; for manufacturing - eligible
    IF v_chapter IN ('21', '22') AND p_invoice_value < 500 THEN
        -- Small consumer quantities likely personal use
        RETURN 'PROVISIONAL'::gst.itc_eligibility;
    END IF;

    -- Cosmetics & beauty products for personal use (Ch 33) - check context
    IF v_chapter = '33' AND p_invoice_value < 1000 THEN
        RETURN 'PROVISIONAL'::gst.itc_eligibility;
    END IF;

    -- General rule: ITC eligible for B2B purchases for business purposes
    RETURN 'ELIGIBLE'::gst.itc_eligibility;
END;
$$;

COMMENT ON FUNCTION gst.compute_itc_eligibility IS
    'Determines ITC eligibility per CGST Act Sections 16 and 17(5) for CPG industry purchases';

-- -------------------------------------------------------------------------
-- FUNCTION: record_itc
-- Records an ITC entry in the ledger from a purchase invoice
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.record_itc(
      p_gstin             VARCHAR(15),
      p_tax_period        CHAR(7),
      p_document_type     VARCHAR(30),
      p_document_number   VARCHAR(50),
      p_document_date     DATE,
      p_supplier_gstin    VARCHAR(15),
      p_hsn_code          VARCHAR(8),
      p_igst_amount       NUMERIC(17,2) DEFAULT 0,
      p_cgst_amount       NUMERIC(17,2) DEFAULT 0,
      p_sgst_amount       NUMERIC(17,2) DEFAULT 0,
      p_cess_amount       NUMERIC(17,2) DEFAULT 0,
      p_supply_category   gst.supply_category DEFAULT 'TAXABLE'
  )
RETURNS UUID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_itc_id        UUID;
    v_eligibility   gst.itc_eligibility;
    v_invoice_value NUMERIC(17,2);
BEGIN
    -- Compute total invoice value approximation
    v_invoice_value := p_igst_amount + p_cgst_amount + p_sgst_amount + p_cess_amount;

    -- Determine eligibility
    v_eligibility := gst.compute_itc_eligibility(
              p_hsn_code        => p_hsn_code,
              p_supplier_gstin  => p_supplier_gstin,
              p_buyer_gstin     => p_gstin,
              p_invoice_date    => p_document_date,
              p_invoice_value   => v_invoice_value,
              p_supply_category => p_supply_category
          );

    INSERT INTO gst.itc_ledger (
              gstin, tax_period, transaction_date,
              document_type, document_number, document_date,
              supplier_gstin, hsn_code,
              igst_itc, cgst_itc, sgst_itc, cess_itc,
              itc_eligibility
          ) VALUES (
              p_gstin, p_tax_period, CURRENT_DATE,
              p_document_type, p_document_number, p_document_date,
              p_supplier_gstin, p_hsn_code,
              CASE WHEN v_eligibility = 'ELIGIBLE' THEN p_igst_amount ELSE 0 END,
              CASE WHEN v_eligibility = 'ELIGIBLE' THEN p_cgst_amount ELSE 0 END,
              CASE WHEN v_eligibility = 'ELIGIBLE' THEN p_sgst_amount ELSE 0 END,
              CASE WHEN v_eligibility = 'ELIGIBLE' THEN p_cess_amount ELSE 0 END,
              v_eligibility
          )
    RETURNING itc_id INTO v_itc_id;

    RETURN v_itc_id;
END;
$$;

COMMENT ON FUNCTION gst.record_itc IS
    'Records Input Tax Credit in ledger from a CPG purchase invoice with eligibility determination';

-- -------------------------------------------------------------------------
-- FUNCTION: get_itc_summary
-- Returns ITC summary for a GSTIN and tax period
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.get_itc_summary(
      p_gstin         VARCHAR(15),
      p_tax_period    CHAR(7)
  )
RETURNS TABLE (
      opening_igst    NUMERIC(17,2),
      opening_cgst    NUMERIC(17,2),
      opening_sgst    NUMERIC(17,2),
      opening_cess    NUMERIC(17,2),
      availed_igst    NUMERIC(17,2),
      availed_cgst    NUMERIC(17,2),
      availed_sgst    NUMERIC(17,2),
      availed_cess    NUMERIC(17,2),
      reversed_igst   NUMERIC(17,2),
      reversed_cgst   NUMERIC(17,2),
      reversed_sgst   NUMERIC(17,2),
      reversed_cess   NUMERIC(17,2),
      net_igst        NUMERIC(17,2),
      net_cgst        NUMERIC(17,2),
      net_sgst        NUMERIC(17,2),
      net_cess        NUMERIC(17,2)
  )
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        0::NUMERIC(17,2)   AS opening_igst,
        0::NUMERIC(17,2)   AS opening_cgst,
        0::NUMERIC(17,2)   AS opening_sgst,
        0::NUMERIC(17,2)   AS opening_cess,
        SUM(CASE WHEN NOT is_reversed THEN igst_itc ELSE 0 END) AS availed_igst,
        SUM(CASE WHEN NOT is_reversed THEN cgst_itc ELSE 0 END) AS availed_cgst,
        SUM(CASE WHEN NOT is_reversed THEN sgst_itc ELSE 0 END) AS availed_sgst,
        SUM(CASE WHEN NOT is_reversed THEN cess_itc ELSE 0 END) AS availed_cess,
        SUM(CASE WHEN is_reversed THEN igst_itc ELSE 0 END) AS reversed_igst,
        SUM(CASE WHEN is_reversed THEN cgst_itc ELSE 0 END) AS reversed_cgst,
        SUM(CASE WHEN is_reversed THEN sgst_itc ELSE 0 END) AS reversed_sgst,
        SUM(CASE WHEN is_reversed THEN cess_itc ELSE 0 END) AS reversed_cess,
        SUM(CASE WHEN NOT is_reversed THEN igst_itc ELSE -igst_itc END) AS net_igst,
        SUM(CASE WHEN NOT is_reversed THEN cgst_itc ELSE -cgst_itc END) AS net_cgst,
        SUM(CASE WHEN NOT is_reversed THEN sgst_itc ELSE -sgst_itc END) AS net_sgst,
        SUM(CASE WHEN NOT is_reversed THEN cess_itc ELSE -cess_itc END) AS net_cess
    FROM gst.itc_ledger
    WHERE gstin = p_gstin
      AND tax_period = p_tax_period
      AND itc_eligibility = 'ELIGIBLE';
$$;

COMMENT ON FUNCTION gst.get_itc_summary IS
    'Returns period-wise ITC summary for GSTR-3B Table 4 preparation';

-- -------------------------------------------------------------------------
-- FUNCTION: reverse_itc
-- Reverses ITC on sales returns or ineligible credit detection
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gst.reverse_itc(
      p_itc_id            UUID,
      p_reversal_reason   TEXT
  )
RETURNS BOOLEAN
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
AS $$
DECLARE
    v_count INT;
BEGIN
    UPDATE gst.itc_ledger
    SET
        is_reversed       = TRUE,
        reversal_reference = p_reversal_reason,
        updated_at        = NOW()
    WHERE itc_id = p_itc_id
      AND is_reversed = FALSE;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count > 0;
END;
$$;

COMMENT ON FUNCTION gst.reverse_itc IS
    'Reverses ITC entry for sales returns, Section 17(5) violations, or credit note adjustments';-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: data/02_hsn_codes_cpg.sql
-- Description: CPG HSN codes and GST rate seed data
-- Brand: MinervaDB GST Calculator for CPG
-- =============================================================================

SET search_path TO gst, public;

-- Indian State Codes
INSERT INTO gst.state_master (state_code, gst_state_code, state_name, union_territory) VALUES
('JK','01','Jammu and Kashmir',FALSE),('HP','02','Himachal Pradesh',FALSE),
('PB','03','Punjab',FALSE),('CH','04','Chandigarh',TRUE),
('UK','05','Uttarakhand',FALSE),('HR','06','Haryana',FALSE),
('DL','07','Delhi',TRUE),('RJ','08','Rajasthan',FALSE),
('UP','09','Uttar Pradesh',FALSE),('BR','10','Bihar',FALSE),
('SK','11','Sikkim',FALSE),('AR','12','Arunachal Pradesh',FALSE),
('NL','13','Nagaland',FALSE),('MN','14','Manipur',FALSE),
('MZ','15','Mizoram',FALSE),('TR','16','Tripura',FALSE),
('ME','17','Meghalaya',FALSE),('AS','18','Assam',FALSE),
('WB','19','West Bengal',FALSE),('JH','20','Jharkhand',FALSE),
('OD','21','Odisha',FALSE),('CT','22','Chhattisgarh',FALSE),
('MP','23','Madhya Pradesh',FALSE),('GJ','24','Gujarat',FALSE),
('DD','25','Dadra and Nagar Haveli and Daman and Diu',TRUE),
('MH','27','Maharashtra',FALSE),('KA','29','Karnataka',FALSE),
('GA','30','Goa',FALSE),('LD','31','Lakshadweep',TRUE),
('KL','32','Kerala',FALSE),('TN','33','Tamil Nadu',FALSE),
('PY','34','Puducherry',TRUE),('AN','35','Andaman and Nicobar Islands',TRUE),
('TG','36','Telangana',FALSE),('LA','38','Ladakh',TRUE)
ON CONFLICT (state_code) DO NOTHING;

-- CPG HSN Codes
INSERT INTO gst.hsn_code_master
    (hsn_code, hsn_description, chapter_code, chapter_description, cpg_category, cpg_sub_category, uom)
VALUES
-- Food & Dairy
('0401','Fresh milk and cream','04','Dairy produce','Food','Dairy','LTR'),
('0403','Curd, yoghurt, buttermilk','04','Dairy produce','Food','Dairy','KG'),
('0405','Butter and milk fats','04','Dairy produce','Food','Dairy','KG'),
('0406','Cheese','04','Dairy produce','Food','Dairy','KG'),
-- Edible Oils
('1507','Soya-bean oil','15','Edible oils and fats','Food','Edible Oils','LTR'),
('1511','Palm oil','15','Edible oils and fats','Food','Edible Oils','LTR'),
('1512','Sunflower-seed oil','15','Edible oils and fats','Food','Edible Oils','LTR'),
('1516','Vanaspati / hydrogenated fats','15','Edible oils and fats','Food','Edible Oils','KG'),
-- Sugar & Confectionery
('1701','Sugar (cane/beet)','17','Sugar and confectionery','Food','Sugar & Sweeteners','KG'),
('1704','Chewing gum, candy (no cocoa)','17','Sugar and confectionery','Food','Confectionery','KG'),
-- Cereals
('1001','Wheat','10','Cereals','Food','Cereals & Grains','KG'),
('1006','Rice','10','Cereals','Food','Cereals & Grains','KG'),
('1101','Wheat flour / atta / maida','11','Milling products','Food','Flour & Grains','KG'),
-- Beverages
('2009','Fruit juices, vegetable juices','20','Preserved veg/fruits','Beverages','Juices','LTR'),
('2201','Mineral water, aerated water, ice','22','Beverages','Beverages','Water','LTR'),
('2202','Sweetened/flavoured waters, soft drinks','22','Beverages','Beverages','Aerated Drinks','LTR'),
-- Processed Foods
('1806','Chocolate and cocoa food preps','18','Cocoa preparations','Food','Chocolate & Cocoa','KG'),
('1901','Malt extract, infant food, Horlicks','19','Cereal preparations','Food','Processed Foods','KG'),
('1902','Pasta, noodles, macaroni','19','Cereal preparations','Food','Pasta & Noodles','KG'),
('1904','Cornflakes, muesli, poha, roasted cereals','19','Cereal preparations','Food','Breakfast Cereals','KG'),
('1905','Bread, pastry, cakes, biscuits, wafers','19','Cereal preparations','Food','Bakery & Biscuits','KG'),
-- Spices & Condiments
('0902','Tea, whether or not flavoured','09','Coffee, tea, spices','Food','Tea & Coffee','KG'),
('0901','Coffee','09','Coffee, tea, spices','Food','Tea & Coffee','KG'),
('0910','Ginger, saffron, turmeric, curry','09','Coffee, tea, spices','Food','Spices','KG'),
('2103','Sauces, tomato ketchup, mustard','21','Misc food preparations','Food','Sauces & Condiments','KG'),
('2104','Soups and broths','21','Misc food preparations','Food','Ready-to-Eat','KG'),
('2106','Namkeen, bhujia, protein concentrates','21','Misc food preparations','Food','Snacks & Namkeen','KG'),
('2007','Jams, jellies, marmalades','20','Preserved veg/fruits','Food','Jams & Spreads','KG'),
-- Personal Care
('3305','Shampoo, conditioners, hair dyes','33','Essential oils & cosmetics','Personal Care','Hair Care','ML'),
('3306','Toothpaste, mouthwash','33','Essential oils & cosmetics','Personal Care','Oral Care','GM'),
('3307','Deodorants, shaving preps, sunscreen','33','Essential oils & cosmetics','Personal Care','Skin Care','ML'),
('3304','Make-up, cosmetics, lipstick','33','Essential oils & cosmetics','Personal Care','Cosmetics','GM'),
('3303','Perfumes and toilet waters','33','Essential oils & cosmetics','Personal Care','Fragrances','ML'),
('3401','Soap and cleansing bars','34','Soap & washing preparations','Personal Care','Soap','KG'),
-- Household
('3402','Detergents, fabric wash, dishwash','34','Soap & washing preparations','Household','Detergents','KG'),
('3808','Household insecticides, disinfectants','38','Chemical products','Household','Pest Control','ML'),
-- Tobacco
('2401','Unmanufactured tobacco','24','Tobacco','Tobacco','Unmanufactured','KG'),
('2402','Cigarettes, cigars, cheroots','24','Tobacco','Tobacco','Cigarettes','NOS'),
('2403','Bidi, khaini, gutka, other tobacco','24','Tobacco','Tobacco','Tobacco Products','KG')
ON CONFLICT (hsn_code) DO UPDATE SET
    hsn_description = EXCLUDED.hsn_description,
    cpg_category = EXCLUDED.cpg_category,
    updated_at = NOW();

-- GST Rates for CPG Products (CGST + SGST = IGST)
INSERT INTO gst.gst_rate_master
    (hsn_code, cgst_rate, sgst_rate, igst_rate, cess_rate, supply_category, notification_ref)
VALUES
-- 0% (Nil-rated)
('0401',0,0,0,0,'NIL_RATED','Sch-I Nil Rated'),  -- Fresh milk
('0403',0,0,0,0,'NIL_RATED','Sch-I Nil Rated'),  -- Curd/lassi
('1001',0,0,0,0,'NIL_RATED','Sch-I Nil Rated'),  -- Wheat (unbranded)
('1006',0,0,0,0,'NIL_RATED','Sch-I Nil Rated'),  -- Rice (unbranded)
('1101',0,0,0,0,'NIL_RATED','Sch-I Nil Rated'),  -- Atta (unbranded)
('1701',0,0,0,0,'NIL_RATED','Sch-I Nil Rated'),  -- Sugar
-- 5% GST
('0405',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Butter
('0406',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Cheese
('0902',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Tea
('0901',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Coffee
('1507',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Soybean oil
('1511',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Palm oil
('1512',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Sunflower oil
('1904',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Cornflakes/poha
('2009',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Fruit juices
('2201',2.5,2.5,5,0,'TAXABLE','Sch-II 5%'),      -- Mineral water
-- 12% GST
('1902',6,6,12,0,'TAXABLE','Sch-III 12%'),       -- Pasta, noodles
('2007',6,6,12,0,'TAXABLE','Sch-III 12%'),       -- Jams, preserves
('2103',6,6,12,0,'TAXABLE','Sch-III 12%'),       -- Sauces, ketchup
('1516',6,6,12,0,'TAXABLE','Sch-III 12%'),       -- Vanaspati
('2106',6,6,12,0,'TAXABLE','Sch-III 12%'),       -- Namkeen, bhujia
('1905',6,6,12,0,'TAXABLE','Sch-III 12%'),       -- Biscuits
-- 18% GST
('1806',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Chocolates
('1901',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Horlicks/malt extract
('2104',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Soups
('3305',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Shampoo
('3306',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Toothpaste
('3401',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Soap
('3402',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Detergents
('3304',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Cosmetics
('3307',9,9,18,0,'TAXABLE','Sch-IV 18%'),        -- Deodorants
-- 28% GST
('2202',14,14,28,0,'TAXABLE','Sch-V 28%'),       -- Aerated drinks
('1704',14,14,28,0,'TAXABLE','Sch-V 28%'),       -- Chewing gum/candy
('3303',14,14,28,0,'TAXABLE','Sch-V 28%'),       -- Perfumes
('3808',14,14,28,0,'TAXABLE','Sch-V 28%'),       -- Insecticides
-- 28% + Cess (Tobacco)
('2402',14,14,28,5,'TAXABLE','Sch-V 28%+Cess'), -- Cigarettes (5% cess)
('2403',14,14,28,0,'TAXABLE','Sch-V 28%'),       -- Bidi/khaini
('2401',14,14,28,0,'TAXABLE','Sch-V 28%')        -- Unmanufactured tobacco
ON CONFLICT DO NOTHING;
