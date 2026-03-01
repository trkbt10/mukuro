import { type FC, type ReactNode, useEffect, useMemo } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';
import { DndContext } from '@dnd-kit/core';
import { Loading } from '@/components/ui';
import {
  BentoGrid, BentoBlock,
  SvgCardShell, SvgCardShellLink,
  SvgIcon, SvgH3, SvgH4, SvgBody, SvgLabel, SvgLabelUpper,
  SvgText,
  contentArea, contentZones, splitH, splitV,
  TYPE,
  type BentoSize, type Rect,
} from '@/components/bento';
import { DraggableBlock } from '@/components/bento/DraggableBlock';
import { DroppableCell } from '@/components/bento/DroppableCell';
import { EditModeToolbar } from '@/components/bento/EditModeToolbar';
import type { DashboardBlockId, DashboardBlock } from '@/components/bento/layout-types';
import { ALL_BLOCK_IDS } from '@/components/bento/layout-types';
import { gridRows, isCellEmpty } from '@/components/bento/layout-engine';
import { usePlugins, useAllSettings, useGatewayStatus, useGatewayHealth, useGatewayHealthLive } from '@/hooks';
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

  // Split bottom zone: ~30% for label, ~70% for display value
  const labelH = TYPE.labelUpper.fontSize * (TYPE.labelUpper.lineHeight ?? 1.4);
  const displayMaxH = bottom.h - labelH - 4; // 4px min gap
  // Scale display fontSize to fit: max 48, but clamp to available height
  const displayFontSize = Math.min(48, displayMaxH / 1.1);
  const displayRenderH = displayFontSize * 1.1;
  // Position label at top of bottom zone, display below with even gap
  const gap = Math.max((bottom.h - labelH - displayRenderH) / 2, 2);
  const displayY = bottom.y + labelH + gap;

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
      <SvgText
        preset={{ ...TYPE.display, fontSize: displayFontSize }}
        text={value}
        x={bottom.x}
        y={displayY}
      />
    </>
  );
};

type SettingsEntry = { label: string; value: string };

const SettingsCard: FC<{ size: BentoSize; entries: SettingsEntry[] }> = ({ size, entries }) => {
  const cr = contentArea(size);

  const labelH = TYPE.labelUpper.fontSize * (TYPE.labelUpper.lineHeight ?? 1.4);
  const bodyH = TYPE.body.fontSize * (TYPE.body.lineHeight ?? 1.5);

  // Compact (1x1): each zone is ~28px but label+body need ~38px.
  // Use inline layout: label and value on same line, no title row.
  const compact = cr.h < (entries.length + 1) * (labelH + bodyH + 4);

  if (compact) {
    const vSplit = splitV(cr, entries.length);
    return (
      <>
        {entries.map((entry, i) => {
          const zone = vSplit.cells[i]!;
          // Stack label + body from zone top, centered vertically within zone
          const contentH = labelH + bodyH;
          const topPad = Math.max((zone.h - contentH) / 2, 0);
          return (
            <g key={entry.label}>
              <SvgLabelUpper x={zone.x} y={zone.y + topPad}>{entry.label}</SvgLabelUpper>
              <SvgBody x={zone.x} y={zone.y + topPad + labelH} fill={TEXT}>{entry.value}</SvgBody>
            </g>
          );
        })}
      </>
    );
  }

  const vSplit = splitV(cr, entries.length + 1);
  const titleZone = vSplit.cells[0]!;

  return (
    <>
      <SvgH4 x={titleZone.x} y={titleZone.y}>{'Settings'}</SvgH4>
      {entries.map((entry, i) => {
        const zone = vSplit.cells[i + 1]!;
        const gap = Math.max((zone.h - labelH - bodyH) * 0.3, 2);
        const valueY = zone.y + labelH + gap;
        return (
          <g key={entry.label}>
            <SvgLabelUpper x={zone.x} y={zone.y}>{entry.label}</SvgLabelUpper>
            <SvgBody x={zone.x} y={valueY} fill={TEXT}>{entry.value}</SvgBody>
          </g>
        );
      })}
    </>
  );
};

const PluginListTitle: FC<{ size: BentoSize; count: number }> = ({ size, count }) => {
  const cr = contentArea(size);
  // Align count badge to right edge of content area, vertically centered with title
  const h3H = TYPE.h3.fontSize * (TYPE.h3.lineHeight ?? 1.35);
  const labelH = TYPE.label.fontSize * (TYPE.label.lineHeight ?? 1.4);
  const labelY = cr.y + (h3H - labelH) / 2;
  return (
    <>
      <SvgH3 x={cr.x} y={cr.y}>{'Plugins'}</SvgH3>
      <SvgLabel x={cr.x + cr.w} y={labelY} fill={TEXT_SEC} textAnchor="end">{`${count}`}</SvgLabel>
    </>
  );
};

