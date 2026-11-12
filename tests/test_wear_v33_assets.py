"""Check exported P2/P3 artwork keeps the character and clears the canvas."""

from pathlib import Path
from PIL import Image


media = Path(__file__).resolve().parents[1] / "wear/src/main/resources/base/media"
names = (
    "fa_monitor_connecting", "fa_monitor_reading", "fa_monitor_monitoring",
    "fa_monitor_signal_unstable", "fa_monitor_reconnecting", "fa_monitor_stopped",
    "fa_companion_stable", "fa_companion_fluctuating", "fa_companion_support_requested",
)

for name in names:
    source = Image.open(media / f"{name}.png").convert("RGBA")
    exported = Image.open(media / f"{name}_transparent.png").convert("RGBA")
    assert exported.width <= source.width and exported.height <= source.height, name
    pixels = list(exported.getdata())
    assert any(a == 0 for _, _, _, a in pixels), f"{name}: canvas remains opaque"
    assert any(a == 255 and max(r, g, b) < 90 for r, g, b, a in pixels), f"{name}: body missing"
    assert any(a == 255 and g > r * 1.15 and g > b * 1.1 for r, g, b, a in pixels), \
        f"{name}: green foot missing"
    assert any(a == 255 and min(r, g, b) > 225 for r, g, b, a in pixels), \
        f"{name}: white eyes/mark missing"

print(f"Validated {len(names)} transparent P2/P3 role assets")
