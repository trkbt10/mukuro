import React from 'react';
import type { FC, ReactNode, CSSProperties } from 'react';
import { viewBoxSize, type BentoSize } from '../grid/fractal';
import styles from './SvgCardShell.module.css';

type SizeCat = 'small' | 'medium' | 'large';

function getSizeCat(size: BentoSize): SizeCat {
  if (size === '1x1') return 'small';
  if (size === '2x1' || size === '1x2') return 'medium';
  return 'large';
}

export type CardTheme = {
  surface: string;
  text: string;
  textSecondary: string;
};

function buildThemeStyle(theme: CardTheme | undefined): CSSProperties | undefined {
  if (!theme) return undefined;
  return {
    '--tone-surface': theme.surface,
    '--tone-text': theme.text,
    '--tone-text-secondary': theme.textSecondary,
  } as CSSProperties;
}

function isConcreteTheme(theme: CardTheme | undefined): boolean {
  return !!theme && !theme.surface.startsWith('var(');
}

// ── SvgCardShell ──

export type SvgCardShellProps = {
  size: BentoSize;
  children: ReactNode;
  /** HTML content overlaid after the SVG (for interactive elements). */
  overlay?: ReactNode;
  theme?: CardTheme;
};

export const SvgCardShell: FC<SvgCardShellProps> = ({ size, children, overlay, theme }) => {
  const { w, h } = viewBoxSize(size);
  const style = buildThemeStyle(theme);
  const hasConcreteTheme = isConcreteTheme(theme);

  return (
    <div
      className={styles.shell}
      data-size={getSizeCat(size)}
      data-themed={hasConcreteTheme || undefined}
      style={style}
    >
      <svg
        viewBox={`0 0 ${w} ${h}`}
        width="100%"
        height="100%"
        preserveAspectRatio="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        {children}
      </svg>
      {overlay}
    </div>
  );
};

// ── SvgCardShellLink (interactive/clickable variant) ──

export type SvgCardShellLinkProps = SvgCardShellProps & {
  href: string;
  onClick?: React.MouseEventHandler<HTMLAnchorElement>;
};

export const SvgCardShellLink: FC<SvgCardShellLinkProps> = ({
  size,
  children,
  overlay,
  theme,
  href,
  onClick,
}) => {
  const { w, h } = viewBoxSize(size);
  const style = buildThemeStyle(theme);
  const hasConcreteTheme = isConcreteTheme(theme);

  return (
    <a
      className={styles.shell}
      data-interactive
      data-size={getSizeCat(size)}
      data-themed={hasConcreteTheme || undefined}
      style={style}
      href={href}
      onClick={onClick}
    >
      <svg
        viewBox={`0 0 ${w} ${h}`}
        width="100%"
        height="100%"
        preserveAspectRatio="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        {children}
      </svg>
      {overlay}
    </a>
  );
};
