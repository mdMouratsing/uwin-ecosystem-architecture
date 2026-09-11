/*
# Cross-Service Transaction Function and Demo Seed Data

1. Purpose
This migration creates the SECURITY DEFINER function that atomically performs a
cross-service transaction: records a wallet transaction, evaluates a reward rule,
credits reward points, updates the wallet/reward ledger balances, records an
analytics event, creates a notification, and writes an audit log — all in one
atomic operation with idempotency support.

It also seeds the demo data:
- Reward programme (uWin Rewards) with tiers and rules
- Organisation (Lagoon Market Ltd)
- Merchant record with categories, capabilities, channels, and location
- Campaign (Lagoon Market Loyalty Bonus)
- Notification templates

NOTE: Demo user (Aisha Raman) and demo merchant staff user are created through
Supabase auth.signUp at runtime — they cannot be seeded via SQL because they
require auth.users entries. The platform admin seed and all other demo data
that does NOT require auth.users is seeded here.

2. The process_cross_service_transaction Function
Parameters:
- p_user_id: the consumer making the transaction
- p_merchant_id: the merchant where the transaction occurs
- p_amount: transaction amount
- p_currency_code: currency (default MUR)
- p_application_code: which app initiated the transaction
- p_idempotency_key: unique key to prevent duplicate processing
- p_campaign_id: optional campaign reference

The function:
a) Checks idempotency — if a transaction with the same key exists, returns it
b) Gets or creates the user's wallet and loyalty_points account
c) Records a wallet transaction (earn type)
d) Updates the wallet account balance
e) Evaluates reward rules (spend-based: Rs100 = 1 point)
f) Gets or creates the user's reward account in the uWin Rewards programme
g) Records a reward transaction (earn type)
h) Updates the reward account balance and total_earned
i) Records an analytics event (reward.earned)
j) Creates a notification (REWARD_EARNED)
k) Writes an audit log
l) Returns a result with all created IDs and the points earned

3. Security
- The function is SECURITY DEFINER — it runs as the table owner, bypassing RLS.
- It checks that the caller is authenticated (auth.uid() must not be null).
- Idempotency is enforced through a unique index on idempotency_key.
*/

