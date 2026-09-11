```text
Document: IDS uWin & RetailFlow Shared Architecture Contract
Version: 1.0
Status: Foundation Architecture
Last Updated: 2026-09-11
Owner: IDS — Intelligent Digitalisation Solutions
```

> This document is the architectural source of truth for all uWin and RetailFlow application projects unless superseded by a later approved version.

---

## 1. Purpose

The IDS ecosystem follows one governing principle:

**ONE PLATFORM — MULTIPLE APPS — ONE IDENTITY — SHARED SERVICES**

Future applications must reuse the shared platform rather than recreate core services. The platform layer — identity, wallet, rewards, merchants, vouchers, campaigns, notifications, analytics, RBAC — sits between IDS infrastructure and the application ecosystem. Consumer apps (uWin family) and business apps (RetailFlow family) both consume the same shared services.

**Current planned applications:**

| Code | Name | Type |
|------|------|------|
| `uwin` | uWin | Consumer |
| `uwin_rewards` | uWin Rewards | Consumer |
| `uwin_market` | uWin Market | Consumer |
| `uwin_services` | uWin Services | Consumer |
| `uwin_travel` | uWin Travel | Consumer |
| `uwin_resto` | uWin Resto | Consumer |
| `uwin_business` | uWin Business | Business |
| `retailflow` | RetailFlow | Business |
| `retailflow_resto` | RetailFlow Resto | Business |

---

## 2. Non-Negotiable Architecture Rules

1. Use uWin ID for consumer identity.
2. Do not create another central user identity system.
3. Use the shared organisation and merchant model.
4. Use the central Merchant Directory.
5. Use the shared uWin Wallet.
6. Use the shared Rewards Engine.
7. Use the common Voucher architecture.
8. Use the common Campaign service.
9. Use the shared Notification service.
10. Use the common RBAC and permission model.
11. Use the standard Analytics Event model.
12. Use shared API conventions.
13. Use shared TypeScript types where available.
14. Use the shared design system.
15. Respect multi-tenant organisation and branch boundaries.
16. Do not duplicate shared business logic inside individual apps.
17. App-specific functionality must reference shared IDs.
18. Every transaction/activity must identify its originating application/channel.
19. Shared services own their respective domains.
20. Any new cross-ecosystem capability must be considered for the shared platform before being implemented inside one app.

---

## 3. Shared Platform Services

Each service owns its domain. App-specific projects must consume or extend these services rather than recreate them.

### Identity Service

Owns: `User`, `Identity`, `Authentication`, `Profile`, `Consent`

### Organisation / Merchant Service

Owns: `Organisation`, `Branch`, `Merchant`, `MerchantLocation`, `MerchantCapability`, `BusinessMembership`

### Wallet Service

Owns: `Wallet`, `WalletAccount`, `WalletAsset`, `WalletTransaction`

### Rewards Service

Owns: `RewardProgramme`, `RewardRule`, `RewardAccount`, `RewardTransaction`, `RewardTier`

### Voucher Service

Owns: `VoucherTemplate`, `Voucher`, `VoucherRedemption`

### Campaign Service

Owns: `Campaign`, `CampaignRule`, `CampaignTarget`

### Notification Service

Owns: `Notification`, `NotificationTemplate`, `NotificationPreferences`, `NotificationDelivery`

### Analytics Service

Owns: `AnalyticsEvent` conventions, application/channel attribution, event identifiers

### Permissions Service

Owns: `Role`, `Permission`, `RolePermission`, `UserRole`, scope definitions

---

## 4. Canonical Shared Identifiers

| Identifier | Used When |
|------------|-----------|
| `user_id` | Referencing the central platform user across any service or app table |
| `profile_id` | Referencing a user's profile data |
| `organisation_id` | Referencing a business entity in any tenant-scoped context |
| `branch_id` | Referencing a specific physical location within an organisation |
| `merchant_id` | Referencing a merchant in the central directory |
| `wallet_id` | Referencing a user's wallet in any transaction or balance context |
| `reward_programme_id` | Referencing a rewards programme |
| `reward_account_id` | Referencing a user's account within a programme |
| `voucher_id` | Referencing an issued voucher |
| `campaign_id` | Referencing a campaign across rules, targets, redemptions |
| `notification_id` | Referencing a notification record |
| `application_code` | Identifying which app/channel initiated an activity (see §5) |

