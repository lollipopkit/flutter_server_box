---
title: Using Themes
description: Choose, install, and manage themes
---

Server Box includes the Default and AMOLED themes and lets you install more,
such as One Dark Pro, from the theme store or
from a theme file. Some store themes, such as Piggy, come with the app: they
are installed on first launch and updated from the theme store like any theme
installed from it. A bundled theme you remove is not installed again. Theme settings are under **Settings → Appearance**.

## Choose a theme

Open **Theme preset** to choose a built-in theme, an installed theme, or
**Custom**. Moving through the list previews themes without saving the change.
Select a theme to apply it. Dismiss the picker to keep the theme you had before
opening it.

Some theme packages contain several variants, such as the Trans, Nonbinary and
Rainbow variants of Pride. Each variant is listed separately, as
`Pride · Trans`, and can be chosen like any other theme. The package is
installed and updated once for all of its variants.

**Custom** lets you choose a local background image and adjust app icons, corner
radii, opacity, and blur. These options are separate from the read-only values
in a packaged theme.

Themes declare which appearance modes they support. Themes that support both
Light and Dark can be used with System, Light, or Dark. If a theme supports only
one mode, the mode setting is locked while that theme is selected. Choose a
theme that supports both modes to switch freely.

AMOLED is a built-in theme. It uses black surfaces in Dark mode and standard
light colors in Light mode. Existing AMOLED settings are migrated to the
matching theme and mode.

## Install a theme

Open **Settings → Appearance → Install theme**. Choose one of these sources:

- **File** to select a `.fsbt` theme package.
- **URL** to install a theme package from an HTTPS link.
- **Folder** on desktop to import a theme directory, useful while developing a
  theme.

After installation, the theme is applied and appears in **Theme preset**.
Installing a theme that is already installed, such as a newer version or a
theme folder imported again after editing, replaces the earlier installation;
if that theme was in use, the new one stays selected. Other installed themes
are not affected.

## Browse the theme store

Open **Settings → Appearance → Theme store** to browse themes from the theme
catalog. A catalog theme that is already installed is shown in the same row.
Select an uninstalled theme to download and apply it. Select an installed theme
to apply it. Use the button beside a theme to install or remove it, depending
on its current state. Removing the theme in use returns the app to its default
theme.

Use the expand button on a row to preview the theme before installing it. The
preview uses the theme's colors, component styles, background and icons;
segmented controls above it switch between Light and Dark and between the
package's variants. A
theme that is not installed is downloaded for the preview and checked like an
install; nothing is installed or applied. Previews are closed by default, and
downloaded preview files are deleted when the store is closed.

For an installed package with variants, the row shows a segmented control
with one segment per variant; select a segment to apply that variant.

The store remembers its latest results between launches, so previously loaded
themes remain visible while offline. The caption below the app bar shows when
the list was last updated; each catalog theme's row shows its repository and
version. Use the refresh button in the app bar or pull down on the list to check
for updates. Descriptions are shown in the app's language when the theme
provides one. Search matches theme names, variant names, descriptions in any
language, and repository names;
the sort control can put the active theme first or sort by name.

When the store offers a different version of an installed theme, its row shows
an update button. Updating replaces the installed version; if the theme is in
use, it stays in use.

Some themes may require a newer app version. They remain visible in the store,
with an explanation when they cannot be installed.

## Create a theme

Theme packages are authored as a directory with a `manifest.toml` and optional
images, then shared as a `.fsbt` file or published in a theme repository. See
the [theme authoring guide](/docs/development/theme-authoring/) for the package
format and publishing instructions.
