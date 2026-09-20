#!/usr/bin/env python3
"""
bake.py — bake .vox models to a sprite atlas with a fixed light. Two backends:

  1. Built-in software renderer (no dependencies beyond Pillow):
       python art/bake/bake.py --src art/vox/debris --out art/atlas/debris --frame 8 --angles 1
     Orthographic dimetric projection, one fixed light (top-left, slightly front),
     3-shade face lighting + cheap ambient occlusion, rendered at 2x then nearest-downsampled.
     Good enough for phase 0 and for anything "tiny".

  2. Blender (for hero-tier parts once we want real AO/rim/emissive bloom):
       blender --background --python art/bake/bake.py -- --blender --src art/vox/parts --out art/atlas/parts --angles 8
     Requires the MagicaVoxel importer add-on enabled in Blender. Stub below; fill in when needed.

Output: <out>.png (atlas, grid of frames) + <out>.json {frame_px, grid, frames:[{name, angle, x, y}]}.
"""
import argparse, json, math, os, struct, sys

def read_vox(path):
    with open(path, "rb") as f: data = f.read()
    assert data[:4] == b"VOX ", path
    pos, size, voxels, palette = 8, None, [], None
    while pos < len(data):
        cid = data[pos:pos+4]; n, m = struct.unpack("<ii", data[pos+4:pos+12]); pos += 12
        content = data[pos:pos+n]
        if cid == b"SIZE": size = struct.unpack("<iii", content[:12])
        elif cid == b"XYZI":
            cnt = struct.unpack("<i", content[:4])[0]
            voxels = [struct.unpack("<BBBB", content[4+i*4:8+i*4]) for i in range(cnt)]
        elif cid == b"RGBA":
            palette = [struct.unpack("<BBBB", content[i*4:i*4+4]) for i in range(256)]
        pos += n if cid != b"MAIN" else 0
    if palette is None:
        palette = [(200, 200, 200, 255)] * 256
    return size, voxels, palette

def render_frame(size, voxels, palette, px, yaw_deg):
    """Software dimetric render into a px×px RGBA buffer (list of rows). Returns rows."""
    from PIL import Image
    S = 2  # supersample
    W = px * S
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    pix = img.load()
    sx, sy, sz = size
    occupied = {(x, y, z) for x, y, z, _ in voxels}
    yaw = math.radians(yaw_deg)
    cy, cx = (sy - 1) / 2, (sx - 1) / 2
    # cube edge in pixels at 2x: fit the model diagonal into the frame
    diag = max(sx, sy) * 1.42 + sz * 0.5
    e = (W * 0.92) / diag
    light = (-0.6, -0.5, 0.62)  # top-left, slightly front, normalised-ish
    def rot(x, y):
        dx, dy = x - cx, y - cy
        return dx * math.cos(yaw) - dy * math.sin(yaw), dx * math.sin(yaw) + dy * math.cos(yaw)
    # painter's order: far to near = ascending (x'+y'), then z
    order = sorted(voxels, key=lambda v: (sum(rot(v[0], v[1])), v[2]))
    zbuf = {}
    for x, y, z, ci in order:
        r, g, b, _ = palette[ci - 1] if ci > 0 else (200, 200, 200, 255)
        rx, ry = rot(x, y)
        # dimetric: screen x from (rx - ry), screen y from (rx + ry)/2 - z
        ox = W / 2 + (rx - ry) * e * 0.866
        oy = W / 2 + (rx + ry) * e * 0.5 - z * e + (sz * e) * 0.35
        # ambient occlusion: count neighbours above/sides
        occl = sum(1 for d in ((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1)) if (x+d[0], y+d[1], z+d[2]) in occupied)
        ao = 1.0 - 0.06 * occl
        faces = [  # (polygon, normal)
            ([(ox, oy - e), (ox + e*0.866, oy - e*0.5), (ox, oy), (ox - e*0.866, oy - e*0.5)], (0, 0, 1)),        # top
            ([(ox - e*0.866, oy - e*0.5), (ox, oy), (ox, oy + e), (ox - e*0.866, oy + e*0.5)], (-0.7, 0.7, 0)),   # left
            ([(ox + e*0.866, oy - e*0.5), (ox, oy), (ox, oy + e), (ox + e*0.866, oy + e*0.5)], (0.7, 0.7, 0)),    # right
        ]
        from PIL import ImageDraw
        d = ImageDraw.Draw(img)
        for poly, n in faces:
            lam = max(0.15, n[0]*light[0] + n[1]*light[1] + n[2]*light[2]) * ao
            lam = 0.45 + 0.75 * lam
            col = (min(255, int(r * lam)), min(255, int(g * lam)), min(255, int(b * lam)), 255)
            d.polygon(poly, fill=col)
    return img.resize((px, px), Image.NEAREST)

def bake_software(src, out, frame, angles):
    from PIL import Image
    files = sorted(f for f in os.listdir(src) if f.endswith(".vox"))
    frames = []
    n = len(files) * angles
    grid = max(1, math.ceil(math.sqrt(n)))
    atlas = Image.new("RGBA", (grid * frame, grid * frame), (0, 0, 0, 0))
    i = 0
    for f in files:
        size, voxels, palette = read_vox(os.path.join(src, f))
        for a in range(angles):
            im = render_frame(size, voxels, palette, frame, 360.0 * a / angles)
            x, y = (i % grid) * frame, (i // grid) * frame
            atlas.paste(im, (x, y))
            frames.append({"name": f[:-4], "angle": a, "x": x, "y": y})
            i += 1
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    atlas.save(out + ".png")
    with open(out + ".json", "w") as jf:
        json.dump({"frame_px": frame, "grid": grid, "frames": frames}, jf, indent=1)
    print(f"baked {n} frames → {out}.png ({grid}×{grid} grid)")

def bake_blender(src, out, frame, angles):
    # Fill in when hero parts need real lighting. Outline:
    #   import bpy; for each .vox: bpy.ops.import_scene.vox(filepath=...)  (MagicaVoxel importer add-on)
    #   camera: orthographic, rotation (54.7°, 0, 45°+yaw), ortho_scale from model bounds
    #   sun light: rotation matching the software light; world strength 0.35 for ambient
    #   render at frame*2 with filter_size 0 (no AA), then downsample with PIL NEAREST
    #   compositor: emissive palette entries → bloom via Glare node
    print("blender backend is a stub; use --software for phase 0"); sys.exit(2)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True); ap.add_argument("--out", required=True)
    ap.add_argument("--frame", type=int, default=8); ap.add_argument("--angles", type=int, default=1)
    ap.add_argument("--blender", action="store_true")
    a = ap.parse_args(argv)
    (bake_blender if a.blender else bake_software)(a.src, a.out, a.frame, a.angles)