---

## 5. Approved Application Codes

```text
uwin
uwin_rewards
uwin_market
uwin_services
uwin_travel
uwin_business
uwin_resto
retailflow
retailflow_resto
```

The code `platform_admin` is reserved for the IDS internal administration environment.

Future apps must use these codes consistently in:

- analytics events (`application_code` column)
- wallet transactions (`application_code` column)
- reward transactions (`application_code` column)
- notifications (`application_code` column)
- campaign records (`application_code` column)
- audit trail metadata
- API metadata
- integration payloads

The canonical TypeScript type is `ApplicationCode` in `packages/shared-types`.

---

## 6. Shared Database Rules

**Implemented** on the provisioned Supabase PostgreSQL database.

### Conventions

- UUID primary keys on all tables
- Foreign-key integrity with appropriate `ON DELETE` actions
- `created_at` / `updated_at` timestamps on all mutable tables
- Explicit lifecycle status fields (not booleans) — see status enums below
- Soft deletion via `deleted_at` where appropriate (e.g. `organisations`)
- Tenant-aware records with `organisation_id` or `user_id` ownership
- No duplicated central user table
- No duplicated merchant directory
- No duplicated wallet ledger
- No duplicated rewards ledger
- Immutable/auditable ledger transactions (`wallet_transactions`, `reward_transactions`)
- Corrections through reversal or adjustment transactions, never by overwriting history
- Idempotency keys on transactional operations (`idempotency_key` column with unique index)

### Canonical Shared Tables (Implemented)

```text
currencies
countries
languages
applications
feature_flags

users
identities
profiles
addresses
authentication_methods
user_preferences
user_consents
consent_history

organisation_types
organisations
branches
departments
business_users
business_roles

merchants
merchant_categories
merchant_locations
merchant_capabilities
merchant_channels

wallet_transaction_types
wallets
wallet_accounts
wallet_assets
wallet_transactions

reward_programmes
reward_rules
reward_accounts
reward_transactions
reward_tiers

voucher_templates
voucher_batches
vouchers
voucher_redemptions
voucher_rules

campaigns
campaign_rules
campaign_targets
campaign_assets
campaign_redemptions
campaign_metrics

roles
permissions
role_permissions
user_roles

notifications
notification_templates
notification_preferences
notification_deliveries
notification_channels

analytics_events
audit_logs

integration_configs
webhook_subscriptions
```

### Status Enums (Implemented)

| Domain | Statuses |
|--------|----------|
| User | `pending`, `active`, `suspended`, `closed` |
| Merchant | `draft`, `pending_review`, `active`, `suspended`, `inactive` |
| Voucher | `issued`, `active`, `redeemed`, `expired`, `cancelled` |
| Campaign | `draft`, `scheduled`, `active`, `paused`, `completed`, `cancelled` |
| Wallet Transaction | `pending`, `completed`, `failed`, `reversed` |

---

## 7. Authentication and uWin ID

### Implemented

- Supabase email/password authentication as the basis for uWin ID
- `users` table extends `auth.users` with platform-specific fields (status, preferred language, country, primary organisation)
- User identity is independent of the application from which they registered — one `user_id` works across all apps
- `identities` table separates authentication identifiers (email, mobile, social) from the core user record
- `authentication_methods` table records how a user can sign in (password, OTP, social, passwordless)
- Business users share the same central identity — a `business_users` record links a `user_id` to an `organisation_id`
- Consumer and business roles may coexist for one user (a person can be a uWin consumer and a restaurant manager simultaneously)
- Session handling via Supabase auth sessions with `onAuthStateChange`
- Row Level Security on all identity tables — users see only their own identity/profile/consent data
- Column-level UPDATE privileges revoked on `users.status` — status changes go through `set_user_status()` SECURITY DEFINER function

### Planned

- Mobile number and OTP authentication (data model architected, not wired to UI)
- Passwordless login (data model architected, not wired to UI)
- Social authentication (data model architected, not wired to UI)
- Single Sign-On (SSO) allowing users to switch applications without re-authenticating — architectural foundation in place (one identity, one session), cross-app SSO flow not yet implemented

---

## 8. Multi-Tenancy and Data Access

### Implemented

