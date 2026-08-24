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

## Tux

`tux.svg` is Larry Ewing's penguin, and the permission he gave is not a
public-domain dedication:

> Permission to use and/or modify this image is granted provided you
> acknowledge me lewing@isc.tamu.edu and The GIMP if someone asks.

So: **this app's generic Linux mark is Tux, created by Larry Ewing
(lewing@isc.tamu.edu) with The GIMP.** That sentence is the whole of what the
condition asks for. It is worth keeping accurate — Tux is by far the most-drawn
glyph here, standing in for every Linux whose flavour is not recognised and for
every case that ships no mark of its own, which is most of them.

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
was traced in: `elementary.svg` carries *Gentoo's* ("Gentoo Logo Dark v1.0",
Sebastian Pipping, Gentoo Foundation Inc.), `voidlinux.svg` carries *AOSC's*
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

Twenty-five distributions have a glyph. Every other `Dist` case is recognised
by name and draws `tux.svg` or `server.svg`. The reasons divide five ways.

**Shipped** — what somebody manages a server on, plus the desktop
distributions common enough that a person will have one machine of:

> almalinux · alpine · arch · centos · coreos · debian · deepin · devuan ·
> elementary · fedora · gentoo · leap · manjaro · mint · mx · nixos ·
> opensuse · popos · rocky · slackware · tumbleweed · ubuntu · voidlinux ·
> wrt · zorin

**Not shipped**, for four reasons:

- **The great majority** — no glyph because nobody would meet one on a server,
  and a glyph nobody sees is bundle weight plus one more mark to have
  justified. Respins of a distribution already in the list (the Arch and
  Ubuntu families), single-purpose live systems, phone and set-top targets,
  projects that have stopped, and the very small. `Dist` still identifies all
  of them; only the picture is absent.
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

Twenty-five is few enough to have checked one by one, and most of them publish
no third-party trademark policy at all — for those, nominative use is simply
the general rule. The ones that *do* publish something are recorded below,
since the wording differs and one of them (CentOS) reads as a prohibition until
the sentence is taken whole:

- **Debian** — the [Open Use Logo](https://www.debian.org/logos/) is dual
  licensed LGPL-3+ / CC-BY-SA-3.0, so even the artwork is free. The only one
  where this question does not arise at all.
- **Fedora** — the [guidelines](https://fedoraproject.org/wiki/Legal:Trademark_guidelines)
  are "not intended to limit fair use of the Fedora Trademarks, i.e., the
  referential use of the trademarks in references to the goods or services with
  which these marks are used by Fedora".
- **openSUSE** — the [guidelines](https://en.opensuse.org/openSUSE:Trademark_guidelines)
  "acknowledge and support your right to make fair use of the openSUSE Marks"
  and do not suggest permission is needed for it.
- **OpenWrt** — the [policy](https://openwrt.org/trademark) permits "nominative
  fair use" to identify OpenWrt without implying endorsement, and permits
  making "true factual statements about OpenWrt".
- **Arch** — the [policy](https://terms.archlinux.org/docs/trademark-policy/)
  prohibits combined marks, implied endorsement and branding of modified
  derivatives; none of those is this.
- **Ubuntu** — Canonical's [IP policy](https://canonical.com/legal/intellectual-property-policy)
  says "if you are producing software for use with or on Ubuntu you may
  reference Ubuntu", subject to no implied endorsement. The "permission in
  writing" clause elsewhere in that document governs putting the mark *in a
  product name*, which this does not.
- **Rocky Linux** — the [policy](https://rockylinux.org/legal/trademarks)
  states that "fair use rights are not restricted" and that a mark may be used
  "to make true factual statements", provided nothing implies the owner
  endorses this app.
- **Armbian** — [terms](https://armbian.com/terms) allow nominative use;
  written permission is for merchandise, redistribution under the brand, and
  commercial use of the logo. (No glyph shipped either way.)
- **CentOS** — the [guidelines](https://www.centos.org/legal/trademarks/) do
  say "you may use the Word Mark, but not the Logos", and the sentence has to
  be read whole: it is about "where what you are distributing is modified
  official CentOS source code or is a build compiled from modified official
  CentOS source code". This app distributes no CentOS.
- **Kali**, **Red Hat**, **Raspberry Pi** — all three reserve logo use to
  written permission; see "Which marks are shipped". No glyph is shipped for
  any of them.
- **Alpine**, **deepin**, **CoreELEC** and the rest — no published third-party
  trademark policy found. Nominative use is the general rule where a project
  has not written one down.

## What would change the answer

- Recolouring or reshaping a glyph. Several policies forbid modifying the mark,
  and "no more of the mark than needed" cuts the other way once it is altered.
  These are tinted with the row's own foreground colour, which is how an icon
  font has always been drawn and is not a change to the mark's form.
- Putting one on a store listing, a promotional page, or anywhere it reads as
  "this app is affiliated with these projects".
- Shipping a distribution's own artwork rather than a redrawn glyph. That is a
  copyright question and the answer is usually no.
