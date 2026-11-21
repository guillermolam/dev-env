package macenv.decision

import rego.v1

required_collectors := ["access", "firewall", "integrity", "tooling", "vulnix"]

default decision := {
	"outcome": "block",
	"eligible": false,
	"reasons": ["MACENV-000: no decision"],
	"rule_ids": ["MACENV-000"],
	"affected_tools": [],
}

decision := {
	"outcome": backup_outcome,
	"eligible": backup_outcome == "allow",
	"reasons": sort([item.reason | some item in backup_issues]),
	"rule_ids": sort([item.id | some item in backup_issues]),
	"affected_tools": [],
} if {
	input.operation == "backup_eligibility"
}

decision := {
	"outcome": update_outcome,
	"eligible": update_outcome == "allow",
	"reasons": sort([item.reason | some item in update_issues]),
	"rule_ids": sort([item.id | some item in update_issues]),
	"affected_tools": sort([id | some id in candidate_ids]),
} if {
	input.operation == "update"
}

backup_outcome := "block" if count(backup_issues) > 0

backup_outcome := "allow" if count(backup_issues) == 0

update_outcome := "block" if {
	some item in update_issues
	item.severity == "block"
} else := "defer" if {
	some item in update_issues
	item.severity == "defer"
} else := "allow"

layers := object.get(input, "policy_layers", {}) if is_object(object.get(input, "policy_layers", {}))

layers := {} if not is_object(object.get(input, "policy_layers", {}))

updates_of(name) := object.get(object.get(layers, name, {}), "updates", {})

tools_of(name) := object.get(object.get(layers, name, {}), "tools", {})

exceptions_of(name) := object.get(object.get(layers, name, {}), "exceptions", [])

max_evidence_age := input.max_age_seconds if {
	is_number(input.max_age_seconds)
	input.max_age_seconds >= 0
	input.max_age_seconds == floor(input.max_age_seconds)
} else := effective_number("max_evidence_age_seconds", 86400)

max_backup_age := effective_number("max_backup_age_seconds", 86400)

max_new_findings := effective_number("max_new_findings", 0)

max_critical := effective_number("max_critical", 0)

# Precedence matches resolved_mode / pin_for: tool > channel > host > shared > defaults.
effective_number(key, fallback) := updates_of("tool")[key] if {
	is_number(updates_of("tool")[key])
} else := updates_of("channel")[key] if {
	is_number(updates_of("channel")[key])
} else := updates_of("host")[key] if {
	is_number(updates_of("host")[key])
} else := updates_of("shared")[key] if {
	is_number(updates_of("shared")[key])
} else := updates_of("defaults")[key] if {
	is_number(updates_of("defaults")[key])
} else := fallback

effective_bool(key, fallback) := updates_of("tool")[key] if {
	is_boolean(updates_of("tool")[key])
} else := updates_of("channel")[key] if {
	is_boolean(updates_of("channel")[key])
} else := updates_of("host")[key] if {
	is_boolean(updates_of("host")[key])
} else := updates_of("shared")[key] if {
	is_boolean(updates_of("shared")[key])
} else := updates_of("defaults")[key] if {
	is_boolean(updates_of("defaults")[key])
} else := fallback

effective_string(key, fallback) := updates_of("tool")[key] if {
	is_string(updates_of("tool")[key])
} else := updates_of("channel")[key] if {
	is_string(updates_of("channel")[key])
} else := updates_of("host")[key] if {
	is_string(updates_of("host")[key])
} else := updates_of("shared")[key] if {
	is_string(updates_of("shared")[key])
} else := updates_of("defaults")[key] if {
	is_string(updates_of("defaults")[key])
} else := fallback

rfc3339(value) if {
	is_string(value)
	regex.match(`^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$`, value)
}

within_age(timestamp, limit) if {
	rfc3339(timestamp)
	rfc3339(input.now)
	is_number(limit)
	age := (time.parse_rfc3339_ns(input.now) - time.parse_rfc3339_ns(timestamp)) / 1000000000
	age >= 0
	age <= limit
}

has_baseline if is_object(input.baseline)