- Row Level Security enabled on every tenant-sensitive table
- Organisation-scoped tables use `business_users` membership checks in RLS policies — a user can only see organisations where they have an active `business_users` record
- Branch-scoped data inherits organisation-level access through the parent organisation
- User-owned data (profiles, wallets, rewards, notifications) uses `auth.uid() = user_id` ownership checks
- Platform/admin-scoped data (audit logs, integration configs, webhook subscriptions) requires platform-level roles

### Scopes

| Scope | Meaning |
|-------|---------|
| `platform` | Access across the entire platform (IDS admins) |
| `organisation` | Access within one organisation |
| `branch` | Access within one branch of an organisation |
| `own` | Access only to the user's own data |

**A user must never gain access to another organisation's restricted data merely because the UI hides it.** Security is enforced server-side at the database policy level (RLS) and through SECURITY DEFINER functions for privileged mutations.

---

## 9. Roles and Permission Convention

### Implemented

**Permission naming convention:** `domain.action`

```text
users.view
users.manage
organisations.view
organisations.manage
merchants.view
merchants.edit
merchants.manage
wallet.view
wallet.adjust
rewards.view
rewards.adjust
vouchers.view
vouchers.redeem
vouchers.manage
campaigns.view
campaigns.create
campaigns.approve
notifications.view
analytics.view
audit.view
roles.manage
branches.manage
```

### Configured Roles (Implemented — seeded in database)

| Role Key | Name | Scope |
|----------|------|-------|
| `ids_super_admin` | IDS Super Admin | platform |
| `platform_admin` | Platform Administrator | platform |
| `support_agent` | Support Agent | platform |
| `finance_officer` | Finance Officer | platform |
| `campaign_manager` | Campaign Manager | platform |
| `analyst` | Analyst | platform |
| `content_manager` | Content Manager | platform |
| `business_owner` | Business Owner | organisation |
| `business_admin` | Business Administrator | organisation |
| `branch_manager` | Branch Manager | branch |
| `staff` | Staff | branch |
| `sales_representative` | Sales Representative | branch |
| `restaurant_manager` | Restaurant Manager | branch |
| `cashier` | Cashier | branch |
| `warehouse_manager` | Warehouse Manager | branch |
| `driver` | Driver | branch |

### Structure

- `roles` — role definitions with `role_key`, `scope`, and `is_system` flag
- `permissions` — structured permission keys with `scope`
- `role_permissions` — mapping table (many-to-many)
- `user_roles` — user-to-role assignments with `scope` and `scope_ref` (for organisation/branch-specific assignments)
- `business_roles` — organisation-level role assignments scoped to a business user

### Privileged Functions (Implemented — SECURITY DEFINER)

| Function | Authorization |
|----------|--------------|
| `assign_role(user_id, role_key, scope, scope_ref)` | `ids_super_admin` or `platform_admin` |
| `set_user_status(user_id, status)` | `ids_super_admin` or `platform_admin` |
| `set_merchant_status(merchant_id, status)` | `ids_super_admin`, `platform_admin`, `business_admin`, or `business_owner` |
| `cancel_voucher(voucher_id)` | `ids_super_admin` or `platform_admin` |
| `has_role(role_key)` | Helper — checks caller's role membership |

---

## 10. Wallet and Ledger Rules

**Implemented.** There is one shared uWin Wallet architecture. A consumer uses the same wallet across all participating applications.

### Wallet Structure

- `wallets` — one wallet per user (unique on `user_id`)
- `wallet_accounts` — sub-accounts per asset type within a wallet
- `wallet_assets` — individual asset references (vouchers, gift cards)
- `wallet_transactions` — the immutable ledger

### Asset Types (Implemented)

```text
loyalty_points
cashback
promotional_credit
gift_card
prepaid_balance
merchant_credit
```

### Transaction Types (Implemented)

```text
credit
debit
earn
redeem
adjustment
expiry
refund
reversal
transfer
```

### Ledger Integrity Rules

- `wallet_transactions` is an append-only ledger — historical transactions are never overwritten or deleted
- Balances are derived from ledger transaction history; the `balance` column on `wallet_accounts` is a cached derivation for performance, not the source of truth
- Corrections use `reversal` or `adjustment` transaction types that reference the original via `related_transaction_id`
- `idempotency_key` column with a unique partial index prevents duplicate credits from retried API requests
- No INSERT/UPDATE/DELETE for regular users on `wallet_transactions` — all transactions are created through the `process_cross_service_transaction()` SECURITY DEFINER function
- The `balance` column on `wallet_accounts` is not client-writable — UPDATE privilege is revoked from `authenticated`

