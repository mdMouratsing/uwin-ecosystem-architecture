/*
# Universal Rewards Engine

1. Purpose
This migration creates the shared rewards service. Reward balances are NOT
duplicated between applications — one rewards account per user per programme.
The engine supports points, loyalty tiers, cashback, bonuses, multipliers,
referrals, missions, challenges, birthday rewards, and merchant-specific
programmes.

2. New Tables
- `reward_programmes` — a rewards programme (ecosystem-wide or merchant-specific)
- `reward_rules` — configurable rules (not hard-coded) that define how rewards
  are earned or redeemed
- `reward_accounts` — a user's account within a programme (balance + tier)
- `reward_transactions` — the rewards ledger (earn, redeem, adjustment, etc.)
- `reward_tiers` — tier definitions per programme (Member, Silver, Gold, Platinum)

3. Design Notes
- Reward rules are data-driven, not hard-coded. A rule has conditions (JSONB),
  reward amount, asset type, optional multiplier, min spend, merchant scope, etc.
- Tier names are NOT hard-coded — each programme defines its own tier names,
  qualification rules (min_points), and benefits.
- reward_transactions is an immutable ledger, same as wallet_transactions.
- reward_accounts.current_balance is a cached derivation for performance.

4. Security
- RLS enabled on all tables.
- Users can read only their own reward accounts and transactions.
- Reward programme/rule/tier definitions are readable by all authenticated users.
- No INSERT/UPDATE/DELETE for regular users on reward_transactions — all
  reward credits go through the SECURITY DEFINER cross-service function.
*/

-- ---------------------------------------------------------------------------
-- Reward Programmes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reward_programmes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  programme_type text NOT NULL DEFAULT 'points' CHECK (programme_type IN ('points','cashback','hybrid')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  country_code text NOT NULL DEFAULT 'MU',
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE reward_programmes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reward_programmes_select_authenticated" ON reward_programmes;
CREATE POLICY "reward_programmes_select_authenticated" ON reward_programmes FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Reward Tiers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reward_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  programme_id uuid NOT NULL REFERENCES reward_programmes(id) ON DELETE CASCADE,
  tier_name text NOT NULL,
  tier_level integer NOT NULL,
  min_points integer NOT NULL DEFAULT 0,
  benefits jsonb NOT NULL DEFAULT '{}'::jsonb,
  validity_period_months integer,
  created_at timestamptz DEFAULT now(),
  UNIQUE(programme_id, tier_level)
);

ALTER TABLE reward_tiers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reward_tiers_select_authenticated" ON reward_tiers;
CREATE POLICY "reward_tiers_select_authenticated" ON reward_tiers FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Reward Rules
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reward_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  programme_id uuid NOT NULL REFERENCES reward_programmes(id) ON DELETE CASCADE,
  rule_key text NOT NULL,
  name text NOT NULL,
  description text,
  rule_type text NOT NULL CHECK (rule_type IN ('earn','redeem','bonus','multiplier','referral','challenge')),
  conditions jsonb NOT NULL DEFAULT '{}'::jsonb,
  reward_amount numeric(18,2) NOT NULL DEFAULT 0,
  reward_asset_type text NOT NULL DEFAULT 'loyalty_points',
  multiplier numeric(5,2),
  min_spend numeric(18,2),
  max_reward numeric(18,2),
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  campaign_id uuid,
  application_code text,
  is_active boolean NOT NULL DEFAULT true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE reward_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reward_rules_select_authenticated" ON reward_rules;
CREATE POLICY "reward_rules_select_authenticated" ON reward_rules FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Reward Accounts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reward_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  programme_id uuid NOT NULL REFERENCES reward_programmes(id) ON DELETE CASCADE,
  tier_id uuid REFERENCES reward_tiers(id) ON DELETE SET NULL,
  total_points_earned integer NOT NULL DEFAULT 0,
  total_points_redeemed integer NOT NULL DEFAULT 0,
  current_balance integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  enrolled_at timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, programme_id)
);

ALTER TABLE reward_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reward_accounts_select_own" ON reward_accounts;
CREATE POLICY "reward_accounts_select_own" ON reward_accounts FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- Balance columns are NOT client-writable
REVOKE UPDATE ON reward_accounts FROM authenticated;

-- ---------------------------------------------------------------------------
-- Reward Transactions (immutable ledger)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reward_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reward_account_id uuid NOT NULL REFERENCES reward_accounts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  transaction_type text NOT NULL CHECK (transaction_type IN ('earn','redeem','adjustment','expiry','reversal','bonus')),
  amount integer NOT NULL,
  source text,
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  campaign_id uuid,
  wallet_transaction_id uuid REFERENCES wallet_transactions(id) ON DELETE SET NULL,
  application_code text,
  idempotency_key text,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','failed','reversed')),
  metadata jsonb,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE reward_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reward_transactions_select_own" ON reward_transactions;
CREATE POLICY "reward_transactions_select_own" ON reward_transactions FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users — reward credits go through
-- the SECURITY DEFINER cross-service function.

CREATE UNIQUE INDEX IF NOT EXISTS idx_reward_tx_idempotency_key
  ON reward_transactions(idempotency_key) WHERE idempotency_key IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_reward_programmes_status ON reward_programmes(status);
CREATE INDEX IF NOT EXISTS idx_reward_tiers_programme_id ON reward_tiers(programme_id);
CREATE INDEX IF NOT EXISTS idx_reward_rules_programme_id ON reward_rules(programme_id);
CREATE INDEX IF NOT EXISTS idx_reward_rules_merchant_id ON reward_rules(merchant_id);
CREATE INDEX IF NOT EXISTS idx_reward_rules_is_active ON reward_rules(is_active);
CREATE INDEX IF NOT EXISTS idx_reward_accounts_user_id ON reward_accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_reward_accounts_programme_id ON reward_accounts(programme_id);
CREATE INDEX IF NOT EXISTS idx_reward_tx_reward_account_id ON reward_transactions(reward_account_id);
CREATE INDEX IF NOT EXISTS idx_reward_tx_user_id ON reward_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_reward_tx_merchant_id ON reward_transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_reward_tx_created_at ON reward_transactions(created_at DESC);
