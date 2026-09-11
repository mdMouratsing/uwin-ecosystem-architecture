'use client';

// ============================================================================
// Dashboard — ecosystem overview across all shared services
// ============================================================================

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase-client';
import { StatCard } from '@/components/admin/stat-card';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Users, Building2, Store, Wallet, Award, Megaphone, Bell,
  Activity, TrendingUp,
} from 'lucide-react';

interface DashboardStats {
  users: number;
  organisations: number;
  merchants: number;
  walletTransactions: number;
  rewardTransactions: number;
  activeCampaigns: number;
  notifications: number;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchStats() {
      try {
        const [
          usersRes,
          orgsRes,
          merchantsRes,
          walletTxRes,
          rewardTxRes,
          campaignsRes,
          notifRes,
        ] = await Promise.all([
          supabase.from('users').select('id', { count: 'exact', head: true }),
          supabase.from('organisations').select('id', { count: 'exact', head: true }),
          supabase.from('merchants').select('id', { count: 'exact', head: true }),
          supabase.from('wallet_transactions').select('id', { count: 'exact', head: true }),
          supabase.from('reward_transactions').select('id', { count: 'exact', head: true }),
          supabase.from('campaigns').select('id', { count: 'exact', head: true }).eq('status', 'active'),
          supabase.from('notifications').select('id', { count: 'exact', head: true }),
        ]);

        setStats({
          users: usersRes.count ?? 0,
          organisations: orgsRes.count ?? 0,
          merchants: merchantsRes.count ?? 0,
          walletTransactions: walletTxRes.count ?? 0,
          rewardTransactions: rewardTxRes.count ?? 0,
          activeCampaigns: campaignsRes.count ?? 0,
          notifications: notifRes.count ?? 0,
        });
      } catch {
        setStats(null);
      } finally {
        setLoading(false);
      }
    }
    fetchStats();
  }, []);

  if (loading) {
    return (
      <div className="space-y-6">
        <div>
          <Skeleton className="h-8 w-64" />
          <Skeleton className="mt-2 h-4 w-96" />
        </div>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 7 }).map((_, i) => (
            <Skeleton key={i} className="h-24" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Platform Dashboard</h1>
        <p className="mt-1 text-muted-foreground">Ecosystem overview across all shared services</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Total Users" value={stats?.users ?? 0} icon={Users} accent />
        <StatCard label="Organisations" value={stats?.organisations ?? 0} icon={Building2} />
        <StatCard label="Merchants" value={stats?.merchants ?? 0} icon={Store} />
        <StatCard label="Wallet Transactions" value={stats?.walletTransactions ?? 0} icon={Wallet} />
        <StatCard label="Reward Transactions" value={stats?.rewardTransactions ?? 0} icon={Award} />
        <StatCard label="Active Campaigns" value={stats?.activeCampaigns ?? 0} icon={Megaphone} />
        <StatCard label="Notifications" value={stats?.notifications ?? 0} icon={Bell} />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card className="border-border/50">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <Activity className="h-5 w-5 text-accent" />
              Platform Health
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <HealthRow label="Rewards Engine" enabled />
            <HealthRow label="Universal Wallet" enabled />
            <HealthRow label="Voucher System" enabled />
            <HealthRow label="Campaign Engine" enabled />
            <HealthRow label="Notification Service" enabled />
            <HealthRow label="Merchant Directory" enabled />
            <HealthRow label="Analytics Collection" enabled />
            <HealthRow label="Multi-Country Mode" enabled={false} />
          </CardContent>
        </Card>

        <Card className="border-border/50">
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-lg">
              <TrendingUp className="h-5 w-5 text-accent" />
              Ecosystem Applications
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-3 text-sm">
              <AppRow name="uWin" type="Consumer" />
              <AppRow name="uWin Rewards" type="Consumer" />
              <AppRow name="uWin Market" type="Consumer" />
              <AppRow name="uWin Services" type="Consumer" />
              <AppRow name="uWin Travel" type="Consumer" />
              <AppRow name="uWin Resto" type="Consumer" />
              <AppRow name="uWin Business" type="Business" />
              <AppRow name="RetailFlow" type="Business" />
              <AppRow name="RetailFlow Resto" type="Business" />
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function HealthRow({ label, enabled }: { label: string; enabled: boolean }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className={`text-xs font-medium ${enabled ? 'text-success' : 'text-muted-foreground/50'}`}>
        {enabled ? 'Operational' : 'Disabled'}
      </span>
    </div>
  );
}

function AppRow({ name, type }: { name: string; type: string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-border/40 px-3 py-2">
      <span className="font-medium">{name}</span>
      <span className="text-xs text-muted-foreground">{type}</span>
    </div>
  );
}
