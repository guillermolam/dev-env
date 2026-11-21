import unittest

from mac_env.provision_plan import REQUIRES, load_plan, next_action


def facts(**overrides):
    base = {
        "nix_built": False,
        "runtime_up": False,
        "homelab_enabled": False,
        "digests_pinned": False,
        "cluster_ready": False,
        "linux_node": False,
        "cloud_account": False,
    }
    base.update(overrides)
    return base


def row(plan_id):
    return next(item for item in load_plan() if item["id"] == plan_id)


class ProvisionPlanTests(unittest.TestCase):
    def test_ids_and_whens(self):
        rows = load_plan()
        ids = [item["id"] for item in rows]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(all(item["when"] in REQUIRES for item in rows))

    def test_cli_is_nix_once_built(self):
        got = next_action(row("cli.nixpkgs"), facts(nix_built=True))
        self.assertEqual(got["technology"], "nix")
        self.assertTrue(got["allowed"])

    def test_cli_waits_for_nix(self):
        got = next_action(row("cli.nixpkgs"), facts())
        self.assertEqual(got["gap"], "nix_built")
        self.assertFalse(got["allowed"])

    def test_podman_playbook_waits_for_runtime(self):
        got = next_action(row("hypervisor.podman"), facts(nix_built=True))
        self.assertEqual(got["technology"], "podman")
        self.assertEqual(got["gap"], "runtime_up")

    def test_podman_playbook_runs_when_up(self):
        got = next_action(row("container.podman"), facts(nix_built=True, runtime_up=True))
        self.assertTrue(got["allowed"])
        self.assertEqual(got["technology"], "podman")

    def test_helm_blocked_by_homelab(self):
        got = next_action(row("helm.external-dns"), facts(nix_built=True))
        self.assertEqual(got["technology"], "helm")
        self.assertEqual(got["gap"], "homelab_enabled")

    def test_helm_allowed_when_cluster_facts_hold(self):
        got = next_action(
            row("helm.external-dns"),
            facts(
                nix_built=True,
                homelab_enabled=True,
                digests_pinned=True,
                cluster_ready=True,
            ),
        )
        self.assertTrue(got["allowed"])

    def test_crio_and_cilium_wait_for_linux(self):
        ready = facts(nix_built=True)
        self.assertEqual(next_action(row("runtime.crio"), ready)["gap"], "linux_node")
        self.assertEqual(next_action(row("cni.cilium"), ready)["gap"], "linux_node")

    def test_r2_is_opentofu_after_account(self):
        blocked = next_action(row("cloud.r2"), facts())
        allowed = next_action(row("cloud.r2"), facts(cloud_account=True))
        self.assertEqual(blocked["gap"], "cloud_account")
        self.assertEqual(allowed["technology"], "opentofu")
        self.assertTrue(allowed["allowed"])

    def test_unknown_when_rejected(self):
        with self.assertRaises(ValueError):
            next_action({"id": "x", "when": "soon", "then": "helm"}, facts())
