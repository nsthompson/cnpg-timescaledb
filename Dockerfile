# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# CloudNativePG PostgreSQL operand image with the TimescaleDB extension.
#
# Base image notes:
#   * "bookworm" (Debian 12) is chosen on purpose. The TimescaleDB APT
#     repository reliably publishes packages for bookworm. The default
#     CNPG PostgreSQL 18 images are built on "trixie" (Debian 13); only
#     switch to a trixie base once you have confirmed Timescale publishes
#     trixie packages, otherwise the apt install step will fail.
#   * Confirm the exact tag exists (CNPG rotates minor versions) here:
#       https://github.com/cloudnative-pg/postgres-containers
#       https://raw.githubusercontent.com/cloudnative-pg/postgres-containers/main/Debian/ClusterImageCatalog-bookworm.yaml
#   * "standard" is the recommended (non-deprecated) flavour. For backups you
#     will use the Barman Cloud Plugin (the in-core support lived in the now
#     deprecated "system" images).
# ---------------------------------------------------------------------------
ARG BASE_IMAGE=ghcr.io/cloudnative-pg/postgresql:18.4-standard-bookworm

FROM ${BASE_IMAGE}

# PostgreSQL major version. MUST match the major version of BASE_IMAGE above.
ARG PG_MAJOR=18

# Pin a specific TimescaleDB upstream version (e.g. 2.24.0).
# Leave empty to install the latest available in the APT repository.
ARG TIMESCALEDB_VERSION=2.28.2

# Everything below installs TimescaleDB from the official Timescale APT repo.
USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    \
    # Add the TimescaleDB APT repository for the current Debian codename.
    . /etc/os-release; \
    curl -fsSL https://packagecloud.io/timescale/timescaledb/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/timescaledb.gpg; \
    echo "deb [signed-by=/usr/share/keyrings/timescaledb.gpg] https://packagecloud.io/timescale/timescaledb/debian/ ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/timescaledb.list; \
    apt-get update; \
    \
    TS_PKG="timescaledb-2-postgresql-${PG_MAJOR}"; \
    if [ -n "${TIMESCALEDB_VERSION}" ]; then \
        # Resolve the exact APT version string from the requested upstream
        # version (the APT version carries a distro suffix, e.g. 2.24.0~debian12).
        FULL_VER="$(apt-cache madison "${TS_PKG}" | awk '{print $3}' \
            | grep -E "^${TIMESCALEDB_VERSION}([~+.-]|$)" | head -n1 || true)"; \
        if [ -z "${FULL_VER}" ]; then \
            echo "ERROR: TimescaleDB ${TIMESCALEDB_VERSION} not available for PostgreSQL ${PG_MAJOR} on ${VERSION_CODENAME}." >&2; \
            echo "Available versions:" >&2; \
            apt-cache madison "${TS_PKG}" >&2; \
            exit 1; \
        fi; \
        apt-get install -y --no-install-recommends "${TS_PKG}=${FULL_VER}"; \
    else \
        apt-get install -y --no-install-recommends "${TS_PKG}"; \
    fi; \
    \
    # Record the installed version for traceability / debugging.
    dpkg-query -W -f='${Version}\n' "${TS_PKG}" > /usr/share/timescaledb.version; \
    \
    # Clean up build-only tooling and apt metadata to keep the image lean.
    apt-get purge -y --auto-remove curl gnupg; \
    rm -rf /var/lib/apt/lists/*; \
    rm -f /etc/apt/sources.list.d/timescaledb.list /usr/share/keyrings/timescaledb.gpg

# Drop back to the unprivileged postgres user expected by CloudNativePG (UID 26).
USER 26
