import { CheckCircle, AlertTriangle, XCircle, Sparkles } from 'lucide-react';
import { Button } from '@/components/ui';
import { useGatewayHealth, useAiProviders, useMessageProviders } from '@/hooks';
import styles from './OnboardingWizard.module.css';

interface Props {
  onComplete: () => void;
  onGoToStep: (step: number) => void;
}

type CheckStatus = 'ok' | 'warn' | 'error';

interface CheckItem {
  label: string;
  status: CheckStatus;
  message: string;
  fixStep?: number;
}

export function HealthCheckStep({ onComplete, onGoToStep }: Props) {
  const { data: health } = useGatewayHealth();
  const { data: providers } = useAiProviders();
  const { data: messageProviders } = useMessageProviders();

  const gatewayOk = health?.status === 'ok' || health?.status === 'healthy';
  const providersWithKey = providers?.filter((p) => p.has_api_key).length ?? 0;
  const connectedChannels = messageProviders?.filter((p) => p.status === 'connected').length ?? 0;
  const totalChannels = messageProviders?.length ?? 0;

  const checks: CheckItem[] = [
    {
      label: 'Gateway',
      status: gatewayOk ? 'ok' : 'error',
      message: gatewayOk ? 'Running' : 'Not responding',
    },
    {
      label: 'AI Provider',
      status: providersWithKey > 0 ? 'ok' : 'error',
      message: providersWithKey > 0
        ? `${providersWithKey} provider${providersWithKey > 1 ? 's' : ''} configured`
        : 'No API key configured',
      fixStep: 0,
    },
    {
      label: 'Channels',
      status: totalChannels === 0
        ? 'warn'
        : connectedChannels > 0
          ? 'ok'
          : 'warn',
      message: totalChannels === 0
        ? 'No channels added'
        : `${connectedChannels}/${totalChannels} connected`,
      fixStep: 2,
    },
  ];

  const allOk = checks.every((c) => c.status === 'ok');

  return (
    <div>
      <h3 className={styles.stepTitle}>Health Check</h3>
      <p className={styles.stepDesc}>
        Verifying your setup. Fix any issues or continue to start using mukuro.
      </p>

      <div className={styles.checkList}>
        {checks.map((check) => {
          const Icon = check.status === 'ok'
            ? CheckCircle
            : check.status === 'warn'
              ? AlertTriangle
              : XCircle;

          return (
            <div key={check.label} className={styles.checkRow}>
              <div className={styles.checkIcon} data-status={check.status}>
                <Icon style={{ width: 16, height: 16 }} />
              </div>
              <div className={styles.checkInfo}>
                <div className={styles.checkLabel}>{check.label}</div>
                <div className={styles.checkStatus}>{check.message}</div>
              </div>
              {check.status !== 'ok' && check.fixStep !== undefined && (
                <button
                  className={styles.checkAction}
                  onClick={() => onGoToStep(check.fixStep!)}
                >
                  Setup
                </button>
              )}
            </div>
          );
        })}
      </div>

      {allOk && (
        <div className={styles.successBlock}>
          <div className={styles.successIcon}>
            <Sparkles style={{ width: 28, height: 28, color: 'var(--mk-success)' }} />
          </div>
          <h4 className={styles.successTitle}>All systems go</h4>
          <p className={styles.successDesc}>
            Your mukuro instance is configured and ready.
          </p>
        </div>
      )}

      <div className={styles.saveRow} style={{ marginTop: 'var(--mk-space-xl)' }}>
        <Button onClick={onComplete}>
          {allOk ? 'Get Started' : 'Finish Setup'}
        </Button>
      </div>
    </div>
  );
}
