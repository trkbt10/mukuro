import { useEffect, useState } from 'react';
import { X, CheckCircle, AlertCircle, AlertTriangle, Info } from 'lucide-react';
import styles from './Toast.module.css';

export type ToastType = 'success' | 'error' | 'warning' | 'info';

export interface ToastData {
  id: string;
  type: ToastType;
  title: string;
  description?: string;
  duration?: number;
}

interface ToastProps extends ToastData {
  onDismiss: (id: string) => void;
}

const icons: Record<ToastType, React.ComponentType<{ className?: string; style?: React.CSSProperties }>> = {
  success: CheckCircle,
  error: AlertCircle,
  warning: AlertTriangle,
  info: Info,
};

const typeStyles: Record<ToastType, string> = {
  success: styles.success,
  error: styles.error,
  warning: styles.warning,
  info: styles.info,
};

const iconTypeStyles: Record<ToastType, string> = {
  success: styles.iconSuccess,
  error: styles.iconError,
  warning: styles.iconWarning,
  info: styles.iconInfo,
};

function ToastItem({ id, type, title, description, duration = 5000, onDismiss }: ToastProps) {
  useEffect(() => {
    if (duration > 0) {
      const timer = setTimeout(() => onDismiss(id), duration);
      return () => clearTimeout(timer);
    }
  }, [id, duration, onDismiss]);

  const Icon = icons[type];

  return (
    <div className={`${styles.toast} ${typeStyles[type]}`} role="alert">
      <div className={styles.inner}>
        <Icon className={`${styles.icon} ${iconTypeStyles[type]}`} />
        <div className={styles.content}>
          <p className={styles.title}>{title}</p>
          {description && <p className={styles.desc}>{description}</p>}
        </div>
        <button
          onClick={() => onDismiss(id)}
          className={styles.dismiss}
          aria-label="Dismiss"
        >
          <X style={{ width: 14, height: 14 }} />
        </button>
      </div>
    </div>
  );
}

let toastId = 0;
const listeners: Set<(toasts: ToastData[]) => void> = new Set();
let toasts: ToastData[] = [];

function notify() {
  listeners.forEach((listener) => listener([...toasts]));
}

export function toast(options: Omit<ToastData, 'id'>): string {
  const id = String(++toastId);
  toasts = [...toasts, { ...options, id }];
  notify();
  return id;
}

toast.success = (title: string, description?: string) =>
  toast({ type: 'success', title, description });

toast.error = (title: string, description?: string) =>
  toast({ type: 'error', title, description });

toast.warning = (title: string, description?: string) =>
  toast({ type: 'warning', title, description });

toast.info = (title: string, description?: string) =>
  toast({ type: 'info', title, description });

toast.dismiss = (id: string) => {
  toasts = toasts.filter((t) => t.id !== id);
  notify();
};

export function Toaster() {
  const [localToasts, setLocalToasts] = useState<ToastData[]>([]);

  useEffect(() => {
    listeners.add(setLocalToasts);
    return () => {
      listeners.delete(setLocalToasts);
    };
  }, []);

  if (localToasts.length === 0) return null;

  return (
    <div className={styles.container}>
      {localToasts.map((t) => (
        <ToastItem key={t.id} {...t} onDismiss={toast.dismiss} />
      ))}
    </div>
  );
}
