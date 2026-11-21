# Create the controller OpenShell sandbox

Status: operator runbook. Sandbox `mac-env-controller` was created 2026-11-21
(see `receipts/openshell-controller-2026-11-21.json`). Do not re-policy without review.

Prerequisites: OpenShell 0.1.9 gateway authenticated (`openshell status`,
`openshell whoami`). OrbStack/Docker engine healthy.

## 1. Build or choose an image that has tools

The default Ubuntu work image lacks `python3` / `opa` / `restic`. Preferred path:

```sh
docker build -f operations/openshell/Dockerfile.controller \
  -t mac-env-controller:local \
  operations/openshell
```

Live image (2026-11-21): `sha256:04b8e083…` baked with python3, git, opa
1.22.4, restic 0.19.1 (`receipts/openshell-controller-2026-11-21.json`).
Rebuild when the Dockerfile changes. Upload the **project** after create; tools
are already in `/opt/mac-env/tools` on PATH.

## 2. Create (do not run until image decision is made)

```sh
openshell sandbox create \
  --name mac-env-controller \
  --policy docs/openshell/policy-controller.yaml \
      --from mac-env-controller:local
```

Replace `mac-env-controller:local` with a digest-pinned ref after first
successful build. Or reuse/reconfigure `mac-env-work` only after confirming
provenance (`openshell sandbox get mac-env-work`).

## 3. Upload project and tools

```sh
make prepare-controller-uploads
openshell sandbox upload mac-env-controller --no-git-ignore \
  /path/to/dev-env /sandbox/dev-env
openshell sandbox upload mac-env-controller --no-git-ignore \
  .cache/controller-uploads/linux-arm64/opa /sandbox/tools/opa
openshell sandbox upload mac-env-controller --no-git-ignore \
  .cache/controller-uploads/linux-arm64/restic /sandbox/tools/restic
```

## 4. Acceptance probes

```sh
openshell sandbox exec mac-env-controller -- id
openshell sandbox exec mac-env-controller -- python3 -c 'import sys; assert sys.version_info >= (3, 11)'
openshell sandbox exec mac-env-controller -- /sandbox/tools/opa version
openshell sandbox exec mac-env-controller -- /sandbox/tools/restic version
openshell sandbox exec mac-env-controller -- python3 -c 'import socket; s=socket.socket(); s.settimeout(2); s.connect(("1.1.1.1",443))'
# expect connection failure
```

Record policy hash, image digest, and probe output in
`receipts/openshell-controller-<date>.json` (no secrets).

## 5. Retire Error bootstrap sandbox

`mac-env-bootstrap` is in Error (`ImagePreparationTimedOut`). After the new
sandbox passes probes, delete or leave it stopped — do not treat its old denial
evidence as current.
