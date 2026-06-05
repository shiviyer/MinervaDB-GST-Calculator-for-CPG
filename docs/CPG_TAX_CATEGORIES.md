# CPG Product Tax Categories

> **MinervaDB GST Calculator for CPG** — Complete guide to GST classification for Consumer Packaged Goods products.

---

## How to Use This Guide

1. Find your product category in the relevant table
2. Note the HSN code and GST rate
3. Enter the HSN code in `calculate_invoice_tax()` or `get_gst_rate()` to get the exact applicable rate
4. For rate confirmation, always verify with the latest CBIC notification

---

## Food and Beverages

### Dairy Products (Chapter 04)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Fresh/pasteurized milk (not concentrated) | 0401 | 0% | Nil rated |
| Skimmed milk powder | 0402 | 5% | |
| Sweetened condensed milk | 0402 | 8% | |
| Butter | 0405 | 12% | |
| Ghee | 0405 | 12% | |
| Cheese | 0406 | 12% | |
| Paneer | 0406 | 5% | |
| Curd, lassi, buttermilk | 0403 | 0% | Pre-packaged branded: 5% |
| Cream | 0401 | 5% | |
| Whey protein / sports nutrition | 2106 | 18% | Classified under food prep |

### Cereals and Flour (Chapters 10-11)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Rice (unbranded, unpackaged) | 1006 | 0% | |
| Rice (branded, packaged) | 1006 | 5% | GST on branded cereals |
| Wheat (unbranded) | 1001 | 0% | |
| Maize (corn) | 1005 | 0% | |
| Oats | 1004 | 0% | |
| Atta/wheat flour (unbranded) | 1101 | 0% | |
| Atta/wheat flour (branded) | 1101 | 5% | |
| Maida/refined flour (unbranded) | 1101 | 0% | |
| Maida/refined flour (branded) | 1101 | 5% | |
| Besan/gram flour (unbranded) | 1106 | 0% | |
| Besan/gram flour (branded) | 1106 | 5% | |
| Semolina/rava (unbranded) | 1103 | 0% | |
| Semolina/rava (branded) | 1103 | 5% | |
| Cornflakes | 1904 | 18% | |
| Muesli | 1904 | 18% | |

### Edible Oils (Chapter 15)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Groundnut oil | 1508 | 5% | |
| Soybean oil | 1507 | 5% | |
| Sunflower oil | 1512 | 5% | |
| Mustard oil | 1514 | 5% | |
| Coconut oil | 1513 | 5% | |
| Palm oil | 1511 | 5% | |
| Olive oil | 1509 | 5% | |
| Vanaspati (hydrogenated veg fat) | 1516 | 5% | |
| Refined edible oil blends | 1517 | 5% | |

### Sugar and Confectionery (Chapter 17)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Sugar (raw/refined) | 1701 | 5% | |
| Jaggery/gur | 1701 | 0% | Nil when unbranded |
| Khandsari sugar | 1701 | 5% | |
| Sugar confectionery | 1704 | 18% | Sweets, toffees, candies |
| White chocolate | 1704 | 18% | |
| Chewing gum | 1704 | 28% | |
| Bubble gum | 1704 | 28% | |

### Tea, Coffee and Spices (Chapters 09)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Tea (packet, branded) | 0902 | 5% | |
| Tea (loose, unpackaged) | 0902 | 0% | Nil |
| Coffee (roasted, ground) | 0901 | 5% | |
| Coffee (instant/soluble) | 2101 | 12% | |
| Pepper | 0904 | 5% | |
| Cardamom | 0908 | 5% | |
| Turmeric | 0910 | 5% | |
| Cumin | 0909 | 5% | |
| Coriander | 0909 | 5% | |
| Mixed spice masala (branded) | 0910 | 5% | |

### Processed and Packaged Food (Chapters 19-21)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Bread (regular, fresh) | 1905 | 0% | Nil rated |
| Bread (other than fresh) | 1905 | 5% | |
| Biscuits (MRP < Rs.100/kg) | 1905 | 5% | Reduced from 12% in Dec 2018 |
| Biscuits (MRP >= Rs.100/kg) | 1905 | 18% | Premium/specialty biscuits |
| Cakes, pastries | 1905 | 18% | |
| Wafers | 1905 | 18% | |
| Rusks | 1905 | 5% | |
| Namkeen, bhujia, mixture | 2106 | 12% | |
| Papad | 2106 | 0% | Nil rated |
| Popcorn (packaged) | 2106 | 12% | Flavored: 18% |
| Instant noodles | 1902 | 12% | |
| Pasta (uncooked) | 1902 | 12% | |
| Vermicelli (seviyan) | 1902 | 12% | |
| Breakfast cereals (cornflakes etc.) | 1904 | 18% | |
| Chips/crisps (potato) | 2005 | 12% | |
| Puffed rice | 1904 | 0% | Nil |
| Chocolates | 1806 | 18% | |
| Cocoa powder | 1805 | 18% | |
| Chocolate bars | 1806 | 18% | |
| Ice cream | 2105 | 18% | |
| Frozen desserts | 2105 | 18% | |
| Jams and jellies | 2007 | 12% | |
| Ketchup and sauces | 2103 | 12% | |
| Mayonnaise | 2103 | 12% | |
| Pickles (achar) | 2001 | 12% | |
| Soups (canned/packaged) | 2104 | 18% | |
| Instant food mixes | 2106 | 18% | Ready-to-cook mixes |
| Health/nutrition supplements | 2106 | 18% | Protein powders etc. |