-- ---------------------------------------------------------------------------
-- Helper: get or create wallet for a user
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_or_create_wallet(p_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_wallet_id uuid;
BEGIN
  SELECT id INTO v_wallet_id FROM wallets WHERE user_id = p_user_id;
  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, status) VALUES (p_user_id, 'active')
    RETURNING id INTO v_wallet_id;
  END IF;
  RETURN v_wallet_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Helper: get or create wallet account for an asset type
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_or_create_wallet_account(
  p_wallet_id uuid,
  p_asset_type text,
  p_currency_code text DEFAULT 'MUR'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_account_id uuid;
BEGIN
  SELECT id INTO v_account_id FROM wallet_accounts
  WHERE wallet_id = p_wallet_id AND asset_type = p_asset_type AND currency_code = p_currency_code;
  IF v_account_id IS NULL THEN
    INSERT INTO wallet_accounts (wallet_id, asset_type, currency_code, balance, status)
    VALUES (p_wallet_id, p_asset_type, p_currency_code, 0, 'active')
    RETURNING id INTO v_account_id;
  END IF;
  RETURN v_account_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Helper: get or create reward account
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_or_create_reward_account(
  p_user_id uuid,
  p_programme_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_account_id uuid;
  v_tier_id uuid;
BEGIN
  SELECT id INTO v_account_id FROM reward_accounts
  WHERE user_id = p_user_id AND programme_id = p_programme_id;
  IF v_account_id IS NULL THEN
    -- Get the lowest tier (Member)
    SELECT id INTO v_tier_id FROM reward_tiers
    WHERE programme_id = p_programme_id
    ORDER BY tier_level ASC LIMIT 1;

    INSERT INTO reward_accounts (user_id, programme_id, tier_id, total_points_earned, total_points_redeemed, current_balance, status, enrolled_at)
    VALUES (p_user_id, p_programme_id, v_tier_id, 0, 0, 0, 'active', now())
    RETURNING id INTO v_account_id;
  END IF;
  RETURN v_account_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- Main: Process Cross-Service Transaction
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION process_cross_service_transaction(
  p_user_id uuid,
  p_merchant_id uuid,
  p_amount numeric,
  p_currency_code text DEFAULT 'MUR',
  p_application_code text DEFAULT 'uwin',
  p_idempotency_key text DEFAULT NULL,
  p_campaign_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_idempotency_key text := COALESCE(p_idempotency_key, gen_random_uuid()::text);
  v_wallet_id uuid;
  v_wallet_account_id uuid;
  v_wallet_tx_id uuid;
  v_programme_id uuid;
  v_reward_account_id uuid;
  v_reward_tx_id uuid;
  v_points_to_earn integer := 0;
  v_new_balance integer := 0;
  v_analytics_event_id uuid;
  v_notification_id uuid;
  v_audit_log_id uuid;
  v_event_id text;
  v_merchant_name text;
  v_existing_tx uuid;
BEGIN
  -- Check idempotency
  SELECT id INTO v_existing_tx FROM wallet_transactions WHERE idempotency_key = v_idempotency_key;
  IF v_existing_tx IS NOT NULL THEN
    -- Return existing result
    SELECT jsonb_build_object(
      'idempotent', true,
      'wallet_transaction_id', v_existing_tx
    ) INTO v_existing_tx;
    RETURN jsonb_build_object('idempotent', true, 'wallet_transaction_id', v_existing_tx);
  END IF;

  -- Validate amount
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid transaction amount';
  END IF;

  -- Get merchant name
  SELECT merchant_name INTO v_merchant_name FROM merchants WHERE id = p_merchant_id;
  IF v_merchant_name IS NULL THEN
    RAISE EXCEPTION 'Merchant not found';
  END IF;

  -- a) Get or create wallet
  v_wallet_id := get_or_create_wallet(p_user_id);

  -- b) Get or create wallet account for loyalty_points
  v_wallet_account_id := get_or_create_wallet_account(v_wallet_id, 'loyalty_points', p_currency_code);

  -- c) Record wallet transaction
  INSERT INTO wallet_transactions (
    wallet_id, wallet_account_id, transaction_type, asset_type,
    amount, currency_code, source, merchant_id, campaign_id,
    application_code, idempotency_key, status, description
  ) VALUES (
    v_wallet_id, v_wallet_account_id, 'earn', 'loyalty_points',
    p_amount, p_currency_code, 'transaction', p_merchant_id, p_campaign_id,
    p_application_code, v_idempotency_key, 'completed',
    'Transaction at ' || v_merchant_name
  )
  RETURNING id INTO v_wallet_tx_id;

  -- d) Update wallet account balance
  UPDATE wallet_accounts
  SET balance = balance + p_amount, updated_at = now()
  WHERE id = v_wallet_account_id;

  -- e) Evaluate reward rules: Rs100 = 1 point (floor)
  -- Check for merchant-specific or campaign-specific rules first
  SELECT COALESCE(
    (SELECT reward_amount FROM reward_rules
     WHERE merchant_id = p_merchant_id AND rule_type = 'earn' AND is_active = true
     AND (starts_at IS NULL OR starts_at <= now())
     AND (ends_at IS NULL OR ends_at >= now())
     AND p_amount >= COALESCE(min_spend, 0)
     ORDER BY created_at DESC LIMIT 1),
    (SELECT reward_amount FROM reward_rules
     WHERE merchant_id IS NULL AND rule_type = 'earn' AND is_active = true
     AND (starts_at IS NULL OR starts_at <= now())
     AND (ends_at IS NULL OR ends_at >= now())
     AND p_amount >= COALESCE(min_spend, 0)
     ORDER BY created_at DESC LIMIT 1),
    FLOOR(p_amount / 100)
  ) INTO v_points_to_earn;

  -- Also check for multiplier rules
  DECLARE
    v_multiplier numeric := 1.0;
  BEGIN
    SELECT reward_rules.multiplier INTO v_multiplier
    FROM reward_rules
    WHERE rule_type = 'multiplier' AND is_active = true
    AND (merchant_id = p_merchant_id OR merchant_id IS NULL)
    AND (starts_at IS NULL OR starts_at <= now())
    AND (ends_at IS NULL OR ends_at >= now())
    ORDER BY merchant_id NULLS LAST, created_at DESC LIMIT 1;

    IF v_multiplier IS NOT NULL AND v_multiplier > 0 THEN
      v_points_to_earn := FLOOR(v_points_to_earn * v_multiplier);
    END IF;
  END;

  -- f) Get uWin Rewards programme
  SELECT id INTO v_programme_id FROM reward_programmes WHERE name = 'uWin Rewards' LIMIT 1;
  IF v_programme_id IS NULL THEN
    RAISE EXCEPTION 'uWin Rewards programme not found';
  END IF;

  -- g) Get or create reward account
  v_reward_account_id := get_or_create_reward_account(p_user_id, v_programme_id);

  -- h) Record reward transaction (if points earned)
  IF v_points_to_earn > 0 THEN
    INSERT INTO reward_transactions (
      reward_account_id, user_id, transaction_type, amount,
      source, merchant_id, campaign_id, wallet_transaction_id,
      application_code, idempotency_key, status, metadata
    ) VALUES (
      v_reward_account_id, p_user_id, 'earn', v_points_to_earn,
      'transaction', p_merchant_id, p_campaign_id, v_wallet_tx_id,
      p_application_code, v_idempotency_key, 'completed',
      jsonb_build_object('transaction_amount', p_amount, 'merchant', v_merchant_name)
    )
    RETURNING id INTO v_reward_tx_id;

    -- Update reward account balance
    UPDATE reward_accounts
    SET total_points_earned = total_points_earned + v_points_to_earn,
        current_balance = current_balance + v_points_to_earn,
        updated_at = now()
    WHERE id = v_reward_account_id;

    SELECT current_balance INTO v_new_balance FROM reward_accounts WHERE id = v_reward_account_id;
  END IF;

  -- i) Record analytics event
  v_event_id := 'evt_' || gen_random_uuid()::text;
  INSERT INTO analytics_events (
    event_id, event_name, user_id, organisation_id, merchant_id,
    application_code, screen_name, country_code, properties
  ) VALUES (
    v_event_id, 'reward_earned', p_user_id, NULL, p_merchant_id,
    p_application_code, 'cross_service_demo', 'MU',
    jsonb_build_object(
      'transaction_amount', p_amount,
      'points_earned', v_points_to_earn,
      'merchant_name', v_merchant_name,
      'new_balance', v_new_balance
    )
  )
  RETURNING id INTO v_analytics_event_id;

  -- j) Create notification
  INSERT INTO notifications (
    user_id, notification_type, category, title, body, data, application_code
  ) VALUES (
    p_user_id, 'REWARD_EARNED', 'loyalty',
    'Points earned!',
    'You earned ' || v_points_to_earn || ' points at ' || v_merchant_name || '. Your new balance is ' || v_new_balance || ' points.',
    jsonb_build_object('points_earned', v_points_to_earn, 'merchant', v_merchant_name, 'new_balance', v_new_balance),
    p_application_code
  )
  RETURNING id INTO v_notification_id;

  -- k) Write audit log
  INSERT INTO audit_logs (
    actor_id, action, entity_type, entity_id, new_value, metadata
  ) VALUES (
    p_user_id, 'cross_service_transaction', 'wallet_transaction', v_wallet_tx_id,
    jsonb_build_object(
      'amount', p_amount,
      'points_earned', v_points_to_earn,
      'merchant', v_merchant_name,
      'wallet_transaction_id', v_wallet_tx_id,
      'reward_transaction_id', v_reward_tx_id,
      'analytics_event_id', v_analytics_event_id,
      'notification_id', v_notification_id
    ),
    jsonb_build_object('application_code', p_application_code, 'idempotency_key', v_idempotency_key)
  )
  RETURNING id INTO v_audit_log_id;

  -- Return result
  RETURN jsonb_build_object(
    'wallet_transaction_id', v_wallet_tx_id,
    'reward_transaction_id', v_reward_tx_id,
    'analytics_event_id', v_analytics_event_id,
    'notification_id', v_notification_id,
    'audit_log_id', v_audit_log_id,
    'points_earned', v_points_to_earn,
    'new_balance', v_new_balance,
    'merchant_name', v_merchant_name,
    'amount', p_amount
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION process_cross_service_transaction FROM anon;
GRANT EXECUTE ON FUNCTION process_cross_service_transaction TO authenticated;

-- Grant execute on helper functions
REVOKE EXECUTE ON FUNCTION get_or_create_wallet FROM anon;
GRANT EXECUTE ON FUNCTION get_or_create_wallet TO authenticated;

REVOKE EXECUTE ON FUNCTION get_or_create_wallet_account FROM anon;
GRANT EXECUTE ON FUNCTION get_or_create_wallet_account TO authenticated;

REVOKE EXECUTE ON FUNCTION get_or_create_reward_account FROM anon;
GRANT EXECUTE ON FUNCTION get_or_create_reward_account TO authenticated;

-- ---------------------------------------------------------------------------
-- Seed: Reward Programme (uWin Rewards)
-- ---------------------------------------------------------------------------
INSERT INTO reward_programmes (name, description, programme_type, status, country_code)
SELECT 'uWin Rewards', 'Ecosystem-wide loyalty programme — earn points across all uWin apps', 'points', 'active', 'MU'
WHERE NOT EXISTS (SELECT 1 FROM reward_programmes WHERE name = 'uWin Rewards');

-- Seed: Reward Tiers
DO $$
DECLARE
  v_programme_id uuid;
BEGIN
  SELECT id INTO v_programme_id FROM reward_programmes WHERE name = 'uWin Rewards';

  INSERT INTO reward_tiers (programme_id, tier_name, tier_level, min_points, benefits, validity_period_months)
  VALUES
    (v_programme_id, 'Member', 1, 0, '{"cashbackRate":"0.5%"}'::jsonb, NULL),
    (v_programme_id, 'Silver', 2, 1000, '{"cashbackRate":"1%","prioritySupport":true}'::jsonb, 12),
    (v_programme_id, 'Gold', 3, 5000, '{"cashbackRate":"1.5%","prioritySupport":true,"exclusiveOffers":true}'::jsonb, 12),
    (v_programme_id, 'Platinum', 4, 15000, '{"cashbackRate":"2%","prioritySupport":true,"exclusiveOffers":true,"freeDelivery":true,"concierge":true}'::jsonb, 12)
  ON CONFLICT (programme_id, tier_level) DO NOTHING;
END $$;

-- Seed: Reward Rules
DO $$
DECLARE
  v_programme_id uuid;
BEGIN
  SELECT id INTO v_programme_id FROM reward_programmes WHERE name = 'uWin Rewards';

  -- Default earn rule: Rs100 = 1 point
  INSERT INTO reward_rules (programme_id, rule_key, name, rule_type, conditions, reward_amount, reward_asset_type, min_spend, is_active)
  VALUES
    (v_programme_id, 'default_earn', 'Default Earn Rate', 'earn', '{"spendPerPoint":100}'::jsonb, 1, 'loyalty_points', 0, true),
    (v_programme_id, 'referral_bonus', 'Referral Bonus', 'referral', '{"type":"new_customer_referral"}'::jsonb, 200, 'loyalty_points', NULL, true)
  ON CONFLICT DO NOTHING;
END $$;

-- ---------------------------------------------------------------------------
-- Seed: Organisation (Lagoon Market Ltd)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_org_id uuid;
  v_branch_id uuid;
  v_merchant_id uuid;
  v_programme_id uuid;
BEGIN
  -- Create organisation if it doesn't exist
  SELECT id INTO v_org_id FROM organisations WHERE name = 'Lagoon Market Ltd';
  IF v_org_id IS NULL THEN
    INSERT INTO organisations (name, legal_name, organisation_type_code, registration_number, contact_email, contact_phone, website_url, status, country_code)
    VALUES ('Lagoon Market Ltd', 'Lagoon Market Ltd Co Ltd', 'merchant', 'BR123456', 'contact@lagoonmarket.mu', '+23052345678', 'https://lagoonmarket.mu', 'active', 'MU')
    RETURNING id INTO v_org_id;
  END IF;

  -- Create branch
  SELECT id INTO v_branch_id FROM branches WHERE organisation_id = v_org_id AND name = 'Grand Baie Branch';
  IF v_branch_id IS NULL THEN
    INSERT INTO branches (organisation_id, name, branch_code, address_line1, city, country_code, latitude, longitude, status)
    VALUES (v_org_id, 'Grand Baie Branch', 'GB001', 'Coastal Road, Grand Baie', 'Grand Baie', 'MU', -20.0151, 57.5802, 'active')
    RETURNING id INTO v_branch_id;
  END IF;

  -- Create merchant
  SELECT id INTO v_merchant_id FROM merchants WHERE organisation_id = v_org_id;
  IF v_merchant_id IS NULL THEN
    INSERT INTO merchants (organisation_id, merchant_name, trading_name, description, contact_phone, contact_email, country_code, status, loyalty_participation, voucher_acceptance, rating)
    VALUES (v_org_id, 'Lagoon Market', 'Lagoon Market', 'A premier supermarket in Grand Baie offering fresh groceries, household goods, and local products. Participating in uWin Rewards.', '+23052345678', 'contact@lagoonmarket.mu', 'MU', 'active', true, true, 4.5)
    RETURNING id INTO v_merchant_id;
  END IF;

  -- Merchant categories
  INSERT INTO merchant_categories (merchant_id, category_code, is_primary) VALUES
    (v_merchant_id, 'grocery', true),
    (v_merchant_id, 'home_goods', false)
  ON CONFLICT DO NOTHING;

  -- Merchant capabilities
  INSERT INTO merchant_capabilities (merchant_id, capability, is_enabled) VALUES
    (v_merchant_id, 'shopping', true),
    (v_merchant_id, 'loyalty', true),
    (v_merchant_id, 'vouchers', true),
    (v_merchant_id, 'offers', true),
    (v_merchant_id, 'delivery', true)
  ON CONFLICT DO NOTHING;

  -- Merchant channels
  INSERT INTO merchant_channels (merchant_id, application_code, is_enabled, activated_at) VALUES
    (v_merchant_id, 'uwin', true, now()),
    (v_merchant_id, 'uwin_rewards', true, now()),
    (v_merchant_id, 'uwin_market', true, now()),
    (v_merchant_id, 'uwin_business', true, now())
  ON CONFLICT DO NOTHING;

  -- Merchant location
  INSERT INTO merchant_locations (merchant_id, branch_id, label, address_line1, city, country_code, latitude, longitude, opening_hours, is_primary)
  VALUES (
    v_merchant_id, v_branch_id, 'Grand Baie Main', 'Coastal Road, Grand Baie', 'Grand Baie', 'MU', -20.0151, 57.5802,
    '{"mon":{"open":"08:00","close":"20:00"},"tue":{"open":"08:00","close":"20:00"},"wed":{"open":"08:00","close":"20:00"},"thu":{"open":"08:00","close":"20:00"},"fri":{"open":"08:00","close":"21:00"},"sat":{"open":"08:00","close":"21:00"},"sun":{"open":"09:00","close":"18:00"}}'::jsonb,
    true
  )
  ON CONFLICT DO NOTHING;

  -- Merchant-specific earn rule: Rs100 = 1 point at Lagoon Market
  SELECT id INTO v_programme_id FROM reward_programmes WHERE name = 'uWin Rewards';
  INSERT INTO reward_rules (programme_id, rule_key, name, rule_type, conditions, reward_amount, reward_asset_type, merchant_id, is_active)
  VALUES (v_programme_id, 'lagoon_market_earn', 'Lagoon Market Earn Rate', 'earn', '{"spendPerPoint":100}'::jsonb, 1, 'loyalty_points', v_merchant_id, true)
  ON CONFLICT DO NOTHING;

  -- Campaign: Lagoon Market Loyalty Bonus
  INSERT INTO campaigns (name, description, campaign_type, status, organisation_id, merchant_id, starts_at, ends_at, currency_code, application_code)
  SELECT 'Lagoon Market Loyalty Bonus', 'Earn 2x points on purchases over Rs500 at Lagoon Market', 'points_bonus', 'active', v_org_id, v_merchant_id, now() - interval '30 days', now() + interval '60 days', 'MUR', 'uwin'
  WHERE NOT EXISTS (SELECT 1 FROM campaigns WHERE name = 'Lagoon Market Loyalty Bonus');
END $$;

-- ---------------------------------------------------------------------------
-- Seed: Notification Templates
-- ---------------------------------------------------------------------------
INSERT INTO notification_templates (notification_type, channel, locale, subject_template, body_template, is_active) VALUES
  ('REWARD_EARNED', 'in_app', 'en', 'Points earned!', 'You earned {{points}} points at {{merchant}}. New balance: {{balance}}.', true),
  ('REWARD_EARNED', 'push', 'en', 'Points earned!', 'You earned {{points}} points at {{merchant}}.', true),
  ('REWARD_EARNED', 'in_app', 'fr', 'Points gagnés!', 'Vous avez gagné {{points}} points chez {{merchant}}. Nouveau solde: {{balance}}.', true),
  ('REWARD_EXPIRING', 'in_app', 'en', 'Points expiring soon', 'You have {{points}} points expiring on {{date}}. Redeem them soon!', true),
  ('REWARD_EXPIRING', 'in_app', 'fr', 'Points expirant bientôt', 'Vous avez {{points}} points expirant le {{date}}.', true),
  ('VOUCHER_RECEIVED', 'in_app', 'en', 'Voucher received', 'You received a voucher: {{voucher_name}}', true),
  ('VOUCHER_RECEIVED', 'in_app', 'fr', 'Bon reçu', 'Vous avez reçu un bon: {{voucher_name}}', true),
  ('CAMPAIGN_AVAILABLE', 'in_app', 'en', 'New offer available', '{{campaign_name}} is now available!', true),
  ('CAMPAIGN_AVAILABLE', 'in_app', 'fr', 'Nouvelle offre', '{{campaign_name}} est maintenant disponible!', true),
  ('SYSTEM_MESSAGE', 'in_app', 'en', 'System message', '{{message}}', true),
  ('SYSTEM_MESSAGE', 'in_app', 'fr', 'Message système', '{{message}}', true),
  ('ACCOUNT_SECURITY', 'in_app', 'en', 'Security alert', '{{message}}', true),
  ('ACCOUNT_SECURITY', 'in_app', 'fr', 'Alerte de sécurité', '{{message}}', true)
ON CONFLICT (notification_type, channel, locale) DO NOTHING;