---

## 11. Rewards Contract

**Implemented.** One rewards account per user per programme. Reward balances are never duplicated between applications.

### Structure

- `reward_programmes` — a rewards programme (ecosystem-wide or merchant-specific)
- `reward_rules` — configurable rules (not hard-coded) defining how rewards are earned or redeemed
- `reward_accounts` — a user's account within a programme (balance + tier)
- `reward_transactions` — the rewards ledger (immutable)
- `reward_tiers` — tier definitions per programme

### Rules

- An application may trigger a reward event but must not create its own independent rewards balance
- Reward rules are data-driven: conditions stored as JSONB, evaluated server-side by the `process_cross_service_transaction()` function
- Merchant-specific programmes: `reward_rules.merchant_id` scopes a rule to a single merchant
- Ecosystem-wide programmes: `reward_rules.merchant_id` is NULL for rules that apply across all merchants
- Tier names are defined per programme, not hard-coded — each programme defines its own tier names, qualification thresholds (`min_points`), and benefits
- `reward_transactions` is an immutable ledger with the same integrity rules as `wallet_transactions`
- No INSERT/UPDATE/DELETE for regular users — reward credits go through the `process_cross_service_transaction()` function

### Implemented Tiers (uWin Rewards Programme)

| Tier | Min Points | Benefits |
|------|-----------|----------|
| Member | 0 | 0.5% cashback rate |
| Silver | 1,000 | 1% cashback, priority support |
| Gold | 5,000 | 1.5% cashback, priority support, exclusive offers |
| Platinum | 15,000 | 2% cashback, priority support, exclusive offers, free delivery, concierge |

---

## 12. Voucher and Campaign Contract

**Implemented.**

### Domain Distinctions

| Concept | Definition |
|---------|-----------|
| **Voucher** | A digital instrument with a unique code, issued from a template, assigned to a user, redeemable at merchants. Has face value or discount percentage. Stored in `vouchers` table. |
| **Coupon / Promo Code** | A promotional code applied at checkout for a discount. Distinct from a wallet voucher. (Planned — not yet implemented as a separate table.) |
| **Loyalty Reward** | Points earned through the Rewards Engine, stored as `reward_transactions` and reflected in `reward_accounts.current_balance`. Not a voucher. |
| **Campaign** | A time-bound promotional initiative that may issue vouchers, bonus points, discounts, or cashback. Stored in `campaigns` table. |

### How Apps Interact with Vouchers

- **Issue:** Through a SECURITY DEFINER function or server-side process — not direct client INSERT
- **Display:** Apps query `vouchers` where `assigned_to_user_id` matches the user
- **Redeem:** Through a privileged function that records a `voucher_redemption` and updates voucher status
- **Attribute to campaigns:** `voucher_templates.campaign_id` links a voucher to its originating campaign
- **Restrictions:** `category_restrictions`, `merchant_restrictions`, `min_spend`, `max_redemptions` on templates

### How Apps Interact with Campaigns

- **Target:** `campaign_targets` supports targeting by `all_users`, `merchant`, `location`, `category`, `segment`, `tier`, `application`
- **Record source/channel:** `campaigns.application_code` and `campaign_redemptions.application_code`
- **Create/Manage:** Requires organisation membership (RLS enforced)
- **Approve/Activate:** `campaigns.status` is a privileged column — UPDATE revoked from `authenticated`, changes go through privileged functions

---

## 13. API Contract

### Implemented Conventions

- **Versioning:** `/api/v1/` prefix
- **Route naming:** plural resource nouns, kebab-case
- **Authentication:** Supabase auth session (Bearer token)
- **Response format (success):**

```json
{
  "data": {},
  "meta": { "page": 1, "pageSize": 20, "total": 100, "totalPages": 5 }
}
```

