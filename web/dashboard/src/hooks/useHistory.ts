import { useState, useCallback, useMemo, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import type {
  HistoryDateEntry,
  HistorySessionSummary,
  HistorySessionDetail,
} from '@mukuro/client';
import { getClient } from '@/lib/client';

// --- 低レベルデータhooks (内部用・個別利用も可) ---

export function useHistoryDates() {
  return useQuery<HistoryDateEntry[]>({
    queryKey: ['history', 'dates'],
    queryFn: () => getClient().history.listDates(),
  });
}

export function useHistorySessions(
  year: number | null,
  month: number | null,
  day: number | null,
) {
  return useQuery<HistorySessionSummary[]>({
    queryKey: ['history', 'sessions', year, month, day],
    queryFn: () => getClient().history.listSessions(year!, month!, day!),
    enabled: year != null && month != null && day != null,
  });
}

export function useHistorySession(sessionId: string | null) {
  return useQuery<HistorySessionDetail>({
    queryKey: ['history', 'session', sessionId],
    queryFn: () => getClient().history.getSession(sessionId!),
    enabled: sessionId != null,
  });
}

export function useResumeSession() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (sessionId: string) =>
      getClient().history.resumeSession(sessionId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['chat'] });
    },
  });
}

// --- ユーティリティ ---

export function formatHistoryDate(year: number, month: number, day: number) {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function parseDate(dateStr: string): { year: number; month: number; day: number } | null {
  const m = dateStr.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  return { year: Number(m[1]), month: Number(m[2]), day: Number(m[3]) };
}

// --- 統合hook: URL状態 + ナビゲーション + データ ---

export interface HistoryNavigation {
  // URL由来の選択状態
  selectedDate: { year: number; month: number; day: number } | null;
  selectedSessionId: string | null;

  // カレンダー表示月
  viewYear: number;
  viewMonth: number;

  // データ
  dates: HistoryDateEntry[] | undefined;
  monthDates: HistoryDateEntry[];
  sessions: HistorySessionSummary[] | undefined;
  sessionDetail: HistorySessionDetail | undefined;

  // ローディング
  datesLoading: boolean;
  detailLoading: boolean;
  resumePending: boolean;

  // アクション
  prevMonth: () => void;
  nextMonth: () => void;
  selectDate: (year: number, month: number, day: number) => void;
  selectSession: (sessionId: string) => void;
  resume: () => Promise<void>;
  refresh: () => void;
}

export function useHistoryNavigation(): HistoryNavigation {
  const navigate = useNavigate();
  const params = useParams<{ date?: string; sessionId?: string }>();

  // URL → 選択状態
  const selectedDate = useMemo(() => {
    if (!params.date) return null;
    return parseDate(params.date);
  }, [params.date]);

  const selectedSessionId = params.sessionId
    ? decodeURIComponent(params.sessionId)
    : null;

  // 月表示state: URLの日付から同期、なければ現在月
  const now = useMemo(() => new Date(), []);
  const [viewYear, setViewYear] = useState(selectedDate?.year ?? now.getFullYear());
  const [viewMonth, setViewMonth] = useState(selectedDate?.month ?? (now.getMonth() + 1));

  useEffect(() => {
    if (selectedDate) {
      setViewYear(selectedDate.year);
      setViewMonth(selectedDate.month);
    }
  }, [selectedDate]);

  // データフェッチ
  const { data: dates, isLoading: datesLoading, refetch: refetchDates } = useHistoryDates();

  const { data: sessions } = useHistorySessions(
    selectedDate?.year ?? null,
    selectedDate?.month ?? null,
    selectedDate?.day ?? null,
  );

  const { data: sessionDetail, isLoading: detailLoading } = useHistorySession(selectedSessionId);

  const resumeMutation = useResumeSession();

  // 当月の日付一覧（降順）
  const monthDates = useMemo(() => {
    if (!dates) return [];
    return dates
      .filter(d => d.year === viewYear && d.month === viewMonth)
      .sort((a, b) => b.day - a.day);
  }, [dates, viewYear, viewMonth]);

  // ナビゲーション
  const prevMonth = useCallback(() => {
    if (viewMonth === 1) {
      setViewYear(y => y - 1);
      setViewMonth(12);
    } else {
      setViewMonth(m => m - 1);
    }
    if (selectedDate) navigate('/history');
  }, [viewMonth, selectedDate, navigate]);

  const nextMonth = useCallback(() => {
    if (viewMonth === 12) {
      setViewYear(y => y + 1);
      setViewMonth(1);
    } else {
      setViewMonth(m => m + 1);
    }
    if (selectedDate) navigate('/history');
  }, [viewMonth, selectedDate, navigate]);

  const selectDate = useCallback((year: number, month: number, day: number) => {
    navigate(`/history/${formatHistoryDate(year, month, day)}`);
  }, [navigate]);

  const selectSession = useCallback((sessionId: string) => {
    if (!params.date) return;
    navigate(`/history/${params.date}/${encodeURIComponent(sessionId)}`);
  }, [params.date, navigate]);

  const resume = useCallback(async () => {
    if (!selectedSessionId) return;
    const result = await resumeMutation.mutateAsync(selectedSessionId);
    localStorage.setItem('mukuro_chat_id', result.chat_id);
    navigate(`/chat?resumed=${encodeURIComponent(result.chat_id)}`);
  }, [selectedSessionId, resumeMutation, navigate]);

  const refresh = useCallback(() => {
    refetchDates();
  }, [refetchDates]);

  return {
    selectedDate,
    selectedSessionId,
    viewYear,
    viewMonth,
    dates,
    monthDates,
    sessions,
    sessionDetail,
    datesLoading,
    detailLoading,
    resumePending: resumeMutation.isPending,
    prevMonth,
    nextMonth,
    selectDate,
    selectSession,
    resume,
    refresh,
  };
}
