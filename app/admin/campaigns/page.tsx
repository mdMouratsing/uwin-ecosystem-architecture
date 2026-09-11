'use client';

// ============================================================================
// Campaigns — admin listing of campaigns
// ============================================================================

import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/lib/supabase-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { StatusBadge } from '@/components/admin/status-badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface CampaignRow {
  id: string;
  name: string | null;
  type: string | null;
  status: string;
  start_date: string | null;
  end_date: string | null;
  application_code: string | null;
}

export default function CampaignsPage() {
  const [campaigns, setCampaigns] = useState<CampaignRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    supabase
      .from('campaigns')
      .select('id, name, type, status, start_date, end_date, application_code')
      .order('name', { ascending: true })
      .limit(100)
      .then(({ data }) => {
        setCampaigns((data as CampaignRow[]) ?? []);
        setLoading(false);
      });
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return campaigns;
    return campaigns.filter((c) => c.name?.toLowerCase().includes(q));
  }, [campaigns, search]);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Campaigns</h1>
        <p className="mt-1 text-muted-foreground">Manage promotional campaigns across applications</p>
      </div>

      <Card className="border-border/50">
        <CardHeader className="flex-row items-center justify-between space-y-0">
          <CardTitle className="text-lg">All Campaigns</CardTitle>
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
                  <TableHead>Name</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Start Date</TableHead>
                  <TableHead>End Date</TableHead>
                  <TableHead>Application</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((c) => (
                  <TableRow key={c.id}>
                    <TableCell className="font-medium">{c.name ?? '—'}</TableCell>
                    <TableCell>{c.type ?? '—'}</TableCell>
                    <TableCell><StatusBadge status={c.status} type="campaign" /></TableCell>
                    <TableCell>{c.start_date ? new Date(c.start_date).toLocaleDateString() : '—'}</TableCell>
                    <TableCell>{c.end_date ? new Date(c.end_date).toLocaleDateString() : '—'}</TableCell>
                    <TableCell className="font-mono text-xs">{c.application_code ?? '—'}</TableCell>
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
