// ============================================================================
// Admin Layout — applies route protection and admin shell to all /admin pages
// ============================================================================

import { ProtectedRoute } from '@/components/admin/protected-route';
import { AdminShell } from '@/components/admin/admin-shell';

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute>
      <AdminShell>{children}</AdminShell>
    </ProtectedRoute>
  );
}
