# Exec plan: platform prerequisites, then local NetBird

Status: in progress — P1 and the D2 issuer are implemented (evaluation only;
no activation, nothing applied to a cluster)  
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
| L4 | cert-manager 1.21.3, 1Password operator (chart 2.4.3), ExternalDNS 1.24.0 | Argo CD Applications | Rendered by `homelab/kubernetes.nix` into `/etc/mac-environment/kubernetes`; all image digests pinned 2026-11-22 (index digests); nothing applies them | Sync order; 1Password items (I4) |
| L4 | Traefik | Argo CD Application | Rendered by `homelab/kubernetes.nix`: chart 42.4.1 (fetchurl, fixed sha256), traefik v3.7.19 index digest pinned; D6 recorded | Not applied; Argo CD transport (D4) unbuilt |
| L5 | DNS and TLS | OpenTofu and ExternalDNS; cert-manager | Cloudflare ExternalDNS rendered when enabled; `cloudflare-dns01` ClusterIssuer (D2) rendered when enabled; NetBird Ingresses reference it | Zone unset; OpenTofu module and state backend; ACME email unset |
| L6 | NetBird server and dashboard | Argo CD Application | `homelab/netbird-server.nix`, off | managementUrl, proxy CIDRs and both image digests set 2026-11-22 (CIDR is the k3s default, verify at P2); 1Password credentials item still open |
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
| D6 | Ingress controller for the NetBird host | Traefik on OrbStack Kubernetes (`ingressClassName: traefik`), terminating TLS with certificates issued by cert-manager via Cloudflare DNS-01 (D2) | NetBird v0.83.1's own deployment targets Traefik, and the rendered Ingresses already carry the h2c annotation for gRPC. Alternatives considered and rejected 2026-11-22: Cilium CNI + Envoy would replace Flannel, which OrbStack documents as unsupported on its managed cluster and conflicts with D1; standalone Envoy Gateway would add a second controller, a cert-manager gateway-shim patch and new digest pins with no workload needing Envoy's L7 features. Revisit D6 only when such a workload appears |

## Inputs required (operator)

