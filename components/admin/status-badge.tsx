'use client';

// ============================================================================
// Status Badge — renders a status value with the correct color variant
// ============================================================================

import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import type { StatusDefinition } from '@/packages/config';
import {
  USER_STATUS_DEFINITIONS,
  MERCHANT_STATUS_DEFINITIONS,
  VOUCHER_STATUS_DEFINITIONS,
  CAMPAIGN_STATUS_DEFINITIONS,
} from '@/packages/config';

const VARIANT_CLASSES: Record<string, string> = {
  default: 'bg-primary/10 text-primary border-primary/20',
  secondary: 'bg-muted text-muted-foreground border-border',
  destructive: 'bg-destructive/10 text-destructive border-destructive/20',
  outline: 'border-border text-foreground',
  success: 'bg-success/10 text-success border-success/20',
  warning: 'bg-warning/10 text-warning border-warning/20',
};

export function StatusBadge({ status, type = 'user' }: { status: string; type?: 'user' | 'merchant' | 'voucher' | 'campaign' }) {
  const definitions: StatusDefinition[] =
    type === 'merchant' ? MERCHANT_STATUS_DEFINITIONS
    : type === 'voucher' ? VOUCHER_STATUS_DEFINITIONS
    : type === 'campaign' ? CAMPAIGN_STATUS_DEFINITIONS
    : USER_STATUS_DEFINITIONS;

  const def = definitions.find((d) => d.value === status);
  const variant = def?.variant ?? 'secondary';
  const label = def?.label ?? status;

  return (
    <Badge variant="outline" className={cn('border', VARIANT_CLASSES[variant])}>
      {label}
    </Badge>
  );
}
