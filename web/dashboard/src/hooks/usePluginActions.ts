/**
 * Plugin Actions (RPC) hooks
 * Generic plugin action invocation + plugin-specific data hooks
 */

import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type { MemoryListResponse } from '@mukuro/client';
import { createMutation } from './mutation';

const PLUGINS_KEY = ['plugins'];
const MEMORY_KEY = ['plugins', 'memory', 'entries'];

// =============================================================================
// Generic Plugin Actions
// =============================================================================

export function usePluginActions(id: string) {
  return useQuery({
    queryKey: [...PLUGINS_KEY, id, 'actions'],
    queryFn: () => getClient().plugins.listActions(id),
    enabled: !!id,
  });
}

/**
 * Generic hook for invoking a plugin action and caching the result.
 * Use for read-only actions that return data.
 */
export function usePluginActionQuery<T>(
  pluginId: string,
  action: string,
  params?: Record<string, unknown>
) {
  return useQuery({
    queryKey: [...PLUGINS_KEY, pluginId, 'actions', action, params],
    queryFn: async () => {
      const res = await getClient().plugins.invokeAction<{ data: T }>(
        pluginId,
        action,
        params
      );
      return res.data;
    },
    enabled: !!pluginId && !!action,
  });
}

// =============================================================================
// Memory Plugin Hooks
// =============================================================================

export function useMemoryEntries() {
  return useQuery({
    queryKey: MEMORY_KEY,
    queryFn: async () => {
      const res = await getClient().plugins.invokeAction<{ data: MemoryListResponse }>(
        'memory', 'list'
      );
      return res.data;
    },
  });
}

export const useSetMemoryEntry = createMutation<unknown, { key: string; value: unknown }>({
  mutationFn: ({ key, value }) =>
    getClient().plugins.invokeAction('memory', 'set', { key, value }),
  invalidateKeys: () => [MEMORY_KEY],
  successMessage: 'Entry saved',
  errorMessage: 'Failed to save entry',
});

export const useDeleteMemoryEntry = createMutation<unknown, string>({
  mutationFn: (key) =>
    getClient().plugins.invokeAction('memory', 'delete', { key }),
  invalidateKeys: () => [MEMORY_KEY],
  successMessage: 'Entry deleted',
  errorMessage: 'Failed to delete entry',
});

export const useClearMemory = createMutation<unknown, void>({
  mutationFn: () =>
    getClient().plugins.invokeAction('memory', 'clear'),
  invalidateKeys: () => [MEMORY_KEY],
  successMessage: 'Memory cleared',
  errorMessage: 'Failed to clear memory',
});
