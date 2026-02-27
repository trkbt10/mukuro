import type { CSSProperties, ComponentType, ReactNode } from 'react';
import styles from './StatCard.module.css';

export interface StatCardProps {
  label: string;
  value: ReactNode;
  icon: ComponentType<{ style?: CSSProperties }>;
  iconBg: string;
  iconColor?: string;
}

export function StatCard({ label, value, icon: Icon, iconBg, iconColor = 'white' }: StatCardProps) {
  return (
    <div className={styles.statCard}>
      <div className={styles.statIcon} style={{ background: iconBg }}>
        <Icon style={{ width: 20, height: 20, color: iconColor }} />
      </div>
      <div>
        <p className={styles.statLabel}>{label}</p>
        <p className={styles.statValue}>{value}</p>
      </div>
    </div>
  );
}
