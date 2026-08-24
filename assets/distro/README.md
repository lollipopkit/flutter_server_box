# Distribution icons

Single-colour glyphs marking which distribution a server runs. Drawn into the
list rows and the pickers, beside the server's name; the *colour* logo on the
detail page is a separate thing, fetched from a URL the user configures, and
this repository ships none of those.

## Where these came from

All of them are taken from [font-logos](https://github.com/lukas-w/font-logos)
(`vectors/`), renamed to match `Dist`'s enum names and put through the
normalisation below — the drawing is untouched. font-logos is released into
the public domain under the [Unlicense](https://github.com/lukas-w/font-logos/blob/master/LICENSE):

> Anyone is free to copy, modify, publish, use, compile, sell, or distribute
> this software, either in source code form or as a compiled binary, for any
> purpose, commercial or non-commercial, and by any means.

That is what makes it legal to *ship the files* — as far as it goes. A licence
grants only what the licensor holds, and font-logos redrew marks it does not
own, so the Unlicense answers the copyright in **its** drawing and not in
whatever was drawn. Which is fine for a triangle or a letterform, where no
copyright subsists at all, and is not fine for an illustration. See
"Which marks are shipped" below; it is why three glyphs that used to be here
are not any more.

Three of the shipped files carry a licence condition of their own — `tux.svg`,
`nixos.svg` and `debian.svg`. They are honoured under "The three attribution
conditions" below.

## Naming and the enum

Each file is named after its `Dist` case, which is also what `{DIST}` expands
to in a custom logo URL — so `Dist.arch` is `arch.svg` and `{DIST}` is `arch`,
whatever font-logos happened to call it (`archlinux`). `tux.svg` is the generic
mark, drawn for a server that has not been asked yet.

**`Dist` names far more distributions than this directory has glyphs, and that
is deliberate.** The enum identifies everything it can — which is what `{DIST}`
and the status page need — while a glyph is shipped only where somebody will be
looking at it. A case is therefore never *removed* when its mark goes: removing
one would break `{DIST}` in a URL somebody already saved. It is added to
`_withoutGlyph` instead, which is reversible and costs nothing.

To add a glyph: find it in font-logos' `vectors/`, copy it in under the `Dist`
name, run `dart run scripts/normalize_distro_svg.dart`, and check it against
"Which marks are shipped" below before committing. To add a distribution
without one, just add the case and an `ID=` entry or a matcher.
`test/dist_icon_test.dart` fails if the two sides disagree.

## The normalisation, and why the files are not byte-identical

`scripts/normalize_distro_svg.dart` strips two elements from every file:
`<metadata>` and `<defs>`. flutter_svg draws neither and says so once per app
run — `unhandled element <metadata/>; Picture key: Svg loader` — which is how
this was noticed at all.

Removing `<defs>` is safe here because nothing referenced what was in it: these
are single-colour glyphs and the app tints them flat, so the gradients,
patterns and `inkscape:perspective` nodes in there were already unreachable.
The script refuses to remove a `<defs>` that *is* referenced, and refuses one
whose `<style>` has a rule some element still carries, so a future glyph with
real CSS is reported rather than silently flattened. `puppy.svg` was that case
once — a stylesheet whose only live rule was `.fil9 {fill:black}`, resolved into
a `fill` attribute by hand before the block was dropped. That file is no longer
shipped, for an unrelated reason, but the guard it prompted is why the next one
will not be flattened quietly.

`<metadata>` is worth a note of its own, because deleting a licence block
normally is not something to do lightly. **In this set it does not describe the
file it is in.** It is Inkscape RDF inherited from whatever document each glyph
was traced in — measured over the fifty-eight files that were here when this
was found: `elementary.svg` carried *Gentoo's* ("Gentoo Logo Dark v1.0",
Sebastian Pipping, Gentoo Foundation Inc.), `voidlinux.svg` carried *AOSC's*
("Logo of Anthon OS4 Project"), and `artix.svg` claimed CC BY-NC-SA 4.0 —
non-commercial, on a file whose actual licence is the Unlicense above. None of
it is a grant this repository relies on, and shipping a file that misattributes
itself is worse than shipping one carrying no metadata at all.

Provenance is still checkable, just not with a plain `diff`: run the
normalisation over font-logos' own copy and compare that. Each of the files
checked this way was byte-identical to upstream before the step. It was run
over the whole set once, matching by content rather than by name, which is also
how the thirteen renames (`arch` ← `archlinux`, `wrt` ← `openwrt`, `rhel` ←
`redhat`, ...) were confirmed to be renames and nothing more.

Two fallbacks. `tux.svg` is drawn for a Linux whose flavour is not known;
`server.svg` — drawn by hand for this app, so it carries nobody's mark — is
drawn for a machine that has not been asked yet, and for the cases below.

## Which marks are shipped

Twelve distributions have a glyph. Every other `Dist` case is recognised by
name and draws `tux.svg` or `server.svg`. The reasons divide four ways.

**Shipped** — the ones a person scanning a list of servers meets often enough
to learn the shape of:

> alpine · arch · centos · debian · deepin · fedora · mint · nixos · popos ·
> rocky · ubuntu · wrt

**Not shipped**, for four reasons:

- **Most of the enum**, and for a reason that is not legal at all: a mark is
  only worth carrying if it will be recognised, and a column of shapes nobody
  can tell apart is no better than a column of penguins. AlmaLinux, Gentoo,
  openSUSE, Slackware, Void and Devuan are perfectly good server
  distributions and are in this group anyway — the line drawn here is
  recognisability, not merit, and it is a judgement call that can be moved.
  Everything in it is still *identified*, by `ID=` and by name, so `{DIST}`
  still expands and the status card still names it. Only the picture is gone.
- **armbian**, **coreelec** — font-logos simply has no glyph. Do not fill them
  in from the projects' own sites: that would be copying their artwork, which
  is the one thing this arrangement avoids.
- **rhel**, **raspbian**, **kali** — withdrawn, and the reason is worth having
  written down because it is the one place this directory's premise does not
  hold. Each is an original illustration rather than a shape — Red Hat's
  Shadowman, the Raspberry Pi raspberry, Kali's dragon — so "it is a redrawn
  glyph" does not answer the copyright the way it does for a triangle or a
  letterform. And each owner has published rules that allow the *word*
  referentially and reserve the *logo*:
  [Red Hat](https://www.redhat.com/en/about/trademark-guidelines-and-policies)
  ("These Guidelines do not give you any permission to use a Red Hat Logo"),
  [Raspberry Pi](https://www.raspberrypi.com/trademark-rules/) (logo use is
  for "the sale or distribution of genuine Raspberry Pi products"), and
  [OffSec](https://www.kali.org/docs/policy/trademark/) (no fair-use
  carve-out offered). Nominative use does not depend on a permission being
  offered — but of everything that was on this list, these three have the
  owners most likely to act on it.
- **macos**, **windows** — a decision, not a gap. Apple's
  [guidelines](https://www.apple.com/legal/intellectual-property/guidelinesfor3rdparties.html)
  say the Apple Logo may not be used "on or in connection with web sites,
  products, packaging, manuals, promotional/advertising materials, or for any
  other purpose except pursuant to an express written trademark license from
  Apple". Microsoft's
  [Windows trademark guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks)
  require a licence for any Windows logo, which is not generally available to
  app developers. Both permit the *word* referentially and neither permits the
  mark, which is the opposite of how the Linux projects are written. A glyph
  set having an `apple.svg` does not change that: the Unlicense answers the
  copyright in the redrawn file, not Apple's trademark.
- **freebsd**, **openbsd**, **netbsd** — the marks a glyph set carries for
  these are the BSD Daemon and Puffy, which are copyrighted *characters*
  rather than geometric logos. The [FreeBSD Trademark Usage FAQ](https://freebsdfoundation.org/legal/trademark-usage-terms-and-conditions/freebsd-trademark-usage-faq/)
  says rights to the Daemon "must be sought from trademark owner Kirk
  McKusick". Redrawing a character is closer to a derivative work than
  redrawing a logo, so these get the neutral outline. The FreeBSD Foundation's
  own policy would allow nominative use of its *logo*; that is a separate
  question from the Daemon, and this sidesteps both.

## Why using them is allowed

Copyright and trademark are separate questions, and the Unlicense only answers
the first. font-logos says as much itself:

> All brand icons are trademarks of their respective owners and should only be
> used to represent the company or product to which they refer.

Which is exactly this use. Showing a distribution's mark next to a server in
order to say *this server runs that distribution* is **nominative use** — using
a mark to refer to the thing it identifies. It is a doctrine of trademark law
rather than a permission any owner grants, and the usual test is three parts:
the thing is not readily identifiable without the mark, no more of the mark is
used than needed, and nothing suggests sponsorship or endorsement. A 20px glyph
in a row that also carries the server's own name and address meets all three.

All twelve were re-checked one at a time after the set was cut down, and every
one of them has a source below. Where a project publishes nothing, the link is
to whatever *is* authoritative about its mark rather than to nothing at all.

| Glyph | Trademark | Copyright in the artwork |
| --- | --- | --- |
| alpine | [none published](https://alpinelinux.org/community/) | [PD-textlogo](https://commons.wikimedia.org/wiki/File:Alpine_Linux.svg) |
| arch | [policy](https://terms.archlinux.org/docs/trademark-policy/) | no statement published |
| centos | [guidelines](https://www.centos.org/legal/trademarks/) (Red Hat's marks) | no statement published |
| debian | [policy](https://www.debian.org/trademark) | [LGPL-3+ / CC-BY-SA-3.0](https://www.debian.org/logos/) |
| deepin | [EULA §2](https://www.deepin.org/en/agreement/end-user-license-agreement/) | no statement published |
| fedora | [guidelines](https://fedoraproject.org/wiki/Legal:Trademark_guidelines) | no statement published |
| mint | [FAQ, Licensing](https://linuxmint.com/faq.php) | no statement published |
| nixos | none published | [CC BY 4.0](https://github.com/NixOS/branding) |
| popos | [COSMIC policy](https://github.com/pop-os/cosmic-epoch/blob/master/TRADEMARK.md), [brand assets](https://github.com/system76/brand) | no statement published |
| rocky | [policy](https://rockylinux.org/legal/trademarks) | no statement published |
| ubuntu | [IP policy](https://canonical.com/legal/intellectual-property-policy) | no statement published |
| wrt | [policy](https://openwrt.org/trademark) | no statement published |
| *tux* | n/a — not a distribution | [Ewing, attribution required](https://commons.wikimedia.org/wiki/File:Tux.svg) |

What each of them actually says, where the wording matters:

- **Debian** — the [Open Use Logo](https://www.debian.org/logos/) is dual
  licensed LGPL-3+ *or* CC-BY-SA-3.0, and Debian says "to refer to Debian,
  please prefer the open use logo". Attribution below.
- **NixOS** — the [branding repository](https://github.com/NixOS/branding)
  puts the logo under **CC BY 4.0**: shareable and adaptable "for any purpose,
  including commercial use", provided credit, a licence link and a note of
  changes. Attribution below. No separate trademark policy found.
- **Linux Mint** — the [FAQ](https://linuxmint.com/faq.php) is explicit and
  permissive: "You can use, promote and show Linux Mint, screenshots of Linux
  Mint and the Linux Mint logo in articles, magazines, websites, books,
  designs, movies, or any document as long as you don't pretend to be Linux
  Mint and that you don't let people believe you are affiliated with Linux
  Mint." The name is trademarked through the Linux Mark Institute.
- **Fedora** — the [guidelines](https://fedoraproject.org/wiki/Legal:Trademark_guidelines)
  are "not intended to limit fair use of the Fedora Trademarks, i.e., the
  referential use of the trademarks in references to the goods or services with
  which these marks are used by Fedora".
- **OpenWrt** — the [policy](https://openwrt.org/trademark) permits "nominative
  fair use" to identify OpenWrt without implying endorsement, and permits
  making "true factual statements about OpenWrt".
- **Ubuntu** — Canonical's [IP policy](https://canonical.com/legal/intellectual-property-policy)
  says "if you are producing software for use with or on Ubuntu you may
  reference Ubuntu", subject to no implied endorsement. The "permission in
  writing" clause elsewhere in that document governs putting the mark *in a
  product name*, which this does not.
- **Rocky Linux** — the [policy](https://rockylinux.org/legal/trademarks)
  states that "fair use rights are not restricted" and that a mark may be used
  "to make true factual statements", provided nothing implies the owner
  endorses this app.
- **Arch** — the [policy](https://terms.archlinux.org/docs/trademark-policy/)
  requires that "the Trademark declaration ( ™ ) must remain intact" and says
  monochrome versions are acceptable — both of which this satisfies; the ™ is
  part of `arch.svg` and is drawn with the rest of it. Its permitted-use
  section is framed around non-commercial "discussion, development and
  advocacy"; see the note on that below.
- **CentOS** — the marks are **Red Hat's**, but this is a separate document
  from Red Hat's own and it contains no blanket prohibition on the logo. The
  "you may use the Word Mark, but not the Logos" sentence has to be read whole:
  it is about "where what you are distributing is modified official CentOS
  source code". This app distributes no CentOS. What it *does* say flatly is
  quoted under "What would change the answer".
- **Pop!_OS** — System76 publishes no policy for Pop!_OS itself; the nearest
  written one is [COSMIC's](https://github.com/pop-os/cosmic-epoch/blob/master/TRADEMARK.md),
  which lets third parties use the mark to refer to the thing so long as the
  use is not misleading and implies no endorsement. Its
  [brand repository](https://github.com/system76/brand) is where the assets
  live and points at that document.
- **deepin** — no standalone policy. The
  [EULA](https://www.deepin.org/en/agreement/end-user-license-agreement/) says
  "UnionTech Software and its affiliates have legal trademark rights to
  '统信' '深度' 'UOS' 'deepin' '统信UOS' trademarks and logos", and its
  redistribution clause requires a rebrand — the ordinary position that a code
  licence carries no trademark licence. Nothing addresses referential display
  either way.
- **Alpine** — nothing published; the
  [community page](https://alpinelinux.org/community/) is where a policy would
  be if there were one. Wikimedia Commons files the logo as
  [`PD-textlogo`](https://commons.wikimedia.org/wiki/File:Alpine_Linux.svg) —
  "consists only of simple geometric shapes or text [...] does not meet the
  threshold of originality needed for copyright protection" — with a trademark
  warning attached, which is exactly how it is treated here.

Entries for marks that were dropped — openSUSE, Armbian, Kali, Red Hat,
Raspberry Pi — are kept in the history of this file rather than here. What was
read once should not have to be read again if a mark comes back.

## Copyright in the drawing, per glyph

Separate question from the one above, and the one this directory used to
assume away. Ten of the twelve are geometry or letterforms — a triangle, a
hexagon, an "f", an "LM", a swirl, a snowflake — and in the United States
those attract no copyright at all: 37 CFR 202.1 excludes "familiar symbols or
designs" and "mere variations of typographic ornamentation, lettering or
coloring". The European bar is lower ("the author's own intellectual
creation"), so thin copyright in a few of them is arguable rather than
impossible; nothing here depends on winning that argument, because the two
that carry an actual licence are attributed and the rest are used
nominatively.

None of the twelve is an illustration or a character. That was the point of
withdrawing `rhel`, `raspbian` and `kali`, and of the wider cut after it.

### The three attribution conditions

**Tux** — `tux.svg` is Larry Ewing's penguin, and the permission he gave is
not a public-domain dedication. His own page is gone; the wording is recorded
on [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Tux.svg) and in
[Wikipedia's article](https://en.wikipedia.org/wiki/Tux_(mascot)):

> Permission to use and/or modify this image is granted provided you
> acknowledge me lewing@isc.tamu.edu and The GIMP if someone asks.

So: **the generic Linux mark in this app is Tux, created by Larry Ewing
(lewing@isc.tamu.edu) with The GIMP.** It is the most-drawn glyph here,
standing in for every Linux whose flavour is not recognised and for every case
that ships no mark of its own.

**NixOS** — CC BY 4.0 requires credit, a licence link, and a note of changes:

> **The NixOS logo** — by the NixOS Project and contributors (Simon Frankau,
> Tim Cuthbertson, Daniel Baker), from
> <https://github.com/NixOS/branding>, licensed
> [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). **Changed**: this
> is font-logos' single-colour redraw, further stripped of `<metadata>` and
> `<defs>`, and the app tints it at the point of drawing.

**Debian** — the Open Use Logo under LGPL-3+ or CC-BY-SA-3.0:

> **The Debian Open Use Logo** — © the Debian Project,
> <https://www.debian.org/logos/>, used under CC-BY-SA-3.0. **Changed**: as
> above. Debian asks that the image link to <https://www.debian.org/> where it
> is used on a web page; this is an application, not a page, and the glyph is
> not a link.

### Where a user sees them

Not here. This file ships inside the app — `assets/distro/` is declared as a
whole directory in `pubspec.yaml`, so `README.md` is bundled with the glyphs —
but nothing renders it, and an acknowledgement nobody can reach is not one.

CC BY 4.0 and CC-BY-SA-3.0 both ask for credit "in any reasonable manner based
on the medium, means, and context". For an application that is the licence
screen it already has: **Settings → About → License**, which is Flutter's
`showLicensePage` over `LicenseRegistry`. That registry collects the LICENSE
file of every package and nothing else, so assets are invisible to it until
something registers them — `lib/data/model/server/dist_license.dart` does, and
`test/dist_license_test.dart` fails if any of the three conditions stops being
stated.

Tux's condition is weaker ("if someone asks") and a file in the repository
would arguably answer it. It is on that screen anyway, because the person most
likely to ask is the one looking at the penguin.

### Both were being missed

Neither condition was met before this was checked, and neither costs anything
to meet. Note the awkward half of it: font-logos redistributes both under the
Unlicense, which is not a licence either upstream granted. A licence conveys
only what the licensor holds, so the safe reading is that the conditions
travel with the drawing, and they are honoured here directly.

## What would change the answer

- **Recolouring — the sharpest of these, and it is not hypothetical.** Every
  glyph is drawn through `ColorFilter.mode(tint, BlendMode.srcIn)`, taking the
  row's foreground colour. CentOS's guidelines say, flatly and without a scope
  clause: "You may not change any logo except to scale it. This means you may
  not add elements to the logo, change the colors or proportions of the logo,
  distort the logo, or combine the logo with other logos." Arch's policy says
  the opposite for the same act — "monochrome versions are acceptable". The
  position taken here is that a single-colour icon-font glyph tinted to the
  surrounding text colour is not a recolouring of a *logo*; the file is already
  monochrome, and a black glyph on a dark background is the alternative. That
  is an argument, not a permission, and it is the one most likely to be wrong.
- **"Non-commercial".** Arch frames permitted use around non-commercial
  discussion, development and advocacy, and Linux Mint's own statements
  restrict commercial use of its branding. This app is AGPL-3.0 and free, with
  no purchase, subscription or paid tier of any kind — but it is distributed
  through the App Store and Google Play, and whether that makes the use
  "commercial" is genuinely arguable. Recorded rather than resolved.
- Putting one on a store listing, a promotional page, or anywhere it reads as
  "this app is affiliated with these projects". The screenshots are the thing
  to watch here, not the app.
- Shipping a distribution's own artwork rather than a redrawn glyph. That is a
  copyright question and the answer is usually no.
- Any of the twelve publishing a policy where it currently publishes none —
  Alpine, deepin and Pop!_OS are the three with nothing to read.
