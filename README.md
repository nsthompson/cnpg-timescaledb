# cnpg-timescaledb

A CloudNativePG-compatible PostgreSQL operand image with the
[TimescaleDB](https://github.com/timescale/timescaledb) extension installed,
built and published to the GitHub Container Registry (GHCR) via GitHub Actions.

The image is built **on top of the official CloudNativePG PostgreSQL operand
image** (not the `timescaledb-ha` image), so it preserves CNPG's standard data
directory layout, UID 26 postgres user, and operator-driven bootstrap — and all
CNPG features (failover, backups, etc.) keep working.

## Why a custom image (and not image volumes)?

TimescaleDB's default build ships features under the Timescale License (TSL),
which is not on the CNCF Allowlist, so there is no official community
*image-volume* extension image for it. Embedding it in a custom operand image is
the simplest reliable path. See the licensing note at the bottom.

## Repository layout

```
.
├── .github/workflows/build.yml   # CI: multi-arch build, push, sign
├── Dockerfile                    # CNPG base + TimescaleDB
├── renovate.json                 # auto-bump TimescaleDB / base image
├── examples/
│   ├── cluster.yaml              # CNPG Cluster using this image
│   └── database.yaml             # declarative CREATE EXTENSION timescaledb
├── LICENSE                       # license for THIS repo's tooling (MIT)
└── NOTICE                        # licenses of the bundled software
```

## Quick start

1. Create a new GitHub repository named `cnpg-timescaledb` and push these files:

   ```bash
   git init -b main
   git add .
   git commit -m "Initial commit: CNPG + TimescaleDB image"
   git remote add origin git@github.com:<OWNER>/cnpg-timescaledb.git
   git push -u origin main
   ```

2. The push triggers `.github/workflows/build.yml`, which builds for
   `linux/amd64` + `linux/arm64` and pushes to
   `ghcr.io/<OWNER>/cnpg-timescaledb`. No secrets to configure — the workflow
   authenticates to GHCR with the built-in `GITHUB_TOKEN`.

3. After the first successful run, make the package public (or grant your
   cluster pull access): **GitHub → your profile/org → Packages →
   `cnpg-timescaledb` → Package settings → Change visibility / Manage Actions
   access**. Private packages require an image pull secret in your cluster.

4. Deploy (replace `<OWNER>`):

   ```bash
   kubectl apply -f examples/cluster.yaml
   kubectl apply -f examples/database.yaml
   ```

5. Verify:

   ```bash
   kubectl exec -ti timescale-cluster-1 -- psql app -c "\dx timescaledb"
   ```

## Published tags

The CI publishes, on pushes to `main`:

- `latest`
- `pg18` — rolling tag for the current major
- `pg18-ts<version>` — e.g. `pg18-ts2.24.0`
- `sha-<short>` — immutable, recommended for production pinning

On a `vX.Y.Z` git tag it additionally publishes `X.Y.Z` and `X.Y`.

Every image is multi-arch and ships with an SBOM, SLSA provenance, and a keyless
[cosign](https://github.com/sigstore/cosign) signature.

## Configuration

The build is parameterised via Docker build args (overridable as workflow inputs
on a manual `workflow_dispatch` run, or by editing the defaults):

| Arg / env             | Default                                                   | Notes |
|-----------------------|-----------------------------------------------------------|-------|
| `BASE_IMAGE`          | `ghcr.io/cloudnative-pg/postgresql:18.3-standard-bookworm` | See note below |
| `PG_MAJOR`            | `18`                                                      | Must match `BASE_IMAGE` |
| `TIMESCALEDB_VERSION` | `2.24.0`                                                  | Blank = latest available |

### Important: base image OS

`bookworm` (Debian 12) is used **deliberately**. The TimescaleDB APT repository
reliably publishes packages for bookworm. The default CNPG PostgreSQL 18 images
are built on `trixie` (Debian 13); only move to a trixie base once you have
confirmed Timescale ships trixie packages, or the `apt install` step will fail.

Verify the exact base tag exists (CNPG rotates minor versions) against the
[bookworm image catalog](https://raw.githubusercontent.com/cloudnative-pg/postgres-containers/main/Debian/ClusterImageCatalog-bookworm.yaml)
and override `BASE_IMAGE` if needed.

## Tuning

CloudNativePG does **not** run `timescaledb-tune`. Set memory- and
worker-related parameters explicitly under `spec.postgresql.parameters` in your
Cluster manifest (see `examples/cluster.yaml`) to match your node sizing.

## Keeping versions current

`renovate.json` configures [Renovate](https://docs.renovatebot.com/) to open PRs
that bump `TIMESCALEDB_VERSION` (tracking TimescaleDB releases) and the CNPG base
image minor version. PostgreSQL **major** upgrades require manual approval via
the Renovate dependency dashboard.

## Licensing

The files in **this repository** (Dockerfile, workflows, manifests) are released
under the MIT License — see `LICENSE`.

The **image produced** by this repository bundles third-party software that
retains its own licenses, including PostgreSQL (PostgreSQL License) and
TimescaleDB. TimescaleDB's community features are governed by the
[Timescale License (TSL)](https://github.com/timescale/timescaledb/blob/main/tsl/LICENSE-TIMESCALE),
a source-available license. You are responsible for ensuring your use complies
with these terms. See `NOTICE`.
