# ServerBox Documentation

The documentation site uses [Astro Starlight](https://starlight.astro.build)
and is published at <https://serverbox.lolli.tech/docs/>. It is served under
`/docs` of the project website; `scripts/build-cloudflare-pages.sh` builds both
sites and copies this site's output into `website/dist/docs/`.

## Structure

```
docs/
├── public/                 # Static assets (favicons, ...)
├── src/content/docs/       # Pages — English at the top level
│   ├── advanced/
│   ├── development/
│   ├── platforms/
│   ├── principles/
│   ├── zh/                 # Simplified Chinese, mirroring the layout above
│   └── *.mdx               # introduction, installation, quick-start, index
└── astro.config.mjs        # Locales and sidebar, including sidebar translations
```

Each `.md` / `.mdx` file under `src/content/docs/` becomes a route named after
its path. A page added in English needs a matching file under `zh/`, and a new
sidebar entry in `astro.config.mjs` carries its own `translations` map.

**Locales are English and Simplified Chinese only.** German, Spanish, French and
Japanese were dropped in Aug 2026 — they had drifted out of sync with the code
and there was no one maintaining them.

## Commands

Run from `docs/`:

| Command | Action |
| :------ | :----- |
| `npm ci` | Install the locked dependencies |
| `npm run dev` | Dev server at `localhost:4321/docs` |
| `npm run check-locale-parity` | Check that English and Simplified Chinese pages mirror each other |
| `npm run build` | Build to `./dist/` |
| `npm run preview` | Preview the build locally |

## Writing

Documentation follows the code. When a page describes changed behaviour,
update it in the same change and keep the English and Simplified Chinese pages
in sync.
