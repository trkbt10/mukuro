import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import { createMutation } from './mutation';

const CONTEXT_KEY = ['context'];

export function useContextFiles() {
  return useQuery({
    queryKey: CONTEXT_KEY,
    queryFn: () => getClient().context.list(),
  });
}

export function useContextFile(name: string) {
  return useQuery({
    queryKey: [...CONTEXT_KEY, name],
    queryFn: () => getClient().context.get(name),
    enabled: !!name,
  });
}

export const useUpdateContextFile = createMutation<unknown, { name: string; content: string }>({
  mutationFn: ({ name, content }) => getClient().context.update(name, content),
  invalidateKeys: ({ name }) => [CONTEXT_KEY, [...CONTEXT_KEY, name]],
  successMessage: 'Context file updated',
  errorMessage: 'Failed to update context file',
});

export const useDeleteContextFile = createMutation<unknown, string>({
  mutationFn: (name) => getClient().context.delete(name),
  invalidateKeys: () => [CONTEXT_KEY],
  successMessage: 'Context file deleted',
  errorMessage: 'Failed to delete context file',
});
