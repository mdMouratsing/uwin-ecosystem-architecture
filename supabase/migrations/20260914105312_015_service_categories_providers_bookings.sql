/*
# Service Categories, Subcategories, Providers, and Bookings

1. Purpose
This migration adds a two-level service taxonomy and service provider/booking
infrastructure to the shared platform. Service categories describe the type of
service a provider offers (e.g. Health, Repairs, Wellness), while subcategories
enable finer-grained filtering (e.g. Dental within Health). Service providers
link to merchants in the central directory and offer bookable services. Users
can book these services through the platform.

This also adds the `health` merchant category to the central directory.

2. New Tables
- `service_categories` — reference table for service category codes and names
- `service_subcategories` — reference table for subcategory codes, parented to
  service categories
- `service_providers` — individual service providers linked to merchants, with
  category, subcategory, rating, city, and pricing
- `provider_services` — individual services offered by a provider (name, price,
  duration)
- `service_bookings` — user bookings for a specific provider service

3. Security
- RLS enabled on all mutable tables (service_providers, provider_services,
  service_bookings).
- service_categories and service_subcategories are reference tables — readable
  by all authenticated users.
- service_providers and provider_services are readable by all authenticated
  users (they are public-facing directory data).
- service_bookings are readable by the booking user (auth.uid() = user_id) and
  by organisation members who own the merchant the provider belongs to.
- INSERT/UPDATE/DELETE on providers and services are restricted to organisation
  members (business_users with status = 'active'). INSERT on bookings is open
  to authenticated users for their own bookings.

4. Relationship to Existing Platform
- service_providers.merchant_id references merchants(id) — every provider is
  linked to a merchant in the central directory.
- service_bookings.user_id references users(id) — every booking is linked to
  a platform user.
- The `health` merchant category is added as a distinct code from `pharmacy`
  (medicine retailers) and `health_beauty` (cosmetics). It covers medical
  service providers (clinics, dentists, opticians, osteopaths, etc.).
*/

-- ---------------------------------------------------------------------------
-- Service Categories (reference table)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_categories (
  code text PRIMARY KEY,
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0
);

ALTER TABLE service_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_categories_select_authenticated" ON service_categories;
CREATE POLICY "service_categories_select_authenticated" ON service_categories FOR SELECT
  TO authenticated USING (true);

INSERT INTO service_categories (code, name, sort_order) VALUES
  ('home', 'Home', 1),
  ('repairs', 'Repairs', 2),
  ('maintenance', 'Maintenance', 3),
  ('beauty', 'Beauty', 4),
  ('wellness', 'Wellness', 5),
  ('education', 'Education', 6),
  ('professional', 'Professional', 7),
  ('utilities', 'Utilities', 8),
  ('telecom', 'Telecom', 9),
  ('appointments', 'Appointments', 10),
  ('health', 'Health', 11)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Service Subcategories (reference table)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_subcategories (
  code text PRIMARY KEY,
  parent_category text NOT NULL REFERENCES service_categories(code),
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0
);

ALTER TABLE service_subcategories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_subcategories_select_authenticated" ON service_subcategories;
CREATE POLICY "service_subcategories_select_authenticated" ON service_subcategories FOR SELECT
  TO authenticated USING (true);

