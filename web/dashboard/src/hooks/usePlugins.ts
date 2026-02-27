import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import type { PluginAddRequest } from '@mukuro/client';
import { toast } from '@/components/ui';

const PLUGINS_KEY = ['plugins'];

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

export function useAddPlugin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (request: PluginAddRequest) => getClient().plugins.add(request),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: PLUGINS_KEY });
      toast.success('Plugin added successfully');
    },
    onError: (error: Error) => {
      toast.error('Failed to add plugin', error.message);
    },
  });
}

export function useDeletePlugin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().plugins.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: PLUGINS_KEY });
      toast.success('Plugin deleted successfully');
    },
    onError: (error: Error) => {
      toast.error('Failed to delete plugin', error.message);
    },
  });
}

export function useEnablePlugin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().plugins.enable(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: PLUGINS_KEY });
      queryClient.invalidateQueries({ queryKey: [...PLUGINS_KEY, id] });
      toast.success('Plugin enabled');
    },
    onError: (error: Error) => {
      toast.error('Failed to enable plugin', error.message);
    },
  });
}

export function useDisablePlugin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().plugins.disable(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: PLUGINS_KEY });
      queryClient.invalidateQueries({ queryKey: [...PLUGINS_KEY, id] });
      toast.success('Plugin disabled');
    },
    onError: (error: Error) => {
      toast.error('Failed to disable plugin', error.message);
    },
  });
}

export function useReloadPlugin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => getClient().plugins.reload(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: [...PLUGINS_KEY, id] });
      toast.success('Plugin reloaded');
    },
    onError: (error: Error) => {
      toast.error('Failed to reload plugin', error.message);
    },
  });
}

export function useUploadPlugin() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ file, filename }: { file: File; filename?: string }) =>
      getClient().plugins.upload(file, filename),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: PLUGINS_KEY });
      toast.success('Plugin uploaded successfully');
    },
    onError: (error: Error) => {
      toast.error('Failed to upload plugin', error.message);
    },
  });
}

export function useUpdatePluginSettings() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      id,
      settings,
    }: {
      id: string;
      settings: Record<string, unknown>;
    }) => getClient().plugins.updateSettings(id, settings),
    onSuccess: (_, { id }) => {
      queryClient.invalidateQueries({ queryKey: [...PLUGINS_KEY, id, 'settings'] });
      toast.success('Settings updated');
    },
    onError: (error: Error) => {
      toast.error('Failed to update settings', error.message);
    },
  });
}
