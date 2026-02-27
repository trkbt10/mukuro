import { createClient, type MukuroClient } from '@mukuro/client';

let client: MukuroClient | null = null;

export function getClient(): MukuroClient {
  if (!client) {
    client = createClient({
      baseUrl: import.meta.env.VITE_API_URL ?? '',
      role: 'admin',
      clientId: 'dashboard',
    });
  }
  return client;
}

export function setClientToken(token: string): void {
  client = createClient({
    baseUrl: import.meta.env.VITE_API_URL ?? '',
    token,
    role: 'admin',
    clientId: 'dashboard',
  });
}
