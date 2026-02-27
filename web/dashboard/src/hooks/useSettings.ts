import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type {
  UpdateRetrySettings,
  UpdateAgentSettings,
  UpdateModelSettings,
  UpdateThinkingSettings,
  UpdateProviderSettings,
} from '@mukuro/client';
import { createMutation } from './mutation';

const SETTINGS_KEY = ['settings'];

export function useAllSettings() {
  return useQuery({
    queryKey: SETTINGS_KEY,
    queryFn: () => getClient().settings.getAll(),
  });
}

export function useRetrySettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'retry'],
    queryFn: () => getClient().settings.getRetry(),
  });
}

export const useUpdateRetrySettings = createMutation<unknown, UpdateRetrySettings>({
  mutationFn: (update) => getClient().settings.updateRetry(update),
  invalidateKeys: () => [SETTINGS_KEY],
  successMessage: 'Retry settings updated',
  errorMessage: 'Failed to update retry settings',
});

export function useAgentSettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'agent'],
    queryFn: () => getClient().settings.getAgent(),
  });
}

export const useUpdateAgentSettings = createMutation<unknown, UpdateAgentSettings>({
  mutationFn: (update) => getClient().settings.updateAgent(update),
  invalidateKeys: () => [SETTINGS_KEY],
  successMessage: 'Agent settings updated',
  errorMessage: 'Failed to update agent settings',
});

export function useModelSettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'model'],
    queryFn: () => getClient().settings.getModel(),
  });
}

export const useUpdateModelSettings = createMutation<unknown, UpdateModelSettings>({
  mutationFn: (update) => getClient().settings.updateModel(update),
  invalidateKeys: () => [SETTINGS_KEY],
  successMessage: 'Model settings updated',
  errorMessage: 'Failed to update model settings',
});

export function useThinkingSettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'thinking'],
    queryFn: () => getClient().settings.getThinking(),
  });
}

export const useUpdateThinkingSettings = createMutation<unknown, UpdateThinkingSettings>({
  mutationFn: (update) => getClient().settings.updateThinking(update),
  invalidateKeys: () => [SETTINGS_KEY],
  successMessage: 'Thinking settings updated',
  errorMessage: 'Failed to update thinking settings',
});

export function useAiProviders() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'providers'],
    queryFn: () => getClient().settings.listProviders(),
  });
}

export function useAiProvider(name: string) {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'providers', name],
    queryFn: () => getClient().settings.getProvider(name),
    enabled: !!name,
  });
}

export const useUpdateAiProvider = createMutation<unknown, { name: string; update: UpdateProviderSettings }>({
  mutationFn: ({ name, update }) => getClient().settings.updateProvider(name, update),
  invalidateKeys: ({ name }) => [SETTINGS_KEY, [...SETTINGS_KEY, 'providers', name]],
  successMessage: 'Provider settings updated',
  errorMessage: 'Failed to update provider settings',
});
