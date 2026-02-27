import { useState } from 'react';
import { Link } from 'react-router-dom';
import { RefreshCw, Upload, Search } from 'lucide-react';
import {
  Card,
  CardContent,
  Button,
  Input,
  Badge,
  Toggle,
  Loading,
  Modal,
  toast,
} from '@/components/ui';
import {
  usePlugins,
  useEnablePlugin,
  useDisablePlugin,
  useReloadPlugin,
  useUploadPlugin,
} from '@/hooks';
import { formatRelativeTime } from '@/lib/utils';

export function Plugins() {
  const { data: plugins, isLoading, refetch } = usePlugins();
  const enablePlugin = useEnablePlugin();
  const disablePlugin = useDisablePlugin();
  const reloadPlugin = useReloadPlugin();
  const uploadPlugin = useUploadPlugin();

  const [search, setSearch] = useState('');
  const [uploadModalOpen, setUploadModalOpen] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);

  const filteredPlugins = plugins?.filter(
    (p) =>
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      p.id.toLowerCase().includes(search.toLowerCase())
  );

  const handleToggle = (id: string, enabled: boolean) => {
    if (enabled) {
      disablePlugin.mutate(id);
    } else {
      enablePlugin.mutate(id);
    }
  };

  const handleReload = (id: string) => {
    reloadPlugin.mutate(id);
  };

  const handleUpload = () => {
    if (!selectedFile) {
      toast.error('Please select a file');
      return;
    }
    uploadPlugin.mutate(
      { file: selectedFile },
      {
        onSuccess: () => {
          setUploadModalOpen(false);
          setSelectedFile(null);
        },
      }
    );
  };

  if (isLoading) {
    return <Loading message="Loading plugins..." />;
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-text">Plugins</h1>
          <p className="text-text-secondary">
            Manage your installed plugins
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => refetch()}
            leftIcon={<RefreshCw className="h-4 w-4" />}
          >
            Refresh
          </Button>
          <Button
            size="sm"
            onClick={() => setUploadModalOpen(true)}
            leftIcon={<Upload className="h-4 w-4" />}
          >
            Upload Plugin
          </Button>
        </div>
      </div>

      <Input
        placeholder="Search plugins..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        leftElement={<Search className="h-4 w-4" />}
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {filteredPlugins && filteredPlugins.length > 0 ? (
          filteredPlugins.map((plugin) => (
            <Card key={plugin.id} className="flex flex-col">
              <CardContent className="flex-1">
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <Link
                      to={`/plugins/${plugin.id}`}
                      className="font-semibold text-text hover:text-primary transition-colors"
                    >
                      {plugin.name}
                    </Link>
                    <p className="text-sm text-text-muted truncate">
                      {plugin.id}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    {plugin.is_builtin && (
                      <Badge variant="default" size="sm">
                        Builtin
                      </Badge>
                    )}
                    <Badge
                      variant={plugin.enabled ? 'success' : 'secondary'}
                      size="sm"
                    >
                      {plugin.enabled ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                </div>

                {plugin.description && (
                  <p className="mt-2 text-sm text-text-secondary line-clamp-2">
                    {plugin.description}
                  </p>
                )}

                <div className="mt-4 space-y-2 text-sm text-text-secondary">
                  <div className="flex justify-between">
                    <span>Version</span>
                    <span className="text-text">{plugin.version}</span>
                  </div>
                  <div className="flex justify-between">
                    <span>Status</span>
                    <span className="text-text">{plugin.status}</span>
                  </div>
                  {!plugin.is_builtin && (
                    <div className="flex justify-between">
                      <span>Loaded</span>
                      <span className="text-text">
                        {formatRelativeTime(plugin.loaded_at)}
                      </span>
                    </div>
                  )}
                </div>
              </CardContent>

              <div className="border-t px-6 py-3 flex items-center justify-between">
                <Toggle
                  checked={plugin.enabled}
                  onChange={() => handleToggle(plugin.id, plugin.enabled)}
                  size="sm"
                />
                {!plugin.is_builtin && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleReload(plugin.id)}
                    loading={reloadPlugin.isPending}
                  >
                    <RefreshCw className="h-4 w-4" />
                  </Button>
                )}
              </div>
            </Card>
          ))
        ) : (
          <div className="col-span-full text-center py-12">
            <p className="text-text-secondary">
              {search ? 'No plugins match your search' : 'No plugins installed'}
            </p>
          </div>
        )}
      </div>

      <Modal
        open={uploadModalOpen}
        onClose={() => setUploadModalOpen(false)}
        title="Upload Plugin"
        description="Upload a plugin ZIP package"
        size="sm"
        footer={
          <>
            <Button
              variant="secondary"
              onClick={() => setUploadModalOpen(false)}
            >
              Cancel
            </Button>
            <Button
              onClick={handleUpload}
              loading={uploadPlugin.isPending}
              disabled={!selectedFile}
            >
              Upload
            </Button>
          </>
        }
      >
        <div className="space-y-4">
          <input
            type="file"
            accept=".zip"
            onChange={(e) => setSelectedFile(e.target.files?.[0] ?? null)}
            className="w-full text-sm text-text file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-primary file:text-white hover:file:bg-primary-hover"
          />
          {selectedFile && (
            <p className="text-sm text-text-secondary">
              Selected: {selectedFile.name}
            </p>
          )}
        </div>
      </Modal>
    </div>
  );
}
