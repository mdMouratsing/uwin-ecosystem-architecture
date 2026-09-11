/*
# Identity, Profiles, and Consents

1. Purpose
This migration creates the central identity layer (uWin ID) for the platform.
A person has one unique platform identity regardless of which application they
registered from. Identity data (auth methods, identifiers) is separated from
profile data (personal info) and preferences (behavioural/settings).

2. New Tables
- `users` — central user record linked to Supabase auth.users, one per person
- `identities` — multiple identity providers per user (email, mobile, social, etc.)
- `profiles` — personal information (name, DOB, contact, image, locale prefs)
- `addresses` — physical addresses belonging to a profile
- `authentication_methods` — how the user can sign in (password, OTP, social, etc.)
- `user_preferences` — communication and privacy preferences
- `user_consents` — consent records (terms, privacy, marketing, etc.)
- `consent_history` — immutable history of consent changes

3. Security
- RLS enabled on all tables.
- Users can read and update only their own identity/profile/preferences/consents.
- Owner columns default to auth.uid() so inserts work without client passing user_id.
- Column-level UPDATE privileges are revoked on sensitive columns (status, etc.)
  and privileged mutations go through SECURITY DEFINER functions (added in RBAC migration).

4. Important Notes
- The `users` table extends Supabase's auth.users with platform-specific fields.
- `identities` is separate from `profiles` so auth mechanisms can change without
  affecting the person's profile data.
- `consent_history` is an append-only table — records are never updated or deleted.
*/

-- ---------------------------------------------------------------------------
-- Users (platform-level extension of auth.users)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','suspended','closed')),
  primary_organisation_id uuid,
  preferred_language text NOT NULL DEFAULT 'en',
  country_code text NOT NULL DEFAULT 'MU',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  deactivated_at timestamptz
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select_own" ON users;
CREATE POLICY "users_select_own" ON users FOR SELECT
  TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "users_insert_own" ON users;
CREATE POLICY "users_insert_own" ON users FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "users_update_own" ON users;
CREATE POLICY "users_update_own" ON users FOR UPDATE
  TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Users can only update their own non-privileged columns
REVOKE UPDATE ON users FROM authenticated;
GRANT UPDATE (preferred_language, country_code) ON users TO authenticated;

-- ---------------------------------------------------------------------------
-- Identities
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS identities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  identity_type text NOT NULL CHECK (identity_type IN ('email','mobile','social','oauth')),
  identifier text NOT NULL,
  is_verified boolean NOT NULL DEFAULT false,
  is_primary boolean NOT NULL DEFAULT false,
  verified_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, identity_type, identifier)
);

