import { useState } from 'react';
import { Zap, Check } from 'lucide-react';
import { Button } from '@/components/ui';
import { useOnboarding } from '@/hooks/useOnboarding';
import { ProviderStep } from './ProviderStep';
import { WorkspaceStep } from './WorkspaceStep';
import { ChannelStep } from './ChannelStep';
import { HealthCheckStep } from './HealthCheckStep';
import styles from './OnboardingWizard.module.css';

const STEPS = [
  { key: 'provider', label: 'Provider' },
  { key: 'workspace', label: 'Workspace' },
  { key: 'channel', label: 'Channel' },
  { key: 'health', label: 'Check' },
] as const;

export function OnboardingWizard() {
  const onboarding = useOnboarding();
  const [step, setStep] = useState(() => onboarding.initialStep);
  const [completedSteps, setCompletedSteps] = useState<Set<number>>(new Set());

  if (!onboarding.shouldShow) return null;

  const markComplete = (stepIndex: number) => {
    setCompletedSteps((prev) => new Set(prev).add(stepIndex));
  };

  const goTo = (targetStep: number) => {
    setStep(targetStep);
  };

  const next = () => {
    markComplete(step);
    if (step < STEPS.length - 1) {
      setStep(step + 1);
    } else {
      onboarding.dismiss();
    }
  };

  const back = () => {
    if (step > 0) setStep(step - 1);
  };

  const skip = () => onboarding.dismiss();

  const finish = () => {
    markComplete(step);
    onboarding.dismiss();
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
            <h2 className={styles.title}>Setup mukuro</h2>
          </div>
          <p className={styles.subtitle}>
            Configure your instance in a few steps. You can always change these settings later.
          </p>

          {/* Progress */}
          <div className={styles.progress}>
            {STEPS.map((s, i) => (
              <div key={s.key} className={styles.stepItem}>
                <div
                  className={`${styles.stepDot} ${i === step ? styles.active : ''} ${completedSteps.has(i) ? styles.completed : ''}`}
                >
                  {completedSteps.has(i) ? (
                    <Check style={{ width: 12, height: 12 }} />
                  ) : (
                    i + 1
                  )}
                </div>
                {i < STEPS.length - 1 && (
                  <div className={`${styles.stepLine} ${completedSteps.has(i) ? styles.filled : ''}`} />
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Body */}
        <div className={styles.body}>
          {step === 0 && <ProviderStep onComplete={next} />}
          {step === 1 && <WorkspaceStep onComplete={next} />}
          {step === 2 && <ChannelStep onComplete={next} />}
          {step === 3 && <HealthCheckStep onComplete={finish} onGoToStep={goTo} />}
        </div>

        {/* Footer */}
        <div className={styles.footer}>
          <div className={styles.footerLeft}>
            <Button variant="ghost" size="sm" onClick={skip}>
              Skip for now
            </Button>
          </div>
          <div className={styles.footerRight}>
            {step > 0 && (
              <Button variant="secondary" size="sm" onClick={back}>
                Back
              </Button>
            )}
            {step < STEPS.length - 1 && (
              <Button variant="secondary" size="sm" onClick={next}>
                Skip step
              </Button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
