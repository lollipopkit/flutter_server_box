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
)
