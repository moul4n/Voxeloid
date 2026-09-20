#!/usr/bin/env python3
"""
gen_debris.py — procedurally generate .vox debris chunks (rocks, shards, crystals).

Writes MagicaVoxel .vox files (format 150) into art/vox/debris/, one per chunk,
plus a shared palette. No dependencies. Then bake.py turns them into the atlas.

  python art/bake/gen_debris.py --count 64 --size 6 --out art/vox/debris

Shapes: 'blob' (noise-carved sphere), 'shard' (elongated), 'crystal' (extruded hexagon).
"""
import argparse, os, random, struct

# 32-colour ramp matching docs/vox-speed-bible.html § Art direction (slot 0 is unused in .vox)
RAMP = [
    (0x15,0x1a,0x26),(0x3a,0x3f,0x4c),(0x6e,0x6a,0x62),(0x9a,0x95,0x8a),(0xc9,0xc3,0xb4),      # neutrals 1-5
    (0x4a,0x40,0x36),(0x6e,0x6a,0x62),(0x9a,0x95,0x8a),(0xc9,0xc3,0xb4),                       # rock 6-9
    (0x2e,0x55,0x7a),(0x4f,0x7f,0xa8),(0x7f,0xb2,0xd8),(0xbf,0xe3,0xf5),                       # ice 10-13
    (0x7a,0x2a,0x0e),(0xa8,0x3e,0x14),(0xe0,0x73,0x1f),(0xff,0xb3,0x47),                       # ember 14-17
    (0x25,0x52,0x1a),(0x3b,0x7a,0x2a),(0x6c,0xc2,0x44),(0xb9,0xf2,0x7a),                       # acid 18-21
    (0x3b,0x2a,0x62),(0x5a,0x3f,0x8f),(0x8f,0x6a,0xd1),(0xc9,0xb1,0xff),                       # crystal 22-25
    (0x5e,0x47,0x0b),(0x8a,0x6a,0x12),(0xd4,0xa6,0x28),(0xff,0xe2,0x7a),                       # gold 26-29
    (0xff,0x6a,0x1a),(0x5a,0xc8,0xff),(0x9a,0xff,0x4a),                                        # emissive 30-32
]
FAMILIES = {"rock": (6, 9), "ice": (10, 13), "ember": (14, 17), "acid": (18, 21), "crystal": (22, 25), "gold": (26, 29)}

def chunk(tag, size, kind, rng):
    """Return dict {(x,y,z): color_index}."""
    lo, hi = FAMILIES[tag]
    vox = {}
    c = (size - 1) / 2
    for x in range(size):
        for y in range(size):
            for z in range(size):
                dx, dy, dz = (x - c) / c, (y - c) / c, (z - c) / c
                if kind == "blob":
                    r = (dx*dx + dy*dy + dz*dz) ** 0.5 + rng.uniform(-0.25, 0.25)
                    inside = r < 0.95
                elif kind == "shard":
                    inside = (dx*dx*3 + dy*dy*3 + dz*dz*0.6) ** 0.5 + rng.uniform(-0.15, 0.15) < 0.95
                else:  # crystal: hexagonal prism
                    hx = max(abs(dx), abs(dx*0.5 + dy*0.866), abs(dx*0.5 - dy*0.866))
                    inside = hx < 0.8 and abs(dz) < 0.95
                if inside:
                    # shade by height: top rows lighter, plus a sprinkle of the highlight
                    shade = lo + min(3, int((z / max(size - 1, 1)) * 3.99))
                    if rng.random() < 0.08: shade = hi
                    vox[(x, y, z)] = shade
    return vox

def write_vox(path, size, vox):
    def chunk_bytes(cid, content, children=b""):
        return cid + struct.pack("<ii", len(content), len(children)) + content + children
    xyzi = struct.pack("<i", len(vox)) + b"".join(struct.pack("<BBBB", x, y, z, c) for (x, y, z), c in vox.items())
    pal = b"".join(struct.pack("<BBBB", r, g, b, 255) for (r, g, b) in RAMP)
    pal += b"\x00\x00\x00\xff" * (256 - len(RAMP))     # 256 entries; index 0 in-file is entry 1
    body = chunk_bytes(b"SIZE", struct.pack("<iii", size, size, size)) + chunk_bytes(b"XYZI", xyzi) + chunk_bytes(b"RGBA", pal)
    data = b"VOX " + struct.pack("<i", 150) + chunk_bytes(b"MAIN", b"", body)
    with open(path, "wb") as f: f.write(data)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=64)
    ap.add_argument("--size", type=int, default=6)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "vox", "debris"))
    a = ap.parse_args()
    rng = random.Random(a.seed)
    os.makedirs(a.out, exist_ok=True)
    tags = list(FAMILIES); kinds = ["blob", "blob", "shard", "crystal"]
    for i in range(a.count):
        tag, kind = tags[i % len(tags)], kinds[i % len(kinds)]
        v = chunk(tag, a.size, kind, rng)
        write_vox(os.path.join(a.out, f"debris_{i:03d}_{tag}_{kind}.vox"), a.size, v)
    print(f"wrote {a.count} chunks to {a.out}")

if __name__ == "__main__":
    main()