well_formed(document, name) if {
	is_object(document)
	entry := document[name]
	is_object(entry)
	is_string(entry.status)
	is_array(entry.findings)
	every item in entry.findings {
		is_string(item)
		item != ""
	}
	is_number(entry.critical)
	entry.critical >= 0
	entry.critical == floor(entry.critical)
	rfc3339(entry.observed_at)
}

backup_issues contains {
	"id": "MACENV-BASELINE",
	"severity": "block",
	"reason": "No explicitly approved baseline",
} if {
	not has_baseline
}

backup_issues contains {
	"id": sprintf("MACENV-EVIDENCE-MISSING:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: missing or invalid evidence", [name]),
} if {
	some name in required_collectors
	not well_formed(input.evidence, name)
}

backup_issues contains {
	"id": sprintf("MACENV-EVIDENCE-BASELINE:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: missing or invalid evidence", [name]),
} if {
	has_baseline
	some name in required_collectors
	not well_formed(input.baseline, name)
}

backup_issues contains {
	"id": sprintf("MACENV-EVIDENCE-INCOMPLETE:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: incomplete collector", [name]),
} if {
	some name in required_collectors
	well_formed(input.evidence, name)
	input.evidence[name].status != "ok"
}

backup_issues contains {
	"id": sprintf("MACENV-EVIDENCE-INCOMPLETE-BASELINE:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: incomplete collector", [name]),
} if {
	has_baseline
	some name in required_collectors
	well_formed(input.baseline, name)
	input.baseline[name].status != "ok"
}

backup_issues contains {
	"id": sprintf("MACENV-STALE:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: stale or future evidence", [name]),
} if {
	some name in required_collectors
	well_formed(input.evidence, name)
	not within_age(input.evidence[name].observed_at, max_evidence_age)
}

backup_issues contains {
	"id": sprintf("MACENV-DB-STALE:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: advisory database is stale or unverified", [name]),
} if {
	some name in required_collectors
	well_formed(input.evidence, name)
	database_time := object.get(input.evidence[name], "database_observed_at", "")
	database_time != ""
	not within_age(database_time, max_evidence_age)
}

new_evidence_findings(name) := {item |
	some item in input.evidence[name].findings
	not item in input.baseline[name].findings
	not exception_covers(sprintf("finding:%s", [item]))
}

backup_issues contains {
	"id": sprintf("MACENV-NEW:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: new findings", [name]),
} if {
	has_baseline
	some name in required_collectors
	well_formed(input.evidence, name)
	well_formed(input.baseline, name)
	count(new_evidence_findings(name)) > max_new_findings
}

backup_issues contains {
	"id": sprintf("MACENV-CRITICAL:%s", [name]),
	"severity": "block",
	"reason": sprintf("%s: critical findings exceed limit", [name]),
} if {
	some name in required_collectors
	well_formed(input.evidence, name)
	input.evidence[name].critical > max_critical
}

backup_issues contains {
	"id": "MACENV-ACCESS",
	"severity": "block",
	"reason": "access: unresolved suspicious activity",
} if {
	well_formed(input.evidence, "access")
	count(input.evidence.access.findings) > 0
}

backup_issues contains {
	"id": "MACENV-NOW",
	"severity": "block",
	"reason": "observation time missing",
} if {
	not rfc3339(input.now)
}

exception_covers(scope) if {
	some layer in ["defaults", "shared", "host", "channel", "tool"]
	some item in exceptions_of(layer)
	item.scope == scope
	is_string(item.reason)
	item.reason != ""
	is_string(item.approver)
	item.approver != ""
	rfc3339(item.expires_at)
	rfc3339(input.now)
	time.parse_rfc3339_ns(item.expires_at) > time.parse_rfc3339_ns(input.now)
}

candidate_ids contains tool.id if {
	is_object(input.candidate)
	some tool in object.get(input.candidate, "tools", [])
	is_string(tool.id)
	tool.id != ""
}

candidate_ids contains id if {
	is_object(input.candidate)
	some field in ["dependencies", "removals", "runtime_closure_changed"]
	some id in object.get(input.candidate, field, [])
	is_string(id)
	id != ""
}

