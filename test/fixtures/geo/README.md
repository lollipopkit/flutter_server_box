# Shared geo test vectors

Copied verbatim from `lollipopkit/ipgeo-shards` at `tests/vectors/`. **Do not
edit them here, and do not regenerate one to make a failing test pass.**

`country_v1.bin` is a small database built by that repository's writer.
`country_v1.json` says what looking each address up in it must answer, with the
coordinates already decoded so both sides compare exactly rather than within a
tolerance.

The point is that two independently written readers — Python there, Dart here —
agree about the format. A reader checked only against bytes its own writer
produced agrees with itself and proves nothing, which is why
`test/helpers/geo_fixture.dart` exists *as well*: that one is a second encoder
written from the specification, and this one is the other repository's actual
output.

Refresh with `python3 tests/make_vectors.py` in that repository, then copy the
directory across. `geo_vectors_test.dart` checks the format version, so a
change on that side that this one has not caught up with fails here rather than
passing quietly.
