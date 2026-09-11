/*
# Universal Wallet — Immutable Ledger Architecture

1. Purpose
This migration creates the uWin Wallet, a universal wallet that supports multiple
asset types (loyalty points, cashback, promotional credits, gift cards, etc.).
The wallet is designed as an immutable ledger: balances are derived from
transaction history, never stored as a mutable number that gets overwritten.

2. New Tables
- `wallets` — top-level wallet per user (one wallet per person)
- `wallet_accounts` — sub-accounts per asset type within a wallet
- `wallet_assets` — individual asset references (vouchers, gift cards, etc.)
- `wallet_transactions` — the immutable ledger (every credit/debit/earn/redeem)
- `wallet_transaction_types` — reference table for transaction type definitions

3. Ledger Integrity
- wallet_transactions is an append-only ledger. Historical transactions are
  NEVER overwritten or deleted.
- Corrections use reversal or adjustment transactions that reference the
  original via related_transaction_id.
- The balance column on wallet_accounts is a cached derivation for performance,
  but the source of truth is the sum of completed transactions.
- A PL/pgSQL function (created in the cross-service migration) recalculates
  balances from the ledger.

4. Idempotency
- wallet_transactions supports an idempotency_key column. The cross-service
  transaction function checks for existing transactions with the same key
  before creating a new one, preventing duplicate credits from retried requests.

5. Security
- RLS enabled on all tables.
- Users can read only their own wallet data.
- No INSERT/UPDATE/DELETE for regular users on wallet_transactions — all
  transactions go through the SECURITY DEFINER cross-service function.
- Wallet account balance is NOT client-writable (column-level revocation).
*/

-- ---------------------------------------------------------------------------
-- Wallet Transaction Types (reference table)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallet_transaction_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_type text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  is_credit boolean NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE wallet_transaction_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_tx_types_select_authenticated" ON wallet_transaction_types;
CREATE POLICY "wallet_tx_types_select_authenticated" ON wallet_transaction_types FOR SELECT
  TO authenticated USING (true);

INSERT INTO wallet_transaction_types (transaction_type, name, description, is_credit) VALUES
  ('credit', 'Credit', 'Generic credit to wallet', true),
  ('debit', 'Debit', 'Generic debit from wallet', false),
  ('earn', 'Earn', 'Earn rewards through activity', true),
  ('redeem', 'Redeem', 'Redeem rewards or balance', false),
  ('adjustment', 'Adjustment', 'Manual adjustment (correction)', true),
  ('expiry', 'Expiry', 'Expired balance or points', false),
  ('refund', 'Refund', 'Refund of a previous debit', true),
  ('reversal', 'Reversal', 'Reversal of a previous transaction', false),
  ('transfer', 'Transfer', 'Transfer between accounts', false)
ON CONFLICT (transaction_type) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Wallets
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  label text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallets_select_own" ON wallets;
CREATE POLICY "wallets_select_own" ON wallets FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users — wallet creation is server-side

-- ---------------------------------------------------------------------------
-- Wallet Accounts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallet_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  asset_type text NOT NULL CHECK (asset_type IN ('loyalty_points','cashback','promotional_credit','gift_card','prepaid_balance','merchant_credit')),
  currency_code text NOT NULL DEFAULT 'MUR',
  balance numeric(18,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(wallet_id, asset_type, currency_code)
);

ALTER TABLE wallet_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_accounts_select_own" ON wallet_accounts;
CREATE POLICY "wallet_accounts_select_own" ON wallet_accounts FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM wallets WHERE wallets.id = wallet_accounts.wallet_id AND wallets.user_id = auth.uid())
  );

-- Balance is NOT client-writable — revoke all UPDATE
REVOKE UPDATE ON wallet_accounts FROM authenticated;

-- ---------------------------------------------------------------------------
-- Wallet Assets
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallet_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  wallet_account_id uuid NOT NULL REFERENCES wallet_accounts(id) ON DELETE CASCADE,
  asset_type text NOT NULL CHECK (asset_type IN ('loyalty_points','cashback','promotional_credit','gift_card','prepaid_balance','merchant_credit')),
  reference text,
  metadata jsonb,
  expires_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE wallet_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_assets_select_own" ON wallet_assets;
CREATE POLICY "wallet_assets_select_own" ON wallet_assets FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM wallets WHERE wallets.id = wallet_assets.wallet_id AND wallets.user_id = auth.uid())
  );

-- No INSERT/UPDATE/DELETE for regular users

-- ---------------------------------------------------------------------------
-- Wallet Transactions (the immutable ledger)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  wallet_account_id uuid NOT NULL REFERENCES wallet_accounts(id) ON DELETE CASCADE,
  transaction_type text NOT NULL,
  asset_type text NOT NULL,
  amount numeric(18,2) NOT NULL,
  currency_code text NOT NULL DEFAULT 'MUR',
  source text,
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  campaign_id uuid,
  application_code text,
  related_transaction_id uuid REFERENCES wallet_transactions(id) ON DELETE SET NULL,
  idempotency_key text,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','failed','reversed')),
  metadata jsonb,
  description text,
  created_at timestamptz DEFAULT now(),
  reversed_at timestamptz
);

ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_transactions_select_own" ON wallet_transactions;
CREATE POLICY "wallet_transactions_select_own" ON wallet_transactions FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM wallets WHERE wallets.id = wallet_transactions.wallet_id AND wallets.user_id = auth.uid())
  );

-- No INSERT/UPDATE/DELETE for regular users — transactions are created only
-- through the SECURITY DEFINER cross-service function.

-- Idempotency: unique index on idempotency_key prevents duplicate transactions
CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_tx_idempotency_key
  ON wallet_transactions(idempotency_key) WHERE idempotency_key IS NOT NULL;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_accounts_wallet_id ON wallet_accounts(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_assets_wallet_id ON wallet_assets(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_wallet_account_id ON wallet_transactions(wallet_account_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_merchant_id ON wallet_transactions(merchant_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_created_at ON wallet_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_status ON wallet_transactions(status);
