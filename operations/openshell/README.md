# OpenShell controller image

Gateway install/start (flake, no Homebrew): [docs/openshell/PROVISION.md](../../docs/openshell/PROVISION.md).

| Artefact | Role |
| --- | --- |
| `Dockerfile.controller` | Ubuntu 24.04 + python3 ≥ 3.11 + bash |
| `docs/openshell/PROVISION.md` | Nix package + LaunchAgent provision/start |
| `docs/openshell/CREATE.md` | Operator create + upload + probe sequence |
| `docs/openshell/policy-controller.yaml` | Proposed deny-by-default FS policy |

## Build (operator)

```sh
docker build -f operations/openshell/Dockerfile.controller \
  -t mac-env-controller:local \
  operations/openshell
docker images --digests mac-env-controller:local
```

Record the image digest in `receipts/openshell-controller-<date>.json`.
Do not push to a public registry until provenance review.

## After create

Upload pinned `opa` 1.22.4 and flake `restic` 0.19.1; run CREATE.md probes.
Agents never create or re-policy the sandbox.
