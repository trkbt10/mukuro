import { type ReactNode } from 'react';
import { SectionHeader } from 'react-editor-ui';
import styles from './PanelSection.module.css';

export interface PanelSectionProps {
  title?: string;
  action?: ReactNode;
  collapsible?: boolean;
  defaultExpanded?: boolean;
  children: ReactNode;
  footer?: ReactNode;
  className?: string;
  /** Flush content without padding (for tables, lists with own padding) */
  flush?: boolean;
}

export function PanelSection({
  title,
  action,
  collapsible,
  defaultExpanded = true,
  children,
  footer,
  className,
  flush,
}: PanelSectionProps) {
  return (
    <div className={`${styles.panel}${className ? ` ${className}` : ''}`}>
      {title && (
        <SectionHeader
          title={title}
          action={action}
          collapsible={collapsible}
          defaultExpanded={defaultExpanded}
        />
      )}
      <div className={styles.content} data-flush={flush || undefined}>{children}</div>
      {footer && <div className={styles.footer}>{footer}</div>}
    </div>
  );
}

/* ── ContentPanel: headerless panel wrapper ── */

export interface ContentPanelProps {
  children: ReactNode;
  /** Remove internal padding */
  flush?: boolean;
}

/**
 * Simple panel container without header.
 * Use for wrapping StatCards or other content that needs a panel border.
 */
export function ContentPanel({ children, flush }: ContentPanelProps) {
  return (
    <div className={styles.panel}>
      <div className={styles.content} data-flush={flush || undefined}>{children}</div>
    </div>
  );
}
