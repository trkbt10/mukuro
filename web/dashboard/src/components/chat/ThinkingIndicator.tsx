import styles from './ThinkingIndicator.module.css';

export function ThinkingIndicator() {
  return (
    <div className={styles.thinking}>
      <div className={styles.thinkingDots}>
        <span className={styles.thinkingDot} />
        <span className={styles.thinkingDot} />
        <span className={styles.thinkingDot} />
      </div>
      <span>Agent is thinking...</span>
    </div>
  );
}
