import styles from './Toggle.module.css';

export interface ToggleProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  label?: string;
  description?: string;
  size?: 'xs' | 'sm' | 'md';
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

  const trackSizeClass =
    size === 'xs' ? styles.trackXs : size === 'sm' ? styles.trackSm : styles.trackMd;
  const thumbSizeClass =
    size === 'xs' ? styles.thumbXs : size === 'sm' ? styles.thumbSm : styles.thumbMd;
  const thumbOnClass =
    size === 'xs' ? styles.thumbOnXs : size === 'sm' ? styles.thumbOnSm : styles.thumbOnMd;

  const trackCls = [styles.track, trackSizeClass, checked ? styles.trackOn : styles.trackOff].join(' ');
  const thumbCls = [styles.thumb, thumbSizeClass, checked ? thumbOnClass : styles.thumbOff].join(' ');

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
