import { WifiOff, RefreshCw } from 'lucide-react';
import { useConnection } from '@/hooks/useConnection';
import { Button } from '@/components/ui';
import { useQueryClient } from '@tanstack/react-query';

export function ConnectionOverlay() {
  const { data, isLoading, refetch } = useConnection();
  const queryClient = useQueryClient();

  // Don't show overlay while initial loading
  if (isLoading) {
    return null;
  }

  // Don't show overlay if connected
  if (data?.status === 'connected') {
    return null;
  }

  const handleRetry = () => {
    // Clear all cached queries and retry connection
    queryClient.clear();
    refetch();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div className="bg-surface rounded-lg shadow-modal p-8 max-w-md mx-4 text-center animate-fade-in">
        <div className="flex justify-center mb-4">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30">
            <WifiOff className="h-8 w-8 text-red-600 dark:text-red-400" />
          </div>
        </div>

        <h2 className="text-xl font-semibold text-text mb-2">
          {data?.status === 'error' ? 'Connection Error' : 'Not Connected'}
        </h2>

        <p className="text-text-secondary mb-6">
          {data?.error ?? 'Unable to connect to mukuro server. Make sure the server is running.'}
        </p>

        <div className="space-y-3">
          <Button
            onClick={handleRetry}
            leftIcon={<RefreshCw className="h-4 w-4" />}
            className="w-full"
          >
            Retry Connection
          </Button>

          <p className="text-xs text-text-muted">
            Expected server at: <code className="bg-surface-secondary px-1 rounded">localhost:6960</code>
          </p>
        </div>
      </div>
    </div>
  );
}
