-- =============================================================================
-- MinervaDB GST Calculator for CPG
-- File: data/03_state_codes.sql
-- Description: Indian state and UT codes seed data (GST state codes)
-- Brand: MinervaDB GST Calculator for CPG
-- License: MIT
-- =============================================================================

SET search_path TO gst, public;

INSERT INTO gst.state_master (state_code, gst_state_code, state_name, union_territory) VALUES
('JK', '01', 'Jammu and Kashmir',             FALSE),
('HP', '02', 'Himachal Pradesh',               FALSE),
('PB', '03', 'Punjab',                         FALSE),
('CH', '04', 'Chandigarh',                     TRUE),
('UT', '05', 'Uttarakhand',                    FALSE),
('HR', '06', 'Haryana',                        FALSE),
('DL', '07', 'Delhi',                          TRUE),
('RJ', '08', 'Rajasthan',                      FALSE),
('UP', '09', 'Uttar Pradesh',                  FALSE),
('BR', '10', 'Bihar',                          FALSE),
('SK', '11', 'Sikkim',                         FALSE),
('AR', '12', 'Arunachal Pradesh',              FALSE),
('NL', '13', 'Nagaland',                       FALSE),
('MN', '14', 'Manipur',                        FALSE),
('ML', '15', 'Meghalaya',                      FALSE),
('AS', '18', 'Assam',                          FALSE),
('WB', '19', 'West Bengal',                    FALSE),
('JH', '20', 'Jharkhand',                      FALSE),
('OD', '21', 'Odisha',                         FALSE),
('CT', '22', 'Chhattisgarh',                   FALSE),
('MP', '23', 'Madhya Pradesh',                 FALSE),
('GJ', '24', 'Gujarat',                        FALSE),
('DD', '26', 'Dadra and Nagar Haveli and Daman and Diu', TRUE),
('MH', '27', 'Maharashtra',                    FALSE),
('AP', '28', 'Andhra Pradesh',                 FALSE),
('KA', '29', 'Karnataka',                      FALSE),
('GA', '30', 'Goa',                            FALSE),
('LA', '31', 'Lakshadweep',                    TRUE),
('KL', '32', 'Kerala',                         FALSE),
('TN', '33', 'Tamil Nadu',                     FALSE),
('PY', '34', 'Puducherry',                     TRUE),
('AN', '35', 'Andaman and Nicobar Islands',     TRUE),
('TS', '36', 'Telangana',                      FALSE),
('AP', '37', 'Andhra Pradesh (New)',            FALSE),
('LD', '31', 'Ladakh',                         TRUE),
('MZ', '15', 'Mizoram',                        FALSE),
('TR', '16', 'Tripura',                        FALSE),
('MG', '17', 'Meghalaya (alternate)',           FALSE)
ON CONFLICT (state_code) DO UPDATE
    SET state_name      = EXCLUDED.state_name,
        union_territory = EXCLUDED.union_territory,
        gst_state_code  = EXCLUDED.gst_state_code;

-- Correct duplicates — keep canonical set
DELETE FROM gst.state_master WHERE state_code = 'MG';

COMMENT ON TABLE gst.state_master IS 'Indian state/UT master with GST 2-digit state codes per GSTIN format.';
