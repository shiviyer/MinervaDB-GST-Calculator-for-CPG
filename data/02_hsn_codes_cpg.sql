-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: data/02_hsn_codes_cpg.sql
-- Description: CPG HSN code reference data with GST rate mappings
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

-- -------------------------------------------------------------------------
-- CPG HSN Code Master — Key categories for Indian CPG industry
-- -------------------------------------------------------------------------
INSERT INTO gst.hsn_code_master
    (hsn_code, hsn_description, chapter_code, chapter_description, cpg_category, cpg_sub_category, uom)
VALUES
-- Chapter 4: Dairy products
('0401',   'Milk and cream, not concentrated nor sweetened',        '04', 'Dairy Products',    'DAIRY',         'FRESH_MILK',      'LTR'),
('0402',   'Milk and cream, concentrated or sweetened',             '04', 'Dairy Products',    'DAIRY',         'CONDENSED_MILK',  'KGS'),
('0403',   'Buttermilk, curd, kefir, yogurt',                       '04', 'Dairy Products',    'DAIRY',         'CURD_YOGURT',     'KGS'),
('0405',   'Butter and other fats derived from milk',               '04', 'Dairy Products',    'DAIRY',         'BUTTER',          'KGS'),
('0406',   'Cheese and curd',                                       '04', 'Dairy Products',    'DAIRY',         'CHEESE',          'KGS'),

-- Chapter 8: Fruits and nuts
('0801',   'Coconuts, Brazil nuts and cashew nuts',                 '08', 'Fruits & Nuts',     'DRY_FRUITS',    'CASHEWS',         'KGS'),
('0802',   'Other nuts (almonds, walnuts, pistachios)',             '08', 'Fruits & Nuts',     'DRY_FRUITS',    'NUTS',            'KGS'),
('0813',   'Dried fruits and dried mixtures of nuts',              '08', 'Fruits & Nuts',     'DRY_FRUITS',    'DRIED_MIX',       'KGS'),

-- Chapter 9: Coffee, tea, spices
('0901',   'Coffee, whether or not roasted or decaffeinated',      '09', 'Coffee & Tea',      'BEVERAGES',     'COFFEE',          'KGS'),
('0902',   'Tea, whether or not flavoured',                        '09', 'Coffee & Tea',      'BEVERAGES',     'TEA',             'KGS'),
('0910',   'Ginger, saffron, turmeric, thyme, curry',              '09', 'Spices',            'SPICES',        'SPICE_MIXES',     'KGS'),

-- Chapter 10: Cereals
('1001',   'Wheat and meslin',                                     '10', 'Cereals',           'STAPLES',       'WHEAT',           'KGS'),
('1006',   'Rice',                                                  '10', 'Cereals',           'STAPLES',       'RICE',            'KGS'),

-- Chapter 11: Milled products
('1101',   'Wheat or meslin flour (atta/maida)',                   '11', 'Milled Products',   'STAPLES',       'FLOUR',           'KGS'),
('1103',   'Cereal groats, meal and pellets',                      '11', 'Milled Products',   'STAPLES',       'SEMOLINA',        'KGS'),
('1108',   'Starches; inulin (cornflour, arrowroot)',              '11', 'Milled Products',   'STAPLES',       'STARCH',          'KGS'),

-- Chapter 15: Animal/vegetable oils
('1507',   'Soya-bean oil and fractions',                          '15', 'Edible Oils',       'EDIBLE_OIL',    'SOYA_OIL',        'LTR'),
('1511',   'Palm oil and fractions',                               '15', 'Edible Oils',       'EDIBLE_OIL',    'PALM_OIL',        'LTR'),
('1512',   'Sunflower-seed or safflower oil',                      '15', 'Edible Oils',       'EDIBLE_OIL',    'SUNFLOWER_OIL',   'LTR'),
('1516',   'Hydrogenated vegetable fats (vanaspati)',              '15', 'Edible Oils',       'EDIBLE_OIL',    'VANASPATI',       'KGS'),

-- Chapter 17: Sugars
('1701',   'Cane or beet sugar and chemically pure sucrose',       '17', 'Sugars',            'SUGAR',         'REFINED_SUGAR',   'KGS'),
('1704',   'Sugar confectionery (sweets, toffees, lollipops)',     '17', 'Confectionery',     'CONFECTIONERY', 'CANDY',           'KGS'),