INSERT INTO service_subcategories (code, parent_category, name, sort_order) VALUES
  ('plumbing', 'repairs', 'Plumbing', 1),
  ('electrical', 'repairs', 'Electrical', 2),
  ('cleaning', 'maintenance', 'Cleaning', 1),
  ('facial', 'beauty', 'Facials', 1),
  ('spa', 'wellness', 'Spa', 1),
  ('massage', 'wellness', 'Massage', 2),
  ('gp', 'health', 'General Practitioner', 1),
  ('dental', 'health', 'Dental', 2),
  ('eye_care', 'health', 'Eye Care', 3),
  ('manual_therapy', 'health', 'Manual Therapy', 4)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Service Providers (linked to merchants)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_providers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  category_code text NOT NULL REFERENCES service_categories(code),
  subcategory_code text REFERENCES service_subcategories(code),
  rating numeric(2,1),
  city text,
  price_from numeric(12,2),
  currency_code text NOT NULL DEFAULT 'MUR',
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('draft','pending_review','active','suspended','inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE service_providers ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view providers (public directory data)
DROP POLICY IF EXISTS "service_providers_select_authenticated" ON service_providers;
CREATE POLICY "service_providers_select_authenticated" ON service_providers FOR SELECT
  TO authenticated USING (true);

-- Organisation members can insert providers for their merchants
DROP POLICY IF EXISTS "service_providers_insert_org_members" ON service_providers;
CREATE POLICY "service_providers_insert_org_members" ON service_providers FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM merchants m
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE m.id = service_providers.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- Organisation members can update providers for their merchants
DROP POLICY IF EXISTS "service_providers_update_org_members" ON service_providers;
CREATE POLICY "service_providers_update_org_members" ON service_providers FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM merchants m
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE m.id = service_providers.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM merchants m
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE m.id = service_providers.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- Organisation members can delete providers for their merchants
DROP POLICY IF EXISTS "service_providers_delete_org_members" ON service_providers;
CREATE POLICY "service_providers_delete_org_members" ON service_providers FOR DELETE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM merchants m
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE m.id = service_providers.merchant_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Provider Services (individual services offered by a provider)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS provider_services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES service_providers(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price numeric(12,2) NOT NULL,
  currency_code text NOT NULL DEFAULT 'MUR',
  duration_min integer,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE provider_services ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view services
DROP POLICY IF EXISTS "provider_services_select_authenticated" ON provider_services;
CREATE POLICY "provider_services_select_authenticated" ON provider_services FOR SELECT
  TO authenticated USING (true);

-- Organisation members can insert services for their providers
DROP POLICY IF EXISTS "provider_services_insert_org_members" ON provider_services;
CREATE POLICY "provider_services_insert_org_members" ON provider_services FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (
      SELECT 1 FROM service_providers sp
      JOIN merchants m ON m.id = sp.merchant_id
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE sp.id = provider_services.provider_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- Organisation members can update services for their providers
DROP POLICY IF EXISTS "provider_services_update_org_members" ON provider_services;
CREATE POLICY "provider_services_update_org_members" ON provider_services FOR UPDATE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM service_providers sp
      JOIN merchants m ON m.id = sp.merchant_id
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE sp.id = provider_services.provider_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM service_providers sp
      JOIN merchants m ON m.id = sp.merchant_id
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE sp.id = provider_services.provider_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- Organisation members can delete services for their providers
DROP POLICY IF EXISTS "provider_services_delete_org_members" ON provider_services;
CREATE POLICY "provider_services_delete_org_members" ON provider_services FOR DELETE
  TO authenticated USING (
    EXISTS (
      SELECT 1 FROM service_providers sp
      JOIN merchants m ON m.id = sp.merchant_id
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE sp.id = provider_services.provider_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- ---------------------------------------------------------------------------
-- Service Bookings (user bookings for a provider service)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_bookings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id uuid NOT NULL REFERENCES service_providers(id),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  service_id uuid NOT NULL REFERENCES provider_services(id),
  scheduled_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','confirmed','completed','cancelled','scheduled')),
  price numeric(12,2) NOT NULL,
  currency_code text NOT NULL DEFAULT 'MUR',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE service_bookings ENABLE ROW LEVEL SECURITY;

-- Users can see their own bookings + org members can see bookings for their providers
DROP POLICY IF EXISTS "service_bookings_select_own_or_org" ON service_bookings;
CREATE POLICY "service_bookings_select_own_or_org" ON service_bookings FOR SELECT
  TO authenticated USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM service_providers sp
      JOIN merchants m ON m.id = sp.merchant_id
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE sp.id = service_bookings.provider_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- Users can create bookings for themselves
DROP POLICY IF EXISTS "service_bookings_insert_own" ON service_bookings;
CREATE POLICY "service_bookings_insert_own" ON service_bookings FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

-- Users can update their own bookings + org members can update (confirm/cancel)
DROP POLICY IF EXISTS "service_bookings_update_own_or_org" ON service_bookings;
CREATE POLICY "service_bookings_update_own_or_org" ON service_bookings FOR UPDATE
  TO authenticated USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM service_providers sp
      JOIN merchants m ON m.id = sp.merchant_id
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE sp.id = service_bookings.provider_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  ) WITH CHECK (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM service_providers sp
      JOIN merchants m ON m.id = sp.merchant_id
      JOIN business_users bu ON bu.organisation_id = m.organisation_id
      WHERE sp.id = service_bookings.provider_id
      AND bu.user_id = auth.uid()
      AND bu.status = 'active'
    )
  );

-- Users can cancel their own bookings
DROP POLICY IF EXISTS "service_bookings_delete_own" ON service_bookings;
CREATE POLICY "service_bookings_delete_own" ON service_bookings FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_service_providers_merchant_id ON service_providers(merchant_id);
CREATE INDEX IF NOT EXISTS idx_service_providers_category_code ON service_providers(category_code);
CREATE INDEX IF NOT EXISTS idx_service_providers_subcategory_code ON service_providers(subcategory_code);
CREATE INDEX IF NOT EXISTS idx_service_providers_status ON service_providers(status);
CREATE INDEX IF NOT EXISTS idx_provider_services_provider_id ON provider_services(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_services_is_active ON provider_services(is_active);
CREATE INDEX IF NOT EXISTS idx_service_bookings_provider_id ON service_bookings(provider_id);
CREATE INDEX IF NOT EXISTS idx_service_bookings_user_id ON service_bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_service_bookings_service_id ON service_bookings(service_id);
CREATE INDEX IF NOT EXISTS idx_service_bookings_status ON service_bookings(status);
CREATE INDEX IF NOT EXISTS idx_service_bookings_scheduled_at ON service_bookings(scheduled_at);
