'use client';

// ============================================================================
// Stat Card — displays a metric with icon, label, and value
// ============================================================================

import { Card, CardContent } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import type { LucideIcon } from 'lucide-react';

interface StatCardProps {
  label: string;
  value: string | number;
  icon: LucideIcon;
  description?: string;
  accent?: boolean;
}

export function StatCard({ label, value, icon: Icon, description, accent }: StatCardProps) {
  return (
    <Card className={cn('border-border/50 transition-shadow hover:shadow-md', accent && 'border-accent/30')}>
      <CardContent className="flex items-center gap-4 p-5">
        <div className={cn(
          'flex h-11 w-11 shrink-0 items-center justify-center rounded-xl',
          accent ? 'bg-accent/10 text-accent' : 'bg-primary/10 text-primary'
        )}>
          <Icon className="h-5 w-5" />
        </div>
        <div className="min-w-0">
          <p className="text-sm font-medium text-muted-foreground">{label}</p>
          <p className="text-2xl font-bold tracking-tight">{value}</p>
          {description && <p className="mt-0.5 text-xs text-muted-foreground">{description}</p>}
        </div>
      </CardContent>
    </Card>
  );
}
