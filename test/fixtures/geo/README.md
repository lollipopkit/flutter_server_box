# Shared geo test vectors

Copied verbatim from `lollipopkit/ipgeo-shards` at `tests/vectors/`. **Do not
edit them here, and do not regenerate one to make a failing test pass.**

`bundle_ip4_v1.bin` and `bundle_ip6_v1.bin` are small bundles built by that
repository's writer, one per address family. The `.json` beside each says what
looking every address up in it must answer, with the coordinates already
decoded so both sides compare exactly rather than within a tolerance.

The point is that two independently written readers — Python there, Dart here —
agree about the format. A reader checked only against bytes its own writer
produced agrees with itself and proves nothing, which is why
`test/helpers/geo_fixture.dart` exists *as well*: that one is a second encoder
written from the specification, and this one is the other repository's actual
output.

Refresh with `python3 tests/make_vectors.py` in that repository, then copy the
directory across. `test/geo_bundle_test.dart` reads them and checks the format
version in each header, so a change on that side that this one has not caught
up with fails here rather than passing quietly.
