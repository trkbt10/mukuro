/**
 * Card spacing audit — validates that content elements fit within their zones.
 *
 * Usage: import { runFullAudit } from './card-audit' and call in dev mode.
 * Logs warnings when elements overflow their content area.
 */

import { TYPE } from '../card-parts/typography';
import { ICON } from './fractal';
import type { Rect, BentoSize } from './fractal';
import { contentArea, contentZones, splitH, splitV } from './fractal';

type ElementPlacement = {
  name: string;
  x: number;
  y: number;
  /** Estimated rendered width */
  w: number;
  /** Estimated rendered height (fontSize * lineHeight) */
  h: number;
};

type AuditResult = {
  card: string;
  size: BentoSize;
  contentRect: Rect;
  elements: ElementPlacement[];
  warnings: string[];
};

function textHeight(preset: keyof typeof TYPE): number {
  const p = TYPE[preset];
  return p.fontSize * (p.lineHeight ?? 1.2);
}

function checkBounds(el: ElementPlacement, bounds: Rect): string | null {
  const bottom = el.y + el.h;
  const right = el.x + el.w;
  const issues: string[] = [];

  if (el.x < bounds.x) issues.push(`left overflow by ${(bounds.x - el.x).toFixed(1)}px`);
  if (el.y < bounds.y) issues.push(`top overflow by ${(bounds.y - el.y).toFixed(1)}px`);
  if (right > bounds.x + bounds.w) issues.push(`right overflow by ${(right - bounds.x - bounds.w).toFixed(1)}px`);
  if (bottom > bounds.y + bounds.h) issues.push(`bottom overflow by ${(bottom - bounds.y - bounds.h).toFixed(1)}px`);

  if (issues.length === 0) return null;
  return `[${el.name}] ${issues.join(', ')}`;
}

function checkMargin(el: ElementPlacement, bounds: Rect, minMargin: number): string | null {
  const bottom = el.y + el.h;
  const bottomMargin = (bounds.y + bounds.h) - bottom;
  if (bottomMargin >= 0 && bottomMargin < minMargin) {
    return `[${el.name}] tight bottom margin: ${bottomMargin.toFixed(1)}px (min ${minMargin}px)`;
  }
  return null;
}

/** Audit the StatCard layout for a given size */
export function auditStatCard(size: BentoSize): AuditResult {
  const cr = contentArea(size);
  const { top, bottom } = contentZones(size);
  const warnings: string[] = [];

  const iconSize = ICON.md;
  const iconEl: ElementPlacement = {
    name: 'icon',
    x: top.x + (top.w - iconSize) / 2,
    y: top.y + (top.h - iconSize) / 2,
    w: iconSize,
    h: iconSize,
  };

  const labelH = textHeight('labelUpper');
  const labelEl: ElementPlacement = {
    name: 'label',
    x: bottom.x,
    y: bottom.y,
    w: 80,
    h: labelH,
  };

  // Adaptive display: fontSize clamps to available height
  const displayMaxH = bottom.h - labelH - 4;
  const displayFontSize = Math.min(48, displayMaxH / 1.1);
  const displayRenderH = displayFontSize * 1.1;
  const gap = Math.max((bottom.h - labelH - displayRenderH) / 2, 2);
  const displayY = bottom.y + labelH + gap;
  const displayEl: ElementPlacement = {
    name: 'display',
    x: bottom.x,
    y: displayY,
    w: 100,
    h: displayRenderH,
  };

  const elements = [iconEl, labelEl, displayEl];

  for (const el of elements) {
    const overflow = checkBounds(el, cr);
    if (overflow) warnings.push(overflow);
    const margin = checkMargin(el, cr, 2);
    if (margin) warnings.push(margin);
  }

  const displayOverflow = checkBounds(displayEl, bottom);
  if (displayOverflow) warnings.push(`(zone) ${displayOverflow}`);

  return { card: 'StatCard', size, contentRect: cr, elements, warnings };
}

