import { useState, useCallback } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Puzzle,
  FileText,
  MessagesSquare,
  PackageCheck,
  Radio,
  PlugZap,
  RefreshCw,
  Upload,
  Plus,
  Ghost,
  User,
  Rocket,
  Bot,
  Wrench,
  UserCircle,
  RotateCcw,
  Cpu,
  Brain,
  Sliders,
} from 'lucide-react';
import { TreeItem } from 'react-editor-ui';
import { LayerItem } from 'react-editor-ui/LayerItem';
import { Badge, IconButton } from '@/components/ui';
import { usePlugins, useMessageProviders, useContextFiles } from '@/hooks';
import styles from './Sidebar.module.css';

const iconSize = { width: 16, height: 16 };
const smallIcon = { width: 14, height: 14 };

const contextFileIcons: Record<string, React.ReactNode> = {
  soul: <Ghost style={smallIcon} />,
  identity: <User style={smallIcon} />,
  bootstrap: <Rocket style={smallIcon} />,
  agents: <Bot style={smallIcon} />,
  tools: <Wrench style={smallIcon} />,
  user: <UserCircle style={smallIcon} />,
};

const settingSections = [
  { id: 'retry', label: 'Retry', icon: <RotateCcw style={smallIcon} /> },
  { id: 'agent', label: 'Agent', icon: <Bot style={smallIcon} /> },
  { id: 'model', label: 'Model', icon: <Cpu style={smallIcon} /> },
  { id: 'thinking', label: 'Thinking', icon: <Brain style={smallIcon} /> },
] as const;

