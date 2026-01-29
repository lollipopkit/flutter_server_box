---
title: Localizations
description: Language and region settings
---

Flutter Server Box supports 12+ languages with full localization.

## Supported Languages

| Language | Status |
|----------|--------|
| English (en) | ✅ Native |
| 简体中文 (zh) | ✅ Native |
| 繁體中文 (zh-Hant) | ✅ Native |
| Deutsch (de) | ✅ Native |
| Français (fr) | ✅ Native |
| Español (es) | ✅ Native |
| Português (pt) | ✅ Native |
| Русский (ru) | ✅ Native |
| Türkçe (tr) | ✅ Native |
| Українська (uk) | ✅ Native |
| Bahasa Indonesia (id) | ✅ Native |
| Nederlands (nl) | ✅ Native |
| 日本語 (ja) | ✅ AI-translated |

## Changing Language

1. Go to **Settings > Language**
2. Select preferred language
3. App restarts to apply changes

## Number Formatting

Numbers are formatted according to locale:

- **Thousands separator**: Comma vs period
- **Decimal separator**: Period vs comma
- **Date format**: Locale-specific

## Time Format

Choose between:

- **24-hour**: 13:00, 14:30
- **12-hour**: 1:00 PM, 2:30 PM

Set in: **Settings > Time Format**

## Contributing Translations

We welcome community translations!

### Translation Files

Located in `lib/l10n/`:

- `app_en.arb` - English (reference)
- `app_zh.arb` - Simplified Chinese
- etc.

### How to Contribute

1. Fork the repository
2. Copy `app_en.arb` to `app_YOUR_LOCALE.arb`
3. Translate values (keep keys the same)
4. Test your translations
5. Submit pull request

### Translation Guidelines

- Keep technical terms consistent
- Use formal address for professional tone
- Maintain placeholder format: `{variable}`
- Test UI with translated strings

## Adding New Language

1. Create new ARB file: `app_xx.arb`
2. Copy all keys from `app_en.arb`
3. Translate all values
4. Add to `l10n.yaml` configuration
5. Run `flutter gen-l10n`
6. Test with new locale

## RTL Languages

Right-to-left languages (Arabic, Hebrew) are partially supported. Full RTL layout support is planned for future releases.

## Quality Notes

- Some languages are AI-translated and may contain errors
- Native speaker reviews are appreciated
- Report translation issues via GitHub
