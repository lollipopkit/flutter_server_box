# Distribution icons

Single-colour glyphs marking which distribution a server runs. Drawn into the
list rows and the pickers, beside the server's name; the *colour* logo on the
detail page is a separate thing, fetched from a URL the user configures, and
this repository ships none of those.

## Where these came from

All of them are taken verbatim from [font-logos](https://github.com/lukas-w/font-logos)
(`vectors/`), renamed to match `Dist`'s enum names. font-logos is released into
the public domain under the [Unlicense](https://github.com/lukas-w/font-logos/blob/master/LICENSE):

> Anyone is free to copy, modify, publish, use, compile, sell, or distribute
> this software, either in source code form or as a compiled binary, for any
> purpose, commercial or non-commercial, and by any means.

That is what makes it legal to *ship the files*. They are redrawn glyphs, not
each project's own artwork, so no distribution's copyright is being copied
here.

Each file is named after its `Dist` case, which is also what `{DIST}` expands
to in a custom logo URL — so `Dist.rhel` is `rhel.svg` and `{DIST}` is `rhel`,
whatever font-logos happened to call it (`redhat`). `tux.svg` is the generic
mark, drawn for a server that has not been asked yet.

To add one: find it in font-logos' `vectors/`, copy it in under the `Dist`
name you are adding, add the case, and add a matcher. `test/dist_icon_test.dart`
fails if any of the four is missing.

`armbian` and `coreelec` have no glyph in font-logos and fall back to the
generic mark. Do not fill those two in from the projects' own sites: that would
be copying their artwork, which is the one thing this arrangement avoids.

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

Sixty-one marks is a lot of projects to have checked, and most of them publish
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
- **Kali** — [OffSec's policy](https://www.kali.org/docs/policy/trademark/)
  reserves uses outside its scope to written permission and states no fair-use
  carve-out. Nominative use does not depend on one being offered.
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
