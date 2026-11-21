# Exec plan: platform prerequisites, then local NetBird

Status: proposed — nothing implemented, nothing run  
Opened: 2026-11-21  
Goal: NetBird 0.83.1 server and dashboard on this Mac's Kubernetes, named in
the operator's Cloudflare zone, with NetBird.app enrolled against it. The
platform under it lands first, in dependency order.

## Operator constraints (2026-11-21)

- Allowed tooling: Nix, Helm, Argo CD Applications and ApplicationSets, Argo
  Workflows, Argo Rollouts, Argo Events, Flux, scripts, Docker, Podman Quadlet,
  OpenTofu/Terraform.
- The operator owns the Cloudflare zone, domain and DNS.
- Similar Argo CD and Helm code exists outside this repository (input I1).
- OpenTofu code is in scope as well. This repository holds none. Whether
  existing OpenTofu code and state live with the Argo CD and Helm code is part
  of input I1.

## Non-goals

- Host activation, `sudo`, `launchctl` or `darwin-rebuild switch` by agents.
- Inline secrets. Every secret stays a 1Password item reference.
- Installing a controller that no workload in this plan needs.

## Dependency chain

| Layer | Component | Tool | Repo state today | Gap |
| --- | --- | --- | --- | --- |
| L0 | OrbStack, Podman, Podman Desktop, Colima | Nix (Home Manager) | Declared with fixed hashes: `homelab/runtime-packages.nix`, `home/container-runtimes.nix` | Activation and runtime tests not evidenced (T21) |
| L0 | `kubectl`, `helm`, `oras`, `argocd`, `tofu` | Nix | `kubectl` and `helm` only, behind `homelab.enable` | ORAS, Argo CD CLI and OpenTofu undeclared; `homelab.enable` also demands 1Password, OpenBao and all digests |
| L1 | Kubernetes | OrbStack, reconciled by Nix | Only `k8s.expose_services false` is reconciled | Cluster enable undeclared; no context check |
| L2 | OCI registry and ORAS bundle | Docker or Quadlet; ORAS | Absent | Registry, push script, digest record |
| L3 | Argo CD | Helm chart rendered by Nix; one bootstrap script | Absent | Chart pin, image digests, root Application |
| L4 | cert-manager 1.21.3, 1Password operator (chart 2.4.3), ExternalDNS 1.24.0 | Argo CD Applications | Rendered by `homelab/kubernetes.nix` into `/etc/mac-environment/kubernetes`; nothing applies them | Every image digest null; no sync order |
| L4 | Traefik | Argo CD Application | NetBird Ingress names class `traefik`; chart not rendered | Chart pin, digests |
| L5 | DNS and TLS | OpenTofu and ExternalDNS; cert-manager | Cloudflare ExternalDNS rendered when enabled; NetBird issuer is `openbao-intermediate`; no OpenTofu code | Zone unset; OpenTofu module and state backend; issuer decision D2 |
| L6 | NetBird server and dashboard | Argo CD Application | `homelab/netbird-server.nix`, off | URL, proxy CIDRs, digests, 1Password item |
| L7 | NetBird.app 0.83.1 | Signed pkg; `netbird up` | Pinned in `homelab/netbird-package.nix`; daemon `NeedsLogin` on the last probe | Enrollment (operator, browser SSO) |

Critical path: L0 → L1 → L2 → L3 → L4 → L5 → L6 → L7.

Argo Workflows, Argo Rollouts, Argo Events and Flux are off the critical path.
Nothing above needs them. Each adds controllers, CRDs and images to pin, so
they wait for a workload that requires them.

## Decisions (operator)

| ID | Decision | Recommended | Reason |
| --- | --- | --- | --- |
| D1 | Cluster | OrbStack Kubernetes | `txtOwnerId = "orbstack-internal"` already assumes it; Colima declares `kubernetes.enabled: false` |
| D2 | Issuer for the NetBird host | ACME DNS-01 through Cloudflare | Publicly trusted certificate, no inbound port, no private CA in the client trust store. `openbao-intermediate` needs host etcd, CoreDNS and OpenBao first |
| D3 | Reconciler | Argo CD only | Existing code uses it; Flux would reconcile the same objects twice |
| D4 | Manifest transport | OCI bundle pushed with ORAS, referenced by digest | Nix renders into the store, not into Git; no Git credential in the cluster. Argo CD OCI source support must be checked against the pinned chart version |
| D5 | Cloudflare ownership split | OpenTofu owns zone settings, token scopes and static records; ExternalDNS owns service records | One writer per record. A second OpenTofu state on a zone that existing code manages would make two |

