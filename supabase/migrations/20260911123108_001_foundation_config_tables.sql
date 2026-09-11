/*
# Foundation Configuration Tables

1. Purpose
This migration creates the foundational lookup and configuration tables that the
rest of the uWin & RetailFlow platform schema depends on. These tables define
countries, currencies, languages, the application/channel registry, and feature
flags. No user-facing data is stored here — these are platform-level reference
data that all future apps and services will read.

2. New Tables
- `currencies` — supported currencies (MUR, EUR, MGA, SCR, USD)
- `countries` — supported countries (Mauritius first, then Réunion, Madagascar, Seychelles)
- `languages` — supported languages (English, French)
- `applications` — registry of all ecosystem applications/channels (uWin, RetailFlow, etc.)
- `feature_flags` — platform-level feature toggles

3. Security
- RLS enabled on all tables.
- These are reference/config tables that authenticated admin users need to read.
- SELECT is granted to authenticated users (read-only reference data).
- No INSERT/UPDATE/DELETE policies for authenticated users — all writes go through
  SECURITY DEFINER functions or direct service-role access (future admin functions).

4. Seed Data
- Currencies: MUR, EUR, MGA, SCR, USD
- Countries: Mauritius (MU), Réunion (RE), Madagascar (MG), Seychelles (SC)
- Languages: English (en), French (fr)
- Applications: platform_admin, uwin, uwin_rewards, uwin_market, uwin_services,
  uwin_travel, uwin_business, uwin_resto, retailflow, retailflow_resto
- Feature flags: rewards_enabled, wallet_enabled, vouchers_enabled, campaigns_enabled,
  notifications_enabled, merchant_directory_enabled, analytics_enabled, multi_country_enabled
*/

-- ---------------------------------------------------------------------------
-- Currencies
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS currencies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  symbol text NOT NULL,
  decimal_places integer NOT NULL DEFAULT 2,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "currencies_select_authenticated" ON currencies;
CREATE POLICY "currencies_select_authenticated" ON currencies FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Countries
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS countries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  currency_code text NOT NULL REFERENCES currencies(code),
  currency_symbol text NOT NULL,
  timezone text NOT NULL,
  phone_prefix text NOT NULL,
  date_format text NOT NULL DEFAULT 'DD/MM/YYYY',
  supported_languages text[] NOT NULL DEFAULT ARRAY['en'],
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE countries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "countries_select_authenticated" ON countries;
CREATE POLICY "countries_select_authenticated" ON countries FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Languages
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS languages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  native_name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE languages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "languages_select_authenticated" ON languages;
CREATE POLICY "languages_select_authenticated" ON languages FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Applications (Channel Registry)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  type text NOT NULL CHECK (type IN ('consumer', 'business', 'admin')),
  icon text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  supported_capabilities text[] NOT NULL DEFAULT ARRAY[]::text[],
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "applications_select_authenticated" ON applications;
CREATE POLICY "applications_select_authenticated" ON applications FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Feature Flags
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feature_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text UNIQUE NOT NULL,
  description text,
  is_enabled boolean NOT NULL DEFAULT true,
  scope text NOT NULL DEFAULT 'platform' CHECK (scope IN ('platform','country','tenant','application')),
  scope_ref text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "feature_flags_select_authenticated" ON feature_flags;
CREATE POLICY "feature_flags_select_authenticated" ON feature_flags FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Seed: Currencies
-- ---------------------------------------------------------------------------
INSERT INTO currencies (code, name, symbol, decimal_places) VALUES
  ('MUR', 'Mauritian Rupee', 'Rs', 2),
  ('EUR', 'Euro', '€', 2),
  ('MGA', 'Malagasy Ariary', 'Ar', 2),
  ('SCR', 'Seychellois Rupee', 'Sr', 2),
  ('USD', 'US Dollar', '$', 2)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed: Countries
