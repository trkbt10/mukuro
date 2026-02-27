import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';
import { MukuroApiError, MukuroNetworkError } from '@mukuro/client';

export type ConnectionStatus = 'connecting' | 'connected' | 'disconnected' | 'error';

interface ConnectionState {
  status: ConnectionStatus;
  error?: string;
  version?: string;
}

export function useConnection() {
  return useQuery<ConnectionState>({
    queryKey: ['connection', 'health'],
    queryFn: async (): Promise<ConnectionState> => {
      try {
        await getClient().settings.getAll();
        return {
          status: 'connected',
        };
      } catch (error) {
        if (error instanceof MukuroNetworkError) {
          return {
            status: 'disconnected',
            error: 'Cannot connect to mukuro server',
          };
        }
        if (error instanceof MukuroApiError) {
          if (error.isUnauthorized()) {
            return {
              status: 'error',
              error: 'Authentication required',
            };
          }
          return {
            status: 'error',
            error: error.message,
          };
        }
        return {
          status: 'error',
          error: 'Unknown error',
        };
      }
    },
    refetchInterval: 10000, // Check every 10 seconds
    retry: false,
  });
}
