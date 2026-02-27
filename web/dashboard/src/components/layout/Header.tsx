import { Moon, Sun, Wifi, WifiOff, Loader2 } from 'lucide-react';
import { useEffect, useState } from 'react';
import { useConnection, type ConnectionStatus } from '@/hooks/useConnection';
import { cn } from '@/lib/utils';

function ConnectionIndicator() {
  const { data, isLoading } = useConnection();
  const status: ConnectionStatus = isLoading ? 'connecting' : (data?.status ?? 'disconnected');

  const statusConfig = {
    connecting: {
      icon: Loader2,
      className: 'text-yellow-500 animate-spin',
      label: 'Connecting...',
    },
    connected: {
      icon: Wifi,
      className: 'text-green-500',
      label: 'Connected',
    },
    disconnected: {
      icon: WifiOff,
      className: 'text-red-500',
      label: 'Disconnected',
    },
    error: {
      icon: WifiOff,
      className: 'text-orange-500',
      label: data?.error ?? 'Error',
    },
  };

  const config = statusConfig[status];
  const Icon = config.icon;

  return (
    <div className="flex items-center gap-2 text-sm">
      <Icon className={cn('h-4 w-4', config.className)} />
      <span className="text-text-secondary hidden sm:inline">{config.label}</span>
    </div>
  );
}

export function Header() {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem('theme');
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const shouldBeDark = stored === 'dark' || (!stored && prefersDark);
    setIsDark(shouldBeDark);
    document.documentElement.classList.toggle('dark', shouldBeDark);
  }, []);

  const toggleTheme = () => {
    const newValue = !isDark;
    setIsDark(newValue);
    document.documentElement.classList.toggle('dark', newValue);
    localStorage.setItem('theme', newValue ? 'dark' : 'light');
  };

  return (
    <header className="flex h-14 items-center justify-between border-b bg-surface px-6">
      <div className="flex items-center gap-4">
        <h1 className="text-lg font-semibold text-text">Dashboard</h1>
      </div>

      <div className="flex items-center gap-4">
        <ConnectionIndicator />

        <button
          onClick={toggleTheme}
          className="flex h-9 w-9 items-center justify-center rounded-md text-text-secondary transition-colors hover:bg-surface-secondary hover:text-text"
          aria-label="Toggle theme"
        >
          {isDark ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
        </button>
      </div>
    </header>
  );
}
