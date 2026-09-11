'use client';

// ============================================================================
// Rewards — reward programmes and recent reward transactions
// ============================================================================

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { StatusBadge } from '@/components/admin/status-badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface ProgrammeRow {
  id: string;
  name: string | null;
  type: string | null;
  status: string;
  country: string | null;
}

interface TxnRow {
  id: string;
  type: string | null;
  amount: number | null;
  source: string | null;
  merchant_id: string | null;
  created_at: string | null;
}

export default function RewardsPage() {
  const [programmes, setProgrammes] = useState<ProgrammeRow[]>([]);
  const [txns, setTxns] = useState<TxnRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      supabase.from('reward_programmes').select('id, name, type, status, country').order('name').limit(100),
      supabase.from('reward_transactions').select('id, type, amount, source, merchant_id, created_at').order('created_at', { ascending: false }).limit(100),
    ]).then(([p, t]) => {
      setProgrammes((p.data as ProgrammeRow[]) ?? []);
      setTxns((t.data as TxnRow[]) ?? []);
      setLoading(false);
    });
  }, []);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Rewards</h1>
        <p className="mt-1 text-muted-foreground">Reward programmes and recent reward transactions</p>
      </div>

      <Tabs defaultValue="programmes">
        <TabsList>
          <TabsTrigger value="programmes">Programmes</TabsTrigger>
          <TabsTrigger value="transactions">Transactions</TabsTrigger>
        </TabsList>

        <TabsContent value="programmes">
          <Card className="border-border/50">
            <CardHeader><CardTitle className="text-lg">Reward Programmes</CardTitle></CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">{Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-12 w-full" />)}</div>
              ) : programmes.length === 0 ? (
                <div className="py-16 text-center text-muted-foreground">No data available</div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow><TableHead>Name</TableHead><TableHead>Type</TableHead><TableHead>Status</TableHead><TableHead>Country</TableHead></TableRow>
                  </TableHeader>
                  <TableBody>
                    {programmes.map((p) => (
                      <TableRow key={p.id}>
                        <TableCell className="font-medium">{p.name ?? '—'}</TableCell>
                        <TableCell>{p.type ?? '—'}</TableCell>
                        <TableCell><StatusBadge status={p.status} type="user" /></TableCell>
                        <TableCell>{p.country ?? '—'}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="transactions">
          <Card className="border-border/50">
            <CardHeader><CardTitle className="text-lg">Recent Reward Transactions</CardTitle></CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">{Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-12 w-full" />)}</div>
              ) : txns.length === 0 ? (
                <div className="py-16 text-center text-muted-foreground">No data available</div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow><TableHead>Type</TableHead><TableHead>Amount</TableHead><TableHead>Source</TableHead><TableHead>Merchant</TableHead><TableHead>Created</TableHead></TableRow>
                  </TableHeader>
                  <TableBody>
                    {txns.map((t) => (
                      <TableRow key={t.id}>
                        <TableCell>{t.type ?? '—'}</TableCell>
                        <TableCell>{t.amount != null ? `Rs ${t.amount}` : '—'}</TableCell>
                        <TableCell>{t.source ?? '—'}</TableCell>
                        <TableCell className="font-mono text-xs">{t.merchant_id ?? '—'}</TableCell>
                        <TableCell>{t.created_at ? new Date(t.created_at).toLocaleDateString() : '—'}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}
