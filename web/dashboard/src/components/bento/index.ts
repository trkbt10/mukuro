// Grid & Block
export { BentoGrid, BentoBlock, type BentoGridProps, type BentoBlockProps } from './BentoGrid';

// Grid math
export {
  CELL, GAP, RATIO, ICON, SPACE,
  viewBoxSize, createGrid, fullRect, insetRect, rectCenter,
  splitH, splitV, place, centerOf,
  contentArea, contentZones,
  type BentoSize, type Rect, type Grid, type SplitResult,
  type Alignment, type Placement,
} from './grid/fractal';

// Card shell
export {
  SvgCardShell, SvgCardShellLink,
  type SvgCardShellProps, type SvgCardShellLinkProps, type CardTheme,
} from './card-parts/SvgCardShell';

// SVG text
export {
  SvgText, SvgDisplay, SvgH2, SvgH3, SvgH4, SvgBody, SvgCaption, SvgLabel, SvgLabelUpper,
  type SvgTextProps,
} from './card-parts/SvgText';

// SVG icon
export { SvgIcon, type SvgIconProps, type IconSize } from './card-parts/SvgIcon';

// Typography presets
export { TYPE, type TypePreset } from './card-parts/typography';

// Layout types & engine
export {
  type DashboardBlockId, type DashboardBlock, type BlockPosition,
  type BlockMeta,
  DEFAULT_DASHBOARD_BLOCKS, ALL_BLOCK_IDS, BLOCK_CATALOG, RESIZE_SIZES, sizeSpan,
} from './layout-types';
export {
  canPlace, compactBlocks, normalizeToColumns, buildInsertionPreview,
  gridRows, getDefaultBlocks, isCellEmpty, resizeBlock, addBlockAt,
} from './layout-engine';

// DnD components
export { DraggableBlock } from './DraggableBlock';
export { DroppableCell } from './DroppableCell';
export { EditModeToolbar } from './EditModeToolbar';
export { ResizeHandle } from './ResizeHandle';
export { BlockPicker } from './BlockPicker';