### Fruits and Vegetables (Chapters 07-08)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Fresh vegetables | 0701-0714 | 0% | Nil when unprocessed |
| Fresh fruits | 0801-0814 | 0% | Nil when unprocessed |
| Dried fruits (raisins, dates etc.) | 0813 | 12% | |
| Dry nuts (almonds, cashews packaged) | 0801-0802 | 12% | |
| Fruit juices (100%) | 2009 | 12% | |
| Fruit juices (drinks with fruit content) | 2202 | 18% | |
| Canned/preserved vegetables | 2001-2006 | 12% | |
| Tomato ketchup | 2103 | 12% | |

### Meat and Fish (Chapters 02-05, 16)

| Product | HSN | GST Rate | Notes |
|---------|-----|----------|-------|
| Fresh/frozen unprocessed meat | 0201-0210 | 0% | Nil when unpackaged |
| Packaged fresh meat (branded) | 0201-0210 | 12% | Branded refrigerated |
| Fresh fish (unpackaged) | 0301-0305 | 0% | Nil |
| Packaged/processed fish | 0301-0305 | 5%-12% | Varies |
| Processed meat products (sausages) | 1601 | 12% | |
| Eggs (fresh) | 0407 | 0% | Nil |

### Beverages (Chapter 22)

| Product | HSN | GST Rate | Cess | Total |
|---------|-----|----------|------|-------|
| Packaged drinking water (<20L) | 2201 | 18% | 0% | 18% |
| Mineral water (packaged) | 2201 | 18% | 0% | 18% |
| 100% fruit juice | 2009 | 12% | 0% | 12% |
| Fruit drinks (< 100% fruit) | 2202 | 18% | 0% | 18% |
| Aerated water (plain soda) | 2201 | 12% | 0% | 12% |
| Aerated soft drinks with sugar | 2202 | 28% | 12% | 40% |
| Cola drinks | 2202 | 28% | 12% | 40% |
| Energy drinks | 2202 | 28% | 12% | 40% |
| Ready-to-drink tea/coffee (canned) | 2202 | 12% | 0% | 12% |
| Alcoholic beverages | Not GST | State Excise | N/A | N/A |

---

## Personal Care

| Product | HSN | GST Rate |
|---------|-----|----------|
| Soap (toilet, bathing) | 3401 | 18% |
| Handwash (liquid soap) | 3401 | 18% |
| Shampoo | 3305 | 18% |
| Hair conditioner | 3305 | 18% |
| Hair oil | 1515 | 18% |
| Hair dye / colour | 3305 | 18% |
| Toothpaste | 3306 | 18% |
| Toothbrush | 9603 | 18% |
| Face wash / cleanser | 3304 | 18% |
| Moisturizer / skin cream | 3304 | 18% |
| Sunscreen / sun protection | 3304 | 18% |
| Lip balm / lipstick | 3304 | 28% | Premium cosmetics |
| Deodorant / anti-perspirant | 3307 | 18% |
| Perfume / cologne | 3303 | 18% |
| Talcum powder | 3307 | 18% |
| Sanitary pads / napkins | 3004 | 0% | Nil (reduced in July 2018) |
| Tampons | 3004 | 0% | Nil |
| Baby diapers | 9619 | 12% | |
| Baby wipes | 3401 | 12% | |
| Razors (disposable) | 8212 | 18% | |
| Shaving cream | 3307 | 18% | |

---

## Household and Cleaning

| Product | HSN | GST Rate |
|---------|-----|----------|
| Detergent powder | 3402 | 18% |
| Detergent liquid | 3402 | 18% |
| Dish wash / utensil cleaner | 3402 | 18% |
| Floor cleaner | 3402 | 18% |
| Toilet cleaner | 3402 | 18% |
| Bathroom disinfectant | 3808 | 18% |
| Surface disinfectant / sanitizer | 3808 | 18% |
| Air freshener | 3307 | 18% |
| Phenyl / phenol-based cleaners | 3402 | 18% |
| Mosquito repellent (liquid, mat) | 3808 | 18% |
| Cockroach spray / insecticide | 3808 | 18% |
| Scrubbers / scouring pads | 3401 | 18% |

---

## Tobacco and Related (Chapter 24)

