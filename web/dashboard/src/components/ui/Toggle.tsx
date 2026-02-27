import styles from './Toggle.module.css';

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
    if (!disabled) onChange(!checked);
  };

  const wrapperCls = [
    styles.wrapper,
    label ? styles.withLabel : '',
    disabled ? styles.disabled : '',
  ]
    .filter(Boolean)
    .join(' ');

  const trackCls = [
    styles.track,
    size === 'sm' ? styles.trackSm : styles.trackMd,
    checked ? styles.trackOn : styles.trackOff,
  ].join(' ');

  const thumbCls = [
    styles.thumb,
    size === 'sm' ? styles.thumbSm : styles.thumbMd,
    checked
      ? size === 'sm'
        ? styles.thumbOnSm
        : styles.thumbOnMd
      : styles.thumbOff,
  ].join(' ');

  return (
    <div className={wrapperCls}>
      {(label || description) && (
        <div className={styles.labelGroup}>
          {label && <span className={styles.label}>{label}</span>}
          {description && <p className={styles.description}>{description}</p>}
        </div>
      )}
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        disabled={disabled}
        onClick={handleClick}
        className={trackCls}
      >
        <span aria-hidden="true" className={thumbCls} />
      </button>
    </div>
  );
}
