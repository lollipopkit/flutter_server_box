# Written for ServerBox Monitor: mounted over linkding's empty custom settings
# module (bookmarks/settings/custom.py), which prod.py imports last.
#
# The agent's proxy says the browser's scheme in X-Forwarded-Proto. Without
# this, a desk on HTTPS fails Django's CSRF origin check on every form (the
# browser's origin is https://, the request reaching linkding is http://).
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
