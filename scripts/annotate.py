"""Anota las capturas: recuadros rojos numerados + una vista ampliada (detalle).

Uso: uv run --with pillow --with numpy python scripts/annotate.py
Lee evidencias/crudas/*.png (+ .png.json con coordenadas exactas de UI Automation) y escribe en
evidencias/anotadas/. La especificación de cada captura está en scripts/evidencias.py.
"""
import json, math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from evidencias import SPEC  # noqa: E402

RED = (220, 20, 30)


def font(size):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/mnt/c/Windows/Fonts/arialbd.ttf"):
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def blocks(a, gap=14, thr=90):
    h = a.shape[0]
    rows = (a[40:h - 60].max(axis=2) > thr).sum(axis=1) > 0
    out, start, last = [], None, None
    for y, v in enumerate(rows):
        if v:
            start = y if start is None else start
            last = y
        elif start is not None and y - last > gap:
            out.append((start + 40, last + 40)); start = None
    if start is not None:
        out.append((start + 40, last + 40))
    res = []
    for y0, y1 in out:
        cols = np.where((a[y0:y1 + 1].max(axis=2) > thr).sum(axis=0) > 0)[0]
        res.append([int(cols.min()), y0, int(cols.max() - cols.min()), y1 - y0])
    return res


def console_regions(im):
    """Devuelve (consulta, resultado) como [x, y, w, h] en una captura de consola maximizada."""
    a = np.asarray(im).astype(int)
    yellow = (a[..., 0] > 180) & (a[..., 1] > 170) & (a[..., 2] < 170)
    yellow[:80] = False
    yellow[-60:] = False
    rows = np.where(yellow.any(axis=1))[0]
    # primer grupo contiguo de lineas amarillas = la consulta
    end = rows[0]
    for r in rows[1:]:
        if r - end > 24:
            break
        end = r
    qy0, qy1 = int(rows[0]), int(end)
    qx1 = int(np.where(yellow[qy0:qy1 + 1].any(axis=0))[0].max())
    bl = [b for b in blocks(a) if b[1] > qy1 + 10 and b[1] < a.shape[0] - 80]
    foot = bl[-1]                                   # "Filas devueltas" + prompt
    res = [b for b in bl[:-1] if b[3] > 20]         # sin la linea separadora
    x0 = min(b[0] for b in res); y0 = min(b[1] for b in res)
    x1 = max(b[0] + b[2] for b in res); y1 = max(b[1] + b[3] for b in res)
    return [0, qy0, qx1, qy1 - qy0], [x0, y0, x1 - x0, y1 - y0]


def arrow(d, a, b, w=7):
    d.line([a, b], fill=RED, width=w)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    L = 34
    d.polygon([b, (b[0] - L * math.cos(ang - 0.45), b[1] - L * math.sin(ang - 0.45)),
               (b[0] - L * math.cos(ang + 0.45), b[1] - L * math.sin(ang + 0.45))], fill=RED)


def draw_marks(im, rects):
    d = ImageDraw.Draw(im)
    W, H = im.size
    f = font(30)
    for i, (x, y, w, h) in enumerate(rects, 1):
        pad = 6
        box = [max(1, x - pad), max(1, y - pad), min(W - 2, x + w + pad), min(H - 2, y + h + pad)]
        d.rectangle(box, outline=RED, width=5)
        # etiqueta numerada pegada a la esquina superior izquierda, fuera del contenido
        tw = d.textlength(str(i), font=f)
        bw, bh = max(44, int(tw) + 22), 44
        bx0 = box[0]; by0 = box[1] - bh if box[1] - bh >= 1 else box[1]
        d.rectangle([bx0, by0, bx0 + bw, by0 + bh], fill=RED)
        d.text((bx0 + (bw - tw) / 2, by0 + 4), str(i), fill="white", font=f)


def resolve(im, meta, spec_marks):
    rects, labels = [], []
    cq = cr = None
    for kind, ref, label in spec_marks:
        if kind == "json":
            m = next((m for m in meta["marks"] if m["name"].startswith(ref) and m["rect"]), None)
            if not m:
                print("   !! sin marca json", ref); continue
            rects.append(m["rect"])
        elif kind == "rect":
            rects.append(list(ref))
        elif kind in ("consulta", "resultado"):
            if cq is None:
                cq, cr = console_regions(im)
            rects.append(cq if kind == "consulta" else cr)
        labels.append(label)
    return rects, labels


def detalle(im, rects, minw=1500, minh=760):
    x0 = min(r[0] for r in rects) - 160; y0 = min(r[1] for r in rects) - 140
    x1 = max(r[0] + r[2] for r in rects) + 160; y1 = max(r[1] + r[3] for r in rects) + 140
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w, h = max(x1 - x0, minw), max(y1 - y0, minh)
    x0, y0 = int(max(0, cx - w / 2)), int(max(0, cy - h / 2))
    x1, y1 = int(min(im.width, cx + w / 2)), int(min(im.height, cy + h / 2))
    return im.crop((x0, y0, x1, y1))


def main():
    crudas = os.path.join(ROOT, "evidencias", "crudas")
    anot = os.path.join(ROOT, "evidencias", "anotadas")
    os.makedirs(anot, exist_ok=True)
    only = set(sys.argv[1:])
    out_meta = {}
    for name, spec in SPEC.items():
        if only and name not in only:
            continue
        src = os.path.join(crudas, name + ".png")
        im = Image.open(src).convert("RGB")
        jp = src + ".json"
        meta = json.load(open(jp, encoding="utf-8-sig")) if os.path.exists(jp) else {"marks": []}
        rects, labels = resolve(im, meta, spec["marks"])
        full = im.copy()
        draw_marks(full, rects)
        full.save(os.path.join(anot, name + ".png"))
        det = detalle(full, rects)
        det.save(os.path.join(anot, name + "-detalle.png"))
        out_meta[name] = {"labels": labels, "rects": rects}
        print("ok", name, len(rects), "marcas")
    if not only:
        json.dump(out_meta, open(os.path.join(anot, "marcas.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


main()