type HealthCardProps = {
  size: BentoSize;
  healthStatus: string;
  isLive: boolean;
};

const HealthCard: FC<HealthCardProps> = ({ size, healthStatus, isLive }) => {
  const cr = contentArea(size);

  const coreOk = healthStatus !== 'unhealthy';
  const apiOk = isLive;
  const coreColor = coreOk ? '#22c55e' : '#ef4444';
  const apiColor = apiOk ? '#22c55e' : '#ef4444';
  const coreLabel = coreOk ? 'Healthy' : 'Unhealthy';
  const apiLabel = apiOk ? 'Healthy' : 'Down';

  const h4H = TYPE.h4.fontSize * (TYPE.h4.lineHeight ?? 1.35);
  const labelH = TYPE.label.fontSize * (TYPE.label.lineHeight ?? 1.4);
  const dotR = 4;

  // Compact (1x1): vertical stack — title, then two status rows
  // Wide layout needs at least ~160px width for horizontal split
  const compact = cr.w < 160;

  if (compact) {
    const vSplit = splitV(cr, 3);
    const titleZone = vSplit.cells[0]!;
    const coreZone = vSplit.cells[1]!;
    const apiZone = vSplit.cells[2]!;

    const renderCompactRow = (zone: Rect, color: string, name: string, val: string) => {
      const cy = zone.y + zone.h / 2;
      return (
        <g key={name}>
          <circle cx={zone.x + dotR + 2} cy={cy} r={dotR} fill={color} />
          <SvgLabel x={zone.x + dotR * 3 + 4} y={cy - labelH / 2}>{name}</SvgLabel>
          <SvgBody x={zone.x + zone.w} y={cy - labelH / 2} textAnchor="end">{val}</SvgBody>
        </g>
      );
    };

    return (
      <>
        <SvgH4 x={titleZone.x} y={titleZone.y}>{'Health'}</SvgH4>
        {renderCompactRow(coreZone, coreColor, 'Core', coreLabel)}
        {renderCompactRow(apiZone, apiColor, 'API', apiLabel)}
      </>
    );
  }

  // Wide layout: horizontal split — title column + status rows
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

  const bodyH = TYPE.body.fontSize * (TYPE.body.lineHeight ?? 1.5);
  const leftGap = Math.max((left.h - h4H - bodyH) * 0.15, 2);
  const subtitleY = left.y + h4H + leftGap;

  const dotPad = dotR * 3;
  const textMidOffset = labelH / 2;

  const renderRow = (row: Rect, color: string, name: string, val: string) => {
    const cy = row.y + row.h / 2;
    const textY = cy - textMidOffset;
    return (
      <g key={name}>
        <circle cx={row.x + dotR + 2} cy={cy} r={dotR} fill={color} />
        <SvgLabel x={row.x + dotPad + 4} y={textY}>{name}</SvgLabel>
        <SvgBody x={row.x + row.w} y={textY} textAnchor="end">{val}</SvgBody>
      </g>
    );
  };

  return (
    <>
      <SvgH4 x={left.x} y={left.y}>{'Health'}</SvgH4>
      <SvgBody x={left.x} y={subtitleY}>{'System'}</SvgBody>
      {renderRow(row1, coreColor, 'Core', coreLabel)}
      {renderRow(row2, apiColor, 'API', apiLabel)}
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
  const { data: gatewayStatus } = useGatewayStatus();
  const { data: gatewayHealth } = useGatewayHealth();
  const { data: gatewayLive } = useGatewayHealthLive();

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

  // Gateway-derived status values
  const statusValue = gatewayStatus
    ? gatewayStatus.state === 'running' ? 'Running' : gatewayStatus.state.charAt(0).toUpperCase() + gatewayStatus.state.slice(1)
    : 'Offline';
  const statusIcon = gatewayStatus?.state === 'running' ? '✓' : '!';
  const healthStatus = gatewayHealth?.status ?? 'unknown';
  const isLive = gatewayLive?.live ?? false;

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
                  <div className={styles.pluginDot} data-enabled={p.enabled || undefined} />
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
              value={statusValue}
              fallbackChar={statusIcon}
              iconBg={gatewayStatus?.state === 'running' ? 'rgba(93,222,176,0.15)' : 'rgba(239,68,68,0.15)'}
              iconText={gatewayStatus?.state === 'running' ? '#5ddeb0' : '#ef4444'}
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
            <HealthCard size={size} healthStatus={healthStatus} isLive={isLive} />
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
