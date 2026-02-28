/**
 * Tool management hooks
 * List, get, enable, disable, delete
 */

import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import { createMutation } from './mutation';

export const TOOLS_KEY = ['tools'];

export function useTools() {
  return useQuery({
    queryKey: TOOLS_KEY,
    queryFn: () => getClient().tools.list(),
  });
}

export function useTool(id: string) {
  return useQuery({
    queryKey: [...TOOLS_KEY, id],
    queryFn: () => getClient().tools.get(id),
    enabled: !!id,
  });
}

export const useEnableTool = createMutation<unknown, string>({
  mutationFn: (id) => getClient().tools.enable(id),
  invalidateKeys: (id) => [TOOLS_KEY, [...TOOLS_KEY, id]],
  successMessage: 'Tool enabled',
  errorMessage: 'Failed to enable tool',
});

export const useDisableTool = createMutation<unknown, string>({
  mutationFn: (id) => getClient().tools.disable(id),
  invalidateKeys: (id) => [TOOLS_KEY, [...TOOLS_KEY, id]],
  successMessage: 'Tool disabled',
  errorMessage: 'Failed to disable tool',
});

export const useDeleteTool = createMutation<unknown, string>({
  mutationFn: (id) => getClient().tools.delete(id),
  invalidateKeys: () => [TOOLS_KEY],
  successMessage: 'Tool deleted',
  errorMessage: 'Failed to delete tool',
});
