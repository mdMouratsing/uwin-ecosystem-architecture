'use client';

// ============================================================================
// Architecture Contract — viewable in the admin interface
// ============================================================================

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  Shield, Users, Building2, Wallet, Award, Ticket, Megaphone,
  Bell, BarChart3, FileText, Globe, Database, Key, Layers,
  CheckCircle2, AlertCircle,
} from 'lucide-react';

export default function ArchitectureContractPage() {
  return (
    <div className="space-y-6 animate-fade-in max-w-4xl">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">uWin &amp; RetailFlow Shared Architecture Contract</h1>
        <p className="mt-1 text-muted-foreground">
          The technical foundation upon which every future uWin and RetailFlow application is developed.
        </p>
      </div>

      {/* Rules */}
      <Card className="border-accent/30">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-lg">
            <Shield className="h-5 w-5 text-accent" />
            Rules Every Future App Must Follow
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid gap-3 sm:grid-cols-2">
            {RULES.map((rule, i) => (
              <div key={i} className="flex items-start gap-3 rounded-lg border border-border/40 p-3">
                <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-success" />
                <span className="text-sm">{rule}</span>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Architecture Overview */}
      <Section title="Architecture Overview" icon={Layers}>
        <p className="text-sm text-muted-foreground">
          ONE PLATFORM — MULTIPLE APPS — ONE IDENTITY — SHARED SERVICES. The platform layer
          sits between the IDS infrastructure and the application ecosystem. Consumer apps
          (uWin family) and business apps (RetailFlow family) both consume the same shared
          services: identity, wallet, rewards, merchants, vouchers, campaigns, notifications,
          analytics, and permissions.
        </p>
        <div className="mt-4 rounded-lg border border-border/40 bg-muted/30 p-6 text-center">
          <p className="font-mono text-xs leading-relaxed text-muted-foreground whitespace-pre">
{`              IDS DIGITAL ECOSYSTEM
                       │
           SHARED PLATFORM LAYER
                       │
┌───────────┬──────────┼──────────┬────────────┐
│           │          │          │            │
uWin ID   Wallet    Rewards   Merchants    Analytics
│           │          │          │
└───────────┴────┬─────┴──────────┘
                 │
           Shared APIs
                 │
  ┌──────────────┴───────────────┐
  │                              │
uWin Ecosystem           RetailFlow Ecosystem
  │                              │
Consumer Apps              Business Apps`}
          </p>
        </div>
      </Section>

      {/* Service Ownership */}
      <Section title="Service Ownership Map" icon={Database}>
        <div className="grid gap-3 sm:grid-cols-2">
          {SERVICES.map((s) => {
            const Icon = s.icon;
            return (
              <div key={s.name} className="rounded-lg border border-border/40 p-4">
                <div className="flex items-center gap-2">
                  <Icon className="h-4 w-4 text-accent" />
                  <span className="font-medium text-sm">{s.name}</span>
                </div>
                <div className="mt-2 space-y-1">
                  {s.entities.map((e) => (
                    <p key={e} className="text-xs text-muted-foreground">→ {e}</p>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </Section>

      {/* Identity Model */}
      <Section title="uWin ID — Central Identity" icon={Key}>
        <p className="text-sm text-muted-foreground">
          A person has one unique platform identity regardless of which application they registered
          from. Identity data (auth methods, identifiers) is separated from profile data (personal
          info) and preferences. Supports email, mobile, OTP, password, passwordless, and future
          social authentication. Business users link their uWin ID to organisations without creating
          separate identities.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Badge variant="outline">users</Badge>
          <Badge variant="outline">identities</Badge>
          <Badge variant="outline">profiles</Badge>
          <Badge variant="outline">authentication_methods</Badge>
          <Badge variant="outline">user_preferences</Badge>
          <Badge variant="outline">user_consents</Badge>
          <Badge variant="outline">consent_history</Badge>
        </div>
      </Section>

      {/* Wallet */}
      <Section title="Universal Wallet — Immutable Ledger" icon={Wallet}>
        <p className="text-sm text-muted-foreground">
          One wallet per consumer, shared across all participating applications. Supports loyalty
          points, cashback, promotional credits, gift cards, and future payment balances. Every
          transaction is an immutable ledger record — balances are derived from transaction history,
          never overwritten. Corrections use reversal or adjustment transactions that reference the
          original. Idempotency keys prevent duplicate credits from retried requests.
        </p>
      </Section>

      {/* Rewards */}
      <Section title="Universal Rewards Engine" icon={Award}>
        <p className="text-sm text-muted-foreground">
          One rewards account per user per programme. Reward balances are never duplicated between
          applications. Rules are configurable (not hard-coded): earn rates, multipliers, bonuses,
          referrals, challenges, birthday rewards, and merchant-specific programmes. Tiers (Member,
          Silver, Gold, Platinum) are defined per programme, not hard-coded.
        </p>
      </Section>

      {/* Merchant Directory */}
      <Section title="Central Merchant Directory" icon={Building2}>
        <p className="text-sm text-muted-foreground">
          One merchant record per business, referenced by all future apps. A merchant is not forced
          into one category — it can have multiple categories and configurable capabilities (shopping,
          restaurant, loyalty, vouchers, bookings, etc.). Channel enablement controls which ecosystem
          applications the merchant is visible on.
        </p>
      </Section>

      {/* Vouchers & Campaigns */}
      <Section title="Voucher, Coupon &amp; Campaign Architecture" icon={Ticket}>
        <p className="text-sm text-muted-foreground">
          Vouchers are digital instruments with unique codes assigned to users. Coupons are promotional codes applied at checkout — they can be multi-use and time-limited. Both are distinct from loyalty rewards (points earned through the Rewards Engine). The campaign engine supports points bonuses, voucher/coupon distributions, discounts, cashback, challenges, referrals, and targeted promotions with segmentation by tier, merchant, location, category, and channel.
        </p>
      </Section>

      {/* Notifications */}
      <Section title="Shared Notification Service" icon={Bell}>
        <p className="text-sm text-muted-foreground">
          All apps publish notifications through one common service. Supports in-app, push (Firebase Cloud Messaging), email, and SMS channels. Mandatory transactional messages are distinguished from marketing communication. Users control their preferences per channel and category. Webhooks are signed using OAuth 2.0 with HMAC-SHA256.
        </p>
      </Section>

      {/* Analytics */}
      <Section title="Standard Analytics Events" icon={BarChart3}>
        <p className="text-sm text-muted-foreground">
          All applications emit events using a standard schema: event_id, event_name, user_id,
          application_code, screen_name, timestamp, and properties. PII is kept out of event
          properties — user identifiers are used instead of copying personal information.
        </p>
      </Section>

      {/* API Conventions */}
      <Section title="API Conventions" icon={FileText}>
        <p className="text-sm text-muted-foreground">
          REST API-first with predictable naming, consistent HTTP methods, pagination, filtering,
          and versioning. Standard response format: <code className="text-xs">&#123; data: &#123;&#125;, meta: &#123;&#125; &#125;</code> for
          success, <code className="text-xs">&#123; error: &#123; code, message &#125; &#125;</code> for errors.
          Architecture supports GraphQL later.
        </p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Badge variant="outline" className="font-mono">/api/v1/users</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/merchants</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/wallets</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/rewards</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/vouchers</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/coupons</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/campaigns</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/notifications</Badge>
          <Badge variant="outline" className="font-mono">/api/v1/auth/token</Badge>
        </div>
      </Section>

      {/* Tenancy */}
      <Section title="Tenancy &amp; Access Control" icon={Globe}>
        <p className="text-sm text-muted-foreground">
          Multi-tenant: organisations cannot see each other&apos;s data. Row Level Security enforces
          tenant boundaries on every tenant-sensitive table. RBAC uses structured permission keys
          (merchant.view, wallet.adjust, campaign.approve) with scopes (platform, organisation,
          branch, own). Privileged mutations (role assignment, balance adjustments, status changes)
          go through SECURITY DEFINER functions that verify the caller&apos;s authorization.
        </p>
      </Section>

      {/* Critical Rule */}
      <Card className="border-destructive/30">
        <CardHeader>
          <CardTitle className="flex items-center gap-2 text-lg text-destructive">
            <AlertCircle className="h-5 w-5" />
            Critical Rule: No Duplication
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            Future projects must NOT create another user table, another rewards balance, another
            merchant table, another wallet ledger, or another central notification preference model
            without an explicit architectural decision. Any future app that needs these capabilities
            must connect to the existing shared platform services.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}

function Section({ title, icon: Icon, children }: { title: string; icon: React.ComponentType<{ className?: string }>; children: React.ReactNode }) {
  return (
    <Card className="border-border/50">
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-lg">
          <Icon className="h-5 w-5 text-accent" />
          {title}
        </CardTitle>
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  );
}

const RULES = [
  'Use uWin ID for authentication.',
  'Never create another consumer identity.',
  'Use the central Merchant Directory.',
  'Use the central Wallet.',
  'Use the common Rewards Engine.',
  'Use standard platform APIs.',
  'Use shared TypeScript types.',
  'Use shared analytics event conventions.',
  'Use shared notification services.',
  'Respect organisation and tenant boundaries.',
  'Import the shared design system.',
  'Do not duplicate shared business logic.',
  'Use application/channel IDs to indicate which app initiated activity.',
  'Create app-specific interfaces, not app-specific copies of platform services.',
];

const SERVICES = [
  { name: 'Identity Service', icon: Key, entities: ['User', 'Identity', 'Profile', 'Authentication'] },
  { name: 'Merchant Service', icon: Building2, entities: ['Organisation', 'Merchant', 'Branch'] },
  { name: 'Wallet Service', icon: Wallet, entities: ['Wallet', 'WalletTransaction'] },
  { name: 'Rewards Service', icon: Award, entities: ['RewardProgramme', 'RewardTransaction'] },
  { name: 'Voucher Service', icon: Ticket, entities: ['VoucherTemplate', 'Voucher'] },
  { name: 'Coupon Service', icon: Ticket, entities: ['CouponTemplate', 'Coupon'] },
  { name: 'Campaign Service', icon: Megaphone, entities: ['Campaign', 'CampaignRule'] },
  { name: 'Notification Service', icon: Bell, entities: ['Notification', 'NotificationTemplate'] },
  { name: 'Analytics Service', icon: BarChart3, entities: ['AnalyticsEvent'] },
];
