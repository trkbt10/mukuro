import { useReducer, useCallback } from 'react';
import type { BentoSize } from '@/components/bento/grid/fractal';
import type { DashboardBlock, DashboardBlockId, BlockPosition } from '@/components/bento/layout-types';
import { BLOCK_CATALOG } from '@/components/bento/layout-types';
import {
  compactBlocks, normalizeToColumns, buildInsertionPreview,
  getDefaultBlocks, resizeBlock, addBlockAt,
} from '@/components/bento/layout-engine';

type LayoutState = {
  blocks: DashboardBlock[];
  columns: number;
  dirty: boolean;
};

type LayoutAction =
  | { type: 'SET_BLOCKS'; blocks: DashboardBlock[] }
  | { type: 'SET_COLUMNS'; columns: number }
  | { type: 'MOVE_BLOCK'; blockId: string; target: BlockPosition }
  | { type: 'RESIZE_BLOCK'; blockId: string; newSize: BentoSize }
  | { type: 'ADD_BLOCK'; blockId: DashboardBlockId; position: BlockPosition }
  | { type: 'REMOVE_BLOCK'; blockId: string }
  | { type: 'MARK_SAVED' }
  | { type: 'RESET' };

function layoutReducer(state: LayoutState, action: LayoutAction): LayoutState {
  switch (action.type) {
    case 'SET_BLOCKS':
      return { ...state, blocks: action.blocks, dirty: false };

    case 'SET_COLUMNS': {
      if (action.columns === state.columns) return state;
      const blocks = normalizeToColumns(state.blocks, action.columns);
      return { ...state, blocks: compactBlocks(blocks, action.columns), columns: action.columns };
    }

    case 'MOVE_BLOCK': {
      const blocks = buildInsertionPreview(state.blocks, action.blockId, action.target, state.columns);
      return { ...state, blocks, dirty: true };
    }

    case 'RESIZE_BLOCK': {
      const blocks = resizeBlock(state.blocks, action.blockId, action.newSize, state.columns);
      return { ...state, blocks, dirty: true };
    }

    case 'ADD_BLOCK': {
      const meta = BLOCK_CATALOG[action.blockId];
      const newBlock: DashboardBlock = {
        id: action.blockId,
        size: meta.defaultSize,
        position: action.position,
      };
      const blocks = addBlockAt(state.blocks, newBlock, state.columns);
      return { ...state, blocks, dirty: true };
    }

    case 'REMOVE_BLOCK': {
      const blocks = compactBlocks(
        state.blocks.filter((b) => b.id !== action.blockId),
        state.columns,
      );
      return { ...state, blocks, dirty: true };
    }

    case 'MARK_SAVED':
      return { ...state, dirty: false };

    case 'RESET': {
      const blocks = getDefaultBlocks(state.columns);
      return { ...state, blocks, dirty: true };
    }
  }
}

export function useDashboardLayout(initialBlocks?: DashboardBlock[], initialColumns: number = 4) {
  const [state, dispatch] = useReducer(layoutReducer, {
    blocks: initialBlocks ?? getDefaultBlocks(initialColumns),
    columns: initialColumns,
    dirty: false,
  });

  const setBlocks = useCallback(
    (blocks: DashboardBlock[]) => dispatch({ type: 'SET_BLOCKS', blocks }),
    [],
  );
  const setColumns = useCallback(
    (columns: number) => dispatch({ type: 'SET_COLUMNS', columns }),
    [],
  );
  const moveBlockWithPush = useCallback(
    (blockId: string, target: BlockPosition) =>
      dispatch({ type: 'MOVE_BLOCK', blockId, target }),
    [],
  );
  const resizeBlockAction = useCallback(
    (blockId: string, newSize: BentoSize) =>
      dispatch({ type: 'RESIZE_BLOCK', blockId, newSize }),
    [],
  );
  const addBlock = useCallback(
    (blockId: DashboardBlockId, position: BlockPosition) =>
      dispatch({ type: 'ADD_BLOCK', blockId, position }),
    [],
  );
  const removeBlock = useCallback(
    (blockId: string) => dispatch({ type: 'REMOVE_BLOCK', blockId }),
    [],
  );
  const markSaved = useCallback(() => dispatch({ type: 'MARK_SAVED' }), []);
  const resetLayout = useCallback(() => dispatch({ type: 'RESET' }), []);

  return {
    state,
    setBlocks, setColumns, moveBlockWithPush,
    resizeBlockAction, addBlock, removeBlock,
    markSaved, resetLayout,
  };
}
