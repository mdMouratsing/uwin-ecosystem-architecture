/*
# Organisations, Branches, and Business Users

1. Purpose
This migration creates the central organisation hierarchy for the platform.
A company or merchant exists only once in the central business graph. One
organisation can operate multiple branches and departments. A person can be
a business user at multiple organisations without creating separate identities.

2. New Tables
- `organisation_types` — reference table (merchant, retailer, restaurant, etc.)
- `organisations` — the central business entity (one per company)
- `branches` — physical locations belonging to an organisation
- `departments` — organisational units within a branch or organisation
- `business_users` — links a platform user to an organisation with a role
- `business_roles` — the specific role a business user holds, scoped to org/branch

3. Security
- RLS enabled on all tables.
- Organisation types are readable by all authenticated users (reference data).
- Organisation/branch/department rows are visible only to users who are members
  of that organisation (through business_users membership).
- Business users can see their own membership and memberships within their org.
- Role assignment is a privileged operation — no INSERT/UPDATE/DELETE for regular
  users. These go through SECURITY DEFINER functions in the RBAC migration.

4. Tenant Isolation
- The key tenant boundary: a user can only see organisations where they have a
  business_users record. This is enforced through RLS USING predicates that check
  membership via a subquery.

5. Ordering Note
- Tables are created BEFORE policies that reference them. `business_users` is
  created before organisation/branch/department policies that reference it.
*/

-- ---------------------------------------------------------------------------
-- Organisation Types (reference table) — created first, no dependencies
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organisation_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE organisation_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "org_types_select_authenticated" ON organisation_types;
CREATE POLICY "org_types_select_authenticated" ON organisation_types FOR SELECT
  TO authenticated USING (true);

-- Seed organisation types
INSERT INTO organisation_types (code, name, description) VALUES
  ('merchant', 'Merchant', 'A retail or service merchant'),
  ('retailer', 'Retailer', 'A retail business'),
  ('restaurant', 'Restaurant', 'A food service establishment'),
  ('distributor', 'Distributor', 'A product distributor'),
  ('manufacturer', 'Manufacturer', 'A product manufacturer'),
  ('hotel', 'Hotel', 'A hospitality establishment'),
  ('service_provider', 'Service Provider', 'A service provider'),
  ('fuel_station', 'Fuel Station', 'A fuel station operator'),
  ('tourism_operator', 'Tourism Operator', 'A tourism operator')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Organisations — no RLS policies yet (policies that reference business_users
-- are added after business_users is created below)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS organisations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  legal_name text,
  organisation_type_code text NOT NULL REFERENCES organisation_types(code),
  registration_number text,
  tax_number text,
  contact_email text,
  contact_phone text,
  website_url text,
  logo_url text,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  country_code text NOT NULL DEFAULT 'MU',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz
);

ALTER TABLE organisations ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Branches
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  name text NOT NULL,
  branch_code text,
  contact_phone text,
  contact_email text,
  address_line1 text,
  address_line2 text,
  city text,
  region text,
  postal_code text,
  country_code text NOT NULL DEFAULT 'MU',
  latitude decimal(10,7),
  longitude decimal(10,7),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE branches ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Departments
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  branch_id uuid REFERENCES branches(id) ON DELETE SET NULL,
  name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Business Users — created before policies that reference it
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS business_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organisation_id uuid NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  branch_id uuid REFERENCES branches(id) ON DELETE SET NULL,
  department_id uuid REFERENCES departments(id) ON DELETE SET NULL,
  job_title text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending','pending_review','active','paused','suspended','inactive','completed','cancelled','closed','expired','redeemed','issued','scheduled')),
  joined_at timestamptz DEFAULT now(),
  left_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(user_id, organisation_id)
);

