/**
 * Turning a repository address into its files.
 *
 * **The address is the repository, and what is fetched is its latest tree** —
 * one request, no git client, no release. For GitHub and everything
 * GitHub-shaped (Gitea, Forgejo, Codeberg) that is `<repo>/archive/HEAD.tar.gz`,
 * which resolves the default branch server-side; `HEAD` rather than `main`
 * because a repository's default branch is not this tool's business to guess.
 *
 * **This rule is implemented twice** — here and in the app's
 * `PluginRepoSource` — because they are in different languages and both have to
 * turn the same address into the same URL. The table in
 * `test/fetch.test.ts` and the one in `test/plugin_repo_test.dart` are the same
 * table for that reason.
 */
import { readTarGz, stripTopDirectory, type TarLimits } from "./tar.ts";

export function isRepoAddress(source: string): boolean {
  return /^https?:\/\//.test(source);
}

/**
 * The tarball an address is fetched from.
 *
 * A URL that already names an archive is taken as it is, so a repository served
 * from anywhere at all can be used by pointing straight at the tarball.
 */
export function archiveUrlOf(address: string): string {
  const trimmed = address.trim();
  if (/\.(tar\.gz|tgz)$/i.test(trimmed)) return trimmed;
  return `${trimmed.replace(/\/+$/, "").replace(/\.git$/i, "")}/archive/HEAD.tar.gz`;
}

/**
 * Measured, and worth knowing before it looks like a bug: GitHub's `HEAD`
 * archive can serve the *previous* commit for a few seconds after a push — the
 * redirect resolves `HEAD` to a sha and that resolution is cached. It caught up
 * within ten seconds when this was written, and a client that refetches a
 * repository once a day cannot tell the difference. A publish followed
 * immediately by a fetch can, which is why `verify.ts` against an address is
 * worth re-running rather than trusted on the first miss.
 */

export async function fetchRepoArchive(
  address: string,
  limits?: TarLimits,
): Promise<Map<string, Uint8Array>> {
  const url = archiveUrlOf(address);
  const res = await fetch(url, { redirect: "follow" });
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  const bytes = new Uint8Array(await res.arrayBuffer());
  return stripTopDirectory(readTarGz(bytes, limits));
}