- **Response format (error):**

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Resource not found"
  }
}
```

- **Pagination:** `page` / `pageSize` query parameters (default 20, max 100)
- **Filtering:** Query parameters mapped to column filters
- **Sorting:** `sortBy` / `sortOrder` query parameters
- **Idempotency:** `Idempotency-Key` header or `idempotency_key` field for transactional operations

### Canonical/Reserved Endpoints

```text
/api/v1/users
/api/v1/profiles
/api/v1/organisations
/api/v1/merchants
/api/v1/wallets
/api/v1/rewards
/api/v1/vouchers
/api/v1/campaigns
/api/v1/notifications
/api/v1/analytics
```

### Implemented Client

The typed API client is in `packages/api-client/index.ts` with `apiGet`, `apiGetList`, `apiPost`, `apiPut`, `apiDelete` helpers and `ApiClientError` with `getUserFacingMessage()` for safe error display.

---

## 14. Event Contract

### Platform / Domain Events

Used for internal platform coordination, webhooks, and audit trails.

```text
user.created
profile.updated
merchant.created
wallet.transaction.created
reward.earned
reward.redeemed
voucher.issued
voucher.redeemed
campaign.activated
notification.requested
```

**Platform event payload structure** (TypeScript: `PlatformEvent` in `packages/shared-types`):

```typescript
interface PlatformEvent<T> {
  eventId: string;
  eventType: string;
  timestamp: string;   // ISO 8601
  payload: T;
}
```

### Analytics Events

Used for behavioural analytics across all applications. Stored in the `analytics_events` table.

**Standard event names:**

```text
app_opened
user_registered
user_logged_in
merchant_viewed
offer_viewed
voucher_saved
reward_earned
reward_redeemed
```

**Analytics event payload structure** (TypeScript: `AnalyticsEvent` in `packages/shared-types`, implemented as `analytics_events` table):

```text
event_id          — unique identifier (text)
event_name        — standard event name
user_id           — UUID (nullable for anonymous events)
anonymous_id      — text (nullable)
session_id        — text (nullable)
organisation_id   — UUID (nullable)
merchant_id       — UUID (nullable)
application_code  — which app emitted the event
screen_name       — text (nullable)
timestamp         — timestamptz
country_code      — text (nullable)
properties        — JSONB (no PII — use user_id reference instead)
```

**PII must not be stored in `properties`.** Use `user_id` to reference the user; join to profile data server-side if needed.

---

## 15. Notification Contract

**Implemented.**

### How Future Apps Request Notifications

Future apps do not insert directly into the `notifications` table. Notifications are created by:

1. The `process_cross_service_transaction()` function (for `REWARD_EARNED`)
2. Future SECURITY DEFINER functions for other notification types
3. Server-side processes that check user preferences before creating a notification

### Notification Record Structure

| Field | Description |
|-------|-------------|
| `notification_type` | One of the types listed below |
| `user_id` | Recipient |
| `category` | `transactional`, `marketing`, `security`, or `loyalty` |
| `title` / `body` | Rendered content |
| `data` | JSONB payload with entity references |
| `application_code` | Which app triggered the notification |
| `is_read` / `read_at` | Read state (user can update) |

### Implemented Notification Types

```text
REWARD_EARNED
REWARD_EXPIRING
VOUCHER_RECEIVED
VOUCHER_EXPIRING
CAMPAIGN_AVAILABLE
SYSTEM_MESSAGE
ACCOUNT_SECURITY
```

### Planned Notification Types (Architected, Not Yet Used)

```text
ORDER_CONFIRMED
BOOKING_CONFIRMED
RESERVATION_REMINDER
DELIVERY_UPDATE
```

### Channels

| Channel | Status |
|---------|--------|
| `in_app` | Implemented |
| `push` | Architected (delivery infrastructure Planned) |
| `email` | Architected (delivery infrastructure Planned) |
| `sms` | Architected (delivery infrastructure Planned) |

### Preferences

Users control preferences through `notification_preferences` (push/email/SMS × transactional/marketing + loyalty alerts). Mandatory transactional and security messages are distinguished from marketing — apps must respect preference flags for marketing but may override for mandatory transactional/security messages.

**Future applications must not build a new central notification preference model.** The `notification_preferences` table is the single source of truth.

---

## 16. Design System Contract

**Implemented.**

### Brand Families

Three brand-family token sets are defined as CSS custom properties, selectable by adding a class to a root element:

| Class | Family | Primary | Accent |
|-------|--------|---------|--------|
| _(default)_ | IDS Platform | Charcoal (220° 20% 14%) | Copper (24° 72% 52%) |
| `.brand-uwin` | uWin (consumer) | Teal (190° 85% 28%) | Amber-gold (40° 88% 50%) |
| `.brand-retailflow` | RetailFlow (business) | Slate-blue (215° 45% 28%) | Emerald (152° 52% 40%) |

All three families share structural tokens: `--radius`, typography scale, spacing, shadows, breakpoints, chart colors, and dark mode variants.

### Shared UI Components

Built on shadcn/ui (Radix UI primitives + Tailwind CSS). Components are in `components/ui/`:

`accordion`, `alert`, `alert-dialog`, `avatar`, `badge`, `button`, `calendar`, `card`, `carousel`, `chart`, `checkbox`, `collapsible`, `command`, `context-menu`, `dialog`, `drawer`, `dropdown-menu`, `form`, `hover-card`, `input`, `input-otp`, `label`, `menubar`, `navigation-menu`, `pagination`, `popover`, `progress`, `radio-group`, `resizable`, `scroll-area`, `select`, `separator`, `sheet`, `skeleton`, `slider`, `sonner`, `switch`, `table`, `tabs`, `textarea`, `toast`, `toggle`, `toggle-group`, `tooltip`

### Platform-Specific Composition Components

In `components/admin/`: `AdminShell`, `ProtectedRoute`, `StatCard`, `StatusBadge`

### Design Rules

- Consumer apps may have distinct brand accents (uWin: teal/amber-gold) while sharing structural components
- RetailFlow apps may have a more operational visual treatment (slate-blue/emerald) while sharing structural components
- Shared components and accessibility standards (keyboard navigation, focus states, semantic HTML, WCAG-conscious contrast) remain common
- No purple, indigo, or violet hues unless explicitly requested
- Import path convention: `@/components/ui/<component>` for shadcn primitives, `@/components/admin/<component>` for admin-specific compositions

---

## 17. Internationalisation and Country Configuration

### Implemented

| Setting | Value |
|---------|-------|
| Initial country | **Mauritius** (code: `MU`) |
| Initial currency | **MUR** (Mauritian Rupee) |
| Display symbol | **Rs** |
| Timezone | `Indian/Mauritius` |
| Phone prefix | `+230` |
| Date format | `DD/MM/YYYY` |
| Initial languages | **English** (`en`), **French** (`fr`) |

### Configuration Location

- Country/currency/language config: `packages/config/index.ts` — `COUNTRIES`, `CURRENCIES`, `LANGUAGES` constants
- Database seed: `countries`, `currencies`, `languages` tables
- Translation files: `packages/i18n/index.ts` — `translations.en` and `translations.fr` with `translate(key, locale)` helper
- TypeScript types: `LanguageCode`, `CountryCode`, `CurrencyCode` in `packages/shared-types`

### Future-Ready (Configured, Not Deployed)

| Country | Code | Currency |
|---------|------|----------|
| Réunion | RE | EUR |
| Madagascar | MG | MGA |
| Seychelles | SC | SCR |

The `multi_country_enabled` feature flag is currently `false` — the platform is locked to Mauritius. Enabling it allows multi-country operation.

Future apps must consume shared locale/country configuration rather than hard-code these values. Mauritian Creole (`mfe`) is architecturally supported but not yet translated.

---

## 18. App-Specific Extension Rules

App-specific domain data is allowed. Duplicate shared infrastructure is not.

### Example: uWin Resto

uWin Resto may create app-specific tables such as:

```text
restaurant_profiles
restaurant_menus
menu_items
restaurant_tables
reservations
restaurant_orders
```

These entities are application-specific but must reference shared platform entities through canonical IDs:

```text
merchant_id        → links to merchants table
organisation_id    → links to organisations table
branch_id          → links to branches table
user_id            → links to users table
campaign_id        → links to campaigns table
wallet_transaction_id → links to wallet_transactions table
```

### Rules

- App-specific tables must use UUID primary keys consistent with the platform convention
- App-specific tables that are tenant-sensitive must implement RLS using the same `business_users` membership pattern
- App-specific tables must include `created_at` / `updated_at` timestamps
- App-specific tables must record `application_code` on any record that originates from or is visible through a specific app
- App-specific transactions that earn rewards or affect wallet balances must go through `process_cross_service_transaction()`, not direct table writes

---

## 19. Cross-App Integration Rules

One application's action must be interoperable with another app through the platform — not through direct database access or duplicated business logic.

### Examples

```text
uWin Resto
→ reservation created (app-specific table, references merchant_id + user_id)
→ RetailFlow Resto receives reservation (queries by merchant_id through shared API)
```

```text
RetailFlow Resto
→ menu updated (app-specific table, references merchant_id)
→ uWin Resto displays updated menu (reads through shared merchant_id reference + API)
```

```text
uWin Market
→ customer places order (app-specific, references user_id + merchant_id)
→ wallet transaction recorded through process_cross_service_transaction()
→ reward points credited to user's shared reward account
→ RetailFlow receives fulfilment request (queries by merchant_id through shared API)
→ notification sent to user through shared notification service
```

Integrations should use shared APIs, shared events, and shared identifiers — never direct cross-app database writes or duplicated business logic.

---

## 20. External Integration Pattern

### Implemented

- `integration_configs` table stores configuration for external integrations (key, provider, configuration JSONB, active flag)
- `webhook_subscriptions` table stores outgoing webhook subscriptions (event type, target URL, secret for signing)
- All integration configs are readable only by `ids_super_admin` or `platform_admin` roles

### Placeholder Integrations (Seeded, Not Connected)

```text
ids_voucher_hub      — IDS Voucher Hub
core_erp             — CORE ERP
kidir                — KiDir
visit_mauritius      — Visit Mauritius
visit_africa         — Visit Africa
persona_insight      — Persona Insight
payment_gateway      — Payment Gateway (provider TBD)
sms_provider         — SMS Provider (provider TBD)
email_provider       — Email Provider (provider TBD)
push_notification    — Push Notification Service (provider TBD)
mapping_service      — Mapping Service (provider TBD)
accounting_system    — Accounting System (provider TBD)
pos_system           — POS System (provider TBD)
```

All are seeded with `is_active = false`. Future apps must not hard-code vendor-specific integration logic. External API calls that need server-side secrets must be proxied through Supabase Edge Functions.

### Webhook Payload Structure (Signature-Ready)

```json
{
  "eventId": "uuid",
  "eventType": "reward.earned",
  "timestamp": "2026-09-11T12:00:00Z",
  "payload": {}
}
```

The `secret` column on `webhook_subscriptions` is used to sign outgoing payloads (HMAC implementation: Planned).

---

## 21. Security Contract

### Implemented

- **Server-side authorisation:** RLS enabled on every table; policies use `auth.uid()` for ownership checks and `business_users` membership for tenant checks
- **Row Level Security:** Every table has RLS enabled with explicit policies (4 per CRUD verb where applicable)
- **Column-level privileges:** Sensitive columns (status, balance, role assignments) have UPDATE revoked from `authenticated` — changes go through SECURITY DEFINER functions
- **SECURITY DEFINER functions:** Privileged mutations (role assignment, status changes, voucher cancellation, cross-service transactions) run as table owner with caller authorization checks
- **Validation:** Transaction amounts validated server-side in `process_cross_service_transaction()`; quantity/price validation in functions
- **Tenant separation:** Organisation-scoped tables check `business_users` membership in RLS predicates — a user cannot see another organisation's data
- **Audit logs:** `audit_logs` table records administrative actions with actor, action, entity, before/after values, and metadata
- **No privileged logic in UI alone:** Every privileged operation has a server-side enforcement point (RLS policy or SECURITY DEFINER function)
- **Secrets not exposed client-side:** Supabase keys in `.env`, service role key never exposed to frontend; external API calls proxied through Edge Functions
- **Transactional idempotency:** `idempotency_key` columns with unique partial indexes on `wallet_transactions` and `reward_transactions`
- **Consent/privacy handling:** `user_consents` and `consent_history` (append-only) tables; consent history is never updated or deleted
- **Error messages:** `getUserFacingMessage()` in the API client maps known error codes to safe user-facing messages; raw database errors are never rendered to the UI

### Planned

- HMAC signature verification for outgoing webhooks
- Rate limiting on API endpoints
- IP address and user agent capture on audit logs (fields exist, not yet populated)

---

## 22. Shared TypeScript Contract

### Implemented Packages

| Package | Path | Contents |
|---------|------|----------|
| shared-types | `packages/shared-types/index.ts` | TypeScript interfaces for all domain objects |
| config | `packages/config/index.ts` | Countries, currencies, languages, applications, feature flags, status definitions, API conventions |
| api-client | `packages/api-client/index.ts` | Typed request/response helpers, error handling |
| i18n | `packages/i18n/index.ts` | English and French translations, `translate()` helper |

### Exported Types (from `packages/shared-types`)

```text
User
Identity
AuthenticationMethod
Profile
Address
UserPreferences
CommunicationPreferences
PrivacyPreferences
Consent
ConsentHistory
OrganisationType
Organisation
Branch
Department
BusinessUser
BusinessRole
Merchant
MerchantCategory
MerchantLocation
MerchantCapability
MerchantChannel
Wallet
WalletAccount
WalletAsset
WalletTransaction
RewardProgramme
RewardRule
RewardAccount
RewardTransaction
RewardTier
VoucherTemplate
Voucher
VoucherBatch
VoucherRedemption
VoucherRule
Campaign
CampaignRule
CampaignTarget
CampaignAsset
CampaignRedemption
CampaignMetrics
Role
Permission
RolePermission
UserRole
Notification
NotificationTemplate
NotificationPreferences
NotificationDelivery
AnalyticsEvent
AuditLog
IntegrationConfig
WebhookSubscription
PlatformEvent
CrossServiceTransactionResult
```

### Exported Types (from `packages/shared-types` — Unions & Enums)

```text
UUID
ISO8601
CountryCode
CurrencyCode
LanguageCode
EntityStatus
UserStatus
MerchantStatus
VoucherStatus
CampaignStatus
ApplicationType
ApplicationCode
PermissionScope
WalletAssetType
WalletTransactionType
WalletTransactionStatus
VoucherType
CampaignType
NotificationType
NotificationChannelType
NotificationCategory
PlatformEventType
```

### Import Convention

```typescript
import type { User, Wallet, RewardProgramme } from '@/packages/shared-types';
import { COUNTRIES, formatCurrency, API_ENDPOINTS } from '@/packages/config';
import { translate } from '@/packages/i18n';
import { apiGet, apiPost, getUserFacingMessage } from '@/packages/api-client';
```

---

## 23. DO NOT DUPLICATE

Future apps must not create independent versions of:

- Central authentication
- Users
- Profiles
- Organisations
- Merchant directory
- Wallet
- Rewards ledger
- Voucher infrastructure
- Campaign infrastructure
- Notification preferences
- RBAC infrastructure
- Shared analytics conventions

If a future app believes one of these must change, it should modify or extend the shared architecture deliberately — through a new migration, a new SECURITY DEFINER function, or an updated shared type — rather than silently fork it.

**This is an Architecture Rule. Violations create data inconsistency, security gaps, and maintenance burden across the entire ecosystem.**

---

## 24. New Shared Capability Decision Rule

When a future app needs new functionality:

### Step 1

Check whether it already exists in shared services (see §3 and §6).

### Step 2

If it exists, reuse it. Reference shared IDs (see §4). Use shared APIs (see §13).

### Step 3

If it does not exist, determine whether it is:

- **Application-specific** — only meaningful within one app, or
- **Cross-ecosystem** — useful across multiple ecosystem applications

### Step 4

If application-specific, implement it within the app using shared platform references (see §18). App-specific tables must reference `merchant_id`, `organisation_id`, `user_id`, etc.

### Step 5

If cross-ecosystem, add it to the shared platform first:

1. Create a new database migration (new table(s), RLS policies)
2. Add the TypeScript type to `packages/shared-types`
3. Update this Architecture Contract
4. Then consume it from the app

---

## 25. Mandatory Preamble for Future Bolt Projects

# Mandatory Instructions for Any New App Project

> This application is part of the IDS uWin/RetailFlow ecosystem. Before implementing any feature, comply with this Shared Architecture Contract. Reuse central platform services for identity, merchants, wallet, rewards, vouchers, campaigns, notifications, analytics, RBAC and shared UI. Do not duplicate these systems. App-specific functionality must extend the platform using the canonical shared identifiers and API/event conventions.
>
> **Canonical application code for this project:** `[insert app code from §5]`
>
> **Shared packages to import:**
> - `@/packages/shared-types` — domain types
> - `@/packages/config` — countries, currencies, languages, feature flags, API endpoints
> - `@/packages/i18n` — translations
> - `@/packages/api-client` — typed API helpers
>
> **Before creating any table, check §6 for the canonical shared tables. Before creating any type, check §22 for the canonical shared types. Before implementing any cross-service operation, use `process_cross_service_transaction()` rather than direct table writes.**

---

*End of Architecture Contract v1.0*