/** Audit the SettingsCard layout */
export function auditSettingsCard(size: BentoSize, entryCount: number): AuditResult {
  const cr = contentArea(size);
  const warnings: string[] = [];
  const elements: ElementPlacement[] = [];

  const lH = textHeight('labelUpper');
  const bH = textHeight('body');
  const contentH = lH + bH;

  // Compact mode: no title row, entries only
  const compact = cr.h < (entryCount + 1) * (lH + bH + 4);

  if (compact) {
    const vSplit = splitV(cr, entryCount);
    for (let i = 0; i < entryCount; i++) {
      const zone = vSplit.cells[i]!;
      const topPad = Math.max((zone.h - contentH) / 2, 0);
      elements.push({ name: `entry[${i}].label`, x: zone.x, y: zone.y + topPad, w: 60, h: lH });
      elements.push({ name: `entry[${i}].value`, x: zone.x, y: zone.y + topPad + lH, w: 80, h: bH });
    }
  } else {
    const vSplit = splitV(cr, entryCount + 1);
    const titleZone = vSplit.cells[0]!;
    elements.push({ name: 'title', x: titleZone.x, y: titleZone.y, w: 60, h: textHeight('h4') });

    for (let i = 0; i < entryCount; i++) {
      const zone = vSplit.cells[i + 1]!;
      const gap = Math.max((zone.h - lH - bH) * 0.3, 2);
      elements.push({ name: `entry[${i}].label`, x: zone.x, y: zone.y, w: 60, h: lH });
      elements.push({ name: `entry[${i}].value`, x: zone.x, y: zone.y + lH + gap, w: 80, h: bH });
    }
  }

  for (const el of elements) {
    const overflow = checkBounds(el, cr);
    if (overflow) warnings.push(overflow);
  }

  return { card: `SettingsCard${compact ? ' (compact)' : ''}`, size, contentRect: cr, elements, warnings };
}

/** Audit the HealthCard layout */
export function auditHealthCard(size: BentoSize): AuditResult {
  const cr = contentArea(size);
  const warnings: string[] = [];
  const elements: ElementPlacement[] = [];

  const h4H = textHeight('h4');
  const bodyH = textHeight('body');
  const labelH = textHeight('label');
  const dotR = 4;

  // Compact: vertical stack (width < 160)
  const compact = cr.w < 160;

  if (compact) {
    const vSplit = splitV(cr, 3);
    const titleZone = vSplit.cells[0]!;
    elements.push({ name: 'title', x: titleZone.x, y: titleZone.y, w: 50, h: h4H });

    for (let i = 1; i <= 2; i++) {
      const zone = vSplit.cells[i]!;
      const cy = zone.y + zone.h / 2;
      elements.push({ name: `row${i}.dot`, x: zone.x, y: cy - dotR, w: dotR * 2 + 4, h: dotR * 2 });
      elements.push({ name: `row${i}.label`, x: zone.x + dotR * 3 + 4, y: cy - labelH / 2, w: 40, h: labelH });
      // Value uses textAnchor=end, positioned at zone right edge
      elements.push({ name: `row${i}.value`, x: zone.x + zone.w - 60, y: cy - labelH / 2, w: 60, h: bodyH });
    }
  } else {
    // Wide layout
    const hSplit = splitH(cr, 3);
    const left = hSplit.cells[0]!;
    const right: Rect = {
      x: hSplit.cells[1]!.x,
      y: cr.y,
      w: hSplit.cells[1]!.w + hSplit.gapX + hSplit.cells[2]!.w,
      h: cr.h,
    };
    const statusSplit = splitV(right, 2);

    const leftGap = Math.max((left.h - h4H - bodyH) * 0.15, 2);
    elements.push({ name: 'title', x: left.x, y: left.y, w: 50, h: h4H });
    elements.push({ name: 'subtitle', x: left.x, y: left.y + h4H + leftGap, w: 50, h: bodyH });

    for (let i = 0; i < 2; i++) {
      const row = statusSplit.cells[i]!;
      const cy = row.y + row.h / 2;
      const dotPad = dotR * 3;
      elements.push({ name: `row${i}.dot`, x: row.x, y: cy - dotR, w: dotR * 2 + 4, h: dotR * 2 });
      elements.push({ name: `row${i}.label`, x: row.x + dotPad + 4, y: cy - labelH / 2, w: 40, h: labelH });
      // Value uses textAnchor=end at row right edge
      elements.push({ name: `row${i}.value`, x: row.x + row.w - 60, y: cy - bodyH / 2, w: 60, h: bodyH });
    }
  }

  for (const el of elements) {
    const overflow = checkBounds(el, cr);
    if (overflow) warnings.push(overflow);
  }

  return { card: `HealthCard${compact ? ' (compact)' : ''}`, size, contentRect: cr, elements, warnings };
}

/** Run all audits for a given size, return warnings */
export function auditAllCards(size: BentoSize): AuditResult[] {
  return [
    auditStatCard(size),
    auditSettingsCard(size, 3),
    auditHealthCard(size),
  ];
}

/** Console-log all audit results for common sizes */
export function runFullAudit(): void {
  const sizes: BentoSize[] = ['1x1', '2x1', '1x2', '2x2'];
  for (const size of sizes) {
    const results = auditAllCards(size);
    for (const r of results) {
      if (r.warnings.length > 0) {
        console.warn(`[CardAudit] ${r.card} @ ${r.size}:`, r.warnings);
      } else {
        console.log(`[CardAudit] ${r.card} @ ${r.size}: OK`);
      }
    }
  }
}
