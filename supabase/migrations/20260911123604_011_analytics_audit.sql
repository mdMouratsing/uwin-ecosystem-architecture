/*
# Analytics Events and Audit Logs

1. Purpose
This migration creates the standard analytics event schema and the central
audit log. Analytics events follow a uniform structure across all applications.
PII is kept out of event properties — user identifiers are used instead of
copying personal information into event tables. Audit logs track important
administrative actions with before/after values.

2. New Tables
- `analytics_events` — standard analytics event records (all apps emit these)
- `audit_logs` — administrative action records (actor, action, before/after)

3. Analytics Event Schema
Every event contains: event_id (unique), event_name, user_id (nullable for
anonymous), anonymous_id, session_id, organisation_id, merchant_id,
application_code, screen_name, timestamp, country_code, properties (JSONB).
PII is NOT stored in properties — only the user_id reference.

4. Audit Log Schema
Each record contains: actor_id, action, entity_type, entity_id, previous_value
(JSONB), new_value (JSONB), metadata, ip_address, user_agent, timestamp.

5. Security
- RLS enabled on both tables.
- Analytics events: users can see their own events. No INSERT/UPDATE/DELETE
  for regular users — events are written through SECURITY DEFINER functions.
- Audit logs: readable only by platform admins and analysts. No INSERT for
  regular users — audit records are written by privileged functions.
*/

-- ---------------------------------------------------------------------------
-- Analytics Events
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id text UNIQUE NOT NULL,
  event_name text NOT NULL,
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  anonymous_id text,
  session_id text,
  organisation_id uuid,
  merchant_id uuid,
  application_code text,
  screen_name text,
  timestamp timestamptz NOT NULL DEFAULT now(),
  country_code text,
  properties jsonb NOT NULL DEFAULT '{}'::jsonb
);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "analytics_events_select_own" ON analytics_events;
CREATE POLICY "analytics_events_select_own" ON analytics_events FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- No INSERT/UPDATE/DELETE for regular users — events are written server-side

-- ---------------------------------------------------------------------------
-- Audit Logs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  previous_value jsonb,
  new_value jsonb,
  metadata jsonb,
  ip_address text,
  user_agent text,
  timestamp timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Audit logs are readable by platform admins and analysts only
DROP POLICY IF EXISTS "audit_logs_select_admin" ON audit_logs;
CREATE POLICY "audit_logs_select_admin" ON audit_logs FOR SELECT
  TO authenticated USING (
    has_role('ids_super_admin') OR has_role('platform_admin') OR has_role('analyst') OR has_role('finance_officer')
  );

-- No INSERT/UPDATE/DELETE for regular users — audit records are written by
-- SECURITY DEFINER functions.

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX IF NOT EXISTS idx_analytics_events_event_name ON analytics_events(event_name);
CREATE INDEX IF NOT EXISTS idx_analytics_events_application_code ON analytics_events(application_code);
CREATE INDEX IF NOT EXISTS idx_analytics_events_timestamp ON analytics_events(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_type ON audit_logs(entity_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