ALTER TABLE business_users ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Business Roles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS business_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id uuid NOT NULL REFERENCES organisations(id) ON DELETE CASCADE,
  business_user_id uuid NOT NULL REFERENCES business_users(id) ON DELETE CASCADE,
  role_key text NOT NULL,
  scope text NOT NULL DEFAULT 'organisation' CHECK (scope IN ('platform','organisation','branch','own')),
  scope_ref uuid,
  assigned_at timestamptz DEFAULT now(),
  assigned_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE business_roles ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- NOW apply RLS policies (business_users exists at this point)
-- ---------------------------------------------------------------------------

-- Organisations policies
DROP POLICY IF EXISTS "organisations_select_member" ON organisations;
CREATE POLICY "organisations_select_member" ON organisations FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = organisations.id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

DROP POLICY IF EXISTS "organisations_insert_member" ON organisations;
CREATE POLICY "organisations_insert_member" ON organisations FOR INSERT
  TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "organisations_update_member" ON organisations;
CREATE POLICY "organisations_update_member" ON organisations FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = organisations.id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = organisations.id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

-- Branches policies
DROP POLICY IF EXISTS "branches_select_member" ON branches;
CREATE POLICY "branches_select_member" ON branches FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = branches.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

DROP POLICY IF EXISTS "branches_insert_member" ON branches;
CREATE POLICY "branches_insert_member" ON branches FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = branches.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

DROP POLICY IF EXISTS "branches_update_member" ON branches;
CREATE POLICY "branches_update_member" ON branches FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = branches.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = branches.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

-- Departments policies
DROP POLICY IF EXISTS "departments_select_member" ON departments;
CREATE POLICY "departments_select_member" ON departments FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = departments.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

-- Business users policies
DROP POLICY IF EXISTS "business_users_select_own_or_member" ON business_users;
CREATE POLICY "business_users_select_own_or_member" ON business_users FOR SELECT
  TO authenticated USING (
    business_users.user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM business_users bu2
      WHERE bu2.organisation_id = business_users.organisation_id
      AND bu2.user_id = auth.uid()
      AND bu2.status = 'active'
    )
  );

DROP POLICY IF EXISTS "business_users_insert_own" ON business_users;
CREATE POLICY "business_users_insert_own" ON business_users FOR INSERT
  TO authenticated WITH CHECK (business_users.user_id = auth.uid());

-- Users can only update their own job_title column
REVOKE UPDATE ON business_users FROM authenticated;
GRANT UPDATE (job_title) ON business_users TO authenticated;

DROP POLICY IF EXISTS "business_users_update_own" ON business_users;
CREATE POLICY "business_users_update_own" ON business_users FOR UPDATE
  TO authenticated USING (business_users.user_id = auth.uid())
  WITH CHECK (business_users.user_id = auth.uid());

-- Business roles policies (read-only for regular users)
DROP POLICY IF EXISTS "business_roles_select_member" ON business_roles;
CREATE POLICY "business_roles_select_member" ON business_roles FOR SELECT
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM business_users
      WHERE business_users.organisation_id = business_roles.organisation_id
      AND business_users.user_id = auth.uid()
      AND business_users.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_organisations_type_code ON organisations(organisation_type_code);
CREATE INDEX IF NOT EXISTS idx_organisations_status ON organisations(status);
CREATE INDEX IF NOT EXISTS idx_organisations_country ON organisations(country_code);
CREATE INDEX IF NOT EXISTS idx_branches_organisation_id ON branches(organisation_id);
CREATE INDEX IF NOT EXISTS idx_departments_organisation_id ON departments(organisation_id);
CREATE INDEX IF NOT EXISTS idx_business_users_user_id ON business_users(user_id);
CREATE INDEX IF NOT EXISTS idx_business_users_organisation_id ON business_users(organisation_id);
CREATE INDEX IF NOT EXISTS idx_business_roles_organisation_id ON business_roles(organisation_id);
CREATE INDEX IF NOT EXISTS idx_business_roles_business_user_id ON business_roles(business_user_id);
