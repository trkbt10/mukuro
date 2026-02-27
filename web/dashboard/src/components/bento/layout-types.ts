import type { BentoSize } from './grid/fractal';

export type BlockPosition = { col: number; row: number };

export type DashboardBlockId =
  | 'plugins-stat'
  | 'providers-stat'
  | 'plugin-list'
  | 'status-stat'
  | 'settings'
  | 'health';

export type DashboardBlock = {
  id: DashboardBlockId;
  size: BentoSize;
  position: BlockPosition;
};

/** Parse BentoSize "CxR" into column/row span */
export function sizeSpan(size: BentoSize): { cols: number; rows: number } {
  const [c, r] = size.split('x').map(Number);
  return { cols: c!, rows: r! };
}

/** All valid resize-target sizes (no 3x1/4x1 — only useful at wide grids) */
export const RESIZE_SIZES: BentoSize[] = ['1x1', '2x1', '1x2', '2x2'];

/** Block catalog — metadata for the picker and resize */
export type BlockMeta = {
  label: string;
  icon: string;
  defaultSize: BentoSize;
};

export const BLOCK_CATALOG: Record<DashboardBlockId, BlockMeta> = {
  'plugins-stat':   { label: 'Plugins',     icon: 'P', defaultSize: '1x1' },
  'providers-stat': { label: 'Providers',   icon: 'M', defaultSize: '1x1' },
  'plugin-list':    { label: 'Plugin List', icon: '☰', defaultSize: '2x2' },
  'status-stat':    { label: 'Status',      icon: '✓', defaultSize: '1x1' },
  'settings':       { label: 'Settings',    icon: '⚙', defaultSize: '1x2' },
  'health':         { label: 'Health',      icon: '♥', defaultSize: '2x1' },
};

export const ALL_BLOCK_IDS: DashboardBlockId[] = Object.keys(BLOCK_CATALOG) as DashboardBlockId[];

/**
 * Default dashboard layout — matches the current 4-column auto-flow order:
 *
 *   col: 0   1   2   3
 * row 0: [Plug] [Prov] [PluginList ]
 * row 1: [Stat] [Settings] [         ]
 * row 2: [  Health  ]
 */
export const DEFAULT_DASHBOARD_BLOCKS: DashboardBlock[] = [
  { id: 'plugins-stat',  size: '1x1', position: { col: 0, row: 0 } },
  { id: 'providers-stat', size: '1x1', position: { col: 1, row: 0 } },
  { id: 'plugin-list',   size: '2x2', position: { col: 2, row: 0 } },
  { id: 'status-stat',   size: '1x1', position: { col: 0, row: 1 } },
  { id: 'settings',      size: '1x2', position: { col: 1, row: 1 } },
  { id: 'health',        size: '2x1', position: { col: 0, row: 2 } },
];
