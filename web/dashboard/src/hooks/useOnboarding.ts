import { useCallback } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { useConnection } from '@/hooks';
import { useAiProviders } from '@/hooks/useSettings';

export interface OnboardingState {
  /** True if no provider has API key configured */
  needsProvider: boolean;
  /** True if at least one provider has API key */
  hasProvider: boolean;
  isLoading: boolean;
  /** Show LLM setup wizard (only when no provider configured) */
  shouldShow: boolean;
  /** Mark setup as complete (invalidates provider cache) */
  complete: () => Promise<void>;
}

/**
 * LLM初期設定の状態管理
 *
 * Source of Truth: config.json (providers配列)
 * - hasProvider: いずれかのプロバイダーにAPIキーが設定されているか
 * - shouldShow: プロバイダー未設定の場合のみウィザードを表示
 *
 * LLM使用可能後のオンボーディングはチャットで行う（BOOTSTRAP.md参照）
 */
export function useOnboarding(): OnboardingState {
  const { data: connection } = useConnection();
  const { data: providers, isLoading } = useAiProviders();
  const queryClient = useQueryClient();

  // Check if any provider has an API key
  const hasProvider = providers?.some((p) => p.has_api_key) ?? false;
  const needsProvider = !hasProvider;

  const complete = useCallback(async () => {
    // Refetch providers to reflect any changes (await ensures data is updated before returning)
    await queryClient.refetchQueries({ queryKey: ['settings', 'providers'] });
  }, [queryClient]);

  const isConnected = connection?.status === 'connected';

  // Show wizard only when connected and no provider has API key
  const shouldShow = isConnected && !isLoading && needsProvider;

  return {
    needsProvider,
    hasProvider,
    isLoading,
    shouldShow,
    complete,
  };
}
