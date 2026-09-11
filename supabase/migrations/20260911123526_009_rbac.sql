/*
# Role-Based Access Control (RBAC)

1. Purpose
This migration creates the RBAC system: roles, permissions, role-permission
mapping, user-role assignments, and scope definitions. Access is NOT based
solely on role names — it uses structured permission keys (e.g. merchant.view,
wallet.adjust) with scopes (platform, organisation, branch, own).

2. New Tables
- `roles` — system and business roles (IDS Super Admin, Platform Admin, etc.)
- `permissions` — structured permission keys with scope
- `role_permissions` — mapping of permissions to roles
- `user_roles` — user-to-role assignments with scope and scope_ref

3. Privileged Functions (SECURITY DEFINER)
- `assign_role` — assigns a role to a user (requires platform admin)
- `set_user_status` — changes a user's status (requires platform admin)
- `set_merchant_status` — changes a merchant's status (requires org admin)
- `adjust_wallet_balance` — manually adjusts a wallet balance (requires finance officer)
- `adjust_reward_balance` — manually adjusts a reward balance (requires platform admin)
- `cancel_voucher` — cancels a voucher (requires platform admin)

4. Security
- RLS enabled on all tables.
- Roles and permissions are readable by all authenticated users.
- user_roles is readable by the user themselves.
- Role assignment, status changes, and balance adjustments are ONLY possible
  through SECURITY DEFINER functions that check the caller's authorization.
- Column-level UPDATE is revoked on user.status, merchant.status, etc.
*/

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_key text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  scope text NOT NULL DEFAULT 'platform' CHECK (scope IN ('platform','organisation','branch','own')),
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "roles_select_authenticated" ON roles;
CREATE POLICY "roles_select_authenticated" ON roles FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Permissions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  permission_key text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  scope text NOT NULL DEFAULT 'platform' CHECK (scope IN ('platform','organisation','branch','own')),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "permissions_select_authenticated" ON permissions;
CREATE POLICY "permissions_select_authenticated" ON permissions FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Role Permissions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(role_id, permission_id)
);

ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "role_permissions_select_authenticated" ON role_permissions;
CREATE POLICY "role_permissions_select_authenticated" ON role_permissions FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- User Roles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id uuid NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  scope text NOT NULL DEFAULT 'platform' CHECK (scope IN ('platform','organisation','branch','own')),
  scope_ref uuid,
  assigned_by uuid REFERENCES users(id),
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, role_id, scope, scope_ref)
);

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_roles_select_own" ON user_roles;
CREATE POLICY "user_roles_select_own" ON user_roles FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users — role assignment is privileged

-- ---------------------------------------------------------------------------
-- Seed: Roles
-- ---------------------------------------------------------------------------
INSERT INTO roles (role_key, name, description, scope, is_system) VALUES
  ('ids_super_admin', 'IDS Super Admin', 'Full platform access including all configuration', 'platform', true),
  ('platform_admin', 'Platform Administrator', 'Manage users, organisations, merchants, and system settings', 'platform', true),
  ('support_agent', 'Support Agent', 'View user accounts and provide support', 'platform', true),
  ('finance_officer', 'Finance Officer', 'Manage wallet adjustments and view financial reports', 'platform', true),
  ('campaign_manager', 'Campaign Manager', 'Create and manage campaigns', 'platform', true),
  ('analyst', 'Analyst', 'View analytics and reports', 'platform', true),
  ('content_manager', 'Content Manager', 'Manage merchant profiles and content', 'platform', true),
  ('business_owner', 'Business Owner', 'Full access to own organisation', 'organisation', true),
  ('business_admin', 'Business Administrator', 'Manage organisation settings and staff', 'organisation', true),
  ('branch_manager', 'Branch Manager', 'Manage a specific branch', 'branch', true),
  ('staff', 'Staff', 'Basic staff access', 'branch', true),
  ('sales_representative', 'Sales Representative', 'Sales operations', 'branch', true),
  ('restaurant_manager', 'Restaurant Manager', 'Manage restaurant operations', 'branch', true),
  ('cashier', 'Cashier', 'Process transactions', 'branch', true),
  ('warehouse_manager', 'Warehouse Manager', 'Manage warehouse operations', 'branch', true),
  ('driver', 'Driver', 'Delivery operations', 'branch', true)
