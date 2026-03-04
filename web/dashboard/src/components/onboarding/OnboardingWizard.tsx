import { Zap } from 'lucide-react';
import { Button } from '@/components/ui';
import { useOnboarding } from '@/hooks/useOnboarding';
import { ProviderStep } from './ProviderStep';
import styles from './OnboardingWizard.module.css';

/**
 * LLM初期設定ウィザード
 *
 * 表示条件: プロバイダーにAPIキーが設定されていない
 * 目的: LLMを使用可能にするための最低限の設定
 *
 * LLM使用可能後のオンボーディングはチャットで行う
 */
export function OnboardingWizard() {
  const { shouldShow, complete } = useOnboarding();

  if (!shouldShow) return null;

  const handleComplete = () => {
    void complete();
  };

  return (
    <div className={styles.overlay}>
      <div className={styles.wizard}>
        {/* Header */}
        <div className={styles.header}>
          <div className={styles.headerTop}>
            <div className={styles.headerIcon}>
              <Zap style={{ width: 18, height: 18, color: 'var(--mk-accent)' }} />
            </div>
            <h2 className={styles.title}>Connect to AI</h2>
          </div>
          <p className={styles.subtitle}>
            Configure your AI provider to get started. You can change this later in Settings.
          </p>
        </div>

        {/* Body */}
        <div className={styles.body}>
          <ProviderStep onComplete={handleComplete} />
        </div>

        {/* Footer */}
        <div className={styles.footer}>
          <div className={styles.footerLeft}>
            <Button variant="ghost" size="sm" onClick={handleComplete}>
              Skip for now
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
