import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type {
  UpdateRetrySettings,
  UpdateAgentSettings,
  UpdateModelInferenceSettings,
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
  invalidateKeys: ({ name }) => [SETTINGS_KEY, [...SETTINGS_KEY, 'providers'], [...SETTINGS_KEY, 'providers', name]],
  successMessage: 'Provider settings updated',
  errorMessage: 'Failed to update provider settings',
});

export function useModelInferenceSettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'model-inference'],
    queryFn: () => getClient().settings.getModelInference(),
  });
}

export const useUpdateModelInferenceSettings = createMutation<unknown, UpdateModelInferenceSettings>({
  mutationFn: (update) => getClient().settings.updateModelInference(update),
  invalidateKeys: () => [SETTINGS_KEY],
  successMessage: 'Model & inference settings updated',
  errorMessage: 'Failed to update model & inference settings',
});

export function useProviderModels(providerName: string) {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'providers', providerName, 'models'],
    queryFn: () => getClient().settings.listProviderModels(providerName),
    enabled: !!providerName,
  });
}
