import { useRef, useCallback, type PointerEvent } from 'react';

type LongPressHandlers = {
  onPointerDown: (e: PointerEvent) => void;
  onPointerMove: (e: PointerEvent) => void;
  onPointerUp: () => void;
  onPointerCancel: () => void;
};

/**
 * Pointer-based long press hook.
 * Fires `onLongPress` after `threshold` ms if pointer doesn't move more than `tolerance` px.
 */
export function useLongPress(
  onLongPress: () => void,
  { threshold = 500, tolerance = 10 }: { threshold?: number; tolerance?: number } = {},
): LongPressHandlers {
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const startRef = useRef<{ x: number; y: number } | null>(null);

  const clear = useCallback(() => {
    if (timerRef.current !== null) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
    startRef.current = null;
  }, []);

  const onPointerDown = useCallback(
    (e: PointerEvent) => {
      startRef.current = { x: e.clientX, y: e.clientY };
      timerRef.current = setTimeout(() => {
        timerRef.current = null;
        onLongPress();
      }, threshold);
    },
    [onLongPress, threshold],
  );

  const onPointerMove = useCallback(
    (e: PointerEvent) => {
      if (!startRef.current) return;
      const dx = e.clientX - startRef.current.x;
      const dy = e.clientY - startRef.current.y;
      if (dx * dx + dy * dy > tolerance * tolerance) {
        clear();
      }
    },
    [clear, tolerance],
  );

  return {
    onPointerDown,
    onPointerMove,
    onPointerUp: clear,
    onPointerCancel: clear,
  };
}
