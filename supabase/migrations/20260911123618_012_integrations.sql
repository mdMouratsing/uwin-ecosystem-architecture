/*
# Integration Configuration and Webhook Subscriptions

1. Purpose
This migration creates placeholder interfaces for future external integrations
(IDS Voucher Hub, CORE ERP, KiDir, payment gateways, SMS/email providers, etc.)
and the webhook subscription architecture for outgoing platform events.

2. New Tables
- `integration_configs` — configuration records for external integrations
- `webhook_subscriptions` — subscriptions to platform events (outgoing webhooks)

3. Webhook Structure
Each webhook subscription specifies an event type and a target URL. The platform
will send signed payloads to the target URL when the event occurs. The payload
includes event ID, event type, timestamp, and data — signature-ready structure.

4. Security
- RLS enabled on both tables.
- Both tables are readable only by platform admins.
- No INSERT/UPDATE/DELETE for regular users.
*/

-- ---------------------------------------------------------------------------
-- Integration Configs
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS integration_configs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  integration_key text UNIQUE NOT NULL,
  name text NOT NULL,
  provider text,
  configuration jsonb,
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE integration_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "integration_configs_select_admin" ON integration_configs;
CREATE POLICY "integration_configs_select_admin" ON integration_configs FOR SELECT
  TO authenticated USING (
    has_role('ids_super_admin') OR has_role('platform_admin')
  );

-- Seed placeholder integration configs
INSERT INTO integration_configs (integration_key, name, provider, is_active) VALUES
  ('ids_voucher_hub', 'IDS Voucher Hub', 'IDS', false),
  ('core_erp', 'CORE ERP', 'IDS', false),
  ('kidir', 'KiDir', 'IDS', false),
  ('visit_mauritius', 'Visit Mauritius', 'External', false),
  ('visit_africa', 'Visit Africa', 'External', false),
  ('persona_insight', 'Persona Insight', 'IDS', false),
  ('payment_gateway', 'Payment Gateway', 'TBD', false),
  ('sms_provider', 'SMS Provider', 'TBD', false),
  ('email_provider', 'Email Provider', 'TBD', false),
  ('push_notification', 'Push Notification Service', 'TBD', false),
  ('mapping_service', 'Mapping Service', 'TBD', false),
  ('accounting_system', 'Accounting System', 'TBD', false),
  ('pos_system', 'POS System', 'TBD', false)
ON CONFLICT (integration_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Webhook Subscriptions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS webhook_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  target_url text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  secret text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE webhook_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "webhook_subscriptions_select_admin" ON webhook_subscriptions;
CREATE POLICY "webhook_subscriptions_select_admin" ON webhook_subscriptions FOR SELECT
  TO authenticated USING (
    has_role('ids_super_admin') OR has_role('platform_admin')
  );

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_integration_configs_key ON integration_configs(integration_key);
CREATE INDEX IF NOT EXISTS idx_webhook_subscriptions_event_type ON webhook_subscriptions(event_type);
CREATE INDEX IF NOT EXISTS idx_webhook_subscriptions_is_active ON webhook_subscriptions(is_active);
