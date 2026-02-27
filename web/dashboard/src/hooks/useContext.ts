import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import { toast } from '@/components/ui';

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

export function useUpdateContextFile() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ name, content }: { name: string; content: string }) =>
      getClient().context.update(name, content),
    onSuccess: (_, { name }) => {
      queryClient.invalidateQueries({ queryKey: CONTEXT_KEY });
      queryClient.invalidateQueries({ queryKey: [...CONTEXT_KEY, name] });
      toast.success('Context file updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update context file', error.message);
    },
  });
}

export function useDeleteContextFile() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (name: string) => getClient().context.delete(name),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: CONTEXT_KEY });
      toast.success('Context file deleted');
    },
    onError: (error: Error) => {
      toast.error('Failed to delete context file', error.message);
    },
  });
}
