import { useEffect, useState } from 'react';
import { X, CheckCircle, AlertCircle, AlertTriangle, Info } from 'lucide-react';
import { cn } from '@/lib/utils';

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

const icons: Record<ToastType, React.ComponentType<{ className?: string }>> = {
  success: CheckCircle,
  error: AlertCircle,
  warning: AlertTriangle,
  info: Info,
};

const styles: Record<ToastType, string> = {
  success: 'border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-950',
  error: 'border-red-200 bg-red-50 dark:border-red-800 dark:bg-red-950',
  warning:
    'border-yellow-200 bg-yellow-50 dark:border-yellow-800 dark:bg-yellow-950',
  info: 'border-blue-200 bg-blue-50 dark:border-blue-800 dark:bg-blue-950',
};

const iconStyles: Record<ToastType, string> = {
  success: 'text-green-600 dark:text-green-400',
  error: 'text-red-600 dark:text-red-400',
  warning: 'text-yellow-600 dark:text-yellow-400',
  info: 'text-blue-600 dark:text-blue-400',
};

function Toast({ id, type, title, description, duration = 5000, onDismiss }: ToastProps) {
  useEffect(() => {
    if (duration > 0) {
      const timer = setTimeout(() => onDismiss(id), duration);
      return () => clearTimeout(timer);
    }
  }, [id, duration, onDismiss]);

  const Icon = icons[type];

  return (
    <div
      className={cn(
        'pointer-events-auto w-full max-w-sm rounded-lg border shadow-lg animate-slide-up',
        styles[type]
      )}
      role="alert"
    >
      <div className="flex items-start gap-3 p-4">
        <Icon className={cn('h-5 w-5 shrink-0', iconStyles[type])} />
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium text-text">{title}</p>
          {description && (
            <p className="mt-1 text-sm text-text-secondary">{description}</p>
          )}
        </div>
        <button
          onClick={() => onDismiss(id)}
          className="shrink-0 rounded-md p-1 text-text-muted hover:text-text transition-colors"
          aria-label="Dismiss"
        >
          <X className="h-4 w-4" />
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
    <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 pointer-events-none">
      {localToasts.map((t) => (
        <Toast key={t.id} {...t} onDismiss={toast.dismiss} />
      ))}
    </div>
  );
}