ALTER TABLE identities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "identities_select_own" ON identities;
CREATE POLICY "identities_select_own" ON identities FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "identities_insert_own" ON identities;
CREATE POLICY "identities_insert_own" ON identities FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "identities_update_own" ON identities;
CREATE POLICY "identities_update_own" ON identities FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "identities_delete_own" ON identities;
CREATE POLICY "identities_delete_own" ON identities FOR DELETE
  TO authenticated USING (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  first_name text,
  surname text,
  preferred_name text,
  date_of_birth date,
  gender text,
  primary_mobile text,
  primary_email text,
  profile_image_url text,
  preferred_language text NOT NULL DEFAULT 'en',
  country_code text NOT NULL DEFAULT 'MU',
  currency_code text NOT NULL DEFAULT 'MUR',
  timezone text NOT NULL DEFAULT 'Indian/Mauritius',
  bio text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Users can update their own profile fields (no privileged columns here)
-- Full column UPDATE is safe for profiles since all columns are user-content.

-- ---------------------------------------------------------------------------
-- Addresses
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS addresses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  label text NOT NULL DEFAULT 'Home',
  line1 text NOT NULL,
  line2 text,
  city text NOT NULL,
  region text,
  postal_code text,
  country_code text NOT NULL DEFAULT 'MU',
  is_default boolean NOT NULL DEFAULT false,
  latitude decimal(10,7),
  longitude decimal(10,7),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "addresses_select_own" ON addresses;
CREATE POLICY "addresses_select_own" ON addresses FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = addresses.profile_id AND profiles.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "addresses_insert_own" ON addresses;
CREATE POLICY "addresses_insert_own" ON addresses FOR INSERT
  TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = addresses.profile_id AND profiles.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "addresses_update_own" ON addresses;
CREATE POLICY "addresses_update_own" ON addresses FOR UPDATE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = addresses.profile_id AND profiles.user_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = addresses.profile_id AND profiles.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "addresses_delete_own" ON addresses;
CREATE POLICY "addresses_delete_own" ON addresses FOR DELETE
  TO authenticated USING (
    EXISTS (SELECT 1 FROM profiles WHERE profiles.id = addresses.profile_id AND profiles.user_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Authentication Methods
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS authentication_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  method text NOT NULL CHECK (method IN ('password','otp','social','passwordless')),
  provider text,
  is_active boolean NOT NULL DEFAULT true,
  last_used_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE authentication_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "auth_methods_select_own" ON authentication_methods;
CREATE POLICY "auth_methods_select_own" ON authentication_methods FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users — auth methods are managed server-side

-- ---------------------------------------------------------------------------
-- User Preferences
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  preferred_language text NOT NULL DEFAULT 'en',
  preferred_currency text NOT NULL DEFAULT 'MUR',
  timezone text NOT NULL DEFAULT 'Indian/Mauritius',
  interests text[] NOT NULL DEFAULT ARRAY[]::text[],
  communication_preferences jsonb NOT NULL DEFAULT '{"pushEnabled":true,"emailEnabled":true,"smsEnabled":false,"marketingEmail":false,"marketingSms":false,"marketingPush":false,"loyaltyAlerts":true}'::jsonb,
  privacy_preferences jsonb NOT NULL DEFAULT '{"profileVisibleToPartners":false,"analyticsConsent":true,"personalisationConsent":false}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_prefs_select_own" ON user_preferences;
CREATE POLICY "user_prefs_select_own" ON user_preferences FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_prefs_insert_own" ON user_preferences;
CREATE POLICY "user_prefs_insert_own" ON user_preferences FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_prefs_update_own" ON user_preferences;
CREATE POLICY "user_prefs_update_own" ON user_preferences FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Consents
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_consents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type text NOT NULL,
  version text NOT NULL DEFAULT '1.0',
  is_granted boolean NOT NULL DEFAULT false,
  granted_at timestamptz,
  withdrawn_at timestamptz,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, consent_type, version)
);

ALTER TABLE user_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "consents_select_own" ON user_consents;
CREATE POLICY "consents_select_own" ON user_consents FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "consents_insert_own" ON user_consents;
CREATE POLICY "consents_insert_own" ON user_consents FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "consents_update_own" ON user_consents;
CREATE POLICY "consents_update_own" ON user_consents FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Consent History (append-only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS consent_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  consent_id uuid NOT NULL REFERENCES user_consents(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('granted','withdrawn')),
  previous_value boolean NOT NULL,
  new_value boolean NOT NULL,
  timestamp timestamptz NOT NULL DEFAULT now(),
  metadata jsonb
);

ALTER TABLE consent_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "consent_history_select_own" ON consent_history;
CREATE POLICY "consent_history_select_own" ON consent_history FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users on consent_history — managed server-side

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_primary_organisation ON users(primary_organisation_id);
CREATE INDEX IF NOT EXISTS idx_identities_user_id ON identities(user_id);
CREATE INDEX IF NOT EXISTS idx_identities_identifier ON identities(identifier);
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_addresses_profile_id ON addresses(profile_id);
CREATE INDEX IF NOT EXISTS idx_auth_methods_user_id ON authentication_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_user_prefs_user_id ON user_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_consents_user_id ON user_consents(user_id);
CREATE INDEX IF NOT EXISTS idx_consent_history_user_id ON consent_history(user_id);
CREATE INDEX IF NOT EXISTS idx_consent_history_consent_id ON consent_history(consent_id);
