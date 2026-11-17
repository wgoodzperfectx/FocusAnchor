"""Check survey boundaries that could silently change the external cohort."""

import sys
import tempfile
import unittest
from datetime import datetime, time, timezone
from pathlib import Path

import openpyxl

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from evaluate_nurse_external import survey_events  # noqa: E402


class NurseSurveyTest(unittest.TestCase):
    def test_unvalidated_is_excluded_and_midnight_event_rolls_over(self):
        book = openpyxl.Workbook()
        sheet = book.active
        sheet.append(["ID", "Start time", "End time", "duration", "date", "Stress level"])
        sheet.append(["AA", time(23, 50), time(0, 10), None, datetime(2020, 5, 1), 2])
        sheet.append(["AA", time(10), time(11), None, datetime(2020, 5, 1), "na"])
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "survey.xlsx"
            book.save(path)
            events, counts = survey_events(path)
        self.assertEqual(counts["unvalidated_label"], 1)
        self.assertEqual(len(events), 1)
        subject, begin, end, label = events[0]
        self.assertEqual((subject, label), ("AA", 2))
        self.assertEqual(datetime.fromtimestamp(begin, timezone.utc).isoformat(), "2020-05-02T05:50:00+00:00")
        self.assertEqual(end - begin, 20 * 60)


if __name__ == "__main__":
    unittest.main()