| ID | Input | Blocks |
| --- | --- | --- |
| I1 | Path or URL of the existing Argo CD and Helm code, and of any existing OpenTofu code with its state backend | L3 and L5 design; reuse instead of rewrite — provided 2026-11-22: `/Users/glam/Git/guillermolam/personal-platform`. Reusable: Argo CD chart pin `10.11.6` (`bootstrap/orbstack/opentofu/argocd.tf`), `oras-provisioner` chart (`bootstrap/orbstack/opentofu/charts/oras-provisioner/`, D4), cert-manager DNS-01 OrbStack resolver workaround (`cert-manager.tf`, adopted), ZeroSSL+Cloudflare DNS-01 issuer pattern (`charts/zerossl-issuer/`), R2 state backend `platform-tofu-state` (`infra/live/prod/cloudflare/cloud.hcl`), `cloudflare-dns-sync.sh`, seed scripts, NetBird API tofu (`ztna/netbird/tofu/`). Divergences: its lab is KIND+Cilium Gateway API (not this plan's OrbStack-managed+Traefik, D1/D6 stand); it has no ExternalDNS and no 1Password Connect server |
| I2 | Cloudflare zone and NetBird hostname | L5, L6 — provided 2026-11-22: zone `lamcloud.net`, host `netbird.lamcloud.net` |
| I3 | Reach: loopback only, or the Mac's LAN address | A record target; OrbStack exposure — provided 2026-11-22: LAN address (`10.0.0.5`, DHCP lease; reserve statically); `kubernetes.exposeServicesToLan` declared |
| I4 | 1Password Connect host and item paths (Cloudflare token, NetBird credentials) | L4, L5, L6 |
| I5 | Where agent edits and Nix evaluation run (OpenShell sandbox or approved builder) | Every phase |

## Phases

| Phase | Outcome | Evidence of done | Status |
| --- | --- | --- | --- |
| P0 | I1–I5 recorded; non-secret values in `homelab/config.nix` | Config diff reviewed | partial — I2 and I3 recorded in `homelab/config.nix` 2026-11-22; I1, I4, I5 still waiting on operator |
| P1 | Staged flags: runtimes, Kubernetes and GitOps independent of `homelab.enable` | `nix flake check --impure --all-systems --no-build` passes | implemented 2026-11-22 (evaluation only; `stages.kubernetes`, `stages.gitops`; kubectl/helm/oras/argocd/tofu declared per stage; OrbStack `k8s.enabled` reconciled per stage; not activated) |
| P2 | OrbStack Kubernetes reconciled on; CLIs declared | Operator switch; `kubectl get nodes` Ready | planned |
| P3 | Chart hashes and image digests pinned for Argo CD, Traefik and L4 | Rendered output holds no tag-only image | mostly done 2026-11-22 — Traefik chart 42.4.1 (fixed sha256); index digests pinned for traefik v3.7.19, cert-manager v1.21.3 (5 images), ExternalDNS v0.24.0, 1Password operator 1.12.1, netbird-server 0.83.1, dashboard v2.96.0; proof build renders every image digest-pinned (0 tag-only refs); fixed latent bug: charts were rendered with `--set-json values=…`, which sets a literal `values` key instead of injecting the values file — all four renders now use `-f` (Traefik's values.schema.json exposed the bug); Argo CD chart pin still open |
| P4 | Registry up; bundle pushed with ORAS | Registry digest equals the digest Nix recorded | planned |
| P5 | Argo CD bootstrapped; root Application or ApplicationSet with sync waves | Every Application Synced and Healthy | planned |
| P6 | cert-manager, 1Password operator, Traefik, ExternalDNS as Applications; DNS-01 issuer | `Certificate` Ready for the NetBird host | planned (the `cloudflare-dns01` issuer manifest landed in `homelab/kubernetes.nix` 2026-11-22; cert-manager now carries the OrbStack DNS-01 recursive-resolver workaround from I1; Traefik rendered ClusterIP per the exposure warning; DNS writer conflict needs an operator call) |
| P7 | NetBird server and dashboard Application | `/health` returns 200; dashboard `/setup` loads over HTTPS | planned |
| P8 | Client enrolled | `netbird status` Connected; NetBird.app shows Connected | operator |
| P9 | NetBird federated with two external OIDC IdPs for failover — Casdoor (lab) and Clerk (SaaS) — via OpenTofu (personal-platform `ztna/netbird/tofu/identity-provider`, provider netbirdio/netbird 0.0.11) | `netbird-tofu identity-provider plan` shows both providers; `active` output read-back matches | module implemented 2026-11-22 (fmt, validate, 6 mock tests pass). Docs (2026-11-12) confirm multiple IdPs render as login buttons and local auth stays as last resort — failover is user-selected, not automatic. Waiting on: real Casdoor issuer URL, Clerk instance issuer, both confidential clients registered with the `/nb-auth` + `/nb-silent-auth` redirect URIs, NB_PAT after P7 |

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
- A LAN address in a public A record discloses that address. Accepted by the
  operator 2026-11-22 (I3); reserve `10.0.0.5` as a static DHCP lease so the
  ExternalDNS record does not drift.
- The DNS-01 token needs DNS edit on one zone only. A wider token is a defect.
- An R2 bucket named `platform-tofu-state` is referenced in
  `docs/operations/offsite-restic.md`. If it holds state for this zone, the
  new module must reuse or import it, not start a second state.
- NetBird uses SQLite on one volume. Back up the volume and keep the store
  encryption key in 1Password before real peers enroll.
- Observed by the operator in personal-platform (2026-11-22): OrbStack's
  LoadBalancer opened listeners on all Mac interfaces even with
  `k8s.expose_services` off. Until P7 re-verifies this, Traefik renders as
  `ClusterIP` (`homelab.kubernetes.traefikServiceType`) and
  `exposeServicesToLan` stays false. LAN reach for `netbird.lamcloud.net`
  is re-decided at P7 (LAN listener vs. the macos-cloudflare tunnel work).
- The identity-provider tofu module keeps local state, which contains the
  OIDC `client_secret`. Keep the state 0600 and move the module to the R2
  `platform-tofu-state` backend before real users depend on it.
- DNS writer conflict (D5): personal-platform's `cloudflare-dns-sync.sh`
  already upserts `*.lamcloud.net` records. One writer per record: either
  exclude `netbird.lamcloud.net` from that script's inputs or drop the
  public DNSEndpoint from `homelab/config.nix` before enabling
  `cloudflare.enable`. Operator decision required at P6.

## Planned change set

- `homelab/config.nix`, `home/container-runtimes.nix`,
  `hosts/mac-studio/homelab-services.nix`, `homelab/kubernetes.nix`,
  `homelab/netbird-server.nix`
- New: Argo CD render module (chart `10.11.6` candidate from I1), ORAS bundle
  derivation (reuse the personal-platform `oras-provisioner` chart), bootstrap
  script, OpenTofu module for Cloudflare (zone settings, token scopes, static
  records; reuse the R2 `platform-tofu-state` backend)
- Landed 2026-11-22: `netbird-tofu` wrapper (flake package, mutating verbs
  behind `NETBIRD_TOFU_CONFIRM=1`, secrets via `op run --env-file=op.env`);
  NetBird identity-provider OpenTofu module in personal-platform
  (`ztna/netbird/tofu/identity-provider/`, with tests and op.env.example)
- `PLAN.md`, `FEATURES.md`, `TASKS.csv` when a status changes; untouched now

## Verification

```bash
make verify-harness
DEVENV_USER="$USER" nix flake check --impure --all-systems --no-build
```

Nix evaluation and builds run through the operator or the approved builder.
