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
} from 'lucide-react';
import { IconButton, Badge } from '@/components/ui';
import { useHistoryNavigation, formatHistoryDate } from '@/hooks';
import type { HistoryRecord } from '@mukuro/client';
import styles from './History.module.css';

function formatTimestamp(ts: number) {
  const d = new Date(ts);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function RecordItem({ record }: { record: HistoryRecord }) {
  const payload = record.payload ?? {};
  const content = typeof payload === 'string'
    ? payload
    : (payload as Record<string, unknown>).content as string | undefined;

  switch (record.record_type) {
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
            <div className={styles.recordUserBubble}>{content ?? '(empty)'}</div>
          </div>
        </div>
      );

    case 'assistant_message':
      return (
        <div className={styles.recordAssistant}>
          <span className={styles.recordAssistantIcon}><Bot style={{ width: 14, height: 14 }} /></span>
          <div className={styles.recordBody}>
            <div className={styles.recordAssistantBubble}>{content ?? '(empty)'}</div>
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
              {content ?? (payload as Record<string, unknown>).message as string ?? 'Unknown error'}
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
      {/* Header */}
      <div className={styles.header}>
        <div className={styles.titleGroup}>
          <h1 className={styles.title}>History</h1>
          {h.dates && (
            <Badge variant="default" size="sm">
              {h.dates.length} date{h.dates.length !== 1 ? 's' : ''}
            </Badge>
          )}
        </div>
        <div className={styles.actions}>
          <IconButton
            icon={<RefreshCw style={{ width: 14, height: 14 }} />}
            aria-label="Refresh"
            onClick={h.refresh}
            variant="ghost"
            size="sm"
          />
        </div>
      </div>

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

          {/* Date list */}
          <div className={styles.dateList}>
            {h.datesLoading ? (
              <div className={styles.loadingState}>
                <Loader2 style={{ width: 16, height: 16, animation: 'spin 1s linear infinite' }} />
              </div>
            ) : h.monthDates.length === 0 ? (
              <div className={styles.emptySubtext} style={{ padding: '16px', textAlign: 'center' }}>
                No history for this month
              </div>
            ) : (
              h.monthDates.map(d => {
                const isSelected = h.selectedDate?.year === d.year
                  && h.selectedDate?.month === d.month
                  && h.selectedDate?.day === d.day;
                return (
                  <div
                    key={`${d.year}-${d.month}-${d.day}`}
                    className={isSelected ? styles.dateItemSelected : styles.dateItem}
                    onClick={() => h.selectDate(d.year, d.month, d.day)}
                  >
                    <span>{formatHistoryDate(d.year, d.month, d.day)}</span>
                    <div className={styles.dateBadges}>
                      {Array.from({ length: Math.min(d.session_count, 5) }).map((_, i) => (
                        <span key={i} className={styles.dateDot} />
                      ))}
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Sessions sub-list */}
          {h.sessions && h.sessions.length > 0 && (
            <div className={styles.sessionsSection}>
              <div className={styles.sessionsLabel}>Sessions</div>
              {h.sessions.map(s => (
                <div
                  key={s.session_id}
                  className={h.selectedSessionId === s.session_id ? styles.sessionItemSelected : styles.sessionItem}
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