-- ---------------------------------------------------------------------------
INSERT INTO countries (code, name, currency_code, currency_symbol, timezone, phone_prefix, supported_languages, is_active) VALUES
  ('MU', 'Mauritius', 'MUR', 'Rs', 'Indian/Mauritius', '+230', ARRAY['en','fr'], true),
  ('RE', 'Réunion', 'EUR', '€', 'Indian/Reunion', '+262', ARRAY['en','fr'], true),
  ('MG', 'Madagascar', 'MGA', 'Ar', 'Indian/Antananarivo', '+261', ARRAY['en','fr'], true),
  ('SC', 'Seychelles', 'SCR', 'Sr', 'Indian/Mahe', '+248', ARRAY['en','fr'], true)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed: Languages
-- ---------------------------------------------------------------------------
INSERT INTO languages (code, name, native_name, is_active) VALUES
  ('en', 'English', 'English', true),
  ('fr', 'French', 'Français', true)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed: Applications
-- ---------------------------------------------------------------------------
INSERT INTO applications (code, name, description, type, icon, status, supported_capabilities, sort_order) VALUES
  ('platform_admin', 'Platform Admin', 'IDS internal administration environment', 'admin', 'shield', 'active', ARRAY['administration','analytics'], 0),
  ('uwin', 'uWin', 'Consumer super-app entry point', 'consumer', 'sparkles', 'active', ARRAY['wallet','rewards','vouchers','campaigns','notifications'], 1),
  ('uwin_rewards', 'uWin Rewards', 'Loyalty and rewards experience', 'consumer', 'award', 'active', ARRAY['rewards','vouchers','campaigns','notifications'], 2),
  ('uwin_market', 'uWin Market', 'Marketplace for products', 'consumer', 'shopping-bag', 'active', ARRAY['shopping','wallet','rewards','vouchers','campaigns','notifications'], 3),
  ('uwin_services', 'uWin Services', 'Service bookings and providers', 'consumer', 'wrench', 'active', ARRAY['services','bookings','wallet','rewards','notifications'], 4),
  ('uwin_travel', 'uWin Travel', 'Travel planning and bookings', 'consumer', 'plane', 'active', ARRAY['travel','bookings','wallet','rewards','vouchers','notifications'], 5),
  ('uwin_resto', 'uWin Resto', 'Restaurant discovery and ordering', 'consumer', 'utensils', 'active', ARRAY['restaurant','bookings','wallet','rewards','vouchers','notifications'], 6),
  ('uwin_business', 'uWin Business', 'Merchant operational dashboard', 'business', 'briefcase', 'active', ARRAY['merchant_management','rewards','campaigns','analytics'], 7),
  ('retailflow', 'RetailFlow', 'Retail management and logistics', 'business', 'store', 'active', ARRAY['merchant_management','analytics','campaigns'], 8),
  ('retailflow_resto', 'RetailFlow Resto', 'Restaurant POS and operations', 'business', 'chef-hat', 'active', ARRAY['restaurant','merchant_management','analytics'], 9)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed: Feature Flags
-- ---------------------------------------------------------------------------
INSERT INTO feature_flags (key, description, is_enabled, scope) VALUES
  ('rewards_enabled', 'Enable the rewards engine across the platform', true, 'platform'),
  ('wallet_enabled', 'Enable the universal wallet', true, 'platform'),
  ('vouchers_enabled', 'Enable voucher issuance and redemption', true, 'platform'),
  ('campaigns_enabled', 'Enable the campaign engine', true, 'platform'),
  ('notifications_enabled', 'Enable the notification service', true, 'platform'),
  ('merchant_directory_enabled', 'Enable the merchant directory', true, 'platform'),
  ('analytics_enabled', 'Enable analytics event collection', true, 'platform'),
  ('multi_country_enabled', 'Allow multiple countries (disable to lock to Mauritius)', false, 'platform')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_countries_currency_code ON countries(currency_code);
CREATE INDEX IF NOT EXISTS idx_applications_type ON applications(type);
CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_feature_flags_scope ON feature_flags(scope);
