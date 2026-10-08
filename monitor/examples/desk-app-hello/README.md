# Example desk app

A `web` desk app (`docs/dev/desk-sys.md`): a counter kept in the app's
storage, a toolbar button and a menu that send a notification.

Package it and install it as an admin (Settings → Apps, or the API):

```sh
COPYFILE_DISABLE=1 tar -czf example_hello.fsba manifest.json ui  # macOS: no ._ files
```
