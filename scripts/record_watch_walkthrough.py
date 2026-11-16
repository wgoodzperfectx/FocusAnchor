"""Record the connected emulator framebuffer during a manual UX walkthrough."""

import argparse
import subprocess
import tempfile
import time
from pathlib import Path

import cv2


ROOT = Path(__file__).resolve().parents[1]
HDC = Path(r"D:\Tools\DevEco26\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe")
DEFAULT_DEST = ROOT / "docs/evidence/watch-v3.3/watch-v33-walkthrough.mp4"
DEVICE_FRAME = "/data/local/tmp/watch-v33-record.jpeg"
FPS = 4


def hdc(*args: str) -> None:
    subprocess.run([str(HDC), *args], check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seconds", type=int, default=50)
    parser.add_argument("--output", type=Path, default=DEFAULT_DEST)
    args = parser.parse_args()
    dest = args.output
    duration_seconds = args.seconds
    dest.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="focusanchor-watch-record-") as folder:
        local_frame = Path(folder) / "frame.jpeg"
        writer = cv2.VideoWriter(str(dest), cv2.VideoWriter_fourcc(*"mp4v"), FPS, (466, 466))
        if not writer.isOpened():
            raise RuntimeError("MP4 writer could not open")
        started = time.monotonic()
        written = 0
        try:
            while time.monotonic() - started < duration_seconds:
                hdc("shell", "snapshot_display", "-f", DEVICE_FRAME)
                hdc("file", "recv", DEVICE_FRAME, str(local_frame))
                frame = cv2.imread(str(local_frame))
                if frame is None or frame.shape[:2] != (466, 466):
                    raise RuntimeError("Unexpected emulator framebuffer")
                target = min(duration_seconds * FPS, max(written + 1,
                    round((time.monotonic() - started) * FPS)))
                while written < target:
                    writer.write(frame)
                    written += 1
                time.sleep(0.15)
            while written < duration_seconds * FPS:
                writer.write(frame)
                written += 1
        finally:
            writer.release()
    print(f"Recorded {written} emulator frames to {dest}")


if __name__ == "__main__":
    main()
