import { type ReactNode } from 'react';
import { Badge as ReuiBadge } from 'react-editor-ui';
import styles from './Badge.module.css';

export interface BadgeProps {
  variant?:
    | 'default'
    | 'primary'
    | 'success'
    | 'warning'
    | 'error'
    | 'secondary';
  size?: 'sm' | 'md';
  children: ReactNode;
  className?: string;
}

export function Badge({
  variant = 'default',
  size,
  children,
  className,
}: BadgeProps) {
  const mapped = variant === 'secondary' ? 'default' : variant;
  return (
    <ReuiBadge variant={mapped} size={size} className={className}>
      {children}
    </ReuiBadge>
  );
}

export interface StatusBadgeProps {
  status: 'active' | 'inactive' | 'loading' | 'error';
  label?: string;
}

const statusMap: Record<
  StatusBadgeProps['status'],
  { variant: BadgeProps['variant']; defaultLabel: string; dotClass: string }
> = {
  active: {
    variant: 'success',
    defaultLabel: 'Active',
    dotClass: styles.dotActive,
  },
  inactive: {
    variant: 'default',
    defaultLabel: 'Inactive',
    dotClass: styles.dotInactive,
  },
  loading: {
    variant: 'warning',
    defaultLabel: 'Loading',
    dotClass: styles.dotLoading,
  },
  error: {
    variant: 'error',
    defaultLabel: 'Error',
    dotClass: styles.dotError,
  },
};

export function StatusBadge({ status, label }: StatusBadgeProps) {
  const { variant, defaultLabel, dotClass } = statusMap[status];

  return (
    <Badge variant={variant}>
      <span className={`${styles.dot} ${dotClass}`} />
      {label ?? defaultLabel}
    </Badge>
  );
}
