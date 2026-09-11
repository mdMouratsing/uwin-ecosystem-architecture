/*
# Voucher Architecture

1. Purpose
This migration creates reusable voucher entities. Vouchers are distinct from
promo codes/coupons and from loyalty rewards. Supports monetary, percentage,
fixed-discount, product, service, restaurant, gift, and promotional voucher types.

2. New Tables
- `voucher_templates` — template defining a voucher's properties and rules
- `voucher_batches` — a batch of vouchers issued from a template
- `vouchers` — individual issued vouchers with unique codes
- `voucher_redemptions` — records of voucher usage
- `voucher_rules` — additional rules attached to a template

3. Security
- RLS enabled on all tables.
- Users can read vouchers assigned to them and their redemption history.
- Voucher templates are readable by authenticated users (for browsing available offers).
- No INSERT/UPDATE/DELETE for regular users on vouchers — issuance and redemption
  go through SECURITY DEFINER functions.
*/

-- ---------------------------------------------------------------------------
-- Voucher Templates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS voucher_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  voucher_type text NOT NULL CHECK (voucher_type IN ('monetary','percentage','fixed_discount','product','service','restaurant','gift','promotional')),
  face_value numeric(18,2),
  discount_percentage numeric(5,2),
  currency_code text NOT NULL DEFAULT 'MUR',
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  campaign_id uuid,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_until timestamptz NOT NULL,
  max_redemptions integer,
  min_spend numeric(18,2),
  category_restrictions text[] NOT NULL DEFAULT ARRAY[]::text[],
  merchant_restrictions uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  terms_and_conditions text,
  image_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE voucher_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "voucher_templates_select_authenticated" ON voucher_templates;
CREATE POLICY "voucher_templates_select_authenticated" ON voucher_templates FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Voucher Batches
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS voucher_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES voucher_templates(id) ON DELETE CASCADE,
  batch_number text NOT NULL,
  quantity integer NOT NULL,
  issued_count integer NOT NULL DEFAULT 0,
  redeemed_count integer NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE voucher_batches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "voucher_batches_select_authenticated" ON voucher_batches;
CREATE POLICY "voucher_batches_select_authenticated" ON voucher_batches FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Vouchers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vouchers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES voucher_templates(id) ON DELETE CASCADE,
  code text UNIQUE NOT NULL,
  qr_code text,
  voucher_type text NOT NULL CHECK (voucher_type IN ('monetary','percentage','fixed_discount','product','service','restaurant','gift','promotional')),
  face_value numeric(18,2),
  discount_percentage numeric(5,2),
  currency_code text NOT NULL DEFAULT 'MUR',
  assigned_to_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'issued' CHECK (status IN ('issued','active','redeemed','expired','cancelled')),
  issued_at timestamptz DEFAULT now(),
  redeemed_at timestamptz,
  expired_at timestamptz,
  batch_id uuid REFERENCES voucher_batches(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vouchers_select_own" ON vouchers;
CREATE POLICY "vouchers_select_own" ON vouchers FOR SELECT
  TO authenticated USING (auth.uid() = assigned_to_user_id);

-- No INSERT/UPDATE/DELETE for regular users — voucher issuance and status
-- changes go through SECURITY DEFINER functions.

-- ---------------------------------------------------------------------------
-- Voucher Redemptions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS voucher_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  voucher_id uuid NOT NULL REFERENCES vouchers(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  transaction_amount numeric(18,2),
  discount_applied numeric(18,2),
  redeemed_at timestamptz DEFAULT now(),
  application_code text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE voucher_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "voucher_redemptions_select_own" ON voucher_redemptions;
CREATE POLICY "voucher_redemptions_select_own" ON voucher_redemptions FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Voucher Rules
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS voucher_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES voucher_templates(id) ON DELETE CASCADE,
  rule_key text NOT NULL,
  conditions jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE voucher_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "voucher_rules_select_authenticated" ON voucher_rules;
CREATE POLICY "voucher_rules_select_authenticated" ON voucher_rules FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_voucher_templates_merchant_id ON voucher_templates(merchant_id);
CREATE INDEX IF NOT EXISTS idx_voucher_templates_status ON voucher_templates(status);
CREATE INDEX IF NOT EXISTS idx_voucher_templates_valid_until ON voucher_templates(valid_until);
CREATE INDEX IF NOT EXISTS idx_voucher_batches_template_id ON voucher_batches(template_id);
CREATE INDEX IF NOT EXISTS idx_vouchers_template_id ON vouchers(template_id);
CREATE INDEX IF NOT EXISTS idx_vouchers_assigned_to_user_id ON vouchers(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_vouchers_status ON vouchers(status);
CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_voucher_id ON voucher_redemptions(voucher_id);
CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_user_id ON voucher_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_voucher_rules_template_id ON voucher_rules(template_id);
