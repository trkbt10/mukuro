import { cn } from '@/lib/utils';

export interface ToggleProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  label?: string;
  description?: string;
  size?: 'sm' | 'md';
}

export function Toggle({
  checked,
  onChange,
  disabled = false,
  label,
  description,
  size = 'md',
}: ToggleProps) {
  const handleClick = () => {
    if (!disabled) {
      onChange(!checked);
    }
  };

  return (
    <div
      className={cn(
        'flex items-center',
        label && 'justify-between',
        disabled && 'opacity-50 cursor-not-allowed'
      )}
    >
      {(label || description) && (
        <div className="mr-4">
          {label && (
            <span className="text-sm font-medium text-text">{label}</span>
          )}
          {description && (
            <p className="text-sm text-text-muted">{description}</p>
          )}
        </div>
      )}
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={handleClick}
        className={cn(
          'relative inline-flex shrink-0 cursor-pointer rounded-full border-2 border-transparent',
          'transition-colors duration-200 ease-in-out',
          'focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2',
          checked ? 'bg-primary' : 'bg-surface-tertiary',
          disabled && 'cursor-not-allowed',
          size === 'sm' ? 'h-5 w-9' : 'h-6 w-11'
        )}
      >
        <span
          aria-hidden="true"
          className={cn(
            'pointer-events-none inline-block transform rounded-full bg-white shadow-lg ring-0',
            'transition duration-200 ease-in-out',
            size === 'sm' ? 'h-4 w-4' : 'h-5 w-5',
            checked
              ? size === 'sm'
                ? 'translate-x-4'
                : 'translate-x-5'
              : 'translate-x-0'
          )}
        />
      </button>
    </div>
  );
}