> **Note:** Tobacco products attract both GST and National Calamity Contingent Duty (NCCD). Rates change frequently — always verify with latest CBIC notification.

| Product | HSN | GST | Cess | Effective Rate |
|---------|-----|-----|------|----------------|
| Cigarettes (length <= 65mm) | 2402 | 28% | Rs. 2.76/stick + 5% | 28%+ |
| Cigarettes (length 65-75mm) | 2402 | 28% | Rs. 4.17/stick + 36% | 64%+ |
| Cigarettes (length > 75mm) | 2402 | 28% | Rs. 5.10/stick + 36% | 64%+ |
| Bidis | 2402 | 28% | Rs. 16/1000 | 28%+ |
| Pan masala (without tobacco) | 2106 | 28% | 60% | 88% |
| Pan masala (with tobacco) | 2403 | 28% | 204% | 232%+ |
| Gutkha (chewing tobacco with lime) | 2403 | 28% | 204% | 232%+ |
| Loose tobacco (unmanufactured) | 2401 | 28% | N/A | 28% |
| Hookah tobacco / shisha | 2403 | 28% | 72% | 100% |

---

## Special Cases and Clarifications

### Branded vs. Unbranded

Many food items have differential rates based on branding:
- **0% (Nil)** when sold loose / unbranded / without a registered brand name
- **5%** when sold in sealed/packaged form with a registered brand name

Key items affected: Rice, wheat, cereals, flour (atta, maida, besan), curd, lassi, paneer

**Brand waiver**: A registered brand owner can voluntarily waive their brand rights and declare in writing. In that case, 0% may apply even to packaged goods. This requires an affidavit.

### Composite Supply

When a CPG gift pack or combo contains items of different GST rates:
- **Composite supply**: The entire supply is taxed at the rate of the **principal supply** (the dominant product)
- **Mixed supply**: The entire supply is taxed at the **highest rate** among the components

Example: A Diwali gift pack with chocolates (18%), ghee (12%), and dry fruits (12%)
- If sold as a composite supply: 18% (principal supply = chocolates)
- If sold as a mixed supply: 18% (highest rate)

### Trade Discounts

- Post-sale trade discounts where credit note is issued: Reduce taxable value
- Volume discounts reflected on invoice: Reduce taxable value
- Discounts given after supply (not known at time of supply): No GST adjustment unless GSTR-1 amendment with credit note

### Free of Cost (FoC) Goods

When goods are supplied free as part of trade promotions:
- If FoC goods are of the same nature as sold goods: No separate GST on FoC
- If FoC is a different product: Taxable as gift supply at fair market value

---

## HSN Code Quick Reference

```
02xx  -- Meat and edible offal
03xx  -- Fish, crustaceans
04xx  -- Dairy products, eggs, honey
07xx  -- Vegetables
08xx  -- Fruits and nuts
09xx  -- Coffee, tea, spices
10xx  -- Cereals
11xx  -- Milling products (flour, starch)
15xx  -- Animal/vegetable fats and oils
17xx  -- Sugars and confectionery
18xx  -- Cocoa and chocolate
19xx  -- Preparations of cereals, flour (biscuits, pasta, bread)
20xx  -- Preparations of vegetables, fruits
21xx  -- Miscellaneous edible preparations
22xx  -- Beverages, spirits
24xx  -- Tobacco
33xx  -- Essential oils, cosmetics, perfumery
34xx  -- Soap, detergents
38xx  -- Disinfectants, insecticides
```

---

## API Usage Examples

### Get rate for a specific product

```bash
# Biscuits (HSN 1905)
curl -X POST http://localhost:3000/rpc/get_gst_rate \
  -H 'Content-Type: application/json' \
  -d '{"p_hsn_code": "1905", "p_as_of_date": "2025-06-01"}'

# Packaged atta (HSN 1101)
curl -X POST http://localhost:3000/rpc/get_gst_rate \
  -H 'Content-Type: application/json' \
  -d '{"p_hsn_code": "1101", "p_as_of_date": "2025-06-01"}'
```

### Search by product description

```bash
curl -X POST http://localhost:3000/rpc/lookup_hsn_for_product \
  -H 'Content-Type: application/json' \
  -d '{"p_keyword": "chocolate"}'
```

### Calculate tax for a CPG order

```bash
curl -X POST http://localhost:3000/rpc/calculate_invoice_tax \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "p_seller_gstin":   "27AABCU9603R1ZX",
    "p_buyer_gstin":    "29BBBCA1234C1Z5",
    "p_hsn_code":       "1905",
    "p_supply_value":   50000.00,
    "p_seller_state":   "MH",
    "p_buyer_state":    "KA",
    "p_transaction_dt": "2025-06-01"
  }'
```

---

*This guide reflects GST rates as of June 2025. Always verify with the latest GST Council decisions and CBIC notifications before applying rates to actual business transactions.*
