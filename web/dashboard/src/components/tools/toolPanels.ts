/**
 * Tool Panel Registry
 *
 * Maps tool names to their custom detail panels.
 * Similar to pluginPanels.ts but for tools.
 * Allows tools to have custom UI beyond the schema-driven settings form.
 *
 * NOTE: To add a custom panel for a tool, the tool must provide
 * a data API via /api/v1/tools/{id}/actions. See api/v1/tools/handlers.mbt.
 */

import { type ComponentType } from 'react';
import { MemoryPanel } from '@/components/plugins/MemoryPanel';

export interface ToolPanelEntry {
  /** Panel component to render */
  component: ComponentType;
  /** Display label */
  label: string;
}

/**
 * Registry: tool name -> list of panels to render on that tool's detail page.
 *
 * Panels registered here use the tool's action API:
 * - memory tool: /api/v1/tools/memory/actions/{list,get,set,delete,clear}
 */
const registry: Record<string, ToolPanelEntry[]> = {
  memory: [
    { component: MemoryPanel, label: 'Memory Store' },
  ],
};

/**
 * Get panels registered for a given tool.
 * Returns empty array if no custom panels exist.
 */
export function getToolPanels(toolName: string): ToolPanelEntry[] {
  return registry[toolName] ?? [];
}

/**
 * Register a custom panel for a tool.
 * Call at module scope to extend the registry.
 */
export function registerToolPanel(toolName: string, entry: ToolPanelEntry): void {
  if (!registry[toolName]) {
    registry[toolName] = [];
  }
  registry[toolName].push(entry);
}

/**
 * Check if a tool has custom panels.
 */
export function hasToolPanels(toolName: string): boolean {
  return toolName in registry && registry[toolName].length > 0;
}