held_ids contains id if {
	some layer in ["defaults", "shared", "host", "channel", "tool"]
	some id, spec in tools_of(layer)
	is_object(spec)
	spec.mode == "hold"
}

held_ids contains id if {
	some layer in ["defaults", "shared", "host", "channel", "tool"]
	updates_of(layer).default_tool_mode == "hold"
	some id in candidate_ids
}

tool_mode_at(layer, id) := tools_of(layer)[id].mode if {
	tools_of(layer)[id].mode != ""
}

default_tool_mode := updates_of("tool").default_tool_mode if {
	updates_of("tool").default_tool_mode != ""
} else := updates_of("channel").default_tool_mode if {
	updates_of("channel").default_tool_mode != ""
} else := updates_of("host").default_tool_mode if {
	updates_of("host").default_tool_mode != ""
} else := updates_of("shared").default_tool_mode if {
	updates_of("shared").default_tool_mode != ""
} else := updates_of("defaults").default_tool_mode if {
	updates_of("defaults").default_tool_mode != ""
} else := "manual"

resolved_mode(id) := "hold" if {
	id in held_ids
} else := tool_mode_at("tool", id) if {
	tool_mode_at("tool", id)
} else := tool_mode_at("channel", id) if {
	tool_mode_at("channel", id)
} else := tool_mode_at("host", id) if {
	tool_mode_at("host", id)
} else := tool_mode_at("shared", id) if {
	tool_mode_at("shared", id)
} else := tool_mode_at("defaults", id) if {
	tool_mode_at("defaults", id)
} else := default_tool_mode

pin_for(id) := tools_of("tool")[id].pin if {
	is_string(tools_of("tool")[id].pin)
	tools_of("tool")[id].pin != ""
} else := tools_of("channel")[id].pin if {
	is_string(tools_of("channel")[id].pin)
	tools_of("channel")[id].pin != ""
} else := tools_of("host")[id].pin if {
	is_string(tools_of("host")[id].pin)
	tools_of("host")[id].pin != ""
} else := tools_of("shared")[id].pin if {
	is_string(tools_of("shared")[id].pin)
	tools_of("shared")[id].pin != ""
} else := tools_of("defaults")[id].pin if {
	is_string(tools_of("defaults")[id].pin)
	tools_of("defaults")[id].pin != ""
} else := ""

allow_major(id) := tools_of("tool")[id].allow_major if {
	is_boolean(tools_of("tool")[id].allow_major)
} else := effective_bool("allow_major", false)

update_issues contains item if {
	some item in backup_issues
}

update_issues contains {
	"id": "MACENV-BASELINE",
	"severity": "block",
	"reason": "No explicitly approved baseline",
} if {
	not has_baseline
}

update_issues contains {
	"id": "MACENV-CANDIDATE-POLICY",
	"severity": "block",
	"reason": "candidate policy cannot authorize itself",
} if {
	input.candidate_supplies_policy == true
}

update_issues contains {
	"id": "MACENV-POLICY-FINGERPRINT",
	"severity": "block",
	"reason": "policy fingerprint mismatch",
} if {
	input.policy_fingerprint_matches == false
}

update_issues contains {
	"id": "MACENV-PLAN-FINGERPRINT",
	"severity": "block",
	"reason": "saved plan does not match candidate",
} if {
	is_string(input.saved_plan_fingerprint)
	input.saved_plan_fingerprint != ""
	input.saved_plan_fingerprint != object.get(input.candidate, "fingerprint", "")
}

update_issues contains {
	"id": "MACENV-INITIATION",
	"severity": "block",
	"reason": "initiation mode missing",
} if {
	not input.initiated in {"scheduled", "manual"}
}

update_issues contains {
	"id": "MACENV-CANDIDATE-MISSING",
	"severity": "block",
	"reason": "candidate missing",
} if {
	not is_object(input.candidate)
}

update_issues contains {
	"id": "MACENV-SCHEMA",
	"severity": "block",
	"reason": "unsupported policy schema",
} if {
	object.get(object.get(layers, "defaults", {}), "schema_version", 0) != 1
}

