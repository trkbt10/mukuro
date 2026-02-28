import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import type {
  HistoryDateEntry,
  HistorySessionSummary,
  HistorySessionDetail,
} from '@mukuro/client';
import { getClient } from '@/lib/client';

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
