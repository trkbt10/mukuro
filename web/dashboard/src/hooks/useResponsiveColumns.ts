import { useState, useCallback, useRef } from 'react';

/**
 * Returns column count (4/2/1) based on container width via ResizeObserver.
 * Uses a callback ref pattern so the observer reliably attaches
 * even when the target element mounts after the hook is first called
 * (e.g. during a loading state).
 */
export function useResponsiveColumns(): { columns: number; ref: (node: HTMLDivElement | null) => void } {
  const [columns, setColumns] = useState(4);
  const observerRef = useRef<ResizeObserver | null>(null);

  const ref = useCallback((node: HTMLDivElement | null) => {
    // Clean up previous observer
    if (observerRef.current) {
      observerRef.current.disconnect();
      observerRef.current = null;
    }

    if (!node) return;

    const update = () => {
      const w = node.clientWidth;
      if (w < 400) setColumns(1);
      else if (w < 700) setColumns(2);
      else setColumns(4);
    };

    update();
    const observer = new ResizeObserver(() => update());
    observer.observe(node);
    observerRef.current = observer;
  }, []);

  return { columns, ref };
}
