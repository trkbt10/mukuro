import type { FC } from 'react';
import { place, type Alignment, type Rect, ICON } from '../grid/fractal';

/** CSS custom property references resolved by the shell. */
const SURFACE = 'var(--tone-surface)';
const TEXT_SECONDARY = 'var(--tone-text-secondary)';

export type IconSize = 'sm' | 'md' | 'lg';

export type SvgIconProps = {
  /** Area to place the icon within. */
  cell: Rect;
  /** Size preset: sm (36), md (48), lg (72). */
  size: IconSize;
  /** Image URL for the icon. Falls back to `fallbackChar` if null. */
  url?: string | null;
  /** Single character rendered when no image URL is provided. */
  fallbackChar: string;
  /** Alignment within the cell. Defaults to center/center. */
  align?: Alignment;
  /** Corner curvature ratio. Default 0.22 (22% of size). */
  curvature?: number;
  /** Unique clip-path ID. Must be unique within the SVG document. */
  clipId: string;
  /** Optional fill for the icon background. */
  bgFill?: string;
  /** Optional fill for the fallback text. */
  textFill?: string;
};

export const SvgIcon: FC<SvgIconProps> = ({
  cell,
  size: sizePreset,
  url,
  fallbackChar,
  align,
  curvature = 0.22,
  clipId,
  bgFill = SURFACE,
  textFill = TEXT_SECONDARY,
}) => {
  const s = ICON[sizePreset];
  const p = place({ zone: cell, width: s, height: s, align });
  const rx = s * curvature;

  return (
    <>
      <defs>
        <clipPath id={clipId}>
          <rect x={p.x} y={p.y} width={s} height={s} rx={rx} ry={rx} />
        </clipPath>
      </defs>

      {url ? (
        <image
          href={url}
          x={p.x}
          y={p.y}
          width={s}
          height={s}
          clipPath={`url(#${clipId})`}
          preserveAspectRatio="xMidYMid slice"
        />
      ) : (
        <>
          <rect x={p.x} y={p.y} width={s} height={s} rx={rx} ry={rx} fill={bgFill} />
          <text
            x={p.x + s / 2}
            y={p.y + s / 2}
            textAnchor="middle"
            dominantBaseline="central"
            fontSize={s * 0.4}
            fontWeight={800}
            fill={textFill}
          >
            {fallbackChar}
          </text>
        </>
      )}
    </>
  );
};
