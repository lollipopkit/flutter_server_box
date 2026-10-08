import js from '@eslint/js'
import globals from 'globals'
import tseslint from 'typescript-eslint'
import svelte from 'eslint-plugin-svelte'
import svelteConfig from './svelte.config.js'

export default tseslint.config(
  // typesafe-i18n fully regenerates these on every `typesafe-i18n` run and
  // stamps them with its own `/* eslint-disable */`; don't lint generated output.
  { ignores: ['dist', 'src/i18n/i18n-types.ts', 'src/i18n/i18n-util.ts', 'src/i18n/i18n-util.async.ts', 'src/i18n/i18n-util.sync.ts', 'src/i18n/i18n-svelte.ts'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs.recommended,
  {
    languageOptions: { globals: globals.browser },
    rules: {
      // Allow underscore-prefixed unused args/vars (e.g. typesafe-i18n's
      // generated formatters.ts signature `(_locale: Locales) => ...`)
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
    },
  },
  {
    files: ['**/*.svelte', '**/*.svelte.ts'],
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
        extraFileExtensions: ['.svelte'],
        svelteConfig,
      },
    },
  },
  {
    // An app reaches the desk through `sys` only (docs/dev/desk-sys.md):
    // never the shell's internals, never another app's directory.
    files: ['src/desk/apps/*/**/*.{ts,svelte}'],
    ignores: ['src/desk/apps/settings/**'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              regex: '^\\.\\./\\.\\./(?!sys(/|$))[^.]',
              message: 'An app uses the desk through `sys` (and `@lollipopkit/desk-ui` for its UI) only.',
            },
            {
              regex: '^\\.\\./[a-z_]+/',
              message: 'Apps are independent: share code through src/lib or src/components.',
            },
          ],
        },
      ],
    },
  },
  {
    // Settings is the system's own app: it alone edits the desk's preferences
    // and hosts other apps' settings pages.
    files: ['src/desk/apps/settings/**/*.{ts,svelte}'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              regex: '^\\.\\./\\.\\./(?!(sys|deskState\\.svelte|prefs\\.svelte|themes\\.svelte|shellPrefs\\.svelte|shell/Wallpaper\\.svelte|window/AppSettingsHost\\.svelte)(/|$))[^.]',
              message: 'Settings uses `sys`, `@lollipopkit/desk-ui` and the desk preferences only.',
            },
            { regex: '^\\.\\./[a-z_]+/', message: 'Apps are independent.' },
          ],
        },
      ],
    },
  },
)
