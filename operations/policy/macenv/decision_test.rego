package macenv.decision_test

import data.macenv.decision
import rego.v1

now := "2026-11-19T03:30:00+00:00"

clean_entry := {
	"status": "ok",
	"observed_at": now,
	"findings": [],
	"critical": 0,
}

clean_collectors := {name: clean_entry |
	some name in ["access", "firewall", "integrity", "tooling", "vulnix"]
}

defaults := {"schema_version": 1, "updates": {
	"default_tool_mode": "manual",
	"allow_reboot": false,
	"allow_major": false,
	"allow_removals": false,
	"require_rollback": true,
	"require_ac_power": true,
	"max_evidence_age_seconds": 86400,
	"max_backup_age_seconds": 86400,
	"max_new_findings": 0,
	"max_critical": 0,
	"min_free_bytes": 10,
	"maintenance_start": "03:00",
	"maintenance_end": "05:00",
}, "tools": {}}

adapter := {
	"can_scan_candidate": true,
	"can_rollback": true,
	"can_unattended": true,
	"can_constrain_dependencies": true,
	"estimated_bytes": 1,
}

host := {
	"ac_power": true,
	"free_bytes": 100,
	"local_time": "03:30",
	"last_verified_backup_at": now,
}

test_backup_allow if {
	decision.decision.outcome == "allow" with input as {
		"operation": "backup_eligibility",
		"now": now,
		"evidence": clean_collectors,
		"baseline": clean_collectors,
		"max_age_seconds": 86400,
	}
}

test_backup_new_finding_identity if {
	current := object.union(clean_collectors, {"vulnix": object.union(clean_entry, {"findings": ["CVE-new"]})})
	baseline := object.union(clean_collectors, {"vulnix": object.union(clean_entry, {"findings": ["CVE-old"]})})
	decision.decision.outcome == "block" with input as {
		"operation": "backup_eligibility",
		"now": now,
		"evidence": current,
		"baseline": baseline,
	}
}

test_auto_does_not_bypass_security if {
	result := decision.decision with input as object.union(update_base, {"policy_layers": object.union(update_base.policy_layers, {"tool": {"tools": {"brew:formula:git": {"mode": "auto"}}}})})
	result.outcome == "block"
	some reason in result.reasons
	contains(reason, "new findings")
}

test_hold_beats_auto if {
	layers := {
		"defaults": defaults,
		"shared": {"tools": {"brew:formula:git": {"mode": "hold"}}},
		"tool": {"tools": {"brew:formula:git": {"mode": "auto"}}},
	}
	result := decision.decision with input as object.union(update_base, {"policy_layers": layers, "evidence": clean_collectors, "candidate_security": {"vulnix": clean_entry}})
	result.outcome == "block"
	some reason in result.reasons
	contains(reason, "held")
}

test_manual_is_not_unattended if {
	result := decision.decision with input as object.union(update_base, {"evidence": clean_collectors, "candidate_security": {"vulnix": clean_entry}})
	result.outcome == "defer"
	some reason in result.reasons
	contains(reason, "manual approval required")
}

test_candidate_cannot_authorize_itself if {
	result := decision.decision with input as object.union(update_base, {"candidate_supplies_policy": true})
	result.outcome == "block"
	some reason in result.reasons
	contains(reason, "cannot authorize itself")
}

test_candidate_security_status_blocks if {
	result := decision.decision with input as object.union(update_base, {
		"evidence": clean_collectors,
		"baseline": clean_collectors,
		"candidate_security": {"vulnix": object.union(clean_entry, {"status": "error"})},
	})
	result.outcome == "block"
	some reason in result.reasons
	contains(reason, "candidate security evidence incomplete")
}

test_candidate_security_stale_blocks if {
	result := decision.decision with input as object.union(update_base, {
		"evidence": clean_collectors,
		"baseline": clean_collectors,
		"candidate_security": {"vulnix": object.union(clean_entry, {"observed_at": "2026-11-01T00:00:00Z"})},
	})
	result.outcome == "block"
	some reason in result.reasons
	contains(reason, "candidate security evidence is stale")
}

test_tool_layer_max_age_beats_channel if {
	layers := {
		"defaults": defaults,
		"channel": {"updates": {"max_evidence_age_seconds": 86400}},
		"tool": {"updates": {"max_evidence_age_seconds": 60}},
	}
	stale := object.union(clean_entry, {"observed_at": "2026-11-19T03:00:00+00:00"})
	result := decision.decision with input as object.union(update_base, {
		"policy_layers": layers,
		"evidence": object.union(clean_collectors, {"vulnix": stale}),
		"baseline": clean_collectors,
		"candidate_security": {"vulnix": clean_entry},
	})
	result.outcome == "block"
	some reason in result.reasons
	contains(reason, "stale")
}

test_max_new_findings_allows_configured_introductions if {
	layers := {"defaults": object.union(defaults, {"updates": object.union(defaults.updates, {"max_new_findings": 1})})}
	result := decision.decision with input as object.union(update_base, {
		"policy_layers": layers,
		"evidence": clean_collectors,
		"baseline": clean_collectors,
		"candidate_security": {"vulnix": object.union(clean_entry, {"findings": ["CVE-new"]})},
		"initiated": "manual",
	})
	not "update introduces findings" in result.reasons
}

update_base := {
	"operation": "update",
	"now": now,
	"initiated": "scheduled",
	"evidence": object.union(clean_collectors, {"vulnix": object.union(clean_entry, {"findings": ["CVE-new"]})}),
	"baseline": object.union(clean_collectors, {"vulnix": object.union(clean_entry, {"findings": ["CVE-old"]})}),
	"candidate_security": {"vulnix": object.union(clean_entry, {"findings": ["CVE-new"]})},
	"candidate_supplies_policy": false,
	"policy_fingerprint_matches": true,
	"saved_plan_fingerprint": "",
	"host": host,
	"policy_layers": {"defaults": defaults},
	"candidate": {
		"channel": "homebrew",
		"fingerprint": "abc",
		"requires_reboot": false,
		"tools": [{"id": "brew:formula:git", "change": "upgrade", "version": "2", "major": false}],
		"dependencies": [],
		"removals": [],
		"runtime_closure_changed": [],
		"adapter": adapter,
	},
}
