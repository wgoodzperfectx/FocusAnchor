"""Remove only border-connected near-white pixels from formal Wear artwork.

The source PNGs remain untouched. Retained RGB pixels, including enclosed white
eyes and marks, are copied byte-for-byte into separate transparent resources.
"""

from collections import deque
from pathlib import Path
from PIL import Image


MEDIA = Path(__file__).resolve().parents[1] / "wear/src/main/resources/base/media"
NAMES = (
    "fa_monitor_connecting", "fa_monitor_reading", "fa_monitor_monitoring",
    "fa_monitor_signal_unstable", "fa_monitor_reconnecting", "fa_monitor_stopped",
    "fa_companion_stable", "fa_companion_fluctuating", "fa_companion_support_requested",
)


def is_background(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _ = pixel
    return min(r, g, b) >= 235 and max(r, g, b) - min(r, g, b) <= 10


def remove_background(source: Path, target: Path) -> int:
    image = Image.open(source).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    seen = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))
    cleared = 0
    while queue:
        x, y = queue.popleft()
        offset = y * width + x
        if seen[offset]:
            continue
        seen[offset] = 1
        if not is_background(pixels[x, y]):
            continue
        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        cleared += 1
        if x:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))
    # The original square canvas leaves the character tiny in a round-watch pill.
    # Trim only fully transparent margins; keep a small transparent breathing space.
    bounds = image.getchannel("A").getbbox()
    if bounds:
        pad = 4
        image = image.crop((max(0, bounds[0] - pad), max(0, bounds[1] - pad),
                            min(width, bounds[2] + pad), min(height, bounds[3] + pad)))
    image.save(target)
    return cleared


if __name__ == "__main__":
    for name in NAMES:
        source = MEDIA / f"{name}.png"
        target = MEDIA / f"{name}_transparent.png"
        print(f"{name}: {remove_background(source, target)} background pixels cleared")