export function Sidebar() {
  const navigate = useNavigate();
  const { pathname } = useLocation();

  const { data: plugins, refetch: refetchPlugins } = usePlugins();
  const { data: providers, refetch: refetchProviders } = useMessageProviders();
  const { data: contextFiles } = useContextFiles();

  const [expanded, setExpanded] = useState<Set<string>>(() => {
    const init = new Set<string>();
    if (pathname.startsWith('/plugins')) init.add('plugins');
    if (pathname.startsWith('/providers')) init.add('providers');
    if (pathname.startsWith('/context')) init.add('context');
    if (pathname.startsWith('/settings')) init.add('settings');
    return init;
  });

  const toggle = useCallback((section: string) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(section)) next.delete(section);
      else next.add(section);
      return next;
    });
  }, []);

  return (
    <aside className={styles.sidebar}>
      <div className={styles.brand}>
        <div className={styles.logo}>M</div>
        <span className={styles.brandName}>mukuro</span>
      </div>

      <nav className={styles.nav} role="tree">
        {/* Dashboard */}
        <TreeItem
          label="Dashboard"
          icon={<LayoutDashboard style={iconSize} />}
          selected={pathname === '/dashboard' || pathname === '/'}
          onClick={() => navigate('/dashboard')}
        />

        {/* Plugins section */}
        <LayerItem
          id="plugins"
          label="Plugins"
          icon={<Puzzle style={iconSize} />}
          hasChildren
          expanded={expanded.has('plugins')}
          onToggle={() => toggle('plugins')}
          selected={pathname === '/plugins'}
          onPointerDown={() => navigate('/plugins')}
          showVisibilityToggle={false}
          showLockToggle={false}
          badge={<Badge variant="default" size="sm">{plugins?.length ?? 0}</Badge>}
        />
        {expanded.has('plugins') && (
          <>
            {plugins?.map((p) => (
              <LayerItem
                key={p.id}
                id={`plugin-${p.id}`}
                label={p.name}
                icon={p.is_builtin ? <PackageCheck style={smallIcon} /> : <Puzzle style={smallIcon} />}
                depth={1}
                selected={pathname === `/plugins/${p.id}`}
                onPointerDown={() => navigate(`/plugins/${p.id}`)}
                showVisibilityToggle={false}
                showLockToggle={false}
                badge={
                  <Badge variant={p.enabled ? 'success' : 'default'} size="sm">
                    {p.enabled ? 'On' : 'Off'}
                  </Badge>
                }
              />
            ))}
            <div className={styles.sectionActions}>
              <IconButton icon={<RefreshCw style={{ width: 12, height: 12 }} />} aria-label="Refresh plugins" onClick={() => refetchPlugins()} variant="ghost" size="sm" />
              <IconButton icon={<Upload style={{ width: 12, height: 12 }} />} aria-label="Upload plugin" onClick={() => navigate('/plugins')} variant="ghost" size="sm" />
            </div>
          </>
        )}

        {/* Providers section */}
        <LayerItem
          id="providers"
          label="Providers"
          icon={<MessagesSquare style={iconSize} />}
          hasChildren
          expanded={expanded.has('providers')}
          onToggle={() => toggle('providers')}
          selected={pathname === '/providers'}
          onPointerDown={() => navigate('/providers')}
          showVisibilityToggle={false}
          showLockToggle={false}
          badge={<Badge variant="default" size="sm">{providers?.length ?? 0}</Badge>}
        />
        {expanded.has('providers') && (
          <>
            {providers?.map((p) => (
              <LayerItem
                key={p.id}
                id={`provider-${p.id}`}
                label={p.name}
                icon={
                  p.status === 'connected'
                    ? <PlugZap style={{ ...smallIcon, color: 'var(--mk-success)' }} />
                    : <Radio style={smallIcon} />
                }
                depth={1}
                selected={pathname === `/providers/${p.id}`}
                onPointerDown={() => navigate(`/providers/${p.id}`)}
                showVisibilityToggle={false}
                showLockToggle={false}
                badge={
                  <Badge variant={p.status === 'connected' ? 'success' : 'default'} size="sm">
                    {p.status === 'connected' ? 'On' : 'Off'}
                  </Badge>
                }
              />
            ))}
            <div className={styles.sectionActions}>
              <IconButton icon={<RefreshCw style={{ width: 12, height: 12 }} />} aria-label="Refresh providers" onClick={() => refetchProviders()} variant="ghost" size="sm" />
              <IconButton icon={<Plus style={{ width: 12, height: 12 }} />} aria-label="Add provider" onClick={() => navigate('/providers')} variant="ghost" size="sm" />
            </div>
          </>
        )}

        {/* Context section */}
        <LayerItem
          id="context"
          label="Context"
          icon={<FileText style={iconSize} />}
          hasChildren
          expanded={expanded.has('context')}
          onToggle={() => toggle('context')}
          selected={pathname === '/context'}
          onPointerDown={() => navigate('/context')}
          showVisibilityToggle={false}
          showLockToggle={false}
          badge={<Badge variant="default" size="sm">{contextFiles?.length ?? 0}</Badge>}
        />
        {expanded.has('context') && contextFiles?.map((f) => (
          <LayerItem
            key={f.name}
            id={`context-${f.name}`}
            label={f.filename}
            icon={contextFileIcons[f.name] ?? <FileText style={smallIcon} />}
            depth={1}
            selected={pathname === `/context/${f.name}`}
            onPointerDown={() => navigate(`/context/${f.name}`)}
            showVisibilityToggle={false}
            showLockToggle={false}
            badge={
              <Badge variant={f.exists ? 'success' : 'default'} size="sm">
                {f.exists ? 'Set' : '—'}
              </Badge>
            }
          />
        ))}

        {/* Settings section */}
        <LayerItem
          id="settings"
          label="Settings"
          icon={<Sliders style={iconSize} />}
          hasChildren
          expanded={expanded.has('settings')}
          onToggle={() => toggle('settings')}
          selected={pathname === '/settings'}
          onPointerDown={() => navigate('/settings')}
          showVisibilityToggle={false}
          showLockToggle={false}
        />
        {expanded.has('settings') && settingSections.map((s) => (
          <LayerItem
            key={s.id}
            id={`settings-${s.id}`}
            label={s.label}
            icon={s.icon}
            depth={1}
            selected={pathname === `/settings/${s.id}`}
            onPointerDown={() => navigate(`/settings/${s.id}`)}
            showVisibilityToggle={false}
            showLockToggle={false}
          />
        ))}
      </nav>

      <div className={styles.userSection}>
        <div className={styles.userCard}>
          <div className={styles.avatar}>A</div>
          <div className={styles.userInfo}>
            <p className={styles.userName}>Admin</p>
            <p className={styles.userEmail}>admin@local</p>
          </div>
        </div>
      </div>
    </aside>
  );
}
