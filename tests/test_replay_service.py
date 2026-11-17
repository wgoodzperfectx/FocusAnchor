"""API safety behavior with synthetic aggregate fixtures."""

import copy
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient

from service.app import app


class ReplayServiceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.fixtures = [cls.client.get("/v1/replay/next", params={"cursor": i}).json()["fixture"]
                        for i in range(3)]

    def test_health_and_openapi_are_replay_only(self):
        health = self.client.get("/v1/health")
        self.assertEqual(health.status_code, 200)
        self.assertFalse(health.json()["agent_connected"])
        self.assertEqual(self.client.get("/openapi.json").status_code, 200)

    def test_good_m1_remains_unknown_until_calibrated(self):
        response = self.client.post(self.fixtures[0]["target"], json=self.fixtures[0]["request"])
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["physio_state"], "unknown")
        self.assertEqual(response.json()["calibration_status"], "uncalibrated")
        self.assertFalse(response.json()["executable"])

    def test_bad_signal_and_missing_feature_reject(self):
        bad = self.client.post(self.fixtures[1]["target"], json=self.fixtures[1]["request"])
        self.assertEqual(bad.json()["reason_codes"], ["BAD_SIGNAL"])
        self.assertIsNone(bad.json()["stress_probability"])
        missing = copy.deepcopy(self.fixtures[0]["request"])
        missing["features"].pop(next(iter(missing["features"])))
        response = self.client.post("/v1/m1/estimate", json=missing)
        self.assertEqual(response.json()["reason_codes"], ["FEATURE_SET_MISMATCH"])

    def test_context_without_need_abstains(self):
        response = self.client.post(self.fixtures[2]["target"], json=self.fixtures[2]["request"])
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["action"], "abstain")
        self.assertEqual(response.json()["reason_codes"], ["NEED_UNOBSERVED"])
        self.assertFalse(response.json()["executable"])

    def test_replay_timestamp_is_preserved_for_g0_age_check(self):
        request = copy.deepcopy(self.fixtures[2]["request"])
        request["timestamp_ms"] = 1790000000123
        response = self.client.post("/v1/m2/decision-candidate", json=request)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["timestamp_ms"], request["timestamp_ms"])
        self.assertFalse(response.json()["executable"])

    def test_ood_and_invalid_context_abstain(self):
        request = copy.deepcopy(self.fixtures[2]["request"])
        request["features"]["battery"] = 1000
        response = self.client.post("/v1/m2/decision-candidate", json=request)
        self.assertEqual(response.json()["reason_codes"], ["OUT_OF_DISTRIBUTION"])
        self.assertTrue(response.json()["ood"])
        request["context_quality"] = "invalid"
        response = self.client.post("/v1/m2/decision-candidate", json=request)
        self.assertEqual(response.json()["reason_codes"], ["BAD_CONTEXT"])

    def test_model_unavailable_and_schema_error_are_explicit(self):
        with patch("service.app.load_bundle", return_value=None):
            response = self.client.post("/v1/m2/decision-candidate", json=self.fixtures[2]["request"])
        self.assertEqual(response.json()["reason_codes"], ["MODEL_UNAVAILABLE"])
        self.assertEqual(response.json()["action"], "abstain")
        invalid = copy.deepcopy(self.fixtures[0]["request"])
        invalid["schema_version"] = "2.1.0"
        response = self.client.post("/v1/m1/estimate", json=invalid)
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()["code"], "INVALID_REQUEST")


if __name__ == "__main__":
    unittest.main()