update_issues contains {
	"id": "MACENV-DEPS-UNKNOWN",
	"severity": "block",
	"reason": "dependency set unknown",
} if {
	is_object(input.candidate)
	not is_array(object.get(input.candidate, "dependencies", null))
}

update_issues contains {
	"id": "MACENV-CLOSURE-UNKNOWN",
	"severity": "block",
	"reason": "runtime closure diff unknown",
} if {
	is_object(input.candidate)
	not is_array(object.get(input.candidate, "runtime_closure_changed", null))
}

update_issues contains {
	"id": "MACENV-NIX-HOLD",
	"severity": "block",
	"reason": "nix hold cannot be enforced by this adapter",
} if {
	object.get(input.candidate, "channel", "") == "nix"
	object.get(object.get(input.candidate, "adapter", {}), "can_constrain_dependencies", false) != true
	some id in held_ids
	startswith(id, "nix:")
}

update_issues contains {
	"id": sprintf("MACENV-HOLD:%s", [id]),
	"severity": "block",
	"reason": sprintf("%s: held; remove the hold explicitly before updating", [id]),
} if {
	some id in candidate_ids
	resolved_mode(id) == "hold"
}

update_issues contains {
	"id": sprintf("MACENV-MANUAL:%s", [id]),
	"severity": "defer",
	"reason": sprintf("%s: manual approval required", [id]),
} if {
	input.initiated == "scheduled"
	some id in candidate_ids
	resolved_mode(id) == "manual"
}

update_issues contains {
	"id": sprintf("MACENV-PIN:%s", [id]),
	"severity": "block",
	"reason": sprintf("%s: pinned version does not match candidate", [id]),
} if {
	some tool in object.get(input.candidate, "tools", [])
	id := tool.id
	pin_for(id) != ""
	object.get(tool, "version", "") != pin_for(id)
}

update_issues contains {
	"id": "MACENV-REBOOT",
	"severity": "defer",
	"reason": "restart required and automatic restart is disabled",
} if {
	object.get(input.candidate, "requires_reboot", false) == true
	effective_bool("allow_reboot", false) != true
}

update_issues contains {
	"id": sprintf("MACENV-MAJOR:%s", [id]),
	"severity": "defer",
	"reason": sprintf("%s: major upgrade is not enabled for unattended execution", [id]),
} if {
	input.initiated == "scheduled"
	some tool in object.get(input.candidate, "tools", [])
	tool.major == true
	id := tool.id
	allow_major(id) != true
}

update_issues contains {
	"id": "MACENV-REMOVAL",
	"severity": "defer",
	"reason": "removals are not enabled for unattended execution",
} if {
	input.initiated == "scheduled"
	effective_bool("allow_removals", false) != true
	count(object.get(input.candidate, "removals", [])) > 0
}

update_issues contains {
	"id": "MACENV-SCAN",
	"severity": "block",
	"reason": "candidate scan unsupported",
} if {
	object.get(object.get(input.candidate, "adapter", {}), "can_scan_candidate", false) != true
}

update_issues contains {
	"id": "MACENV-ROLLBACK",
	"severity": "block",
	"reason": "rollback capability required but not available",
} if {
	effective_bool("require_rollback", true) == true
	object.get(object.get(input.candidate, "adapter", {}), "can_rollback", false) != true
}

update_issues contains {
	"id": "MACENV-UNATTENDED",
	"severity": "block",
	"reason": "adapter cannot apply this change unattended",
} if {
	input.initiated == "scheduled"
	object.get(object.get(input.candidate, "adapter", {}), "can_unattended", false) != true
}

update_issues contains {
	"id": "MACENV-CANDIDATE-SECURITY",
	"severity": "block",
	"reason": "candidate security evidence missing",
} if {
	not well_formed(input.candidate_security, "vulnix")
}

update_issues contains {
	"id": "MACENV-CANDIDATE-SECURITY-STATUS",
	"severity": "block",
	"reason": "candidate security evidence incomplete",
} if {
	well_formed(input.candidate_security, "vulnix")
	input.candidate_security.vulnix.status != "ok"
}

