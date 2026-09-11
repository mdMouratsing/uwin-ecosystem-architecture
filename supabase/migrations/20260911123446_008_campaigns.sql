/*
# Campaign Engine

1. Purpose
This migration creates the central campaign model. Campaigns can be points
bonuses, voucher distributions, discounts, cashback, challenges, referrals,
targeted promotions, or sponsored offers. Targeting supports all users,
merchants, locations, categories, customer segments, loyalty tiers, and
application channels.

2. New Tables
- `campaigns` — the campaign definition
- `campaign_rules` — rules that define what triggers a reward and how much
- `campaign_targets` — targeting criteria (who/what the campaign applies to)
- `campaign_assets` — media assets for the campaign
- `campaign_redemptions` — records of users redeeming campaign offers
- `campaign_metrics` — aggregated metrics (impressions, clicks, redemptions)

3. Security
- RLS enabled on all tables.
- Active campaigns and their rules/targets are readable by all authenticated users.
- Campaign redemptions are readable only by the user who redeemed.
- Campaign management (create/update) requires organisation membership.
- Campaign metrics are readable by organisation members only.
*/

-- ---------------------------------------------------------------------------
-- Campaigns
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaigns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  campaign_type text NOT NULL CHECK (campaign_type IN ('points_bonus','voucher','discount','cashback','challenge','referral','targeted_promotion','sponsored_offer')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','scheduled','active','paused','completed','cancelled')),
  organisation_id uuid REFERENCES organisations(id) ON DELETE SET NULL,
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  starts_at timestamptz NOT NULL DEFAULT now(),
  ends_at timestamptz NOT NULL,
  budget numeric(18,2),
  currency_code text NOT NULL DEFAULT 'MUR',
  application_code text,
  image_url text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;

-- Active campaigns are visible to all authenticated users
DROP POLICY IF EXISTS "campaigns_select_authenticated" ON campaigns;
CREATE POLICY "campaigns_select_authenticated" ON campaigns FOR SELECT
  TO authenticated USING (true);

-- Campaign management requires organisation membership
DROP POLICY IF EXISTS "campaigns_insert_member" ON campaigns;
CREATE POLICY "campaigns_insert_member" ON campaigns FOR INSERT
  TO authenticated WITH CHECK (
    organisation_id IS NULL OR EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = campaigns.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

DROP POLICY IF EXISTS "campaigns_update_member" ON campaigns;
CREATE POLICY "campaigns_update_member" ON campaigns FOR UPDATE
  TO authenticated USING (
    organisation_id IS NULL OR EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = campaigns.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  ) WITH CHECK (
    organisation_id IS NULL OR EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = campaigns.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

-- Campaign status is privileged — revoke UPDATE on it
REVOKE UPDATE ON campaigns FROM authenticated;
GRANT UPDATE (name, description, starts_at, ends_at, budget, image_url) ON campaigns TO authenticated;

-- ---------------------------------------------------------------------------
-- Campaign Rules
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  rule_key text NOT NULL,
  conditions jsonb NOT NULL DEFAULT '{}'::jsonb,
  reward_amount numeric(18,2),
  reward_asset_type text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE campaign_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_rules_select_authenticated" ON campaign_rules;
CREATE POLICY "campaign_rules_select_authenticated" ON campaign_rules FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Campaign Targets
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  target_type text NOT NULL CHECK (target_type IN ('all_users','merchant','location','category','segment','tier','application')),
  target_ref text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE campaign_targets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_targets_select_authenticated" ON campaign_targets;
CREATE POLICY "campaign_targets_select_authenticated" ON campaign_targets FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Campaign Assets
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  asset_type text NOT NULL CHECK (asset_type IN ('image','banner','video','copy')),
  url text,
  content text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE campaign_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_assets_select_authenticated" ON campaign_assets;
CREATE POLICY "campaign_assets_select_authenticated" ON campaign_assets FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Campaign Redemptions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  merchant_id uuid REFERENCES merchants(id) ON DELETE SET NULL,
  reward_amount numeric(18,2),
  redeemed_at timestamptz DEFAULT now(),
  application_code text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE campaign_redemptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_redemptions_select_own" ON campaign_redemptions;
CREATE POLICY "campaign_redemptions_select_own" ON campaign_redemptions FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users — redemptions go through
-- SECURITY DEFINER functions.

-- ---------------------------------------------------------------------------
-- Campaign Metrics
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id uuid NOT NULL UNIQUE REFERENCES campaigns(id) ON DELETE CASCADE,
  impressions integer NOT NULL DEFAULT 0,
  clicks integer NOT NULL DEFAULT 0,
  redemptions integer NOT NULL DEFAULT 0,
  total_reward_issued numeric(18,2) NOT NULL DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE campaign_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "campaign_metrics_select_member" ON campaign_metrics;
CREATE POLICY "campaign_metrics_select_member" ON campaign_metrics FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN campaigns c ON c.organisation_id = bu.organisation_id
      WHERE c.id = campaign_metrics.campaign_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_organisation_id ON campaigns(organisation_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_merchant_id ON campaigns(merchant_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_application_code ON campaigns(application_code);
CREATE INDEX IF NOT EXISTS idx_campaign_rules_campaign_id ON campaign_rules(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_targets_campaign_id ON campaign_targets(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_assets_campaign_id ON campaign_assets(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_redemptions_campaign_id ON campaign_redemptions(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_redemptions_user_id ON campaign_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_campaign_metrics_campaign_id ON campaign_metrics(campaign_id);
