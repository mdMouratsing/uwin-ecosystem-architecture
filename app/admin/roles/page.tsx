'use client';

// ============================================================================
// Roles & Permissions — admin listing of roles and permissions
// ============================================================================

import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase-client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Skeleton } from '@/components/ui/skeleton';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

interface RoleRow {
  id: string;
  role_key: string;
  name: string | null;
  description: string | null;
  scope: string | null;
  is_system: boolean | null;
}

interface PermissionRow {
  id: string;
  permission_key: string;
  name: string | null;
  description: string | null;
  scope: string | null;
}

export default function RolesPage() {
  const [roles, setRoles] = useState<RoleRow[]>([]);
  const [permissions, setPermissions] = useState<PermissionRow[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      supabase.from('roles').select('id, role_key, name, description, scope, is_system').order('name').limit(100),
      supabase.from('permissions').select('id, permission_key, name, description, scope').order('name').limit(100),
    ]).then(([r, p]) => {
      setRoles((r.data as RoleRow[]) ?? []);
      setPermissions((p.data as PermissionRow[]) ?? []);
      setLoading(false);
    });
  }, []);

  return (
    <div className="space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Roles &amp; Permissions</h1>
        <p className="mt-1 text-muted-foreground">Manage access control roles and their permissions</p>
      </div>

      <Tabs defaultValue="roles">
        <TabsList>
          <TabsTrigger value="roles">Roles</TabsTrigger>
          <TabsTrigger value="permissions">Permissions</TabsTrigger>
        </TabsList>

        <TabsContent value="roles">
          <Card className="border-border/50">
            <CardHeader><CardTitle className="text-lg">Roles</CardTitle></CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">{Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-12 w-full" />)}</div>
              ) : roles.length === 0 ? (
                <div className="py-16 text-center text-muted-foreground">No data available</div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow><TableHead>Role Key</TableHead><TableHead>Name</TableHead><TableHead>Description</TableHead><TableHead>Scope</TableHead><TableHead>System</TableHead></TableRow>
                  </TableHeader>
                  <TableBody>
                    {roles.map((r) => (
                      <TableRow key={r.id}>
                        <TableCell className="font-mono text-xs">{r.role_key}</TableCell>
                        <TableCell className="font-medium">{r.name ?? '—'}</TableCell>
                        <TableCell className="text-muted-foreground">{r.description ?? '—'}</TableCell>
                        <TableCell>{r.scope ?? '—'}</TableCell>
                        <TableCell>
                          <Badge variant="outline" className={r.is_system ? 'border-primary/20 text-primary' : 'text-muted-foreground'}>
                            {r.is_system ? 'System' : 'Custom'}
                          </Badge>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="permissions">
          <Card className="border-border/50">
            <CardHeader><CardTitle className="text-lg">Permissions</CardTitle></CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">{Array.from({ length: 5 }).map((_, i) => <Skeleton key={i} className="h-12 w-full" />)}</div>
              ) : permissions.length === 0 ? (
                <div className="py-16 text-center text-muted-foreground">No data available</div>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow><TableHead>Permission Key</TableHead><TableHead>Name</TableHead><TableHead>Description</TableHead><TableHead>Scope</TableHead></TableRow>
                  </TableHeader>
                  <TableBody>
                    {permissions.map((p) => (
                      <TableRow key={p.id}>
                        <TableCell className="font-mono text-xs">{p.permission_key}</TableCell>
                        <TableCell className="font-medium">{p.name ?? '—'}</TableCell>
                        <TableCell className="text-muted-foreground">{p.description ?? '—'}</TableCell>
                        <TableCell>{p.scope ?? '—'}</TableCell>
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