## Inputs required (operator)

| ID | Input | Blocks |
| --- | --- | --- |
| I1 | Path or URL of the existing Argo CD and Helm code, and of any existing OpenTofu code with its state backend | L3 and L5 design; reuse instead of rewrite |
| I2 | Cloudflare zone and NetBird hostname | L5, L6 |
| I3 | Reach: loopback only, or the Mac's LAN address | A record target; OrbStack exposure, now forced off |
| I4 | 1Password Connect host and item paths (Cloudflare token, NetBird credentials) | L4, L5, L6 |
| I5 | Where agent edits and Nix evaluation run (OpenShell sandbox or approved builder) | Every phase |

## Phases

| Phase | Outcome | Evidence of done | Status |
| --- | --- | --- | --- |
| P0 | I1–I5 recorded; non-secret values in `homelab/config.nix` | Config diff reviewed | waiting on operator |
| P1 | Staged flags: runtimes, Kubernetes and GitOps independent of `homelab.enable` | `nix flake check --impure --all-systems --no-build` passes | planned |
| P2 | OrbStack Kubernetes reconciled on; CLIs declared | Operator switch; `kubectl get nodes` Ready | planned |
| P3 | Chart hashes and image digests pinned for Argo CD, Traefik and L4 | Rendered output holds no tag-only image | planned |
| P4 | Registry up; bundle pushed with ORAS | Registry digest equals the digest Nix recorded | planned |
| P5 | Argo CD bootstrapped; root Application or ApplicationSet with sync waves | Every Application Synced and Healthy | planned |
| P6 | cert-manager, 1Password operator, Traefik, ExternalDNS as Applications; DNS-01 issuer | `Certificate` Ready for the NetBird host | planned |
| P7 | NetBird server and dashboard Application | `/health` returns 200; dashboard `/setup` loads over HTTPS | planned |
| P8 | Client enrolled | `netbird status` Connected; NetBird.app shows Connected | operator |

Optional interim lane: the same pinned NetBird images under Docker Compose or
a Quadlet on loopback, retired when P7 passes. Not started; needs an explicit
operator decision because it runs outside the Nix configuration.

## Supply-chain gates

- Charts and release manifests: `fetchurl` with a fixed sha256 (existing pattern).
- Images: digest only. Rendering fails on a null digest (existing `require`).
- Bundles: Argo CD references the ORAS digest, never a tag.
- Nix inputs: `flake.lock`; `vulnix` on the system closure.
- PyPI (collector run 2026-11-21, commit `e73e797b5100`): 3 direct development
  dependencies, 0 known advisories, 2 maintenance flags (`cognitive-complexity`,
  `radon`). No lockfile, so the transitive tree was not examined. Report kept
  outside Git at `.cache/supply-chain-audit/report.md`.
- Open item S1: that collector reads npm, PyPI and Go only. Nix inputs, Helm
  charts, OCI images and OpenTofu providers are not assessed by it. A scanner
  for those ecosystems is not selected.

## Risks

- `homelab.enable` couples runtimes, host daemons and operators through one
  assertion set. P1 must split it without weakening any assertion.
- STUN on UDP 3478 through OrbStack Kubernetes is untested. Verify at P7.
- A LAN address in a public A record discloses that address.
- The DNS-01 token needs DNS edit on one zone only. A wider token is a defect.
- An R2 bucket named `platform-tofu-state` is referenced in
  `docs/operations/offsite-restic.md`. If it holds state for this zone, the
  new module must reuse or import it, not start a second state.
- NetBird uses SQLite on one volume. Back up the volume and keep the store
  encryption key in 1Password before real peers enroll.

## Planned change set

- `homelab/config.nix`, `home/container-runtimes.nix`,
  `hosts/mac-studio/homelab-services.nix`, `homelab/kubernetes.nix`,
  `homelab/netbird-server.nix`
- New: Argo CD and Traefik render modules, ORAS bundle derivation, bootstrap
  script, OpenTofu module for Cloudflare (zone settings, token scopes, static
  records)
- `PLAN.md`, `FEATURES.md`, `TASKS.csv` when a status changes; untouched now

## Verification

```bash
make verify-harness
DEVENV_USER="$USER" nix flake check --impure --all-systems --no-build
```

Nix evaluation and builds run through the operator or the approved builder.
