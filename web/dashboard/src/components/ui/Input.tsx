import { forwardRef, type ChangeEvent, type ReactNode } from 'react';
import { Input as ReuiInput } from 'react-editor-ui';
import styles from './Input.module.css';

export interface InputProps {
  value?: string;
  onChange?: (value: string, event: ChangeEvent<HTMLInputElement>) => void;
  type?: 'text' | 'search' | 'number' | 'password';
  placeholder?: string;
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  label?: string;
  error?: string;
  helperText?: string;
  iconStart?: ReactNode;
  iconEnd?: ReactNode;
  className?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  (
    {
      label,
      error,
      helperText,
      value,
      onChange,
      iconStart,
      iconEnd,
      ...rest
    },
    ref
  ) => {
    return (
      <div className={styles.fieldWrapper}>
        {label && <label className={styles.label}>{label}</label>}
        <ReuiInput
          ref={ref}
          value={value ?? ''}
          onChange={(v, e) => onChange?.(v, e)}
          iconStart={iconStart}
          iconEnd={iconEnd}
          {...rest}
        />
        {error && <span className={styles.error}>{error}</span>}
        {helperText && !error && (
          <span className={styles.helper}>{helperText}</span>
        )}
      </div>
    );
  }
);

Input.displayName = 'Input';

export interface TextareaProps
  extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
  helperText?: string;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ label, error, helperText, id, ...props }, ref) => {
    const inputId = id ?? label?.toLowerCase().replace(/\s+/g, '-');

    return (
      <div className={styles.fieldWrapper}>
        {label && (
          <label htmlFor={inputId} className={styles.label}>
            {label}
          </label>
        )}
        <textarea
          ref={ref}
          id={inputId}
          className={styles.textarea}
          data-error={error ? true : undefined}
          {...props}
        />
        {error && <span className={styles.error}>{error}</span>}
        {helperText && !error && (
          <span className={styles.helper}>{helperText}</span>
        )}
      </div>
    );
  }
);

Textarea.displayName = 'Textarea';
