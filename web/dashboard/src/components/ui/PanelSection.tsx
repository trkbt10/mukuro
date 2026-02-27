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
}

export function PanelSection({
  title,
  action,
  collapsible,
  defaultExpanded = true,
  children,
  footer,
  className,
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
      <div className={styles.content}>{children}</div>
      {footer && <div className={styles.footer}>{footer}</div>}
    </div>
  );
}
