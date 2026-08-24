# Distribution marks

Five logos, shipped with the app and drawn beside a server's name when nothing
else says where a mark comes from. Every other distribution is fetched from an
address the user configures — `serverMarkUrl`, expanding `{DIST}` — and this
directory has nothing to do with it.

## Why five

Two questions have to be answered before a logo can be *shipped*, and only one
of them is easy.

**Trademark** is the easy one. Showing a distribution's mark next to a server
in order to say *this server runs that distribution* is nominative use — a mark
used to refer to the thing it identifies. It is a doctrine rather than a
permission any owner grants, and the usual test is three parts: the thing is
not readily identifiable without the mark, no more of the mark is used than
needed, and nothing suggests sponsorship or endorsement. A 20px mark in a row
that also carries the server's own name and address meets all three.

**Copyright in the artwork** is the hard one, and it is what this directory is
short because of. A logo is somebody's drawing. Redistributing it needs a
licence, and almost no project grants one — a trademark policy permitting
referential use says nothing about copying the file. Five do:

| Mark | Licence | Source |
| --- | --- | --- |
| debian | [LGPL-3+ or CC BY-SA 3.0](https://www.debian.org/logos/) | `openlogo-nd.svg` |
| gentoo | [CC BY-SA 2.5](https://www.gentoo.org/inside-gentoo/artwork/gentoo-logo.html) | `gentoo-signet.svg` |
| rocky | [CC BY-SA 4.0](https://github.com/rocky-linux/branding) | `logo/src/icon-primary.svg` |
| nixos | [CC BY 4.0](https://github.com/NixOS/nixos-artwork) | `logo/nix-snowflake-colours.svg` |
| alpine | [no copyright subsists](https://commons.wikimedia.org/wiki/File:Alpine_Linux.svg) | `alpinelinux-logo-icon.svg` |

Alpine is the odd one: its mark is simple geometry, which under 37 CFR 202.1
attracts no copyright at all ("familiar symbols or designs"), so there is
nothing to license. Wikimedia Commons files it as `PD-textlogo`. The trademark
is still the Alpine Linux Development Team's.

The four Creative Commons licences all require attribution. That is discharged
in the app itself — Settings → About → License, registered by
`lib/data/model/server/dist_license.dart` — because this file ships inside the
bundle but nothing renders it, and a notice nobody can reach is not one.

## What was checked and rejected

Not for want of asking. Each of these permits the *word* or referential use and
reserves the artwork:

- **Ubuntu** — the Circle of Friends is a Canonical trademark, supplied as
  artwork under brand guidelines rather than under any free licence.
  Canonical's [IP policy](https://canonical.com/legal/intellectual-property-policy)
  permits referring to Ubuntu; it does not permit redistributing the logo.
- **Fedora** — [the logo page](https://fedoraproject.org/wiki/Logo) says the
  logo "is a registered trademark used worldwide by Red Hat, Inc." with
  restrictions set out in the trademark guidelines, and permission requests go
  to logo@fedoraproject.org. It is also drawn in a proprietary font that Red
  Hat pays for, which is a second reason the file is not ours to pass on.
- **Arch** — "The Arch Linux name and logo are recognized trademarks. Some
  rights reserved." Retired logos remain under licence restrictions; the
  CC-BY-SA on [the policy](https://terms.archlinux.org/docs/trademark-policy/)
  covers the policy document, not the mark.
- **openSUSE** — the trap worth recording. `openSUSE/artwork` is CC BY-SA 3.0
  at its root, but `logos/official/LICENSE` says, of the logos specifically:
  "These logos are all rights reserved." A repository-level licence is not a
  file-level one, and this is the only place so far where the two disagree.
- **Red Hat**, **Raspberry Pi**, **Kali** — all three reserve logo use to
  written permission outright, and their marks are illustrations rather than
  shapes, so redrawing would not have answered the copyright either.

## Adding one

Find a statement from the project that licenses the *artwork*, not the
trademark, and permits redistribution. A CC licence, a GPL/LGPL, or a
below-the-threshold mark like Alpine's. If all you can find is a trademark
policy, however permissive, the answer is no — leave it to the address the
user configures.

Then: drop the file in named after its `Dist` case, add the case to `_bundled`
in `dist.dart`, add a row to the table above, and add its notice to
`dist_license.dart`. `test/dist_icon_test.dart` fails if any of those is
missing.

**Ship the file unmodified**, as far as it will go. Not tidied, not
recoloured, not stripped of its metadata — under CC BY-SA a modified file is an
adaptation and carries the share-alike obligation, and the metadata is where
some of these carry their own attribution. flutter_svg logs
`unhandled element <metadata/>` once per run for the trouble, which is the
right trade.

**Then check it draws**, because "unmodified" is not the same as "works".
`debian.svg` is a 2001 Adobe Illustrator export and did not: the parser strips
namespaces before reading attribute names, so `xmlns:x="http://ns.adobe.com/…"`
arrives as an attribute called `x` and its value goes to `double.parse`. It
threw on load and flutter_svg drew an empty box — no exception reaching the
app, nothing in the log, just a gap where the swirl should be. What fixed it is
recorded with the file below.

`test/dist_asset_render_test.dart` compiles each of these the way flutter_svg
does and fails if one yields no geometry or no paint. It is the only test here
that would have caught that, and four others passed straight through it: the
file existed, the enum named it, the README listed it and the widget built.

## Changes made to the files

- **debian.svg** — the DTD's entity declarations expanded in place and dropped,
  and Illustrator's `xmlns:x`/`xmlns:i`/`xmlns:graph`/`xmlns:a` declarations and
  the `i:`-namespaced attributes under them removed. Nothing else: the twelve
  `d=` path strings are byte-identical to what Debian publishes, and the two
  render the same. Debian offers the logo under LGPL-3+ *or* CC BY-SA 3.0, and
  either permits this so long as the change is stated — which is what this line
  is for, and why it is repeated in the in-app notice.
- The other four are byte-identical to their sources.
