import {
  Wifi,
  WifiOff,
  Loader2,
  AlertCircle,
  ShieldAlert,
} from 'lucide-react';
import { Badge } from '@/components/ui';
import type { ChatStatus } from '@/hooks/useChat';

const iconSm = { width: 10, height: 10, marginRight: 4 };

export function StatusBadge({ status }: { status: ChatStatus }) {
  const config: Record<
    ChatStatus,
    { label: string; variant: 'success' | 'warning' | 'error' | 'default'; icon: React.ReactNode }
  > = {
    connected:    { label: 'Connected',    variant: 'success', icon: <Wifi style={iconSm} /> },
    thinking:     { label: 'Thinking...',  variant: 'warning', icon: <Wifi style={iconSm} /> },
    connecting:   { label: 'Connecting',   variant: 'default', icon: <Loader2 style={{ ...iconSm, animation: 'spin 1s linear infinite' }} /> },
    disconnected: { label: 'Disconnected', variant: 'error',   icon: <WifiOff style={iconSm} /> },
    error:        { label: 'Error',        variant: 'error',   icon: <AlertCircle style={iconSm} /> },
    auth_error:   { label: 'Auth Required',variant: 'warning', icon: <ShieldAlert style={iconSm} /> },
  };

  const { label, variant, icon } = config[status];
  return (
    <Badge variant={variant} size="sm">
      {icon}
      {label}
    </Badge>
  );
}
