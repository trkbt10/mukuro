/**
 * Typography presets — ported from zakoducthunt bento-grid.
 * Compositions reference semantic roles, not raw numbers.
 */

export type TypePreset = {
  fontSize: number;
  fontWeight: number;
  letterSpacing?: number;
  lineHeight?: number;
  fontStyle?: 'normal' | 'italic';
  fontFamily?: string;
};

export const TYPE = {
  // ── Display ──
  display: { fontSize: 48, fontWeight: 800, letterSpacing: -0.04, lineHeight: 1.1 },
  displayLg: { fontSize: 64, fontWeight: 800, letterSpacing: -0.05, lineHeight: 1.05 },

  // ── Headings ──
  h1: { fontSize: 36, fontWeight: 800, letterSpacing: -0.03, lineHeight: 1.2 },
  h2: { fontSize: 24, fontWeight: 700, letterSpacing: -0.02, lineHeight: 1.2 },
  h3: { fontSize: 20, fontWeight: 700, letterSpacing: -0.02, lineHeight: 1.35 },
  h4: { fontSize: 17, fontWeight: 600, letterSpacing: -0.01, lineHeight: 1.35 },

  // ── Body ──
  body: { fontSize: 15, fontWeight: 500, lineHeight: 1.5 },
  bodySmall: { fontSize: 13, fontWeight: 500, lineHeight: 1.5 },

  // ── Caption & Labels ──
  caption: { fontSize: 12, fontWeight: 500, lineHeight: 1.4 },
  label: { fontSize: 13, fontWeight: 600, letterSpacing: 0.02, lineHeight: 1.4 },
  labelUpper: { fontSize: 11, fontWeight: 700, letterSpacing: 0.08, lineHeight: 1.4 },
} as const satisfies Record<string, TypePreset>;