-- Chapter 18: Cocoa and preparations
('1801',   'Cocoa beans',                                          '18', 'Cocoa',             'CONFECTIONERY', 'COCOA_BEANS',     'KGS'),
('1805',   'Cocoa powder, not containing added sugar',            '18', 'Cocoa',             'CONFECTIONERY', 'COCOA_POWDER',    'KGS'),
('1806',   'Chocolate and other preparations containing cocoa',   '18', 'Chocolate',         'CONFECTIONERY', 'CHOCOLATE',       'KGS'),

-- Chapter 19: Cereals/pastry/biscuits
('1901',   'Malt extract; food preps of flour, groats (infant food)', '19', 'Processed Food', 'FOOD',          'INFANT_FOOD',     'KGS'),
('1902',   'Pasta, macaroni, noodles, vermicelli',                 '19', 'Processed Food',    'FOOD',          'NOODLES_PASTA',   'KGS'),
('1904',   'Prepared foods from cereals (muesli, cornflakes)',     '19', 'Processed Food',    'FOOD',          'BREAKFAST_CEREAL','KGS'),
('1905',   'Bread, pastry, cakes, biscuits, wafers, rusks',       '19', 'Biscuits & Bakery', 'BAKERY',        'BISCUITS',        'KGS'),

-- Chapter 20: Vegetables/fruit preparations
('2001',   'Vegetables, fruit, nuts preserved by vinegar',        '20', 'Preserved Food',    'FOOD',          'PICKLES',         'KGS'),
('2002',   'Tomatoes, prepared or preserved',                     '20', 'Preserved Food',    'FOOD',          'TOMATO_PRODUCTS', 'KGS'),
('2007',   'Jams, fruit jellies, marmalades',                     '20', 'Preserved Food',    'FOOD',          'JAMS_JELLIES',    'KGS'),
('2009',   'Fruit juices and vegetable juices',                   '20', 'Fruit Juices',      'BEVERAGES',     'FRUIT_JUICE',     'LTR'),

-- Chapter 21: Miscellaneous food preparations
('2101',   'Extracts, essences of coffee/tea/mate',               '21', 'Food Preps',        'BEVERAGES',     'INSTANT_COFFEE',  'KGS'),
('2103',   'Sauces and preparations; mixed condiments',           '21', 'Food Preps',        'CONDIMENTS',    'SAUCES',          'KGS'),
('2104',   'Soups and broths and preparations (instant soups)',   '21', 'Food Preps',        'FOOD',          'SOUPS',           'KGS'),
('2106',   'Food preparations not elsewhere specified (health supplements)', '21', 'Health',  'HEALTH',        'SUPPLEMENTS',     'KGS'),

-- Chapter 22: Beverages
('2201',   'Waters, including natural/artificial mineral waters',  '22', 'Beverages',         'BEVERAGES',     'PACKAGED_WATER',  'LTR'),
('2202',   'Waters with added sugar/flavour; aerated drinks',     '22', 'Beverages',         'BEVERAGES',     'AERATED_DRINKS',  'LTR'),
('2209',   'Vinegar and substitutes obtained from acetic acid',   '22', 'Condiments',        'CONDIMENTS',    'VINEGAR',         'LTR'),

-- Chapter 24: Tobacco
('2401',   'Unmanufactured tobacco; tobacco refuse',              '24', 'Tobacco',           'TOBACCO',       'RAW_TOBACCO',     'KGS'),
('2402',   'Cigars, cheroots, cigarillos and cigarettes',         '24', 'Tobacco',           'TOBACCO',       'CIGARETTES',      'NOS'),
('2403',   'Other manufactured tobacco (bidis, khaini, gutka)',   '24', 'Tobacco',           'TOBACCO',       'SMOKELESS_TOBACCO','KGS'),

