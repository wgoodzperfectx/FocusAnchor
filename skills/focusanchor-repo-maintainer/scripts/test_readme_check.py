import unittest

from readme_check import review


class ReadmeCheckTest(unittest.TestCase):
    def test_flags_relevant_changes_without_requiring_docs_change(self):
        result = review(["scripts/agentarts-runtime-client.mjs", "wear/src/main/ets/services/WearSyncQueue.ts"])
        self.assertIn("agentarts_provider", result)
        self.assertIn("watch_ack", result)
        self.assertNotIn("knowledge_v2", result)

    def test_unrelated_change_has_no_trigger(self):
        self.assertEqual(review(["LICENSE", "assets/logo.png"]), {})


if __name__ == "__main__":
    unittest.main()
