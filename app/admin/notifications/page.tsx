'use client';

// ============================================================================
// Notifications — admin listing of recent notifications
// ============================================================================

import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/lib/supabase-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface NotificationRow {
  id: string;
  type: string | null;
  category: string | null;
  title: string | null;
  body: string | null;
  is_read: boolean | null;
  application_code: string | null;
  created_at: string | null;
}

function truncate(text: string | null, n = 60) {
  if (!text) return '—';
  return text.length > n ? text.slice(0, n) + '…' : text;
}

export default function NotificationsPage() {
  const [items, setItems] = useState<NotificationRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    supabase
      .from('notifications')
      .select('id, type, category, title, body, is_read, application_code, created_at')
      .order('created_at', { ascending: false })
      .limit(100)
      .then(({ data }) => {
        setItems((data as NotificationRow[]) ?? []);
        setLoading(false);
      });
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return items;
    return items.filter((n) => n.title?.toLowerCase().includes(q));
  }, [items, search]);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Notifications</h1>
        <p className="mt-1 text-muted-foreground">Recent notifications dispatched across applications</p>
      </div>

      <Card className="border-border/50">
        <CardHeader className="flex-row items-center justify-between space-y-0">
          <CardTitle className="text-lg">Recent Notifications</CardTitle>
          <Input
            placeholder="Search by title..."
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
                  <TableHead>Category</TableHead>
                  <TableHead>Title</TableHead>
                  <TableHead>Body</TableHead>
                  <TableHead>Read</TableHead>
                  <TableHead>Application</TableHead>
                  <TableHead>Created</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filtered.map((n) => (
                  <TableRow key={n.id}>
                    <TableCell>{n.type ?? '—'}</TableCell>
                    <TableCell>{n.category ?? '—'}</TableCell>
                    <TableCell className="font-medium">{n.title ?? '—'}</TableCell>
                    <TableCell className="max-w-xs text-muted-foreground">{truncate(n.body)}</TableCell>
                    <TableCell>
                      <Badge variant="outline" className={n.is_read ? 'border-success/20 text-success' : 'text-muted-foreground'}>
                        {n.is_read ? 'Read' : 'Unread'}
                      </Badge>
                    </TableCell>
                    <TableCell className="font-mono text-xs">{n.application_code ?? '—'}</TableCell>
                    <TableCell>{n.created_at ? new Date(n.created_at).toLocaleDateString() : '—'}</TableCell>
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
