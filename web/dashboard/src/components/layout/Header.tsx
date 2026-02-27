import { Moon, Sun, Wifi, WifiOff, Loader2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useConnection, type ConnectionStatus } from '@/hooks/useConnection';
import {
  Toolbar,
  ToolbarGroup,
  ToolbarDivider,
  IconButton,
  StatusBarItem,
} from 'react-editor-ui';

function ConnectionIndicator() {
  const { data, isLoading } = useConnection();
  const status: ConnectionStatus = isLoading
    ? 'connecting'
    : (data?.status ?? 'disconnected');

  const iconSize = { width: 14, height: 14 };

  const configs: Record<ConnectionStatus, { icon: React.ReactNode; label: string }> = {
    connecting: {
      icon: <Loader2 style={{ ...iconSize, animation: 'spin 1s linear infinite', color: 'var(--mk-warning)' }} />,
      label: 'Connecting...',
    },
    connected: {
      icon: <Wifi style={{ ...iconSize, color: 'var(--mk-success)' }} />,
      label: 'Connected',
    },
    disconnected: {
      icon: <WifiOff style={{ ...iconSize, color: 'var(--mk-error)' }} />,
      label: 'Disconnected',
    },
    error: {
      icon: <WifiOff style={{ ...iconSize, color: 'var(--mk-warning)' }} />,
      label: data?.error ?? 'Error',
    },
  };

  const config = configs[status];

  return (
    <StatusBarItem>
      <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        {config.icon}
        <span>{config.label}</span>
      </span>
    </StatusBarItem>
  );
}

export function Header() {
  const [isDark, setIsDark] = useState(true);

  useEffect(() => {
    const stored = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    setIsDark(stored === 'dark' || stored === null || (!stored && prefersDark));
  }, []);

  const toggleTheme = () => {
    const newValue = !isDark;
    setIsDark(newValue);
    localStorage.setItem('theme', newValue ? 'dark' : 'light');
  };

  return (
    <Toolbar>
      <ToolbarGroup>
        <StatusBarItem>
          <span style={{ fontWeight: 600, fontSize: 'var(--mk-font-size-lg)' }}>
            Dashboard
          </span>
        </StatusBarItem>
      </ToolbarGroup>
      <ToolbarDivider />
      <ToolbarGroup>
        <ConnectionIndicator />
        <IconButton
          icon={isDark ? <Sun style={{ width: 16, height: 16 }} /> : <Moon style={{ width: 16, height: 16 }} />}
          aria-label="Toggle theme"
          onClick={toggleTheme}
          variant="ghost"
          size="sm"
        />
      </ToolbarGroup>
    </Toolbar>
  );
}
