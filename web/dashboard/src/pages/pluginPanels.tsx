/**
 * Plugin Panel Registry
 *
 * Maps plugin IDs to their custom detail panels.
 * To add a panel for a new plugin, register it here.
 * The PluginDetail page renders panels from this registry
 * based on the current plugin ID.
 */

import { type ComponentType } from 'react';
import { MemoryPanel } from './MemoryPanel';

export interface PluginPanelEntry {
  /** Panel component to render */
  component: ComponentType;
  /** Display label (used in future tabbed/section UI) */
  label: string;
}

/**
 * Registry: plugin ID -> list of panels to render on that plugin's detail page.
 * Each plugin can have multiple panels.
 */
const registry: Record<string, PluginPanelEntry[]> = {
  memory: [
    { component: MemoryPanel, label: 'Memory Store' },
  ],
};

/**
 * Get panels registered for a given plugin.
 * Returns empty array if no custom panels exist.
 */
export function getPluginPanels(pluginId: string): PluginPanelEntry[] {
  return registry[pluginId] ?? [];
}

/**
 * Register a custom panel for a plugin.
 * Call at module scope to extend the registry.
 */
export function registerPluginPanel(pluginId: string, entry: PluginPanelEntry): void {
  if (!registry[pluginId]) {
    registry[pluginId] = [];
  }
  registry[pluginId].push(entry);
}
