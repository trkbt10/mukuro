import js from "@eslint/js";
import tseslint from "typescript-eslint";
import globals from "globals";

/**
 * Custom plugin: no-cross-boundary-reexport
 *
 * Forbids re-exporting from parent directories (e.g. export { X } from '../foo').
 * This prevents modules from reaching outside their own boundary to re-export.
 */
const noCrossBoundaryReexport = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Disallow re-exporting from parent directories (cross-boundary exports)",
    },
    messages: {
      forbidden:
        "Cross-boundary re-export is not allowed. Do not re-export from parent directories ('{{source}}').",
    },
    schema: [],
  },
  create(context) {
    function check(node) {
      if (node.source && /^\.\.\//.test(node.source.value)) {
        context.report({
          node,
          messageId: "forbidden",
          data: { source: node.source.value },
        });
      }
    }
    return {
      ExportAllDeclaration: check,
      ExportNamedDeclaration: check,
    };
  },
};

const customPlugin = {
  rules: {
    "no-cross-boundary-reexport": noCrossBoundaryReexport,
  },
};

export default tseslint.config(
  // Ignored paths
  {
    ignores: ["**/dist/**", "**/node_modules/**", "**/bin/**"],
  },

  // Base recommended rules
  js.configs.recommended,
  ...tseslint.configs.recommended,

  // TypeScript files (client)
  {
    files: ["client/src/**/*.ts"],
    languageOptions: {
      globals: globals.node,
    },
  },

  // TypeScript + React files (dashboard)
  {
    files: ["dashboard/src/**/*.{ts,tsx}"],
    languageOptions: {
      globals: globals.browser,
    },
  },

  // Custom export rules for all TS/TSX files
  {
    files: ["**/*.{ts,tsx}"],
    plugins: {
      custom: customPlugin,
    },
    rules: {
      // Forbid: export * from '...'
      "no-restricted-syntax": [
        "error",
        {
          selector: "ExportAllDeclaration",
          message:
            "Wildcard exports (export * from) are not allowed. Use named exports instead.",
        },
      ],

      // Forbid: export { ... } from '../...' (cross-boundary re-export)
      "custom/no-cross-boundary-reexport": "error",
    },
  },
);
