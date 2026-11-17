"""Extract the supplied FocusAnchor status sheets into transparent ArkUI PNGs.

Usage: python scripts/extract_status_icons.py PHONE_SHEET WATCH_SHEET
"""

from pathlib import Path
import sys

from PIL import Image


NAMES = (
    "ready", "listening", "breaking_down", "awaiting_confirmation",
    "first_step", "in_progress", "paused", "step_complete",
)


def extract(sheet_path: Path, output_dir: Path) -> None:
    sheet = Image.open(sheet_path).convert("RGB")
    if sheet.size != (1536, 1024):
        raise ValueError(f"Expected a 1536x1024 sheet: {sheet_path}")
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(NAMES):
        column = index % 4
        row = index // 4
        top = 180 if row == 0 else 590
        bottom = 415 if row == 0 else 820
        tile = sheet.crop((column * 384, top, (column + 1) * 384, bottom))
        rgba = Image.new("RGBA", tile.size)
        result = []
        for red, green, blue in tile.getdata():
            # The source was flattened onto white. Recover soft edge alpha and
            # remove the white matte so it also looks clean on a dark watch.
            if min(red, green, blue) > 225:
                opacity = 0.0
            elif green > red + 8 and green > blue + 8:
                opacity = min(1.0, (255 - red) / 135)
            else:
                opacity = min(1.0, (255 - (red + green + blue) / 3) / 220)
            if opacity < 0.15:
                opacity = 0.0
            alpha = max(0, min(255, round(opacity * 255)))
            if alpha == 0:
                result.append((0, 0, 0, 0))
            elif alpha == 255:
                result.append((red, green, blue, 255))
            else:
                result.append((
                    max(0, min(255, round((red - 255 * (1 - opacity)) / opacity))),
                    max(0, min(255, round((green - 255 * (1 - opacity)) / opacity))),
                    max(0, min(255, round((blue - 255 * (1 - opacity)) / opacity))),
                    alpha,
                ))
        rgba.putdata(result)
        bounds = rgba.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"No artwork found for {name}")
        artwork = rgba.crop(bounds)
        artwork.thumbnail((296, 208), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (320, 240))
        canvas.alpha_composite(artwork, ((320 - artwork.width) // 2, (240 - artwork.height) // 2))
        canvas.save(output_dir / f"status_{name}.png", optimize=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    root = Path(__file__).resolve().parents[1]
    extract(Path(sys.argv[1]), root / "entry/src/main/resources/base/media")
    extract(Path(sys.argv[2]), root / "wear/src/main/resources/base/media")
