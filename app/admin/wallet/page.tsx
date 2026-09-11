'use client';

// ============================================================================
// Wallet — recent wallet transactions
// ============================================================================

import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/lib/supabase-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface WalletRow {
  id: string;
  transaction_type: string | null;
  asset_type: string | null;
  amount: number | null;
  currency: string | null;
  status: string | null;
  source: string | null;
  created_at: string | null;
}

export default function WalletPage() {
  const [txns, setTxns] = useState<WalletRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    supabase
      .from('wallet_transactions')
      .select('id, transaction_type, asset_type, amount, currency, status, source, created_at')
      .order('created_at', { ascending: false })
      .limit(100)
      .then(({ data }) => {
        setTxns((data as WalletRow[]) ?? []);
        setLoading(false);
      });
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return txns;
    return txns.filter((t) => t.source?.toLowerCase().includes(q));
  }, [txns, search]);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Wallet</h1>
        <p className="mt-1 text-muted-foreground">Recent universal wallet transactions across the platform</p>
      </div>

      <Card className="border-border/50">
        <CardHeader className="flex-row items-center justify-between space-y-0">
          <CardTitle className="text-lg">Recent Transactions</CardTitle>
          <Input
            placeholder="Search by source..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="max-w-xs"
          />
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="space-y-3">
              {Array.from({ length: 6 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <div className="py-16 text-center text-muted-foreground">No data available</div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Type</TableHead>
                  <TableHead>Asset</TableHead>
                  <TableHead>Amount</TableHead>
                  <TableHead>Currency</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Source</TableHead>
                  <TableHead>Created</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((t) => (
                  <TableRow key={t.id}>
                    <TableCell className="font-medium">{t.transaction_type ?? '—'}</TableCell>
                    <TableCell>{t.asset_type ?? '—'}</TableCell>
                    <TableCell>{t.amount != null ? `Rs ${t.amount}` : '—'}</TableCell>
                    <TableCell>{t.currency ?? '—'}</TableCell>
                    <TableCell>{t.status ?? '—'}</TableCell>
                    <TableCell>{t.source ?? '—'}</TableCell>
                    <TableCell>{t.created_at ? new Date(t.created_at).toLocaleDateString() : '—'}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
