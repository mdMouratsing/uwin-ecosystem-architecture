/*
# Central Merchant Directory

1. Purpose
This migration creates the shared merchant directory. Future apps reference the
central merchant record instead of creating their own merchant tables. A merchant
is linked to an organisation and can have multiple locations, categories,
capabilities, and channel (application) enablements.

2. New Tables
- `merchants` — the central merchant record linked to an organisation
- `merchant_categories` — business categories per merchant (multi-category)
- `merchant_locations` — physical locations for a merchant
- `merchant_capabilities` — configurable capabilities per merchant (shopping,
  restaurant, loyalty, vouchers, bookings, etc.)
- `merchant_channels` — which ecosystem applications/channels a merchant is
  enabled on (uWin, uWin Resto, RetailFlow, etc.)

3. Security
- RLS enabled on all tables.
- Merchant data is visible to users who are members of the merchant's parent
  organisation (via business_users membership check).
- INSERT/UPDATE/DELETE requires organisation membership.
- Merchant status changes and channel enablement are privileged operations
  that go through SECURITY DEFINER functions (RBAC migration).

4. Design Notes
- A merchant is NOT forced into one fixed category. merchant_categories supports
  multiple categories per merchant with a primary flag.
- Capabilities are configurable per merchant — a hotel can have accommodation,
  restaurant, service, and rewards capabilities simultaneously.
- merchant_channels allows a merchant to be visible on specific apps only.
*/

-- ---------------------------------------------------------------------------
-- Merchants
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  merchant_name text NOT NULL,
  trading_name text,
  description text,
  logo_url text,
  cover_image_url text,
  website_url text,
  contact_phone text,
  contact_email text,
  country_code text NOT NULL DEFAULT 'MU',
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','pending_review','active','suspended','inactive')),
  loyalty_participation boolean NOT NULL DEFAULT false,
  voucher_acceptance boolean NOT NULL DEFAULT false,
  rating numeric(3,2),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "merchants_select_member" ON merchants;
CREATE POLICY "merchants_select_member" ON merchants FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = merchants.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchants_insert_member" ON merchants;
CREATE POLICY "merchants_insert_member" ON merchants FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = merchants.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchants_update_member" ON merchants;
CREATE POLICY "merchants_update_member" ON merchants FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = merchants.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = merchants.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

-- Merchant status is a privileged column — revoke UPDATE on it from authenticated
REVOKE UPDATE ON merchants FROM authenticated;
GRANT UPDATE (
  merchant_name, trading_name, description, logo_url, cover_image_url,
  website_url, contact_phone, contact_email, loyalty_participation,
  voucher_acceptance, rating
) ON merchants TO authenticated;

-- ---------------------------------------------------------------------------
-- Merchant Categories
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  category_code text NOT NULL,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  UNIQUE(merchant_id, category_code)
);

ALTER TABLE merchant_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "merchant_categories_select_member" ON merchant_categories;
CREATE POLICY "merchant_categories_select_member" ON merchant_categories FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_categories.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchant_categories_insert_member" ON merchant_categories;
CREATE POLICY "merchant_categories_insert_member" ON merchant_categories FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_categories.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchant_categories_delete_member" ON merchant_categories;
CREATE POLICY "merchant_categories_delete_member" ON merchant_categories FOR DELETE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_categories.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Merchant Locations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  branch_id uuid REFERENCES branches(id) ON DELETE SET NULL,
  label text NOT NULL,
  address_line1 text NOT NULL,
  address_line2 text,
  city text NOT NULL,
  region text,
  postal_code text,
  country_code text NOT NULL DEFAULT 'MU',
  latitude decimal(10,7),
  longitude decimal(10,7),
  opening_hours jsonb,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE merchant_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "merchant_locations_select_member" ON merchant_locations;
CREATE POLICY "merchant_locations_select_member" ON merchant_locations FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_locations.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchant_locations_insert_member" ON merchant_locations;
CREATE POLICY "merchant_locations_insert_member" ON merchant_locations FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_locations.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchant_locations_update_member" ON merchant_locations;
CREATE POLICY "merchant_locations_update_member" ON merchant_locations FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_locations.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_locations.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Merchant Capabilities
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_capabilities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  capability text NOT NULL,
  is_enabled boolean NOT NULL DEFAULT true,
  configuration jsonb,
  created_at timestamptz DEFAULT now(),
  UNIQUE(merchant_id, capability)
);

ALTER TABLE merchant_capabilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "merchant_capabilities_select_member" ON merchant_capabilities;
CREATE POLICY "merchant_capabilities_select_member" ON merchant_capabilities FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_capabilities.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchant_capabilities_insert_member" ON merchant_capabilities;
CREATE POLICY "merchant_capabilities_insert_member" ON merchant_capabilities FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_capabilities.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

DROP POLICY IF EXISTS "merchant_capabilities_update_member" ON merchant_capabilities;
CREATE POLICY "merchant_capabilities_update_member" ON merchant_capabilities FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_capabilities.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_capabilities.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Merchant Channels
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  application_code text NOT NULL,
  is_enabled boolean NOT NULL DEFAULT false,
  activated_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(merchant_id, application_code)
);

ALTER TABLE merchant_channels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "merchant_channels_select_member" ON merchant_channels;
CREATE POLICY "merchant_channels_select_member" ON merchant_channels FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users bu
      JOIN merchants m ON m.organisation_id = bu.organisation_id
      WHERE m.id = merchant_channels.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- Channel enablement is a privileged operation — no INSERT/UPDATE for regular users

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_merchants_organisation_id ON merchants(organisation_id);
CREATE INDEX IF NOT EXISTS idx_merchants_status ON merchants(status);
CREATE INDEX IF NOT EXISTS idx_merchants_country ON merchants(country_code);
CREATE INDEX IF NOT EXISTS idx_merchant_categories_merchant_id ON merchant_categories(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_categories_category_code ON merchant_categories(category_code);
CREATE INDEX IF NOT EXISTS idx_merchant_locations_merchant_id ON merchant_locations(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_capabilities_merchant_id ON merchant_capabilities(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_channels_merchant_id ON merchant_channels(merchant_id);
