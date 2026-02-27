import { WifiOff, RefreshCw } from 'lucide-react';
import { useConnection } from '@/hooks/useConnection';
import { Button } from '@/components/ui';
import { useQueryClient } from '@tanstack/react-query';
import styles from './ConnectionOverlay.module.css';

export function ConnectionOverlay() {
  const { data, isLoading, refetch } = useConnection();
  const queryClient = useQueryClient();

  if (isLoading) return null;
  if (data?.status === 'connected') return null;

  const handleRetry = () => {
    queryClient.clear();
    refetch();
  };

  return (
    <div className={styles.overlay}>
      <div className={styles.card}>
        <div className={styles.iconWrap}>
          <div className={styles.iconCircle}>
            <WifiOff style={{ width: 28, height: 28, color: 'var(--mk-error)' }} />
          </div>
        </div>

        <h2 className={styles.title}>
          {data?.status === 'error' ? 'Connection Error' : 'Not Connected'}
        </h2>

        <p className={styles.message}>
          {data?.error ??
            'Unable to connect to mukuro server. Make sure the server is running.'}
        </p>

        <div className={styles.actions}>
          <Button
            onClick={handleRetry}
            leftIcon={<RefreshCw style={{ width: 14, height: 14 }} />}
          >
            Retry Connection
          </Button>

          <p className={styles.hint}>
            Expected server at:{' '}
            <code className={styles.code}>localhost:6960</code>
          </p>
        </div>
      </div>
    </div>
  );
}
