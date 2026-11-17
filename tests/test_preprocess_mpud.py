"""Small temporal fixture for the MPUD extraction boundary."""

import csv
import io
from pathlib import Path
import sys
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from preprocess_mpud import extract_subject  # noqa: E402


class MpudExtractionTest(unittest.TestCase):
    def test_post_event_sensor_state_cannot_enter_earlier_notification(self):
        events = [
            {"ts": "2016-06-01 10:00:00", "sensor_id": "Screen", "Screen_Value": "Unlocked"},
            {"ts": "2016-06-01 10:05:00", "sensor_id": "Esm", "Esm_Posted": "2016-06-01 10:05:00", "Esm_Timedout": "2016-06-01 10:15:00"},
            {"ts": "2016-06-01 10:06:00", "sensor_id": "Screen", "Screen_Value": "Off"},
            {"ts": "2016-06-01 10:15:00", "sensor_id": "Esm", "Esm_Posted": "2016-06-01 10:15:00", "Esm_Clicked": "2016-06-01 10:16:00"},
        ]
        stream = io.StringIO()
        columns = ["ts", "sensor_id", "Screen_Value", "Esm_Posted", "Esm_Timedout", "Esm_Clicked"]
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        writer.writerows(events)
        archive_bytes = io.BytesIO()
        with zipfile.ZipFile(archive_bytes, "w") as archive:
            archive.writestr("data/u_fixture.csv", stream.getvalue())
        archive_bytes.seek(0)
        with zipfile.ZipFile(archive_bytes) as archive:
            rows, stats = extract_subject(archive, "data/u_fixture.csv")
        self.assertEqual([r["clicked_10m"] for r in rows], [0, 1])
        self.assertEqual([r["screen_on"] for r in rows], [1, 0])
        self.assertEqual([r["screen_5m"] for r in rows], [1, 0])
        self.assertEqual(stats["out_of_order"], 0)


if __name__ == "__main__":
    unittest.main()
