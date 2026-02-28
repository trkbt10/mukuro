/**
 * Plugin management hooks
 * List, get, add, delete, enable, disable, reload, upload, settings
 */

import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type { PluginAddRequest } from '@mukuro/client';
import { createMutation } from './mutation';

export const PLUGINS_KEY = ['plugins'];

export function usePlugins() {
  return useQuery({
    queryKey: PLUGINS_KEY,
    queryFn: () => getClient().plugins.list(),
  });
}

export function usePlugin(id: string) {
  return useQuery({
    queryKey: [...PLUGINS_KEY, id],
    queryFn: () => getClient().plugins.get(id),
    enabled: !!id,
  });
}

export function usePluginSettings(id: string) {
  return useQuery({
    queryKey: [...PLUGINS_KEY, id, 'settings'],
    queryFn: () => getClient().plugins.getSettings(id),
    enabled: !!id,
  });
}

export const useAddPlugin = createMutation<unknown, PluginAddRequest>({
  mutationFn: (request) => getClient().plugins.add(request),
  invalidateKeys: () => [PLUGINS_KEY],
  successMessage: 'Plugin added successfully',
  errorMessage: 'Failed to add plugin',
});

export const useDeletePlugin = createMutation<unknown, string>({
  mutationFn: (id) => getClient().plugins.delete(id),
  invalidateKeys: () => [PLUGINS_KEY],
  successMessage: 'Plugin deleted successfully',
  errorMessage: 'Failed to delete plugin',
});

export const useEnablePlugin = createMutation<unknown, string>({
  mutationFn: (id) => getClient().plugins.enable(id),
  invalidateKeys: (id) => [PLUGINS_KEY, [...PLUGINS_KEY, id]],
  successMessage: 'Plugin enabled',
  errorMessage: 'Failed to enable plugin',
});

export const useDisablePlugin = createMutation<unknown, string>({
  mutationFn: (id) => getClient().plugins.disable(id),
  invalidateKeys: (id) => [PLUGINS_KEY, [...PLUGINS_KEY, id]],
  successMessage: 'Plugin disabled',
  errorMessage: 'Failed to disable plugin',
});

export const useReloadPlugin = createMutation<unknown, string>({
  mutationFn: (id) => getClient().plugins.reload(id),
  invalidateKeys: (id) => [[...PLUGINS_KEY, id]],
  successMessage: 'Plugin reloaded',
  errorMessage: 'Failed to reload plugin',
});

export const useUploadPlugin = createMutation<unknown, { file: File; filename?: string }>({
  mutationFn: ({ file, filename }) => getClient().plugins.upload(file, filename),
  invalidateKeys: () => [PLUGINS_KEY],
  successMessage: 'Plugin uploaded successfully',
  errorMessage: 'Failed to upload plugin',
});

export const useUpdatePluginSettings = createMutation<unknown, { id: string; settings: Record<string, unknown> }>({
  mutationFn: ({ id, settings }) => getClient().plugins.updateSettings(id, settings),
  invalidateKeys: ({ id }) => [[...PLUGINS_KEY, id, 'settings']],
  successMessage: 'Settings updated',
  errorMessage: 'Failed to update settings',
});
