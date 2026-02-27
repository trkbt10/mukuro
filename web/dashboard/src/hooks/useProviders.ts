import { useQuery, useMutation } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type {
  MessageProviderAddRequest,
  MessageProviderUpdateRequest,
} from '@mukuro/client';
import { toast } from '@/components/ui';
import { createMutation } from './mutation';

const PROVIDERS_KEY = ['providers'];

export function useProviders() {
  return useQuery({
    queryKey: PROVIDERS_KEY,
    queryFn: () => getClient().providers.list(),
  });
}

export function useProvider(id: string) {
  return useQuery({
    queryKey: [...PROVIDERS_KEY, id],
    queryFn: () => getClient().providers.get(id),
    enabled: !!id,
  });
}

export function useProviderTypes() {
  return useQuery({
    queryKey: [...PROVIDERS_KEY, 'types'],
    queryFn: () => getClient().providers.getTypes(),
  });
}

export function useProviderSchema(providerType: string) {
  return useQuery({
    queryKey: [...PROVIDERS_KEY, 'schema', providerType],
    queryFn: () => getClient().providers.getSchema(providerType),
    enabled: !!providerType,
  });
}

export const useAddProvider = createMutation<unknown, MessageProviderAddRequest>({
  mutationFn: (request) => getClient().providers.add(request),
  invalidateKeys: () => [PROVIDERS_KEY],
  successMessage: 'Provider added successfully',
  errorMessage: 'Failed to add provider',
});

export const useUpdateProvider = createMutation<unknown, { id: string; request: MessageProviderUpdateRequest }>({
  mutationFn: ({ id, request }) => getClient().providers.update(id, request),
  invalidateKeys: ({ id }) => [PROVIDERS_KEY, [...PROVIDERS_KEY, id]],
  successMessage: 'Provider updated',
  errorMessage: 'Failed to update provider',
});

export const useDeleteProvider = createMutation<unknown, string>({
  mutationFn: (id) => getClient().providers.delete(id),
  invalidateKeys: () => [PROVIDERS_KEY],
  successMessage: 'Provider deleted',
  errorMessage: 'Failed to delete provider',
});

export const useEnableProvider = createMutation<unknown, string>({
  mutationFn: (id) => getClient().providers.enable(id),
  invalidateKeys: (id) => [PROVIDERS_KEY, [...PROVIDERS_KEY, id]],
  successMessage: 'Provider enabled',
  errorMessage: 'Failed to enable provider',
});

export const useDisableProvider = createMutation<unknown, string>({
  mutationFn: (id) => getClient().providers.disable(id),
  invalidateKeys: (id) => [PROVIDERS_KEY, [...PROVIDERS_KEY, id]],
  successMessage: 'Provider disabled',
  errorMessage: 'Failed to disable provider',
});

export const useConnectProvider = createMutation<unknown, string>({
  mutationFn: (id) => getClient().providers.connect(id),
  invalidateKeys: (id) => [[...PROVIDERS_KEY, id]],
  successMessage: 'Provider connecting...',
  errorMessage: 'Failed to connect provider',
});

export const useDisconnectProvider = createMutation<unknown, string>({
  mutationFn: (id) => getClient().providers.disconnect(id),
  invalidateKeys: (id) => [[...PROVIDERS_KEY, id]],
  successMessage: 'Provider disconnected',
  errorMessage: 'Failed to disconnect provider',
});

// useTestProvider has conditional success logic — kept as manual useMutation
export function useTestProvider() {
  return useMutation({
    mutationFn: (id: string) => getClient().providers.test(id),
    onSuccess: (result) => {
      if (result.ok) {
        toast.success(result.message ?? 'Configuration valid');
      } else {
        toast.error('Configuration invalid', result.error);
      }
    },
    onError: (error: Error) => {
      toast.error('Failed to test provider', error.message);
    },
  });
}
