import type { DashboardBlock } from '@/components/bento/layout-types';

const STORAGE_KEY = 'mukuro-dashboard-layout';

export interface LayoutStorage {
  load(): Promise<DashboardBlock[] | null>;
  save(blocks: DashboardBlock[]): Promise<void>;
}

export class LocalLayoutStorage implements LayoutStorage {
  async load(): Promise<DashboardBlock[] | null> {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      if (!Array.isArray(parsed)) return null;
      return parsed as DashboardBlock[];
    } catch {
      return null;
    }
  }

  async save(blocks: DashboardBlock[]): Promise<void> {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(blocks));
  }
}

/** Singleton storage instance */
export const layoutStorage: LayoutStorage = new LocalLayoutStorage();
