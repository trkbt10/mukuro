import { Puzzle, MessageSquare, Settings as SettingsIcon, Activity } from 'lucide-react';
import { Link } from 'react-router-dom';
import { Card, CardContent, Loading } from '@/components/ui';
import { usePlugins, useAllSettings } from '@/hooks';
import { cn } from '@/lib/utils';

interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ComponentType<{ className?: string }>;
  href: string;
  color: string;
}

function StatCard({ title, value, icon: Icon, href, color }: StatCardProps) {
  return (
    <Link to={href}>
      <Card className="hover:shadow-md transition-shadow">
        <CardContent className="flex items-center gap-4">
          <div
            className={cn(
              'flex h-12 w-12 items-center justify-center rounded-lg',
              color
            )}
          >
            <Icon className="h-6 w-6 text-white" />
          </div>
          <div>
            <p className="text-sm text-text-secondary">{title}</p>
            <p className="text-2xl font-semibold text-text">{value}</p>
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

export function Dashboard() {
  const { data: plugins, isLoading: pluginsLoading } = usePlugins();
  const { data: settings, isLoading: settingsLoading } = useAllSettings();

  if (pluginsLoading || settingsLoading) {
    return <Loading message="Loading dashboard..." />;
  }

  const enabledPlugins = plugins?.filter((p) => p.enabled).length ?? 0;
  const totalPlugins = plugins?.length ?? 0;
  const providerCount = settings?.providers.length ?? 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-text">Dashboard</h1>
        <p className="text-text-secondary">
          Overview of your mukuro instance
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Active Plugins"
          value={`${enabledPlugins}/${totalPlugins}`}
          icon={Puzzle}
          href="/plugins"
          color="bg-primary"
        />
        <StatCard
          title="Prompts"
          value="Configured"
          icon={MessageSquare}
          href="/prompts"
          color="bg-blue-500"
        />
        <StatCard
          title="Providers"
          value={providerCount}
          icon={SettingsIcon}
          href="/settings"
          color="bg-purple-500"
        />
        <StatCard
          title="Status"
          value="Healthy"
          icon={Activity}
          href="/settings"
          color="bg-green-500"
        />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <div className="border-b px-6 py-4">
            <h2 className="text-lg font-semibold text-text">Recent Plugins</h2>
          </div>
          <CardContent>
            {plugins && plugins.length > 0 ? (
              <div className="space-y-3">
                {plugins.slice(0, 5).map((plugin) => (
                  <Link
                    key={plugin.id}
                    to={`/plugins/${plugin.id}`}
                    className="flex items-center justify-between rounded-lg border p-3 hover:bg-surface-secondary transition-colors"
                  >
                    <div>
                      <p className="font-medium text-text">{plugin.name}</p>
                      <p className="text-sm text-text-secondary">
                        v{plugin.version}
                      </p>
                    </div>
                    <span
                      className={cn(
                        'inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium',
                        plugin.enabled
                          ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400'
                          : 'bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400'
                      )}
                    >
                      {plugin.enabled ? 'Active' : 'Inactive'}
                    </span>
                  </Link>
                ))}
              </div>
            ) : (
              <p className="text-center text-text-secondary py-8">
                No plugins installed
              </p>
            )}
          </CardContent>
        </Card>

        <Card>
          <div className="border-b px-6 py-4">
            <h2 className="text-lg font-semibold text-text">Quick Settings</h2>
          </div>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium text-text">Model</p>
                  <p className="text-sm text-text-secondary">
                    {settings?.model.model_name ?? 'Not configured'}
                  </p>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium text-text">Max Retries</p>
                  <p className="text-sm text-text-secondary">
                    {settings?.retry.max_retries ?? 3}
                  </p>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium text-text">Max Iterations</p>
                  <p className="text-sm text-text-secondary">
                    {settings?.agent.max_iterations ?? 10}
                  </p>
                </div>
              </div>
              <Link
                to="/settings"
                className="block text-center text-sm text-primary hover:underline"
              >
                View all settings
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
