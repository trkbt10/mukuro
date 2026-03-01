import { useState, useMemo, useCallback } from 'react';
import { useAiProviders, useContextFiles, useMessageProviders, useConnection } from '@/hooks';

const DISMISS_KEY = 'mukuro-onboarding-dismissed';

export interface OnboardingState {
  needsProvider: boolean;
  needsWorkspace: boolean;
  needsChannel: boolean;
  isComplete: boolean;
  isLoading: boolean;
  shouldShow: boolean;
  dismissed: boolean;
  initialStep: number;
  dismiss: () => void;
  reset: () => void;
}

export function useOnboarding(): OnboardingState {
  const { data: connection } = useConnection();
  const { data: providers, isLoading: providersLoading } = useAiProviders();
  const { data: contextFiles, isLoading: contextLoading } = useContextFiles();
  const { data: messageProviders, isLoading: channelsLoading } = useMessageProviders();

  const [dismissed, setDismissed] = useState(
    () => localStorage.getItem(DISMISS_KEY) === 'true',
  );

  const dismiss = useCallback(() => {
    localStorage.setItem(DISMISS_KEY, 'true');
    setDismissed(true);
  }, []);

  const reset = useCallback(() => {
    localStorage.removeItem(DISMISS_KEY);
    setDismissed(false);
  }, []);

  const isLoading = providersLoading || contextLoading || channelsLoading;
  const isConnected = connection?.status === 'connected';

  const needsProvider = useMemo(
    () => !providers?.some((p) => p.has_api_key),
    [providers],
  );

  const needsWorkspace = useMemo(() => {
    if (!contextFiles) return true;
    const soul = contextFiles.find((f) => f.name === 'soul');
    const identity = contextFiles.find((f) => f.name === 'identity');
    return !soul?.exists || soul.is_default || !identity?.exists || identity.is_default;
  }, [contextFiles]);

  const needsChannel = useMemo(
    () => !messageProviders || messageProviders.length === 0,
    [messageProviders],
  );

  const isComplete = !needsProvider && !needsWorkspace && !needsChannel;

  const initialStep = needsProvider ? 0 : needsWorkspace ? 1 : needsChannel ? 2 : 3;

  const shouldShow = isConnected && !isLoading && !isComplete && !dismissed;

  return {
    needsProvider,
    needsWorkspace,
    needsChannel,
    isComplete,
    isLoading,
    shouldShow,
    dismissed,
    initialStep,
    dismiss,
    reset,
  };
}
