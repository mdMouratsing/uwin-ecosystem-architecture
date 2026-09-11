'use client';

// ============================================================================
// Architecture Demo — Consumer (Aisha Raman) + Merchant (Lagoon Market)
// + Cross-Service Transaction demonstration
// ============================================================================

import { useEffect, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase-client';
import { useAuth } from '@/components/providers/auth-provider';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Skeleton } from '@/components/ui/skeleton';
import {
  User, Wallet, Award, Ticket, Bell, Building2, Store, MapPin,
  Zap, CheckCircle2, Loader2, Sparkles, ArrowRight,
} from 'lucide-react';
import { formatCurrency } from '@/packages/config';

export default function ArchitectureDemoPage() {
  const { user } = useAuth();
  const [loading, setLoading] = useState(true);
  const [merchant, setMerchant] = useState<{
    id: string; merchant_name: string; trading_name: string | null;
    description: string | null; contact_phone: string | null; contact_email: string | null;
    loyalty_participation: boolean; voucher_acceptance: boolean; rating: number | null;
  } | null>(null);
  const [merchantOrg, setMerchantOrg] = useState<{
    name: string; organisation_type_code: string; contact_email: string | null;
    website_url: string | null; status: string;
  } | null>(null);
  const [merchantBranch, setMerchantBranch] = useState<{
    name: string; address_line1: string | null; city: string | null;
  } | null>(null);
  const [walletTxCount, setWalletTxCount] = useState(0);
  const [rewardBalance, setRewardBalance] = useState(0);
  const [rewardTier, setRewardTier] = useState<string>('Member');
  const [notifications, setNotifications] = useState<Array<{
    id: string; notification_type: string; title: string; body: string; is_read: boolean; created_at: string;
  }>>([]);
  const [vouchers, setVouchers] = useState<Array<{
    id: string; code: string; voucher_type: string; face_value: number | null; status: string;
  }>>([]);
  const [recentTx, setRecentTx] = useState<Array<{
    id: string; transaction_type: string; amount: number; description: string | null; created_at: string;
  }>>([]);

  // Cross-service transaction state
  const [txAmount, setTxAmount] = useState('500');
  const [txRunning, setTxRunning] = useState(false);
  const [txResult, setTxResult] = useState<{
    points_earned: number; new_balance: number; merchant_name: string; amount: number;
    wallet_transaction_id: string; reward_transaction_id: string | null;
    analytics_event_id: string; notification_id: string | null; audit_log_id: string;
  } | null>(null);
  const [txError, setTxError] = useState<string | null>(null);

  const loadDemoData = useCallback(async () => {
    if (!user) return;
    setLoading(true);

    try {
      // Fetch merchant (Lagoon Market)
      const { data: merchantData } = await supabase
        .from('merchants')
        .select('id, merchant_name, trading_name, description, contact_phone, contact_email, loyalty_participation, voucher_acceptance, rating, organisation_id')
        .ilike('merchant_name', 'Lagoon Market')
        .limit(1)
        .maybeSingle();

      if (merchantData) {
        setMerchant(merchantData);

        // Fetch organisation
        const { data: orgData } = await supabase
          .from('organisations')
          .select('name, organisation_type_code, contact_email, website_url, status')
          .eq('id', merchantData.organisation_id)
          .maybeSingle();
        setMerchantOrg(orgData);

        // Fetch branch
        const { data: branchData } = await supabase
          .from('branches')
          .select('name, address_line1, city')
          .eq('organisation_id', merchantData.organisation_id)
          .limit(1)
          .maybeSingle();
        setMerchantBranch(branchData);
      }

      // Fetch current user's wallet transactions count
      const { count: wCount } = await supabase
        .from('wallet_transactions')
        .select('id', { count: 'exact', head: true });

      setWalletTxCount(wCount ?? 0);

      // Fetch recent wallet transactions
      const { data: txData } = await supabase
        .from('wallet_transactions')
        .select('id, transaction_type, amount, description, created_at')
        .order('created_at', { ascending: false })
        .limit(5);
      setRecentTx(txData ?? []);

      // Fetch reward account
      const { data: rewardData } = await supabase
        .from('reward_accounts')
        .select('current_balance, tier_id')
        .eq('user_id', user.id)
        .maybeSingle();

      if (rewardData) {
        setRewardBalance(rewardData.current_balance);
        if (rewardData.tier_id) {
          const { data: tierData } = await supabase
            .from('reward_tiers')
            .select('tier_name')
            .eq('id', rewardData.tier_id)
            .maybeSingle();
          if (tierData) setRewardTier(tierData.tier_name);
        }
      }

      // Fetch notifications
      const { data: notifData } = await supabase
        .from('notifications')
        .select('id, notification_type, title, body, is_read, created_at')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(5);
      setNotifications(notifData ?? []);

      // Fetch vouchers
      const { data: voucherData } = await supabase
        .from('vouchers')
        .select('id, code, voucher_type, face_value, status')
        .eq('assigned_to_user_id', user.id)
        .limit(5);
      setVouchers(voucherData ?? []);

    } catch {
      // Silently handle — demo data may not exist yet
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    loadDemoData();
  }, [loadDemoData]);

  const runTransaction = async () => {
    if (!user || !merchant) return;
    setTxRunning(true);
    setTxError(null);
    setTxResult(null);

    try {
      const amount = parseFloat(txAmount);
      if (isNaN(amount) || amount <= 0) {
        setTxError('Please enter a valid amount');
        setTxRunning(false);
        return;
      }

      const idempotencyKey = `demo_${user.id}_${Date.now()}`;

      const { data, error } = await supabase.rpc('process_cross_service_transaction', {
        p_user_id: user.id,
        p_merchant_id: merchant.id,
        p_amount: amount,
        p_currency_code: 'MUR',
        p_application_code: 'uwin',
        p_idempotency_key: idempotencyKey,
      });

      if (error) throw error;

      setTxResult(data as typeof txResult);

      // Refresh data
      await loadDemoData();
    } catch (err) {
      setTxError('Could not process the transaction. Please try again.');
    } finally {
      setTxRunning(false);
    }
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-64" />
        <div className="grid gap-4 md:grid-cols-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-64" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Architecture Demo</h1>
        <p className="mt-1 text-muted-foreground">
          Demonstrating the shared platform services through a fictional consumer and merchant
        </p>
      </div>

      <Tabs defaultValue="consumer">
        <TabsList>
          <TabsTrigger value="consumer">Consumer — Aisha Raman</TabsTrigger>
          <TabsTrigger value="merchant">Merchant — Lagoon Market</TabsTrigger>
          <TabsTrigger value="transaction">Cross-Service Transaction</TabsTrigger>
        </TabsList>

        {/* Consumer Demo */}
        <TabsContent value="consumer" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <User className="h-5 w-5 text-accent" />
                  uWin ID & Profile
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <DemoRow label="uWin ID" value={user?.id?.slice(0, 8) + '…' ?? '—'} />
                <DemoRow label="Email" value={user?.email ?? '—'} />
                <DemoRow label="Identity" value="Email (primary)" />
                <DemoRow label="Auth Method" value="Password" />
                <DemoRow label="Status" value={<Badge variant="outline" className="border-success/20 bg-success/10 text-success">Active</Badge>} />
              </CardContent>
            </Card>

            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Wallet className="h-5 w-5 text-accent" />
                  Wallet
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <DemoRow label="Wallet Status" value={<Badge variant="outline" className="border-success/20 bg-success/10 text-success">Active</Badge>} />
                <DemoRow label="Total Transactions" value={walletTxCount} />
                <div className="pt-2">
                  <p className="mb-2 text-sm font-medium text-muted-foreground">Recent Transactions</p>
                  {recentTx.length > 0 ? (
                    <div className="space-y-2">
                      {recentTx.map((tx) => (
                        <div key={tx.id} className="flex items-center justify-between rounded-lg border border-border/40 px-3 py-2 text-sm">
                          <div>
                            <p className="font-medium capitalize">{tx.transaction_type}</p>
                            <p className="text-xs text-muted-foreground">{tx.description ?? '—'}</p>
                          </div>
                          <span className="font-medium">{formatCurrency(tx.amount)}</span>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-sm text-muted-foreground">No transactions yet. Run the cross-service transaction demo below.</p>
                  )}
                </div>
              </CardContent>
            </Card>

            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Award className="h-5 w-5 text-accent" />
                  Rewards
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <DemoRow label="Programme" value="uWin Rewards" />
                <DemoRow label="Current Tier" value={<Badge className="bg-accent/10 text-accent border-accent/20">{rewardTier}</Badge>} />
                <DemoRow label="Current Balance" value={`${rewardBalance} points`} />
                <DemoRow label="Total Earned" value={`${rewardBalance} points`} />
              </CardContent>
            </Card>

            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Ticket className="h-5 w-5 text-accent" />
                  Vouchers & Notifications
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div>
                  <p className="mb-2 text-sm font-medium text-muted-foreground">Vouchers ({vouchers.length})</p>
                  {vouchers.length > 0 ? (
                    <div className="space-y-2">
                      {vouchers.map((v) => (
                        <div key={v.id} className="flex items-center justify-between rounded-lg border border-border/40 px-3 py-2 text-sm">
                          <span className="font-mono text-xs">{v.code}</span>
                          <Badge variant="outline" className="capitalize">{v.status}</Badge>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-sm text-muted-foreground">No vouchers assigned.</p>
                  )}
                </div>
                <div className="pt-2">
                  <p className="mb-2 flex items-center gap-1.5 text-sm font-medium text-muted-foreground">
                    <Bell className="h-3.5 w-3.5" /> Notifications
                  </p>
                  {notifications.length > 0 ? (
                    <div className="space-y-2">
                      {notifications.map((n) => (
                        <div key={n.id} className="rounded-lg border border-border/40 px-3 py-2 text-sm">
                          <div className="flex items-center justify-between">
                            <p className="font-medium">{n.title}</p>
                            {!n.is_read && <span className="h-2 w-2 rounded-full bg-accent" />}
                          </div>
                          <p className="mt-0.5 text-xs text-muted-foreground line-clamp-2">{n.body}</p>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-sm text-muted-foreground">No notifications yet.</p>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Merchant Demo */}
        <TabsContent value="merchant" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Building2 className="h-5 w-5 text-accent" />
                  Organisation
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <DemoRow label="Name" value={merchantOrg?.name ?? 'Lagoon Market Ltd'} />
                <DemoRow label="Type" value={merchantOrg?.organisation_type_code ?? 'merchant'} />
                <DemoRow label="Email" value={merchantOrg?.contact_email ?? '—'} />
                <DemoRow label="Website" value={merchantOrg?.website_url ?? '—'} />
                <DemoRow label="Status" value={<Badge variant="outline" className="border-success/20 bg-success/10 text-success capitalize">{merchantOrg?.status ?? 'active'}</Badge>} />
              </CardContent>
            </Card>

            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Store className="h-5 w-5 text-accent" />
                  Merchant Profile
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <DemoRow label="Merchant Name" value={merchant?.merchant_name ?? '—'} />
                <DemoRow label="Trading Name" value={merchant?.trading_name ?? '—'} />
                <DemoRow label="Phone" value={merchant?.contact_phone ?? '—'} />
                <DemoRow label="Loyalty" value={merchant?.loyalty_participation ? <Badge className="bg-success/10 text-success border-success/20">Participating</Badge> : <Badge variant="secondary">No</Badge>} />
                <DemoRow label="Vouchers" value={merchant?.voucher_acceptance ? <Badge className="bg-success/10 text-success border-success/20">Accepted</Badge> : <Badge variant="secondary">No</Badge>} />
                <DemoRow label="Rating" value={merchant?.rating ? `${merchant.rating} / 5` : '—'} />
              </CardContent>
            </Card>

            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <MapPin className="h-5 w-5 text-accent" />
                  Branch
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <DemoRow label="Branch Name" value={merchantBranch?.name ?? 'Grand Baie Branch'} />
                <DemoRow label="Address" value={merchantBranch?.address_line1 ?? '—'} />
                <DemoRow label="City" value={merchantBranch?.city ?? 'Grand Baie'} />
                <DemoRow label="Country" value="Mauritius (MU)" />
              </CardContent>
            </Card>

            <Card className="border-border/50">
              <CardHeader>
                <CardTitle className="flex items-center gap-2 text-lg">
                  <Sparkles className="h-5 w-5 text-accent" />
                  Ecosystem Channels
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="flex flex-wrap gap-2">
                  <Badge className="bg-accent/10 text-accent border-accent/20">uWin</Badge>
                  <Badge className="bg-accent/10 text-accent border-accent/20">uWin Rewards</Badge>
                  <Badge className="bg-accent/10 text-accent border-accent/20">uWin Market</Badge>
                  <Badge className="bg-accent/10 text-accent border-accent/20">uWin Business</Badge>
                </div>
                <p className="mt-4 text-sm text-muted-foreground">
                  This merchant is visible across four ecosystem applications. Future apps reference the same central merchant record.
                </p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Cross-Service Transaction */}
        <TabsContent value="transaction" className="space-y-4">
          <Card className="border-border/50">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-lg">
                <Zap className="h-5 w-5 text-accent" />
                Cross-Service Transaction Demo
              </CardTitle>
              <CardDescription>
                Simulate a transaction at Lagoon Market to see the shared services work end-to-end:
                wallet ledger, reward rule evaluation, analytics event, notification, and audit trail.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-end">
                <div className="space-y-2">
                  <Label htmlFor="amount">Amount (Rs)</Label>
                  <Input
                    id="amount"
                    type="number"
                    value={txAmount}
                    onChange={(e) => setTxAmount(e.target.value)}
                    placeholder="500"
                    disabled={txRunning}
                    className="w-40"
                  />
                </div>
                <Button
                  onClick={runTransaction}
                  disabled={txRunning || !merchant}
                  className="bg-accent text-accent-foreground hover:bg-accent/90"
                >
                  {txRunning ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Processing…
                    </>
                  ) : (
                    <>
                      <Zap className="mr-2 h-4 w-4" />
                      Run Transaction
                    </>
                  )}
                </Button>
              </div>

              {txError && (
                <div className="rounded-lg border border-destructive/20 bg-destructive/5 p-4 text-sm text-destructive">
                  {txError}
                </div>
              )}

              {txResult && (
                <div className="rounded-lg border border-success/20 bg-success/5 p-6 animate-slide-up">
                  <div className="flex items-center gap-2 text-success">
                    <CheckCircle2 className="h-5 w-5" />
                    <p className="font-semibold">Transaction completed successfully</p>
                  </div>

                  <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                    <ResultRow label="Amount" value={formatCurrency(txResult.amount)} />
                    <ResultRow label="Points Earned" value={`${txResult.points_earned} pts`} />
                    <ResultRow label="New Balance" value={`${txResult.new_balance} pts`} />
                    <ResultRow label="Wallet TX ID" value={txResult.wallet_transaction_id?.slice(0, 8) + '…'} />
                    <ResultRow label="Reward TX ID" value={txResult.reward_transaction_id?.slice(0, 8) + '…' ?? '—'} />
                    <ResultRow label="Analytics Event" value={txResult.analytics_event_id?.slice(0, 8) + '…'} />
                    <ResultRow label="Notification" value={txResult.notification_id?.slice(0, 8) + '…' ?? '—'} />
                    <ResultRow label="Audit Log" value={txResult.audit_log_id?.slice(0, 8) + '…'} />
                  </div>

                  <div className="mt-4 space-y-2">
                    <p className="text-sm font-medium text-muted-foreground">Services triggered atomically:</p>
                    <div className="flex flex-wrap gap-2">
                      <FlowStep label="Wallet Ledger" />
                      <ArrowRight className="h-4 w-4 text-muted-foreground/50" />
                      <FlowStep label="Reward Rule" />
                      <ArrowRight className="h-4 w-4 text-muted-foreground/50" />
                      <FlowStep label="Points Credited" />
                      <ArrowRight className="h-4 w-4 text-muted-foreground/50" />
                      <FlowStep label="Analytics Event" />
                      <ArrowRight className="h-4 w-4 text-muted-foreground/50" />
                      <FlowStep label="Notification" />
                      <ArrowRight className="h-4 w-4 text-muted-foreground/50" />
                      <FlowStep label="Audit Trail" />
                    </div>
                  </div>
                </div>
              )}

              {!txResult && !txError && !txRunning && (
                <div className="rounded-lg border border-border/40 bg-muted/30 p-6 text-center">
                  <p className="text-sm text-muted-foreground">
                    Click "Run Transaction" to simulate a purchase at Lagoon Market.
                    The system will atomically record the wallet transaction, evaluate reward rules,
                    credit points, fire an analytics event, create a notification, and write an audit log.
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}

function DemoRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="text-sm font-medium text-right">{value}</span>
    </div>
  );
}

function ResultRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-border/40 bg-background px-3 py-2">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="text-sm font-medium">{value}</p>
    </div>
  );
}

function FlowStep({ label }: { label: string }) {
  return (
    <Badge variant="outline" className="border-accent/20 bg-accent/5 text-foreground">
      {label}
    </Badge>
  );
}