-- Chapter 33: Personal care
('3301',   'Essential oils (not deterpenated)',                    '33', 'Personal Care',     'PERSONAL_CARE', 'ESSENTIAL_OILS',  'KGS'),
('3303',   'Perfumes and toilet waters',                          '33', 'Personal Care',     'PERSONAL_CARE', 'PERFUMES',        'LTR'),
('3304',   'Beauty/makeup preps and skin-care preps',             '33', 'Personal Care',     'PERSONAL_CARE', 'COSMETICS',       'KGS'),
('3305',   'Preparations for use on hair (shampoo, conditioner)', '33', 'Personal Care',     'PERSONAL_CARE', 'HAIR_CARE',       'LTR'),
('3306',   'Preparations for oral/dental hygiene (toothpaste)',   '33', 'Personal Care',     'PERSONAL_CARE', 'ORAL_CARE',       'KGS'),
('3307',   'Shaving preparations, deodorants, bath preps',        '33', 'Personal Care',     'PERSONAL_CARE', 'BODY_CARE',       'KGS'),

-- Chapter 34: Household care
('3401',   'Soap, organic surface-active products for washing',   '34', 'Household Care',    'HOUSEHOLD',     'SOAP',            'KGS'),
('3402',   'Organic surface-active agents (detergents)',          '34', 'Household Care',    'HOUSEHOLD',     'DETERGENTS',      'KGS'),
('3405',   'Polishes and creams (shoe polish, floor polish)',     '34', 'Household Care',    'HOUSEHOLD',     'POLISHES',        'KGS'),

-- Chapter 38: Chemical household products
('3808',   'Insecticides, rodenticides, disinfectants',           '38', 'Household Care',    'HOUSEHOLD',     'INSECTICIDES',    'KGS')

ON CONFLICT (hsn_code) DO UPDATE
    SET hsn_description   = EXCLUDED.hsn_description,
        chapter_code      = EXCLUDED.chapter_code,
        cpg_category      = EXCLUDED.cpg_category,
        cpg_sub_category  = EXCLUDED.cpg_sub_category,
        uom               = EXCLUDED.uom,
        updated_at        = NOW();

-- -------------------------------------------------------------------------
-- GST Rate mappings for CPG HSN codes
-- Source: CBIC GST Rate Schedule (as amended through 2024-25)
-- -------------------------------------------------------------------------
INSERT INTO gst.gst_rate_master
    (hsn_code, cgst_rate, sgst_rate, igst_rate, cess_rate, supply_category, notification_ref)
VALUES
-- 0% (NIL rated)
('0401', 0,    0,    0,    0,    'NIL_RATED',  'GST Notification 2/2017'),
('0402', 0,    0,    0,    0,    'NIL_RATED',  'GST Notification 2/2017'),
('0403', 0,    0,    0,    0,    'NIL_RATED',  'GST Notification 2/2017'),
('1001', 0,    0,    0,    0,    'NIL_RATED',  'GST Notification 2/2017'),
('1006', 0,    0,    0,    0,    'NIL_RATED',  'GST Notification 2/2017'),
('1101', 0,    0,    0,    0,    'NIL_RATED',  'GST Notification 2/2017'),
('2201', 0,    0,    0,    0,    'NIL_RATED',  'GST Notification 2/2017'),

-- 2.5%+2.5% = 5%
('0405', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('0406', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('0801', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('0802', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('0901', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('0902', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('1507', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('1511', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('1512', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('1701', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('2009', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),
('3401', 2.5,  2.5,  5,    0,    'TAXABLE',    'GST Schedule I 5%'),

-- 6%+6% = 12%
('0813', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('1516', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('1704', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('2007', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('2103', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('2104', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('1902', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('1904', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),
('1905', 6,    6,    12,   0,    'TAXABLE',    'GST Schedule II 12%'),

-- 9%+9% = 18%
('0910', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('1805', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('1806', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('1901', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('2101', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('2106', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3301', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3303', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3304', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3305', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3306', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3307', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3402', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3405', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),
('3808', 9,    9,    18,   0,    'TAXABLE',    'GST Schedule III 18%'),

-- 14%+14% = 28% + Cess
('2202', 14,   14,   28,   12,   'TAXABLE',    'GST Schedule IV 28% + 12% Cess'),
('2402', 14,   14,   28,   0,    'TAXABLE',    'GST Schedule IV 28%'),
('2403', 14,   14,   28,   0,    'TAXABLE',    'GST Schedule IV 28%')

ON CONFLICT DO NOTHING;
