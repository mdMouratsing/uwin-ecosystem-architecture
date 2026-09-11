/*
# Notification Service

1. Purpose
This migration creates the shared notification architecture. All future apps
publish notifications through this common service. Supports in-app, push-ready,
email-ready, and SMS-ready channels. Mandatory transactional messages are
distinguished from marketing communication.

2. New Tables
- `notifications` — individual notification records
- `notification_templates` — templates per type, channel, and locale
- `notification_preferences` — user's channel and category preferences
- `notification_deliveries` — delivery records per channel
- `notification_channels` — reference table for supported channels

3. Security
- RLS enabled on all tables.
- Users can read and update (mark read) only their own notifications.
- Notification preferences are read/update by the owner only.
- Notification templates are readable by all authenticated users.
- Notification deliveries are read-only for the notification owner.
- No INSERT for regular users on notifications — they are created by the
  cross-service function or SECURITY DEFINER functions.
*/

-- ---------------------------------------------------------------------------
-- Notification Channels (reference)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_type text UNIQUE NOT NULL CHECK (channel_type IN ('in_app','push','email','sms')),
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE notification_channels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notif_channels_select_authenticated" ON notification_channels;
CREATE POLICY "notif_channels_select_authenticated" ON notification_channels FOR SELECT
  TO authenticated USING (true);

INSERT INTO notification_channels (channel_type, name, is_active) VALUES
  ('in_app', 'In-App', true),
  ('push', 'Push', true),
  ('email', 'Email', true),
  ('sms', 'SMS', true)
ON CONFLICT (channel_type) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_type text NOT NULL,
  category text NOT NULL DEFAULT 'transactional' CHECK (category IN ('transactional','marketing','security','loyalty')),
  title text NOT NULL,
  body text NOT NULL,
  data jsonb,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamptz,
  application_code text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select_own" ON notifications;
CREATE POLICY "notifications_select_own" ON notifications FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

-- Users can update is_read and read_at only
REVOKE UPDATE ON notifications FROM authenticated;
GRANT UPDATE (is_read, read_at) ON notifications TO authenticated;

DROP POLICY IF EXISTS "notifications_update_own" ON notifications;
CREATE POLICY "notifications_update_own" ON notifications FOR UPDATE
  TO authenticated USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Notification Templates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_type text NOT NULL,
  channel text NOT NULL CHECK (channel IN ('in_app','push','email','sms')),
  locale text NOT NULL DEFAULT 'en',
  subject_template text NOT NULL,
  body_template text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  UNIQUE(notification_type, channel, locale)
);

ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notif_templates_select_authenticated" ON notification_templates;
CREATE POLICY "notif_templates_select_authenticated" ON notification_templates FOR SELECT
  TO authenticated USING (true);

-- ---------------------------------------------------------------------------
-- Notification Preferences
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  push_transactional boolean NOT NULL DEFAULT true,
  push_marketing boolean NOT NULL DEFAULT false,
  email_transactional boolean NOT NULL DEFAULT true,
  email_marketing boolean NOT NULL DEFAULT false,
  sms_transactional boolean NOT NULL DEFAULT true,
  sms_marketing boolean NOT NULL DEFAULT false,
  loyalty_alerts boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notif_prefs_select_own" ON notification_preferences;
CREATE POLICY "notif_prefs_select_own" ON notification_preferences FOR SELECT
  TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notif_prefs_insert_own" ON notification_preferences;
CREATE POLICY "notif_prefs_insert_own" ON notification_preferences FOR INSERT
  TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "notif_prefs_update_own" ON notification_preferences;
CREATE POLICY "notif_prefs_update_own" ON notification_preferences FOR UPDATE
  TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Notification Deliveries
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('in_app','push','email','sms')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','sent','delivered','failed')),
  provider_reference text,
  sent_at timestamptz,
  delivered_at timestamptz,
  error text,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE notification_deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notif_deliveries_select_own" ON notification_deliveries;
CREATE POLICY "notif_deliveries_select_own" ON notification_deliveries FOR SELECT
  TO authenticated USING (
    EXISTS (SELECT 1 FROM notifications WHERE notifications.id = notification_deliveries.notification_id AND notifications.user_id = auth.uid())
  );

-- No INSERT/UPDATE/DELETE for regular users

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_templates_type ON notification_templates(notification_type);
CREATE INDEX IF NOT EXISTS idx_notif_prefs_user_id ON notification_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_notif_deliveries_notification_id ON notification_deliveries(notification_id);
