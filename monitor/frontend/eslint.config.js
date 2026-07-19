import js from '@eslint/js'
import globals from 'globals'
import tseslint from 'typescript-eslint'
import svelte from 'eslint-plugin-svelte'
import svelteConfig from './svelte.config.js'

export default tseslint.config(
  { ignores: ['dist'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs.recommended,
  {
    languageOptions: { globals: globals.browser },
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
