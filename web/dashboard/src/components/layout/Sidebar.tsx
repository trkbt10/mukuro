import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  Puzzle,
  FileText,
  Settings,
  ChevronRight,
  MessagesSquare,
} from 'lucide-react';
import { cn } from '@/lib/utils';

interface NavItem {
  to: string;
  icon: React.ComponentType<{ className?: string }>;
  label: string;
}

const navItems: NavItem[] = [
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/plugins', icon: Puzzle, label: 'Plugins' },
  { to: '/providers', icon: MessagesSquare, label: 'Providers' },
  { to: '/context', icon: FileText, label: 'Context' },
  { to: '/settings', icon: Settings, label: 'Settings' },
];

export function Sidebar() {
  return (
    <aside className="flex h-screen w-64 flex-col border-r bg-surface-secondary">
      <div className="flex h-14 items-center border-b px-4">
        <div className="flex items-center gap-2">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary">
            <span className="text-sm font-bold text-white">M</span>
          </div>
          <span className="font-semibold text-text">mukuro</span>
        </div>
      </div>

      <nav className="flex-1 space-y-1 p-3">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-surface text-text'
                  : 'text-text-secondary hover:bg-surface hover:text-text'
              )
            }
          >
            {({ isActive }) => (
              <>
                <item.icon className="h-5 w-5" />
                <span className="flex-1">{item.label}</span>
                {isActive && (
                  <ChevronRight className="h-4 w-4 text-text-muted" />
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      <div className="border-t p-4">
        <div className="flex items-center gap-3">
          <div className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-tertiary">
            <span className="text-xs font-medium text-text-secondary">A</span>
          </div>
          <div className="flex-1 min-w-0">
            <p className="truncate text-sm font-medium text-text">Admin</p>
            <p className="truncate text-xs text-text-muted">admin@local</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
