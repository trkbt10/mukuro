import { useMemo } from 'react';
import {
  History as HistoryIcon,
  ChevronLeft,
  ChevronRight,
  RefreshCw,
  Play,
  Circle,
  User,
  Bot,
  Wrench,
  CheckCircle,
  AlertCircle,
  Loader2,
  Info,
} from 'lucide-react';
import { IconButton, Badge } from '@/components/ui';
import { PageToolbar } from '@/components/layout/PageToolbar';
import { AssistantContent } from '@/components/chat';
import { useHistoryNavigation } from '@/hooks';
import { formatTimestamp, extractRecordContent } from '@/lib/messages';
import type { HistoryRecord, HistoryDateEntry } from '@mukuro/client';
import styles from './History.module.css';

const WEEKDAYS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

interface CalendarGridProps {
  viewYear: number;
  viewMonth: number;
  monthDates: HistoryDateEntry[];
  selectedDate: { year: number; month: number; day: number } | null;
  onSelectDate: (year: number, month: number, day: number) => void;
}

function CalendarGrid({ viewYear, viewMonth, monthDates, selectedDate, onSelectDate }: CalendarGridProps) {
  const today = useMemo(() => new Date(), []);
  const todayYear = today.getFullYear();
  const todayMonth = today.getMonth() + 1;
  const todayDay = today.getDate();

  const sessionCountByDay = useMemo(() => {
    const map = new Map<number, number>();
    for (const d of monthDates) {
      map.set(d.day, d.session_count);
    }
    return map;
  }, [monthDates]);

  const cells = useMemo(() => {
    const firstDayOfWeek = new Date(viewYear, viewMonth - 1, 1).getDay();
    const daysInMonth = new Date(viewYear, viewMonth, 0).getDate();

    return Array.from({ length: 42 }, (_, i) => {
      const day = i - firstDayOfWeek + 1;
      if (day < 1 || day > daysInMonth) return null;
      return day;
    });
  }, [viewYear, viewMonth]);

  return (
    <div className={styles.calendarGrid}>
      <div className={styles.calendarHeader}>
        {WEEKDAYS.map((d, i) => (
          <span key={i}>{d}</span>
        ))}
      </div>
      <div className={styles.calendarBody}>
        {cells.map((day, i) => {
          const hasSessions = day !== null && sessionCountByDay.has(day);
          const isSelected = day !== null
            && selectedDate?.year === viewYear
            && selectedDate?.month === viewMonth
            && selectedDate?.day === day;
          const isToday = day !== null
            && viewYear === todayYear
            && viewMonth === todayMonth
            && day === todayDay;

          return (
            <div
              key={i}
              className={styles.calendarCell}
              data-empty={day === null || undefined}
              data-selected={isSelected || undefined}
              data-today={isToday || undefined}
              onClick={() => day !== null && onSelectDate(viewYear, viewMonth, day)}
            >
              {day !== null && (
                <>
                  <span className={styles.dayNumber}>{day}</span>
                  {hasSessions && <span className={styles.sessionDot} />}
                </>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function RecordItem({ record }: { record: HistoryRecord }) {
  const payload = record.payload ?? {};
  const content = extractRecordContent(payload);

  switch (record.record_type) {
    case 'session_meta': {
      const channel = (payload as Record<string, unknown>).channel as string | undefined;
      return (
        <div className={styles.recordStatus}>
          <span className={styles.recordStatusDot}><Info style={{ width: 12, height: 12 }} /></span>
          <div className={styles.recordBody}>
            <span className={styles.recordStatusText}>
              Session created {formatTimestamp(record.timestamp)}{channel ? ` (${channel})` : ''}
            </span>
          </div>
        </div>
      );
    }

    case 'session_start':
      return (
        <div className={styles.recordStatus}>
          <span className={styles.recordStatusDot}><Circle style={{ width: 12, height: 12 }} /></span>
          <div className={styles.recordBody}>
            <span className={styles.recordStatusText}>
              Session started {formatTimestamp(record.timestamp)}
            </span>
          </div>
        </div>
      );

    case 'session_end':
      return (
        <div className={styles.recordStatus}>
          <span className={styles.recordStatusDot}><Circle style={{ width: 12, height: 12 }} /></span>
          <div className={styles.recordBody}>
            <span className={styles.recordStatusText}>
              Session ended {formatTimestamp(record.timestamp)}
            </span>
          </div>
        </div>
      );

    case 'user_message':
      return (
        <div className={styles.recordUser}>
          <span className={styles.recordUserIcon}><User style={{ width: 14, height: 14 }} /></span>
          <div className={styles.recordBody}>
            <div className={styles.recordUserBubble}>{content || '(empty)'}</div>
          </div>
        </div>
      );

    case 'assistant_message':
      return (
        <div className={styles.recordAssistant}>
          <span className={styles.recordAssistantIcon}><Bot style={{ width: 14, height: 14 }} /></span>
          <div className={styles.recordBody}>
            <div className={styles.recordAssistantBubble}>
              {content ? <AssistantContent content={content} /> : '(empty)'}
            </div>
          </div>
        </div>
      );

    case 'tool_call': {
      const toolName = (payload as Record<string, unknown>).tool_name as string | undefined;
      const args = (payload as Record<string, unknown>).arguments;
      const argsStr = args ? JSON.stringify(args) : '';
      return (
        <div className={styles.recordTool}>
          <span className={styles.recordToolIcon}><Wrench style={{ width: 14, height: 14 }} /></span>
          <div className={styles.recordBody}>
            <div className={styles.recordToolBlock}>
              <span className={styles.recordToolName}>{toolName ?? 'tool'}</span>
              {argsStr && <span>({argsStr.length > 100 ? argsStr.slice(0, 100) + '...' : argsStr})</span>}
            </div>
          </div>
        </div>
      );
    }

    case 'tool_result':
      return (
        <div className={styles.recordResult}>
          <span className={styles.recordResultIcon}><CheckCircle style={{ width: 14, height: 14 }} /></span>
          <div className={styles.recordBody}>
            <div className={styles.recordResultBlock}>
              {content
                ? (content.length > 200 ? content.slice(0, 200) + '...' : content)
                : '(no content)'}
            </div>
          </div>
        </div>
      );

    case 'error':
      return (
        <div className={styles.recordError}>
          <span className={styles.recordErrorIcon}><AlertCircle style={{ width: 14, height: 14 }} /></span>
          <div className={styles.recordBody}>
            <div className={styles.recordErrorBanner}>
              {content || 'Unknown error'}
            </div>
          </div>
        </div>
      );

    default:
      return null;
  }
}

export function History() {
  const h = useHistoryNavigation();

  return (
    <div className={styles.page}>
      <PageToolbar
        title="History"
        titleBadge={
          h.dates && (
            <Badge variant="default" size="sm">
              {h.dates.length} date{h.dates.length !== 1 ? 's' : ''}
            </Badge>
          )
        }
        noPadding
        actions={
          <IconButton
            icon={<RefreshCw style={{ width: 14, height: 14 }} />}
            aria-label="Refresh"
            onClick={h.refresh}
            variant="ghost"
            size="sm"
          />
        }
      />

      <div className={styles.body}>
        {/* Left panel */}
        <div className={styles.leftPanel}>
          {/* Month nav */}
          <div className={styles.monthNav}>
            <IconButton
              icon={<ChevronLeft style={{ width: 14, height: 14 }} />}
              aria-label="Previous month"
              onClick={h.prevMonth}
              variant="ghost"
              size="sm"
            />
            <span className={styles.monthLabel}>
              {h.viewYear}/{String(h.viewMonth).padStart(2, '0')}
            </span>
            <IconButton
              icon={<ChevronRight style={{ width: 14, height: 14 }} />}
              aria-label="Next month"
              onClick={h.nextMonth}
              variant="ghost"
              size="sm"
            />
          </div>

          {/* Calendar grid */}
          {h.datesLoading ? (
            <div className={styles.loadingState}>
              <Loader2 style={{ width: 16, height: 16, animation: 'spin 1s linear infinite' }} />
            </div>
          ) : (
            <CalendarGrid
              viewYear={h.viewYear}
              viewMonth={h.viewMonth}
              monthDates={h.monthDates}
              selectedDate={h.selectedDate}
              onSelectDate={h.selectDate}
            />
          )}

          {/* Sessions sub-list */}
          {h.sessions && h.sessions.length > 0 && (
            <div className={styles.sessionsSection}>
              <div className={styles.sessionsLabel}>Sessions</div>
              {h.sessions.map(s => (
                <div
                  key={s.session_id}
                  className={styles.sessionItem}
                  data-selected={h.selectedSessionId === s.session_id || undefined}
                  onClick={() => h.selectSession(s.session_id)}
                >
                  <span className={styles.sessionId} title={s.session_id}>
                    {s.chat_id}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Right panel */}
        <div className={styles.rightPanel}>
          {h.selectedSessionId && h.sessionDetail ? (
            <>
              {/* Session header */}
              <div className={styles.sessionHeader}>
                <div>
                  <div className={styles.sessionTitle}>{h.selectedSessionId}</div>
                  <div className={styles.sessionMeta}>
                    {h.sessionDetail.records.length} record{h.sessionDetail.records.length !== 1 ? 's' : ''}
                  </div>
                </div>
                <button
                  className={styles.resumeBtn}
                  onClick={h.resume}
                  disabled={h.resumePending}
                >
                  <Play style={{ width: 12, height: 12 }} />
                  {h.resumePending ? 'Resuming...' : 'Resume Chat'}
                </button>
              </div>

              {/* Timeline */}
              <div className={styles.timeline}>
                {h.sessionDetail.records.map((record, i) => (
                  <RecordItem key={i} record={record} />
                ))}
                {h.sessionDetail.records.every(r =>
                  r.record_type === 'session_meta' || r.record_type === 'session_start'
                ) && (
                  <div className={styles.emptyTimeline}>
                    <Info style={{ width: 16, height: 16 }} />
                    <span>No messages in this session yet</span>
                  </div>
                )}
              </div>
            </>
          ) : h.detailLoading ? (
            <div className={styles.loadingState}>
              <Loader2 style={{ width: 20, height: 20, animation: 'spin 1s linear infinite' }} />
            </div>
          ) : (
            <div className={styles.emptyState}>
              <HistoryIcon className={styles.emptyIcon} style={{ width: 48, height: 48 }} />
              <span className={styles.emptyText}>
                {h.selectedDate ? 'Select a session to view' : 'Select a date to browse history'}
              </span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
