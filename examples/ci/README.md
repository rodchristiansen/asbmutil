# Running asbmutil in Linux CI

`asbmutil` is a Swift binary, but the release build is a **static Linux
executable** — so you can drive Apple Business/School Manager from any headless
CI runner (GitHub Actions, Azure DevOps, GitLab) with no Mac and no Keychain in
the loop. These samples show the whole pattern end to end.

## The three-step pattern

1. **Get the binary.** Download the latest `*-linux-amd64.tar.gz` asset from the
   [releases](https://github.com/rodchristiansen/asbmutil/releases), untar, and
   put `asbmutil` on `PATH`. It's self-contained (`--static-swift-stdlib`), so
   there's nothing else to install.
2. **Load credentials.** On Linux there's no Keychain, so `asbmutil` reads
   credentials from a file store at `~/.config/asbmutil/`. `asbmutil config set`
   writes that store from your ABM API client id, key id, and PEM private key —
   supplied as CI secrets, never committed.
3. **Run commands.** Every command prints clean JSON on stdout and all
   diagnostics on stderr, so piping into `jq` (or a script) just works.

[`setup-asbmutil.sh`](setup-asbmutil.sh) does steps 1 and 2 from three
environment variables:

```bash
ASBM_CLIENT_ID=... ASBM_KEY_ID=... ASBM_PRIVATE_KEY_PEM="$(cat key.pem)" \
  ./setup-asbmutil.sh
```

## Getting the credentials

In Apple Business Manager, go to **Preferences → API**, create a managed API
account, and download the private key (`.pem`). That gives you the client id,
key id, and PEM. Store all three as secrets in your CI system:

| Secret | Value |
|---|---|
| `ASBM_CLIENT_ID` | e.g. `BUSINESSAPI.84c7b9e1-...` |
| `ASBM_KEY_ID` | the API key id |
| `ASBM_PRIVATE_KEY_PEM` | the full contents of the `.pem` file |

## GitHub Actions samples

Copy either file into your repo's `.github/workflows/` (they live here, outside
`.github/`, so they don't run against this repo):

- **[`asbmutil-report.yml`](github-actions/asbmutil-report.yml)** — read-only.
  On a daily schedule, pulls every MDM server and its device list and publishes
  the JSON as a build artifact. A good "is ABM drifting from my inventory?"
  heartbeat. Safe to run on a timer.
- **[`asbmutil-assign.yml`](github-actions/asbmutil-assign.yml)** — write.
  Manual-trigger reassignment of a set of serials to a target MDM server — the
  core move of a MicroMDM → Intune migration. Dry-run by default: it always
  shows the current assignment first, and only calls `assign --confirm` when you
  uncheck the dry-run box.

## Azure DevOps and others

The same three steps work on any runner. In an Azure Pipelines job it's a
`script:` step that curls the release asset and a second one that runs
`asbmutil config set` from pipeline secrets — see
[`setup-asbmutil.sh`](setup-asbmutil.sh) for the exact commands to lift.

## Why the file store, and a gotcha

On Linux (musl), `FileManager.homeDirectoryForCurrentUser` resolves the
*passwd* home via `getpwuid()` and ignores `$HOME` — which bites service
accounts whose passwd home is `/nonexistent`. The file store reads `$HOME`
first for exactly this reason, so make sure your CI job has `HOME` set (GitHub
and Azure runners do by default). If you provision the store by writing its JSON
files directly instead of using `config set`, drop them in `$HOME/.config/asbmutil/`
with `0600` permissions.

## Handy read-only commands to script

Every MDM server and its id:

```bash
asbmutil list-mdm-servers
```

Devices grouped by server, or the server a given set of serials is on:

```bash
asbmutil list-devices-servers --all
asbmutil list-devices-servers --serials A,B,C
```

Full per-device attributes (including AppleCare and assigned MDM), and whole-fleet AppleCare coverage:

```bash
asbmutil get-devices-info --serials A,B,C
asbmutil list-devices --include-applecare
```

Migration verification from Apple's own audit log (Business Manager only):

```bash
asbmutil audit-events --start 2026-07-01T00:00:00Z --end 2026-07-14T23:59:59Z --type DEVICE_ASSIGNED_TO_SERVER
```
