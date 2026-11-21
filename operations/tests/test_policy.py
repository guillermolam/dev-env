import copy
import unittest
from datetime import UTC, datetime

from policy import REQUIRED, evaluate


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 11, 19, tzinfo=UTC)
        self.baseline = {
            name: {
                "status": "ok",
                "observed_at": self.now.isoformat(),
                "findings": [],
                "critical": 0,
            }
            for name in REQUIRED
        }
        self.current = copy.deepcopy(self.baseline)

    def check(self):
        return evaluate(self.current, self.baseline, self.now)

    def test_complete_unchanged(self):
        self.assertEqual(self.check(), [])

    def test_missing_baseline(self):
        self.assertTrue(evaluate(self.current, None, self.now))

    def test_missing_collector(self):
        del self.current["firewall"]
        self.assertTrue(self.check())

    def test_equal_counts_different_cves(self):
        self.baseline["vulnix"]["findings"] = ["CVE-old"]
        self.current["vulnix"]["findings"] = ["CVE-new"]
        self.assertTrue(self.check())

    def test_stale_future_and_naive(self):
        for value in ("2020-01-01T00:00:00+00:00", "2030-01-01T00:00:00+00:00", "2026-11-19"):
            self.current["vulnix"]["observed_at"] = value
            self.assertTrue(self.check())

    def test_failed_scanner(self):
        self.current["vulnix"]["status"] = "error"
        self.assertTrue(self.check())

    def test_severity_regression(self):
        self.current["vulnix"]["critical"] = 1
        self.assertTrue(self.check())

    def test_suspicious_access_even_if_baselined(self):
        self.current["access"]["findings"] = ["unexpected-login"]
        self.baseline["access"]["findings"] = ["unexpected-login"]
        self.assertTrue(self.check())

    def test_malformed(self):
        for value in (None, [], "", {"findings": "bad"}):
            self.current["tooling"] = value
            self.assertTrue(self.check())


if __name__ == "__main__":
    unittest.main()
