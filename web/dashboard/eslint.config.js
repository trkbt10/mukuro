import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';
import noClassNameComposition from './eslint-rules/no-classname-composition.js';

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['src/**/*.{ts,tsx}'],
    plugins: {
      'react-hooks': reactHooks,
      'mukuro': {
        rules: {
          'no-classname-composition': noClassNameComposition,
        },
      },
    },
    rules: {
      // React hooks
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',

      // TypeScript
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'off', // Too strict for now

      // Custom: forbid className composition (concatenation, template literals)
      // Use CSS `composes` in .module.css instead
      'mukuro/no-classname-composition': 'error',
    },
  },
  {
    // Relaxed rules for test files
    files: ['src/**/*.spec.{ts,tsx}', 'src/**/*.test.{ts,tsx}'],
    rules: {
      '@typescript-eslint/no-unused-vars': 'off',
    },
  },
  {
    ignores: ['dist/', 'node_modules/', '*.config.js', 'eslint-rules/'],
  }
);
