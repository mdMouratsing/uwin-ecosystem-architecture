/*
# Coupon / Promo Code Shared Platform Tables

1. Purpose
This migration adds coupon/promo code infrastructure to the shared platform.
Coupons are distinct from vouchers (which are digital instruments with unique
codes assigned to users) and from loyalty rewards (which are points earned
through the Rewards Engine). Coupons are promotional codes applied at checkout
for a discount — they can be multi-use, time-limited, and category/merchant
restricted.

2. New Tables
- `coupon_templates` — template defining a coupon's properties (discount type,
  value, validity, usage limits, restrictions)
- `coupons` — individual coupon codes (can be single-use or multi-use)
- `coupon_redemptions` — records of coupon usage at checkout

3. Security
- RLS enabled on all tables.
- Coupon templates are readable by all authenticated users (for displaying
  available offers in consumer apps).
- Coupons are readable by the user they're assigned to (if single-use assigned).
- Coupon redemptions are readable by the redeeming user.
- No INSERT/UPDATE/DELETE for regular users — coupon issuance and redemption
  go through SECURITY DEFINER functions.

4. Relationship to Vouchers
- Vouchers: digital instrument with unique code, assigned to a user, has face
  value or discount, redeemed at merchant. Stored in `vouchers` table.
- Coupons: promotional code applied at checkout for a discount. Can be multi-use.
  Stored in `coupons` table. NOT assigned to a specific user (unless single-use).
- Loyalty Rewards: points earned through Rewards Engine, stored as
  reward_transactions. Not a coupon or voucher.
*/

-- ---------------------------------------------------------------------------
-- Coupon Templates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupon_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  coupon_type text NOT NULL CHECK (coupon_type IN ('percentage','fixed_discount','free_shipping','buy_one_get_one','fixed_amount_off')),
  discount_value numeric(18,2) NOT NULL,
  discount_percentage numeric(5,2),
  currency_code text NOT NULL DEFAULT 'MUR',
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  campaign_id uuid,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_until timestamptz NOT NULL,
  max_total_redemptions integer,
  max_redemptions_per_user integer NOT NULL DEFAULT 1,
  min_spend numeric(18,2),
  max_discount numeric(18,2),
  category_restrictions text[] NOT NULL DEFAULT ARRAY[]::text[],
  merchant_restrictions uuid[] NOT NULL DEFAULT ARRAY[]::uuid[],
  terms_and_conditions text,
  is_multi_use boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE coupon_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coupon_templates_select_authenticated" ON coupon_templates;
CREATE POLICY "coupon_templates_select_authenticated" ON coupon_templates FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Coupons (individual codes)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id uuid NOT NULL REFERENCES coupon_templates(id) ON DELETE CASCADE,
  code text UNIQUE NOT NULL,
  coupon_type text NOT NULL CHECK (coupon_type IN ('percentage','fixed_discount','free_shipping','buy_one_get_one','fixed_amount_off')),
  discount_value numeric(18,2) NOT NULL,
  discount_percentage numeric(5,2),
  currency_code text NOT NULL DEFAULT 'MUR',
  assigned_to_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  is_single_use boolean NOT NULL DEFAULT true,
  times_used integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('issued','active','redeemed','expired','cancelled')),
  issued_at timestamptz DEFAULT now(),
  first_used_at timestamptz,
  last_used_at timestamptz,
  expired_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coupons_select_own" ON coupons;
CREATE POLICY "coupons_select_own" ON coupons FOR SELECT
  TO authenticated USING (auth.uid() = assigned_to_user_id OR assigned_to_user_id IS NULL);

-- No INSERT/UPDATE/DELETE for regular users

-- ---------------------------------------------------------------------------
-- Coupon Redemptions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupon_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id uuid NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  order_amount numeric(18,2),
  discount_applied numeric(18,2),
  application_code text,
  redeemed_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE coupon_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coupon_redemptions_select_own" ON coupon_redemptions;
CREATE POLICY "coupon_redemptions_select_own" ON coupon_redemptions FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users

