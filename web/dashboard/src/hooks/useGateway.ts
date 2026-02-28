import { useQuery } from '@tanstack/react-query';
import { getClient } from '@/lib/client';

const GATEWAY_KEY = ['gateway'];

export function useGatewayStatus() {
  return useQuery({
    queryKey: [...GATEWAY_KEY, 'status'],
    queryFn: () => getClient().gateway.getStatus(),
    refetchInterval: 15_000,
  });
}

export function useGatewayHealth() {
  return useQuery({
    queryKey: [...GATEWAY_KEY, 'health'],
    queryFn: () => getClient().gateway.getHealth(),
    refetchInterval: 15_000,
  });
}

export function useGatewayHealthLive() {
  return useQuery({
    queryKey: [...GATEWAY_KEY, 'health', 'live'],
    queryFn: () => getClient().gateway.getHealthLive(),
    refetchInterval: 10_000,
  });
}

export function useGatewayHealthReady() {
  return useQuery({
    queryKey: [...GATEWAY_KEY, 'health', 'ready'],
    queryFn: () => getClient().gateway.getHealthReady(),
    refetchInterval: 10_000,
  });
}
