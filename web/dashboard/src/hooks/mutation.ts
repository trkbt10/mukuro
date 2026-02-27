import { useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from '@/components/ui';

interface MutationConfig<TData, TVariables> {
  mutationFn: (variables: TVariables) => Promise<TData>;
  invalidateKeys?: (variables: TVariables, data: TData) => readonly unknown[][];
  successMessage?: string;
  errorMessage: string;
}

export function createMutation<TData = unknown, TVariables = void>({
  mutationFn,
  invalidateKeys,
  successMessage,
  errorMessage,
}: MutationConfig<TData, TVariables>) {
  return function useManagedMutation() {
    const queryClient = useQueryClient();

    return useMutation<TData, Error, TVariables>({
      mutationFn,
      onSuccess: (data, variables) => {
        if (invalidateKeys) {
          for (const key of invalidateKeys(variables, data)) {
            queryClient.invalidateQueries({ queryKey: key });
          }
        }
        if (successMessage) {
          toast.success(successMessage);
        }
      },
      onError: (error: Error) => {
        toast.error(errorMessage, error.message);
      },
    });
  };
}
