/**
 * ESLint rule: mukuro/no-classname-composition
 *
 * Forbids className composition via JavaScript. className must always be a single
 * styles.* reference. Use data-* attributes for variants.
 *
 * This rule enforces:
 * 1. One component = One CSS module file (1:1 principle)
 * 2. No className composition in JavaScript - variant states via data-* attributes
 * 3. All styling logic lives in CSS, not in JSX
 *
 * Bad:
 *   className={styles.foo + ' ' + styles.bar}
 *   className={`${styles.foo} ${styles.bar}`}
 *   className={[styles.foo, styles.bar].join(' ')}
 *   className={clsx(styles.foo, styles.bar)}
 *   className={condition ? styles.active : styles.inactive}  // multiple styles.*
 *
 * Good:
 *   className={styles.button}                                 // single class
 *   className={styles.button} data-variant="primary"          // variant via data attr
 *   className={styles.step} data-state={isActive ? 'active' : 'default'}
 *   className={styles.item} data-selected={isSelected || undefined}
 *
 * CSS:
 *   .button { }
 *   .button[data-variant="primary"] { background: blue; }
 *   .step[data-state="active"] { color: green; }
 *   .item[data-selected] { background: var(--accent); }
 *
 * Pattern for boolean attributes:
 *   data-selected={isSelected || undefined}  // renders nothing when false
 *
 * Pattern for enum states:
 *   data-state={status}  // status: 'active' | 'inactive' | 'loading'
 *   .element[data-state="active"] { }
 *   .element[data-state="loading"] { }
 */

/** @type {import('eslint').Rule.RuleModule} */
export default {
  meta: {
    type: 'problem',
    docs: {
      description: 'Forbid className composition. Use single class + data-* attributes for variants.',
      category: 'Best Practices',
    },
    messages: {
      noMultipleStyles: 'className must be a single styles.* reference. Use data-* attributes for variants instead.',
    },
    schema: [],
  },

  create(context) {
    /**
     * Check if an expression accesses styles.* (CSS module)
     */
    function isStylesAccess(node) {
      return (
        node.type === 'MemberExpression' &&
        node.object.type === 'Identifier' &&
        node.object.name === 'styles'
      );
    }

    /**
     * Check if node is className prop assignment
     */
    function isClassNameProp(node) {
      return (
        node.type === 'JSXAttribute' &&
        node.name.type === 'JSXIdentifier' &&
        node.name.name === 'className'
      );
    }

    /**
     * Count styles.* accesses in an expression
     */
    function countStylesAccess(node) {
      let count = 0;
      function visit(n) {
        if (!n || typeof n !== 'object') return;
        if (isStylesAccess(n)) count++;
        for (const key in n) {
          if (key !== 'parent' && n[key] && typeof n[key] === 'object') {
            if (Array.isArray(n[key])) {
              n[key].forEach(visit);
            } else {
              visit(n[key]);
            }
          }
        }
      }
      visit(node);
      return count;
    }

    return {
      JSXAttribute(node) {
        if (!isClassNameProp(node)) return;
        if (!node.value || node.value.type !== 'JSXExpressionContainer') return;

        const expr = node.value.expression;

        // Allow single styles.* access
        if (isStylesAccess(expr)) {
          return;
        }

        // Forbid any expression with 2+ styles.* accesses
        if (countStylesAccess(expr) >= 2) {
          context.report({ node: expr, messageId: 'noMultipleStyles' });
        }
      },
    };
  },
};
