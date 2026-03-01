import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { IconButton } from '@/components/ui';
import styles from './PageToolbar.module.css';

export interface PageToolbarProps {
  /** Main title */
  title: string;
  /** Back navigation - shows back button when provided */
  back?: string;
  /** Subtitle shown below title (optional, for top-level pages only) */
  subtitle?: string;
  /** Badge/status element shown next to title (optional) */
  titleBadge?: ReactNode;
  /** Right-aligned actions (optional) */
  actions?: ReactNode;
  /** Set true when parent has no padding (e.g., full-height layouts like Chat/History) */
  noPadding?: boolean;
}

/**
 * Page toolbar with optional back navigation and actions.
 *
 * For detail pages, use `back` prop to show a back button.
 * The sidebar already shows the hierarchy, so no breadcrumb needed.
 */
export function PageToolbar({
  title,
  back,
  subtitle,
  titleBadge,
  actions,
  noPadding,
}: PageToolbarProps) {
  const navigate = useNavigate();

  return (
    <div className={styles.toolbar} data-no-padding={noPadding || undefined}>
      <div className={styles.left}>
        {back && (
          <IconButton
            icon={<ArrowLeft style={{ width: 16, height: 16 }} />}
            aria-label="Back"
            onClick={() => navigate(back)}
            variant="ghost"
            size="sm"
          />
        )}
        <div className={styles.titleBlock}>
          <div className={styles.titleRow}>
            <h1 className={styles.title}>{title}</h1>
            {titleBadge && <span className={styles.badge}>{titleBadge}</span>}
          </div>
          {subtitle && <p className={styles.subtitle}>{subtitle}</p>}
        </div>
      </div>
      {actions && <div className={styles.actions}>{actions}</div>}
    </div>
  );
}
