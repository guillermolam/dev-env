"""Compatibility wrapper. Eligibility is delegated to local OPA, never reimplemented here."""

from datetime import UTC, datetime

from mac_env.opa_eval import evaluate_input

REQUIRED = frozenset({"vulnix", "firewall", "tooling", "access", "integrity"})


def evaluate(current, baseline, now=None, max_age_seconds=86400):
    now = now or datetime.now(UTC)
    if now.tzinfo is None:
        return ["observation time missing"]
    decision = evaluate_input(
        {
            "operation": "backup_eligibility",
            "now": now.isoformat(),
            "evidence": evidence_records(current),
            "baseline": evidence_records(baseline),
            "max_age_seconds": max_age_seconds,
            "policy_layers": {
                "defaults": {
                    "schema_version": 1,
                    "updates": {"max_evidence_age_seconds": max_age_seconds},
                    "tools": {},
                }
            },
        }
    )
    return decision["reasons"]


def evidence_records(document):
    if isinstance(document, dict):
        return document.get("evidence", document)
    return document
