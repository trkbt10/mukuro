import { describe, it, expect, vi } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useHistoryNavigation, formatHistoryDate } from './useHistory';
import type { ReactNode } from 'react';

// ---------------------------------------------------------------------------
// Mock API client — navigation/state tests don't need real responses
// ---------------------------------------------------------------------------

vi.mock('@/lib/client', () => ({
  getClient: () => ({
    history: {
      listDates: vi.fn().mockResolvedValue([]),
      listSessions: vi.fn().mockResolvedValue([]),
      getSession: vi.fn().mockResolvedValue({ session_id: '', records: [] }),
      resumeSession: vi.fn().mockResolvedValue({ chat_id: 'new-id' }),
    },
  }),
}));

// ---------------------------------------------------------------------------
// Wrapper: MemoryRouter + QueryClient (単一 history/* ルート)
// ---------------------------------------------------------------------------

function createWrapper(initialPath: string) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[initialPath]}>
          <Routes>
            <Route path="history/*" element={<>{children}</>} />
            <Route path="*" element={<>{children}</>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    );
  };
}

// ---------------------------------------------------------------------------
// formatHistoryDate
// ---------------------------------------------------------------------------

describe('formatHistoryDate', () => {
  it('pads single-digit month and day', () => {
    expect(formatHistoryDate(2026, 2, 8)).toBe('2026-02-08');
  });

  it('keeps double-digit month and day', () => {
    expect(formatHistoryDate(2026, 12, 28)).toBe('2026-12-28');
  });
});

// ---------------------------------------------------------------------------
// useHistoryNavigation
// ---------------------------------------------------------------------------

describe('useHistoryNavigation', () => {
  // --- URL parsing ---

  describe('URL parsing', () => {
    it('/history → no date, no session', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history'),
      });
      expect(result.current.selectedDate).toBeNull();
      expect(result.current.selectedSessionId).toBeNull();
    });

    it('/history/2026-02-28 → date parsed', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-02-28'),
      });
      expect(result.current.selectedDate).toEqual({ year: 2026, month: 2, day: 28 });
      expect(result.current.selectedSessionId).toBeNull();
    });

    it('/history/2026-02-28/web_chat%3Aabc → date + decoded session', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-02-28/web_chat%3Aabc'),
      });
      expect(result.current.selectedDate).toEqual({ year: 2026, month: 2, day: 28 });
      expect(result.current.selectedSessionId).toBe('web_chat:abc');
    });

    it('invalid date segment → null', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/not-a-date'),
      });
      expect(result.current.selectedDate).toBeNull();
    });
  });

  // --- month view defaults ---

  describe('month view', () => {
    it('defaults to current month at /history', () => {
      const now = new Date();
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history'),
      });
      expect(result.current.viewYear).toBe(now.getFullYear());
      expect(result.current.viewMonth).toBe(now.getMonth() + 1);
    });

    it('syncs view month from URL date', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2025-06-15'),
      });
      expect(result.current.viewYear).toBe(2025);
      expect(result.current.viewMonth).toBe(6);
    });
  });

  // --- month navigation ---

  describe('month navigation', () => {
    it('prevMonth decrements month', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-03-15'),
      });
      act(() => result.current.prevMonth());
      expect(result.current.viewYear).toBe(2026);
      expect(result.current.viewMonth).toBe(2);
    });

    it('prevMonth wraps January → December (year - 1)', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-01-10'),
      });
      act(() => result.current.prevMonth());
      expect(result.current.viewYear).toBe(2025);
      expect(result.current.viewMonth).toBe(12);
    });

    it('nextMonth increments month', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-02-28'),
      });
      act(() => result.current.nextMonth());
      expect(result.current.viewYear).toBe(2026);
      expect(result.current.viewMonth).toBe(3);
    });

    it('nextMonth wraps December → January (year + 1)', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-12-01'),
      });
      act(() => result.current.nextMonth());
      expect(result.current.viewYear).toBe(2027);
      expect(result.current.viewMonth).toBe(1);
    });

    // このテストが今回のバグ(Route再マウントによるstate消失)を検出する
    it('prevMonth clears date selection AND preserves month state', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-03-15'),
      });
      expect(result.current.selectedDate).not.toBeNull();
      expect(result.current.viewMonth).toBe(3);

      act(() => result.current.prevMonth());

      // date cleared (navigated to /history), but month state survives
      expect(result.current.selectedDate).toBeNull();
      expect(result.current.viewYear).toBe(2026);
      expect(result.current.viewMonth).toBe(2);
    });

    it('nextMonth clears date selection AND preserves month state', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-03-15'),
      });
      act(() => result.current.nextMonth());

      expect(result.current.selectedDate).toBeNull();
      expect(result.current.viewYear).toBe(2026);
      expect(result.current.viewMonth).toBe(4);
    });

    it('consecutive month navigation preserves state', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history'),
      });
      const initialMonth = result.current.viewMonth;

      act(() => result.current.prevMonth());
      act(() => result.current.prevMonth());
      act(() => result.current.prevMonth());

      const expected = ((initialMonth - 3 - 1 + 12) % 12) + 1;
      expect(result.current.viewMonth).toBe(expected);
    });
  });

  // --- selectDate ---

  describe('selectDate', () => {
    it('navigates to date URL and updates selectedDate', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history'),
      });
      act(() => result.current.selectDate(2026, 2, 28));
      expect(result.current.selectedDate).toEqual({ year: 2026, month: 2, day: 28 });
    });

    it('syncs view month to newly selected date', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history'),
      });
      act(() => result.current.selectDate(2025, 8, 5));
      expect(result.current.viewYear).toBe(2025);
      expect(result.current.viewMonth).toBe(8);
    });
  });

  // --- selectSession ---

  describe('selectSession', () => {
    it('navigates with encoded session ID', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history/2026-02-28'),
      });
      act(() => result.current.selectSession('web_chat:abc123'));
      expect(result.current.selectedSessionId).toBe('web_chat:abc123');
    });

    it('is no-op without date in URL', () => {
      const { result } = renderHook(() => useHistoryNavigation(), {
        wrapper: createWrapper('/history'),
      });
      act(() => result.current.selectSession('web_chat:abc123'));
      expect(result.current.selectedSessionId).toBeNull();
    });
  });
});