-- ---------------------------------------------------------------------------
-- Coupon Redemption Function (SECURITY DEFINER)
-- Validates coupon eligibility, records redemption, increments usage counter
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION redeem_coupon(
  p_coupon_code text,
  p_user_id uuid,
  p_merchant_id uuid DEFAULT NULL,
  p_order_amount numeric DEFAULT NULL,
  p_application_code text DEFAULT 'uwin'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_coupon record;
  v_template record;
  v_discount numeric(18,2);
  v_redemption_id uuid;
BEGIN
  -- Fetch coupon
  SELECT * INTO v_coupon FROM coupons WHERE code = p_coupon_code AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Coupon not found or not active';
  END IF;

  -- Fetch template
  SELECT * INTO v_template FROM coupon_templates WHERE id = v_coupon.template_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Coupon template not found';
  END IF;

  -- Check validity period
  IF now() < v_template.valid_from OR now() > v_template.valid_until THEN
    RAISE EXCEPTION 'Coupon is not within its validity period';
  END IF;

  -- Check max total redemptions
  IF v_template.max_total_redemptions IS NOT NULL AND v_coupon.times_used >= v_template.max_total_redemptions THEN
    RAISE EXCEPTION 'Coupon has reached its maximum total redemptions';
  END IF;

  -- Check single-use
  IF v_coupon.is_single_use AND v_coupon.times_used >= 1 THEN
    RAISE EXCEPTION 'Coupon has already been used';
  END IF;

  -- Check min spend
  IF v_template.min_spend IS NOT NULL AND p_order_amount IS NOT NULL AND p_order_amount < v_template.min_spend THEN
    RAISE EXCEPTION 'Order amount does not meet minimum spend requirement';
  END IF;

  -- Calculate discount
  IF v_coupon.coupon_type = 'percentage' THEN
    v_discount := p_order_amount * v_coupon.discount_percentage / 100;
    IF v_template.max_discount IS NOT NULL AND v_discount > v_template.max_discount THEN
      v_discount := v_template.max_discount;
    END IF;
  ELSIF v_coupon.coupon_type IN ('fixed_discount', 'fixed_amount_off') THEN
    v_discount := v_coupon.discount_value;
  ELSIF v_coupon.coupon_type = 'free_shipping' THEN
    v_discount := 0; -- Shipping discount handled by app
  ELSE
    v_discount := v_coupon.discount_value;
  END IF;

  -- Record redemption
  INSERT INTO coupon_redemptions (coupon_id, user_id, merchant_id, order_amount, discount_applied, application_code)
  VALUES (v_coupon.id, p_user_id, p_merchant_id, p_order_amount, v_discount, p_application_code)
  RETURNING id INTO v_redemption_id;

  -- Increment usage
  UPDATE coupons
  SET times_used = times_used + 1,
      last_used_at = now(),
      first_used_at = COALESCE(first_used_at, now()),
      status = CASE WHEN is_single_use THEN 'redeemed' ELSE status END
  WHERE id = v_coupon.id;

  RETURN jsonb_build_object(
    'redemption_id', v_redemption_id,
    'discount_applied', v_discount,
    'coupon_code', v_coupon.code,
    'coupon_type', v_coupon.coupon_type
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION redeem_coupon FROM anon;
GRANT EXECUTE ON FUNCTION redeem_coupon TO authenticated;

-- ---------------------------------------------------------------------------
-- Update integration_configs: set FCM as push notification provider
-- ---------------------------------------------------------------------------
UPDATE integration_configs
SET provider = 'Firebase Cloud Messaging', is_active = true, updated_at = now()
WHERE integration_key = 'push_notification';

-- ---------------------------------------------------------------------------
-- Update integration_configs: set OAuth as webhook signing protocol
-- ---------------------------------------------------------------------------
UPDATE integration_configs
SET configuration = jsonb_build_object('signing_protocol', 'oauth2', 'algorithm', 'HMAC-SHA256'),
    updated_at = now()
WHERE integration_key = 'push_notification';

-- Add webhook_signing integration config
INSERT INTO integration_configs (integration_key, name, provider, configuration, is_active)
SELECT 'webhook_signing', 'Webhook Signing Service', 'Internal',
       jsonb_build_object('signing_protocol', 'oauth2', 'algorithm', 'HMAC-SHA256', 'token_endpoint', '/api/v1/auth/token'),
       true
WHERE NOT EXISTS (SELECT 1 FROM integration_configs WHERE integration_key = 'webhook_signing');

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_coupon_templates_merchant_id ON coupon_templates(merchant_id);
CREATE INDEX IF NOT EXISTS idx_coupon_templates_status ON coupon_templates(status);
CREATE INDEX IF NOT EXISTS idx_coupon_templates_valid_until ON coupon_templates(valid_until);
CREATE INDEX IF NOT EXISTS idx_coupons_template_id ON coupons(template_id);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_assigned_to_user_id ON coupons(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_coupons_status ON coupons(status);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_coupon_id ON coupon_redemptions(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_user_id ON coupon_redemptions(user_id);
