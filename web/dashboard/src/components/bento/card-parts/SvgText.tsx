import type { FC } from 'react';
import type { TypePreset } from './typography';

/** CSS custom property references resolved by the card shell. */
const TEXT = 'var(--tone-text)';
const TEXT_SECONDARY = 'var(--tone-text-secondary)';

// ── Core SvgText ──

export type SvgTextProps = {
  preset: TypePreset;
  text: string;
  x: number;
  y: number;
  maxWidth?: number;
  maxLines?: number;
  fill?: string;
  textAnchor?: 'start' | 'middle' | 'end';
};

/**
 * Render a single-line SVG text element with a TypePreset.
 *
 * Uses `dominant-baseline: text-before-edge` so y is the top of the text box
 * (matching the reference's text layout convention).
 */
export const SvgText: FC<SvgTextProps> = ({
  preset,
  text,
  x,
  y,
  maxWidth,
  fill = TEXT,
  textAnchor = 'start',
}) => (
  <text
    x={x}
    y={y}
    fill={fill}
    fontSize={preset.fontSize}
    fontWeight={preset.fontWeight}
    letterSpacing={preset.letterSpacing ? `${preset.letterSpacing}em` : undefined}
    fontStyle={preset.fontStyle}
    fontFamily={preset.fontFamily}
    textAnchor={textAnchor}
    dominantBaseline="text-before-edge"
    style={maxWidth ? { maxWidth } : undefined}
  >
    {text}
  </text>
);

// ── Semantic wrappers ──

type SemanticTextProps = {
  children: string;
  x: number;
  y: number;
  maxWidth?: number;
  fill?: string;
  textAnchor?: 'start' | 'middle' | 'end';
};

export const SvgDisplay: FC<SemanticTextProps> = ({ children, fill = TEXT, ...rest }) => (
  <SvgText preset={{ fontSize: 48, fontWeight: 800, letterSpacing: -0.04, lineHeight: 1.1 }} text={children} fill={fill} {...rest} />
);

export const SvgH2: FC<SemanticTextProps> = ({ children, fill = TEXT, ...rest }) => (
  <SvgText preset={{ fontSize: 24, fontWeight: 700, letterSpacing: -0.02, lineHeight: 1.2 }} text={children} fill={fill} {...rest} />
);

export const SvgH3: FC<SemanticTextProps> = ({ children, fill = TEXT, ...rest }) => (
  <SvgText preset={{ fontSize: 20, fontWeight: 700, letterSpacing: -0.02, lineHeight: 1.35 }} text={children} fill={fill} {...rest} />
);

export const SvgH4: FC<SemanticTextProps> = ({ children, fill = TEXT, ...rest }) => (
  <SvgText preset={{ fontSize: 17, fontWeight: 600, letterSpacing: -0.01, lineHeight: 1.35 }} text={children} fill={fill} {...rest} />
);

export const SvgBody: FC<SemanticTextProps> = ({ children, fill = TEXT_SECONDARY, ...rest }) => (
  <SvgText preset={{ fontSize: 15, fontWeight: 500, lineHeight: 1.5 }} text={children} fill={fill} {...rest} />
);

export const SvgCaption: FC<SemanticTextProps> = ({ children, fill = TEXT_SECONDARY, ...rest }) => (
  <SvgText preset={{ fontSize: 12, fontWeight: 500, lineHeight: 1.4 }} text={children} fill={fill} {...rest} />
);

export const SvgLabel: FC<SemanticTextProps> = ({ children, fill = TEXT, ...rest }) => (
  <SvgText preset={{ fontSize: 13, fontWeight: 600, letterSpacing: 0.02, lineHeight: 1.4 }} text={children} fill={fill} {...rest} />
);

export const SvgLabelUpper: FC<SemanticTextProps> = ({ children, fill = TEXT_SECONDARY, ...rest }) => (
  <SvgText preset={{ fontSize: 11, fontWeight: 700, letterSpacing: 0.08, lineHeight: 1.4 }} text={children.toUpperCase()} fill={fill} {...rest} />
);
