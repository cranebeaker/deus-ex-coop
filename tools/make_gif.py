"""Turn the engine screenshots (Shot*.bmp) of a showcase run into a GIF.
    python tools/make_gif.py <System dir> <out.gif> [width]"""
import glob
import os
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
width = int(sys.argv[3]) if len(sys.argv) > 3 else 480
files = sorted(glob.glob(os.path.join(src, "Shot*.bmp")))
frames = []
for f in files:
    im = Image.open(f).convert("RGB")
    im = im.resize((width, width * im.height // im.width), Image.LANCZOS)
    frames.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
frames[0].save(out, save_all=True, append_images=frames[1:], duration=120, loop=0, optimize=True)
print(out, len(frames), "frames", os.path.getsize(out) // 1024, "KB")
