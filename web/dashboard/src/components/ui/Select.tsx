import { Select as ReuiSelect } from 'react-editor-ui';
import styles from './Select.module.css';

export type SelectOption = {
  value: string;
  label: string;
  disabled?: boolean;
};

export interface SelectProps {
  label?: string;
  error?: string;
  helperText?: string;
  options: SelectOption[];
  value?: string;
  onChange?: (value: string) => void;
  placeholder?: string;
  disabled?: boolean;
  className?: string;
}

export function Select({
  label,
  error,
  helperText,
  options,
  value,
  onChange,
  placeholder,
  disabled,
  className,
}: SelectProps) {
  return (
    <div className={styles.fieldWrapper}>
      {label && <label className={styles.label}>{label}</label>}
      <ReuiSelect
        options={options}
        value={value ?? ''}
        onChange={(v) => onChange?.(v)}
        placeholder={placeholder}
        disabled={disabled}
        size="sm"
        className={className}
      />
      {error && <span className={styles.error}>{error}</span>}
      {helperText && !error && (
        <span className={styles.helper}>{helperText}</span>
      )}
    </div>
  );
}
