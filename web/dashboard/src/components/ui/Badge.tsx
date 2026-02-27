import { type HTMLAttributes, type ReactNode } from 'react';
import { cn } from '@/lib/utils';

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  variant?: 'default' | 'primary' | 'success' | 'warning' | 'error' | 'secondary';
  size?: 'sm' | 'md';
  children: ReactNode;
}

export function Badge({
  className,
  variant = 'default',
  size = 'md',
  children,
  ...props
}: BadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center font-medium rounded-full',
        {
          'bg-surface-tertiary text-text-secondary': variant === 'default',
          'bg-primary/10 text-primary': variant === 'primary',
          'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400':
            variant === 'success',
          'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400':
            variant === 'warning',
          'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400':
            variant === 'error',
          'bg-surface-secondary text-text-muted border': variant === 'secondary',
        },
        {
          'px-2 py-0.5 text-xs': size === 'sm',
          'px-2.5 py-0.5 text-xs': size === 'md',
        },
        className
      )}
      {...props}
    >
      {children}
    </span>
  );
}

export interface StatusBadgeProps {
  status: 'active' | 'inactive' | 'loading' | 'error';
  label?: string;
}

export function StatusBadge({ status, label }: StatusBadgeProps) {
  const variants: Record<
    StatusBadgeProps['status'],
    { variant: BadgeProps['variant']; defaultLabel: string }
  > = {
    active: { variant: 'success', defaultLabel: 'Active' },
    inactive: { variant: 'secondary', defaultLabel: 'Inactive' },
    loading: { variant: 'warning', defaultLabel: 'Loading' },
    error: { variant: 'error', defaultLabel: 'Error' },
  };

  const { variant, defaultLabel } = variants[status];

  return (
    <Badge variant={variant}>
      <span
        className={cn('mr-1.5 h-1.5 w-1.5 rounded-full', {
          'bg-green-500': status === 'active',
          'bg-gray-400': status === 'inactive',
          'bg-yellow-500 animate-pulse': status === 'loading',
          'bg-red-500': status === 'error',
        })}
      />
      {label ?? defaultLabel}
    </Badge>
  );
}
