# Two-Phase Helm Templating

A pattern for Helm charts that enforces strict security policies in production while keeping full flexibility during development.

## Problem

Security teams require certain Kubernetes security settings (security contexts, volume permissions, etc.) to be **hardcoded** in manifests — not overridable via Helm values. At the same time, developers need the ability to override these settings in local and dev environments for debugging and testing.

## Solution

This project implements a **two-phase approach**:

1. **Development phase** (`make package`) — All values, including security settings, are parameterized and can be overridden per environment via `values.yaml` and `env/*.yaml` files.
2. **Release phase** (`make release`) — A build script reads `values_security.yaml`, hardcodes its values directly into the Helm templates, and removes them from `values.yaml`. The resulting chart has security policies baked in and cannot be overridden at deploy time.

## Project Structure

```
.
├── Makefile
├── mychart/
│   ├── Chart.yaml
│   ├── values.yaml                 # Default values (parameterized)
│   ├── values_security.yaml        # Security values to be hardcoded in release
│   └── templates/
│       ├── deployment.yaml
│       └── service.yaml
├── env/
│   ├── dev.yaml                    # Dev overrides (relaxed security)
│   ├── staging.yaml
│   ├── preprod.yaml
│   └── prod.yaml
├── scripts/
│   └── hardcode-security.sh        # Patches templates for release
├── out/                            # Generated manifests (gitignored)
└── release/                        # Release chart with hardcoded security (gitignored)
```

## How It Works

### values_security.yaml

Define all security-related values that must be hardcoded in the release chart:

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL

secretVolumeDefaultMode: 0400
```

The script `hardcode-security.sh` automatically picks up **all top-level keys** from this file. To hardcode a new attribute, add it here and reference it in the template — no script changes needed.

### Supported patterns

The script handles two types of references in templates:

- **Block values** using `toYaml`: `{{- toYaml .Values.podSecurityContext | nindent 8 }}` — replaced with indented YAML block
- **Scalar values** using inline reference: `{{ .Values.secretVolumeDefaultMode }}` — replaced with the literal value

### Development flow

In development, security values are parameterized and can be overridden per environment:

```yaml
# env/dev.yaml — relaxed for local development
podSecurityContext:
  runAsNonRoot: false
  runAsUser: 0

securityContext:
  allowPrivilegeEscalation: true
  readOnlyRootFilesystem: false
```

### Release flow

During release, the script:

1. Copies the chart to `release/`
2. Reads all keys from `values_security.yaml`
3. Replaces template references with hardcoded values in `deployment.yaml`
4. Removes security keys from `release/values.yaml`
5. Deletes `values_security.yaml` from the release chart

The release chart can then be used in Jenkins or other CI/CD pipelines, where only non-security values (replicas, image tags, resources) can be configured.

## Makefile Targets

| Target | Description |
|---|---|
| `make template` | Render templates to stdout |
| `make template-debug` | Render templates with debug output |
| `make package` | Render templates to `out/manifests.yaml` |
| `make release` | Build release chart with hardcoded security |
| `make test` | Build both and show diff between package and release |
| `make lint` | Lint the chart |

All targets support `ENV` variable (default: `dev`):

```bash
make template ENV=prod
make package ENV=staging
make test ENV=dev
```

## Quick Start

### Prerequisites

- [Helm](https://helm.sh/docs/intro/install/)
- [yq](https://github.com/mikefarah/yq) (`brew install yq`)

### Usage

```bash
# Render dev manifests
make package

# Build release chart with hardcoded security
make release

# Compare dev vs release to verify security differences
make test
```

### Example test output

```
=== Diff: package (dev) vs release (hardcoded) ===
<         runAsNonRoot: false
<         runAsUser: 0
---
>         runAsNonRoot: true
>         runAsUser: 1000
<             allowPrivilegeEscalation: true
<             readOnlyRootFilesystem: false
---
>             allowPrivilegeEscalation: false
>             readOnlyRootFilesystem: true
<             defaultMode: 420
---
>             defaultMode: 0400
```

## Adding New Hardcoded Values

1. Add the key to `mychart/values_security.yaml`
2. Reference it in the template using `{{ toYaml .Values.<key> }}` or `{{ .Values.<key> }}`
3. Add a default to `mychart/values.yaml`
4. Optionally override in `env/*.yaml`
5. Run `make test` to verify
