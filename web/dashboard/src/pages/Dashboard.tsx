import { type FC, type ReactNode, useEffect, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';
import { DndContext } from '@dnd-kit/core';
import { Loading } from '@/components/ui';
import {
  BentoGrid, BentoBlock,
  SvgCardShell, SvgCardShellLink,
  SvgIcon, SvgH3, SvgH4, SvgBody, SvgLabel, SvgLabelUpper, SvgDisplay,
  contentArea, contentZones, splitH, splitV,
  type BentoSize, type Rect,
} from '@/components/bento';
import { DraggableBlock } from '@/components/bento/DraggableBlock';
import { DroppableCell } from '@/components/bento/DroppableCell';
import { EditModeToolbar } from '@/components/bento/EditModeToolbar';
import type { DashboardBlockId, DashboardBlock } from '@/components/bento/layout-types';
import { ALL_BLOCK_IDS } from '@/components/bento/layout-types';
import { gridRows, isCellEmpty } from '@/components/bento/layout-engine';
import { usePlugins, useAllSettings } from '@/hooks';
import { useResponsiveColumns } from '@/hooks/useResponsiveColumns';
import { useDashboardLayout } from '@/hooks/useDashboardLayout';
import { useEditMode } from '@/hooks/useEditMode';
import { useLongPress } from '@/hooks/useLongPress';
import { useEditDragAndDrop } from '@/hooks/useEditDragAndDrop';
import { layoutStorage } from '@/lib/layoutStorage';
import styles from './Dashboard.module.css';

// ── SVG color tokens ──

const TEXT = 'var(--tone-text)';
const TEXT_SEC = 'var(--tone-text-secondary)';

// ============================================================
// Card content components — all accept dynamic `size`
// ============================================================

type StatCardProps = {
  size: BentoSize;
  label: string;
  value: string;
  fallbackChar: string;
  iconBg: string;
  iconText: string;
  clipId: string;
};

const StatCard: FC<StatCardProps> = ({ size, label, value, fallbackChar, iconBg, iconText, clipId }) => {
  const { top, bottom } = contentZones(size);
  return (
    <>
      <SvgIcon
        cell={top}
        size="md"
        fallbackChar={fallbackChar}
        clipId={clipId}
        bgFill={iconBg}
        textFill={iconText}
      />
      <SvgLabelUpper x={bottom.x} y={bottom.y}>{label}</SvgLabelUpper>
      <SvgDisplay x={bottom.x} y={bottom.y + 18}>{value}</SvgDisplay>
    </>
  );
};

type SettingsEntry = { label: string; value: string };

const SettingsCard: FC<{ size: BentoSize; entries: SettingsEntry[] }> = ({ size, entries }) => {
  const cr = contentArea(size);
  const vSplit = splitV(cr, entries.length + 1);
  const titleZone = vSplit.cells[0]!;

  return (
    <>
      <SvgH4 x={titleZone.x} y={titleZone.y}>{'Settings'}</SvgH4>
      {entries.map((entry, i) => {
        const zone = vSplit.cells[i + 1]!;
        return (
          <g key={entry.label}>
            <SvgLabelUpper x={zone.x} y={zone.y}>{entry.label}</SvgLabelUpper>
            <SvgBody x={zone.x} y={zone.y + 16} fill={TEXT}>{entry.value}</SvgBody>
          </g>
        );
      })}
    </>
  );
};

const PluginListTitle: FC<{ size: BentoSize; count: number }> = ({ size, count }) => {
  const cr = contentArea(size);
  return (
    <>
      <SvgH3 x={cr.x} y={cr.y}>{'Plugins'}</SvgH3>
      <SvgLabel x={cr.x + cr.w - 24} y={cr.y + 4} fill={TEXT_SEC}>{`${count}`}</SvgLabel>
    </>
  );
};

const HealthCard: FC<{ size: BentoSize }> = ({ size }) => {
  const cr = contentArea(size);
  const hSplit = splitH(cr, 3);
  const left = hSplit.cells[0]!;
  const right: Rect = {
    x: hSplit.cells[1]!.x,
    y: cr.y,
    w: hSplit.cells[1]!.w + hSplit.gapX + hSplit.cells[2]!.w,
    h: cr.h,
  };
  const statusSplit = splitV(right, 2);
  const row1 = statusSplit.cells[0]!;
  const row2 = statusSplit.cells[1]!;

  return (
    <>
      <SvgH4 x={left.x} y={left.y}>{'Health'}</SvgH4>
      <SvgBody x={left.x} y={left.y + 24}>{'System'}</SvgBody>

      <circle cx={row1.x + 6} cy={row1.y + row1.h / 2} r={4} fill="#22c55e" />
      <SvgLabel x={row1.x + 18} y={row1.y + row1.h / 2 - 7}>{'Core'}</SvgLabel>
      <SvgBody x={row1.x + row1.w - 50} y={row1.y + row1.h / 2 - 7}>{'Healthy'}</SvgBody>

      <circle cx={row2.x + 6} cy={row2.y + row2.h / 2} r={4} fill="#22c55e" />
      <SvgLabel x={row2.x + 18} y={row2.y + row2.h / 2 - 7}>{'API'}</SvgLabel>
      <SvgBody x={row2.x + row2.w - 50} y={row2.y + row2.h / 2 - 7}>{'Healthy'}</SvgBody>
    </>
  );
};

// ============================================================
// Dashboard Page
// ============================================================

export function Dashboard() {
  const navigate = useNavigate();
  const { data: plugins, isLoading: pluginsLoading } = usePlugins();
  const { data: settings, isLoading: settingsLoading } = useAllSettings();

  const { columns, ref: gridRef } = useResponsiveColumns();
  const {
    state: layout, setBlocks, setColumns, moveBlockWithPush,
    resizeBlockAction, addBlock, removeBlock,
    markSaved, resetLayout,
  } = useDashboardLayout(undefined, 4);
  const { isEditing, enterEditMode, exitEditMode } = useEditMode();

  // Load saved layout on mount
  useEffect(() => {
    layoutStorage.load().then((saved) => {
      if (saved) setBlocks(saved);
    });
  }, [setBlocks]);

  // Sync column count
  useEffect(() => { setColumns(columns); }, [columns, setColumns]);

  // DnD
  const dnd = useEditDragAndDrop(layout.blocks, layout.columns, moveBlockWithPush);

  // Long press → enter edit mode
  const longPressHandlers = useLongPress(enterEditMode);

  const handleDone = () => {
    layoutStorage.save(layout.blocks);
    markSaved();
    exitEditMode();
  };

  // Compute hidden block IDs (blocks not currently in layout)
  const hiddenBlockIds = useMemo(() => {
    const activeIds = new Set(layout.blocks.map((b) => b.id));
    return ALL_BLOCK_IDS.filter((id) => !activeIds.has(id));
  }, [layout.blocks]);

  const handleAddBlock = (blockId: DashboardBlockId, col: number, row: number) => {
    addBlock(blockId, { col, row });
  };

  if (pluginsLoading || settingsLoading) {
    return <Loading message="Loading dashboard..." />;
  }

  const enabledPlugins = plugins?.filter((p) => p.enabled).length ?? 0;
  const totalPlugins = plugins?.length ?? 0;
  const providerCount = settings?.providers.length ?? 0;

  const settingsEntries: SettingsEntry[] = [
    { label: 'Model', value: settings?.model.model_name ?? 'N/A' },
    { label: 'Retries', value: `${settings?.retry.max_retries ?? 3}` },
    { label: 'Iterations', value: `${settings?.agent.max_iterations ?? 10}` },
  ];

  // Render block content with dynamic size
  function renderBlockContent(block: DashboardBlock): ReactNode {
    const { id, size } = block;

    const pluginListOverlay = (
      <div className={styles.pluginListOverlay}>
        {plugins && plugins.length > 0 ? (
          <>
            {plugins.slice(0, 6).map((p) => (
              <Link key={p.id} to={`/plugins/${p.id}`} className={styles.pluginRow}>
                <div className={styles.pluginInfo}>
                  <div className={p.enabled ? styles.pluginDotOn : styles.pluginDotOff} />
                  <span className={styles.pluginName}>{p.name}</span>
                </div>
                <span className={styles.pluginVersion}>v{p.version}</span>
              </Link>
            ))}
            <Link to="/plugins" className={styles.linkRow}>
              View all <ArrowRight style={{ width: 12, height: 12 }} />
            </Link>
          </>
        ) : (
          <p className={styles.emptyState}>No plugins installed</p>
        )}
      </div>
    );

    switch (id) {
      case 'plugins-stat':
        return (
          <SvgCardShellLink
            size={size}
            href="/plugins"
            onClick={(e) => { e.preventDefault(); navigate('/plugins'); }}
          >
            <StatCard
              size={size}
              label="Plugins"
              value={`${enabledPlugins}/${totalPlugins}`}
              fallbackChar="P"
              iconBg="rgba(108,138,255,0.15)"
              iconText="#6c8aff"
              clipId="stat-plugins"
            />
          </SvgCardShellLink>
        );
      case 'providers-stat':
        return (
          <SvgCardShellLink
            size={size}
            href="/providers"
            onClick={(e) => { e.preventDefault(); navigate('/providers'); }}
          >
            <StatCard
              size={size}
              label="Providers"
              value={`${providerCount}`}
              fallbackChar="M"
              iconBg="rgba(100,181,246,0.15)"
              iconText="#64b5f6"
              clipId="stat-providers"
            />
          </SvgCardShellLink>
        );
      case 'plugin-list':
        return (
          <SvgCardShell size={size} overlay={pluginListOverlay}>
            <PluginListTitle size={size} count={totalPlugins} />
          </SvgCardShell>
        );
      case 'status-stat':
        return (
          <SvgCardShell size={size}>
            <StatCard
              size={size}
              label="Status"
              value="OK"
              fallbackChar="✓"
              iconBg="rgba(93,222,176,0.15)"
              iconText="#5ddeb0"
              clipId="stat-health"
            />
          </SvgCardShell>
        );
      case 'settings':
        return (
          <SvgCardShellLink
            size={size}
            href="/settings"
            onClick={(e) => { e.preventDefault(); navigate('/settings'); }}
          >
            <SettingsCard size={size} entries={settingsEntries} />
          </SvgCardShellLink>
        );
      case 'health':
        return (
          <SvgCardShell size={size}>
            <HealthCard size={size} />
          </SvgCardShell>
        );
    }
  }

  // Display blocks — preview during drag, else current
  const displayBlocks = dnd.insertionPreviewBlocks ?? layout.blocks;
  const totalRows = gridRows(displayBlocks, columns);

  // Droppable cells for edit mode
  const droppableCells: ReactNode[] = [];
  if (isEditing) {
    for (let r = 0; r < totalRows + 2; r++) {
      for (let c = 0; c < columns; c++) {
        const empty = isCellEmpty(displayBlocks, c, r, columns);
        droppableCells.push(
          <DroppableCell
            key={`cell-${c}-${r}`}
            col={c}
            row={r}
            empty={empty}
            hiddenBlockIds={hiddenBlockIds}
            onAddBlock={handleAddBlock}
          />,
        );
      }
    }
  }

  const gridContent = displayBlocks.map((block) => {
    const content = renderBlockContent(block);
    if (isEditing) {
      return (
        <DraggableBlock
          key={block.id}
          id={block.id}
          size={block.size}
          position={block.position}
          columns={columns}
          jiggle
          onResize={resizeBlockAction}
          onRemove={removeBlock}
        >
          {content}
        </DraggableBlock>
      );
    }
    return (
      <BentoBlock
        key={block.id}
        size={block.size}
        position={block.position}
        columns={columns}
        entering
        {...longPressHandlers}
      >
        {content}
      </BentoBlock>
    );
  });

  const gridElement = (
    <div className={styles.gridWrapper}>
      <EditModeToolbar
        isEditing={isEditing}
        onEdit={enterEditMode}
        onDone={handleDone}
        onReset={resetLayout}
      />
      <BentoGrid ref={gridRef} columns={columns} squareCells>
        {droppableCells}
        {gridContent}
      </BentoGrid>
    </div>
  );

  if (isEditing) {
    return (
      <div className={styles.page}>
        <DndContext
          sensors={dnd.sensors}
          onDragStart={dnd.handleDragStart}
          onDragOver={dnd.handleDragOver}
          onDragEnd={dnd.handleDragEnd}
          onDragCancel={dnd.handleDragCancel}
        >
          {gridElement}
        </DndContext>
      </div>
    );
  }

  return <div className={styles.page}>{gridElement}</div>;
}
