import { type ReactNode } from 'react';
import { Badge as ReuiBadge } from 'react-editor-ui';

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

