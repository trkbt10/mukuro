import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type {
  UpdateRetrySettings,
  UpdateAgentSettings,
  UpdateModelSettings,
  UpdateThinkingSettings,
  UpdateProviderSettings,
} from '@mukuro/client';
import { toast } from '@/components/ui';

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

export function useUpdateRetrySettings() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (update: UpdateRetrySettings) =>
      getClient().settings.updateRetry(update),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: SETTINGS_KEY });
      toast.success('Retry settings updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update retry settings', error.message);
    },
  });
}

export function useAgentSettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'agent'],
    queryFn: () => getClient().settings.getAgent(),
  });
}

export function useUpdateAgentSettings() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (update: UpdateAgentSettings) =>
      getClient().settings.updateAgent(update),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: SETTINGS_KEY });
      toast.success('Agent settings updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update agent settings', error.message);
    },
  });
}

export function useModelSettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'model'],
    queryFn: () => getClient().settings.getModel(),
  });
}

export function useUpdateModelSettings() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (update: UpdateModelSettings) =>
      getClient().settings.updateModel(update),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: SETTINGS_KEY });
      toast.success('Model settings updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update model settings', error.message);
    },
  });
}

export function useThinkingSettings() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'thinking'],
    queryFn: () => getClient().settings.getThinking(),
  });
}

export function useUpdateThinkingSettings() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (update: UpdateThinkingSettings) =>
      getClient().settings.updateThinking(update),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: SETTINGS_KEY });
      toast.success('Thinking settings updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update thinking settings', error.message);
    },
  });
}

export function useProviders() {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'providers'],
    queryFn: () => getClient().settings.listProviders(),
  });
}

export function useProvider(name: string) {
  return useQuery({
    queryKey: [...SETTINGS_KEY, 'providers', name],
    queryFn: () => getClient().settings.getProvider(name),
    enabled: !!name,
  });
}

export function useUpdateProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      name,
      update,
    }: {
      name: string;
      update: UpdateProviderSettings;
    }) => getClient().settings.updateProvider(name, update),
    onSuccess: (_, { name }) => {
      queryClient.invalidateQueries({ queryKey: SETTINGS_KEY });
      queryClient.invalidateQueries({
        queryKey: [...SETTINGS_KEY, 'providers', name],
      });
      toast.success('Provider settings updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update provider settings', error.message);
    },
  });
}
