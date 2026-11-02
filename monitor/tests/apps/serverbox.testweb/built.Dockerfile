# The test web app's built service: an image made on the machine from this
# file (`build:`), so a deploy builds and a purge removes what it built.
# `COPY . /ctx` copies the build's context: the stack's folder, of which the
# agent's `.dockerignore` lets nothing through, the env file least of all.
FROM docker.io/library/alpine:3.24
COPY . /ctx/
CMD ["sleep", "infinity"]