update_issues contains {
	"id": "MACENV-CANDIDATE-SECURITY-STALE",
	"severity": "block",
	"reason": "candidate security evidence is stale or future",
} if {
	well_formed(input.candidate_security, "vulnix")
	not within_age(input.candidate_security.vulnix.observed_at, max_evidence_age)
}

update_issues contains {
	"id": "MACENV-CANDIDATE-DB-STALE",
	"severity": "block",
	"reason": "candidate advisory database is stale or unverified",
} if {
	well_formed(input.candidate_security, "vulnix")
	database_time := object.get(input.candidate_security.vulnix, "database_observed_at", "")
	database_time != ""
	not within_age(database_time, max_evidence_age)
}

introduced_findings := {item |
	some item in input.candidate_security.vulnix.findings
	not item in input.evidence.vulnix.findings
	not exception_covers(sprintf("finding:%s", [item]))
}

update_issues contains {
	"id": "MACENV-INTRODUCED",
	"severity": "block",
	"reason": "update introduces findings",
} if {
	well_formed(input.evidence, "vulnix")
	well_formed(input.candidate_security, "vulnix")
	count(introduced_findings) > max_new_findings
}

update_issues contains {
	"id": "MACENV-CANDIDATE-CRITICAL",
	"severity": "block",
	"reason": "candidate critical findings exceed limit",
} if {
	well_formed(input.candidate_security, "vulnix")
	input.candidate_security.vulnix.critical > max_critical
}

update_issues contains {
	"id": "MACENV-BACKUP-AGE",
	"severity": "block",
	"reason": "verified backup is missing or stale",
} if {
	not within_age(object.get(object.get(input, "host", {}), "last_verified_backup_at", ""), max_backup_age)
}

update_issues contains {
	"id": "MACENV-WINDOW",
	"severity": "defer",
	"reason": "outside maintenance window",
} if {
	input.initiated == "scheduled"
	not in_window
}

update_issues contains {
	"id": "MACENV-POWER",
	"severity": "defer",
	"reason": "AC power required",
} if {
	input.initiated == "scheduled"
	effective_bool("require_ac_power", true) == true
	object.get(object.get(input, "host", {}), "ac_power", false) != true
}

update_issues contains {
	"id": "MACENV-DISK",
	"severity": "block",
	"reason": "insufficient or unknown free disk",
} if {
	not enough_disk
}

update_issues contains {
	"id": "MACENV-PERMANENT-EXCEPTION",
	"severity": "block",
	"reason": "permanent exception rejected",
} if {
	some layer in ["defaults", "shared", "host", "channel", "tool"]
	some item in exceptions_of(layer)
	not rfc3339(object.get(item, "expires_at", ""))
}

in_window if {
	start := effective_string("maintenance_start", "03:00")
	end := effective_string("maintenance_end", "05:00")
	local_time := object.get(object.get(input, "host", {}), "local_time", "")
	start <= end
	local_time >= start
	local_time < end
}

in_window if {
	start := effective_string("maintenance_start", "03:00")
	end := effective_string("maintenance_end", "05:00")
	local_time := object.get(object.get(input, "host", {}), "local_time", "")
	start > end
	local_time >= start
}

in_window if {
	start := effective_string("maintenance_start", "03:00")
	end := effective_string("maintenance_end", "05:00")
	local_time := object.get(object.get(input, "host", {}), "local_time", "")
	start > end
	local_time < end
}

enough_disk if {
	free := object.get(object.get(input, "host", {}), "free_bytes", -1)
	is_number(free)
	estimated := object.get(object.get(input.candidate, "adapter", {}), "estimated_bytes", 0)
	is_number(estimated)
	estimated >= 0
	needed := effective_number("min_free_bytes", 21474836480)
	estimated * 2 > needed
	free >= estimated * 2
}

enough_disk if {
	free := object.get(object.get(input, "host", {}), "free_bytes", -1)
	is_number(free)
	estimated := object.get(object.get(input.candidate, "adapter", {}), "estimated_bytes", 0)
	is_number(estimated)
	estimated >= 0
	needed := effective_number("min_free_bytes", 21474836480)
	estimated * 2 <= needed
	free >= needed
}
