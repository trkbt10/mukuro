import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Plug, PlugZap, Trash2, TestTube } from 'lucide-react';
import {
  Button,
  Badge,
  Toggle,
  Loading,
  PanelSection,
  PropertyRow,
  DeleteConfirmModal,
} from '@/components/ui';
import {
  useMessageProvider,
  useEnableMessageProvider,
  useDisableMessageProvider,
  useConnectMessageProvider,
  useDisconnectMessageProvider,
  useTestMessageProvider,
  useDeleteMessageProvider,
} from '@/hooks';
import styles from './ProviderDetail.module.css';

export function ProviderDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const { data: provider, isLoading } = useMessageProvider(id ?? '');
  const enableProvider = useEnableMessageProvider();
  const disableProvider = useDisableMessageProvider();
  const connectProvider = useConnectMessageProvider();
  const disconnectProvider = useDisconnectMessageProvider();
  const testProvider = useTestMessageProvider();
  const deleteProvider = useDeleteMessageProvider();

  const [deleteModalOpen, setDeleteModalOpen] = useState(false);

  if (isLoading) {
    return <Loading message="Loading provider..." />;
  }

  if (!provider) {
    return (
      <div className={styles.emptyState}>
        <p className={styles.notFoundText}>Provider not found</p>
      </div>
    );
  }

  const handleToggle = () => {
    if (provider.enabled) disableProvider.mutate(provider.id);
    else enableProvider.mutate(provider.id);
  };

  const handleConnect = () => {
    if (provider.status === 'connected' || provider.status === 'connecting') {
      disconnectProvider.mutate(provider.id);
    } else {
      connectProvider.mutate(provider.id);
    }
  };

  const handleDelete = () => {
    deleteProvider.mutate(provider.id, {
      onSuccess: () => navigate('/providers'),
    });
  };

  const getStatusVariant = (status: string) => {
    if (status === 'connected') return 'success' as const;
    if (status === 'connecting') return 'warning' as const;
    if (status.startsWith('error')) return 'error' as const;
    return 'default' as const;
  };

  return (
    <div className={styles.page}>
      <div className={styles.titleRow}>
        <div>
          <div className={styles.titleGroup}>
            <h1 className={styles.pageTitle}>{provider.name}</h1>
            <Badge variant={getStatusVariant(provider.status)} size="sm">
              {provider.status}
            </Badge>
          </div>
          <p className={styles.providerId}>{provider.id}</p>
        </div>
        <div className={styles.actions}>
          <Button
            variant="secondary"
            size="sm"
            onClick={handleConnect}
            leftIcon={
              provider.status === 'connected'
                ? <PlugZap style={{ width: 14, height: 14, color: 'var(--mk-success)' }} />
                : <Plug style={{ width: 14, height: 14 }} />
            }
          >
            {provider.status === 'connected' ? 'Disconnect' : 'Connect'}
          </Button>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => testProvider.mutate(provider.id)}
            loading={testProvider.isPending}
            leftIcon={<TestTube style={{ width: 14, height: 14 }} />}
          >
            Test
          </Button>
          <Button
            variant="danger"
            size="sm"
            onClick={() => setDeleteModalOpen(true)}
            leftIcon={<Trash2 style={{ width: 14, height: 14 }} />}
          >
            Delete
          </Button>
        </div>
      </div>

      <div className={styles.grid}>
        <PanelSection title="Details">
          <div className={styles.propList}>
            <PropertyRow label="Type">
              <Badge variant="default">{provider.provider_type}</Badge>
            </PropertyRow>
            <PropertyRow label="Status">
              <Badge variant={getStatusVariant(provider.status)}>
                {provider.status}
              </Badge>
            </PropertyRow>
            <PropertyRow label="Auto Connect">
              {provider.auto_connect ? 'Yes' : 'No'}
            </PropertyRow>
            {provider.last_error && (
              <PropertyRow label="Last Error">
                <span className={styles.errorText}>{provider.last_error}</span>
              </PropertyRow>
            )}
            <div className={styles.enableRow}>
              <span className={styles.enableLabel}>Enable Provider</span>
              <Toggle
                checked={provider.enabled}
                onChange={handleToggle}
                disabled={enableProvider.isPending || disableProvider.isPending}
              />
            </div>
          </div>
        </PanelSection>

        <PanelSection title="Statistics">
          <div className={styles.propList}>
            <PropertyRow label="Messages Sent">
              <span className={styles.statValue}>{provider.messages_sent}</span>
            </PropertyRow>
            <PropertyRow label="Messages Received">
              <span className={styles.statValue}>{provider.messages_received}</span>
            </PropertyRow>
          </div>
        </PanelSection>

        {provider.settings && Object.keys(provider.settings).length > 0 && (
          <PanelSection title="Settings">
            <div className={styles.propList}>
              {Object.entries(provider.settings).map(([key, value]) => (
                <PropertyRow key={key} label={key}>
                  {typeof value === 'string' && (key.includes('key') || key.includes('token') || key.includes('secret'))
                    ? '••••••••'
                    : String(value)}
                </PropertyRow>
              ))}
            </div>
          </PanelSection>
        )}
      </div>

      <DeleteConfirmModal
        open={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        title="Delete Provider"
        description="Are you sure you want to delete this provider? This action cannot be undone."
        onConfirm={handleDelete}
        isPending={deleteProvider.isPending}
      >
        <p className={styles.modalText}>
          Provider <strong>{provider.name}</strong> will be permanently removed.
          Any active connections will be terminated.
        </p>
      </DeleteConfirmModal>
    </div>
  );
}
