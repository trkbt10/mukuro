import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import { createMutation } from './mutation';

const CONTEXT_DATA_KEY = ['context', 'data'];
const CONTEXT_TEMPLATES_KEY = ['context', 'templates'];

// ============================================================
// Data Hooks
// ============================================================

export function useContextDataFiles() {
  return useQuery({
    queryKey: CONTEXT_DATA_KEY,
    queryFn: () => getClient().context.listData(),
  });
}

export function useContextDataFile(name: string) {
  return useQuery({
    queryKey: [...CONTEXT_DATA_KEY, name],
    queryFn: () => getClient().context.getData(name),
    enabled: !!name,
  });
}

export const useUpdateContextDataFile = createMutation<unknown, { name: string; content: string }>({
  mutationFn: ({ name, content }) => getClient().context.updateData(name, content),
  invalidateKeys: ({ name }) => [CONTEXT_DATA_KEY, [...CONTEXT_DATA_KEY, name]],
  successMessage: 'Context file updated',
  errorMessage: 'Failed to update context file',
});

export const useDeleteContextDataFile = createMutation<unknown, string>({
  mutationFn: (name) => getClient().context.deleteData(name),
  invalidateKeys: () => [CONTEXT_DATA_KEY],
  successMessage: 'Context file deleted',
  errorMessage: 'Failed to delete context file',
});

// ============================================================
// Template Hooks
// ============================================================

export function useContextTemplates() {
  return useQuery({
    queryKey: CONTEXT_TEMPLATES_KEY,
    queryFn: () => getClient().context.listTemplates(),
  });
}

export function useContextTemplate(name: string) {
  return useQuery({
    queryKey: [...CONTEXT_TEMPLATES_KEY, name],
    queryFn: () => getClient().context.getTemplate(name),
    enabled: !!name,
  });
}
