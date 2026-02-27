import { forwardRef, type ReactNode, type MouseEvent } from 'react';
import { Button as ReuiButton } from 'react-editor-ui';
import { Loader2 } from 'lucide-react';

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  leftIcon?: ReactNode;
  rightIcon?: ReactNode;
  disabled?: boolean;
  children?: ReactNode;
  onClick?: (event: MouseEvent<HTMLButtonElement>) => void;
  className?: string;
  type?: 'button' | 'submit' | 'reset';
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    {
      variant = 'primary',
      size = 'md',
      loading = false,
      leftIcon,
      rightIcon,
      disabled,
      children,
      ...rest
    },
    ref
  ) => {
    const spinnerIcon = (
      <Loader2
        style={{
          width: 14,
          height: 14,
          animation: 'spin 1s linear infinite',
        }}
      />
    );

    return (
      <ReuiButton
        ref={ref}
        variant={variant}
        size={size}
        disabled={disabled || loading}
        iconStart={loading ? spinnerIcon : leftIcon}
        iconEnd={!loading ? rightIcon : undefined}
        {...rest}
      >
        {children}
      </ReuiButton>
    );
  }
);

Button.displayName = 'Button';
