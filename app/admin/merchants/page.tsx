'use client';

// ============================================================================
// Merchants — admin listing of merchants
// ============================================================================

import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/lib/supabase-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { Badge } from '@/components/ui/badge';
import { StatusBadge } from '@/components/admin/status-badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface MerchantRow {
  id: string;
  merchant_name: string | null;
  trading_name: string | null;
  country: string | null;
  status: string;
  loyalty_participation: boolean | null;
  voucher_acceptance: boolean | null;
  rating: number | null;
}

function YesNo({ value }: { value: boolean | null }) {
  return (
    <Badge variant="outline" className={value ? 'border-success/20 text-success' : 'text-muted-foreground'}>
      {value ? 'Yes' : 'No'}
    </Badge>
  );
}

export default function MerchantsPage() {
  const [merchants, setMerchants] = useState<MerchantRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    supabase
      .from('merchants')
      .select('id, merchant_name, trading_name, country, status, loyalty_participation, voucher_acceptance, rating')
      .order('merchant_name', { ascending: true })
      .limit(100)
      .then(({ data }) => {
        setMerchants((data as MerchantRow[]) ?? []);
        setLoading(false);
      });
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return merchants;
    return merchants.filter(
      (m) => m.merchant_name?.toLowerCase().includes(q) || m.trading_name?.toLowerCase().includes(q),
    );
  }, [merchants, search]);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Merchants</h1>
        <p className="mt-1 text-muted-foreground">Manage merchants across the network</p>
      </div>

      <Card className="border-border/50">
        <CardHeader className="flex-row items-center justify-between space-y-0">
          <CardTitle className="text-lg">All Merchants</CardTitle>
          <Input
            placeholder="Search by name..."
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
                  <TableHead>Merchant</TableHead>
                  <TableHead>Trading Name</TableHead>
                  <TableHead>Country</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Loyalty</TableHead>
                  <TableHead>Vouchers</TableHead>
                  <TableHead>Rating</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((m) => (
                  <TableRow key={m.id}>
                    <TableCell className="font-medium">{m.merchant_name ?? '—'}</TableCell>
                    <TableCell>{m.trading_name ?? '—'}</TableCell>
                    <TableCell>{m.country ?? '—'}</TableCell>
                    <TableCell><StatusBadge status={m.status} type="merchant" /></TableCell>
                    <TableCell><YesNo value={m.loyalty_participation} /></TableCell>
                    <TableCell><YesNo value={m.voucher_acceptance} /></TableCell>
                    <TableCell>{m.rating != null ? m.rating.toFixed(1) : '—'}</TableCell>
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