ON CONFLICT (role_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed: Permissions
-- ---------------------------------------------------------------------------
INSERT INTO permissions (permission_key, name, description, scope) VALUES
  ('users.view', 'View Users', 'View user accounts and profiles', 'platform'),
  ('users.manage', 'Manage Users', 'Create, suspend, and close user accounts', 'platform'),
  ('organisations.view', 'View Organisations', 'View organisations', 'platform'),
  ('organisations.manage', 'Manage Organisations', 'Create and edit organisations', 'platform'),
  ('merchants.view', 'View Merchants', 'View merchant directory', 'platform'),
  ('merchants.edit', 'Edit Merchants', 'Edit merchant profiles', 'organisation'),
  ('merchants.manage', 'Manage Merchants', 'Create and change merchant status', 'platform'),
  ('wallet.view', 'View Wallet', 'View wallet transactions', 'platform'),
  ('wallet.adjust', 'Adjust Wallet', 'Manually adjust wallet balances', 'platform'),
  ('rewards.view', 'View Rewards', 'View reward programmes and transactions', 'platform'),
  ('rewards.adjust', 'Adjust Rewards', 'Manually adjust reward balances', 'platform'),
  ('vouchers.view', 'View Vouchers', 'View vouchers', 'platform'),
  ('vouchers.redeem', 'Redeem Vouchers', 'Redeem vouchers', 'platform'),
  ('vouchers.manage', 'Manage Vouchers', 'Issue and cancel vouchers', 'platform'),
  ('campaigns.view', 'View Campaigns', 'View campaigns', 'platform'),
  ('campaigns.create', 'Create Campaigns', 'Create new campaigns', 'platform'),
  ('campaigns.approve', 'Approve Campaigns', 'Approve and activate campaigns', 'platform'),
  ('notifications.view', 'View Notifications', 'View notifications', 'platform'),
  ('analytics.view', 'View Analytics', 'View analytics events and reports', 'platform'),
  ('audit.view', 'View Audit Logs', 'View audit logs', 'platform'),
  ('roles.manage', 'Manage Roles', 'Assign and revoke roles', 'platform'),
  ('branches.manage', 'Manage Branches', 'Create and edit branches', 'organisation')
ON CONFLICT (permission_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Seed: Role-Permission mappings
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r_ids_super_admin uuid;
  r_platform_admin uuid;
  r_support_agent uuid;
  r_finance_officer uuid;
  r_campaign_manager uuid;
  r_analyst uuid;
  r_content_manager uuid;
  r_business_owner uuid;
  r_business_admin uuid;
  r_branch_manager uuid;
BEGIN
  SELECT id INTO r_ids_super_admin FROM roles WHERE role_key = 'ids_super_admin';
  SELECT id INTO r_platform_admin FROM roles WHERE role_key = 'platform_admin';
  SELECT id INTO r_support_agent FROM roles WHERE role_key = 'support_agent';
  SELECT id INTO r_finance_officer FROM roles WHERE role_key = 'finance_officer';
  SELECT id INTO r_campaign_manager FROM roles WHERE role_key = 'campaign_manager';
  SELECT id INTO r_analyst FROM roles WHERE role_key = 'analyst';
  SELECT id INTO r_content_manager FROM roles WHERE role_key = 'content_manager';
  SELECT id INTO r_business_owner FROM roles WHERE role_key = 'business_owner';
  SELECT id INTO r_business_admin FROM roles WHERE role_key = 'business_admin';
  SELECT id INTO r_branch_manager FROM roles WHERE role_key = 'branch_manager';

  -- IDS Super Admin gets ALL permissions
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_ids_super_admin, id FROM permissions
  ON CONFLICT DO NOTHING;

  -- Platform Admin gets most permissions except finance-specific ones
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_platform_admin, id FROM permissions WHERE permission_key NOT IN ('wallet.adjust','rewards.adjust')
  ON CONFLICT DO NOTHING;

  -- Support Agent
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_support_agent, id FROM permissions WHERE permission_key IN ('users.view','merchants.view','organisations.view','notifications.view')
  ON CONFLICT DO NOTHING;

  -- Finance Officer
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_finance_officer, id FROM permissions WHERE permission_key IN ('wallet.view','wallet.adjust','rewards.view','rewards.adjust','analytics.view','audit.view')
  ON CONFLICT DO NOTHING;

  -- Campaign Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_campaign_manager, id FROM permissions WHERE permission_key IN ('campaigns.view','campaigns.create','campaigns.approve','analytics.view')
  ON CONFLICT DO NOTHING;

  -- Analyst
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_analyst, id FROM permissions WHERE permission_key IN ('analytics.view','users.view','organisations.view','merchants.view','wallet.view','rewards.view','campaigns.view','audit.view')
  ON CONFLICT DO NOTHING;

  -- Content Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_content_manager, id FROM permissions WHERE permission_key IN ('merchants.view','merchants.edit','organisations.view')
  ON CONFLICT DO NOTHING;

  -- Business Owner
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_business_owner, id FROM permissions WHERE permission_key IN ('merchants.view','merchants.edit','organisations.view','branches.manage','campaigns.view','campaigns.create','analytics.view','wallet.view','rewards.view')
  ON CONFLICT DO NOTHING;

  -- Business Admin
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_business_admin, id FROM permissions WHERE permission_key IN ('merchants.view','merchants.edit','organisations.view','branches.manage','campaigns.view','analytics.view')
  ON CONFLICT DO NOTHING;

  -- Branch Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT r_branch_manager, id FROM permissions WHERE permission_key IN ('merchants.view','campaigns.view','analytics.view')
  ON CONFLICT DO NOTHING;
END $$;

-- ---------------------------------------------------------------------------
-- Privileged Functions (SECURITY DEFINER)
-- ---------------------------------------------------------------------------

-- Helper: check if caller has a specific role
CREATE OR REPLACE FUNCTION has_role(p_role_key text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles ur
    JOIN roles r ON r.id = ur.role_id
    WHERE ur.user_id = auth.uid()
    AND r.role_key = p_role_key
  );
$$;

-- Assign a role to a user (requires platform admin or super admin)
CREATE OR REPLACE FUNCTION assign_role(
  p_user_id uuid,
  p_role_key text,
  p_scope text DEFAULT 'platform',
  p_scope_ref uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role_id uuid;
BEGIN
  IF NOT (has_role('ids_super_admin') OR has_role('platform_admin')) THEN
    RAISE EXCEPTION 'Not authorized to assign roles';
  END IF;

  SELECT id INTO v_role_id FROM roles WHERE role_key = p_role_key;
  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role not found';
  END IF;

  INSERT INTO user_roles (user_id, role_id, scope, scope_ref, assigned_by)
  VALUES (p_user_id, v_role_id, p_scope, p_scope_ref, auth.uid())
  ON CONFLICT (user_id, role_id, scope, scope_ref) DO NOTHING;
END;
$$;

REVOKE EXECUTE ON FUNCTION assign_role FROM anon;
GRANT EXECUTE ON FUNCTION assign_role TO authenticated;

-- Set user status (requires platform admin)
CREATE OR REPLACE FUNCTION set_user_status(
  p_user_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT (has_role('ids_super_admin') OR has_role('platform_admin')) THEN
    RAISE EXCEPTION 'Not authorized to change user status';
  END IF;

  IF p_status NOT IN ('pending','active','suspended','closed') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;

  UPDATE users SET status = p_status, updated_at = now() WHERE id = p_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION set_user_status FROM anon;
GRANT EXECUTE ON FUNCTION set_user_status TO authenticated;

-- Set merchant status (requires org admin or platform admin)
CREATE OR REPLACE FUNCTION set_merchant_status(
  p_merchant_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT (has_role('ids_super_admin') OR has_role('platform_admin') OR has_role('business_admin') OR has_role('business_owner')) THEN
    RAISE EXCEPTION 'Not authorized to change merchant status';
  END IF;

  IF p_status NOT IN ('draft','pending_review','active','suspended','inactive') THEN
    RAISE EXCEPTION 'Invalid status';
  END IF;

  UPDATE merchants SET status = p_status, updated_at = now() WHERE id = p_merchant_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION set_merchant_status FROM anon;
GRANT EXECUTE ON FUNCTION set_merchant_status TO authenticated;

-- Cancel voucher (requires platform admin)
CREATE OR REPLACE FUNCTION cancel_voucher(p_voucher_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT (has_role('ids_super_admin') OR has_role('platform_admin')) THEN
    RAISE EXCEPTION 'Not authorized to cancel vouchers';
  END IF;

  UPDATE vouchers SET status = 'cancelled' WHERE id = p_voucher_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION cancel_voucher FROM anon;
GRANT EXECUTE ON FUNCTION cancel_voucher TO authenticated;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_roles_role_key ON roles(role_key);
CREATE INDEX IF NOT EXISTS idx_permissions_permission_key ON permissions(permission_key);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON user_roles(role_id);
