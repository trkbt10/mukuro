import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type {
  MessageProviderAddRequest,
  MessageProviderUpdateRequest,
} from '@mukuro/client';
import { toast } from '@/components/ui';

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

export function useAddProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (request: MessageProviderAddRequest) =>
      getClient().providers.add(request),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: PROVIDERS_KEY });
      toast.success('Provider added successfully');
    },
    onError: (error: Error) => {
      toast.error('Failed to add provider', error.message);
    },
  });
}

export function useUpdateProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      id,
      request,
    }: {
      id: string;
      request: MessageProviderUpdateRequest;
    }) => getClient().providers.update(id, request),
    onSuccess: (_, { id }) => {
      queryClient.invalidateQueries({ queryKey: PROVIDERS_KEY });
      queryClient.invalidateQueries({ queryKey: [...PROVIDERS_KEY, id] });
      toast.success('Provider updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update provider', error.message);
    },
  });
}

export function useDeleteProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().providers.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: PROVIDERS_KEY });
      toast.success('Provider deleted');
    },
    onError: (error: Error) => {
      toast.error('Failed to delete provider', error.message);
    },
  });
}

export function useEnableProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().providers.enable(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: PROVIDERS_KEY });
      queryClient.invalidateQueries({ queryKey: [...PROVIDERS_KEY, id] });
      toast.success('Provider enabled');
    },
    onError: (error: Error) => {
      toast.error('Failed to enable provider', error.message);
    },
  });
}

export function useDisableProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().providers.disable(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: PROVIDERS_KEY });
      queryClient.invalidateQueries({ queryKey: [...PROVIDERS_KEY, id] });
      toast.success('Provider disabled');
    },
    onError: (error: Error) => {
      toast.error('Failed to disable provider', error.message);
    },
  });
}

export function useConnectProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().providers.connect(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: [...PROVIDERS_KEY, id] });
      toast.success('Provider connecting...');
    },
    onError: (error: Error) => {
      toast.error('Failed to connect provider', error.message);
    },
  });
}

export function useDisconnectProvider() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().providers.disconnect(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: [...PROVIDERS_KEY, id] });
      toast.success('Provider disconnected');
    },
    onError: (error: Error) => {
      toast.error('Failed to disconnect provider', error.message);
    },
  });
}

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
