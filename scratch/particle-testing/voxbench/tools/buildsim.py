#!/usr/bin/env python3
"""
buildsim — build-space simulator for a tag-based compounding buff system.

Models the four-layer stacking scheme (flat / increased / more / bounded),
tag-gated modifiers, conversion, and on-event chain reactions with a depth
guard, then explores the build space two ways:

  exhaustive : every k-subset of the pool (order-independent by design)
  montecarlo : simulated runs with offer-of-3, tag-weighted offers, and a
               picker policy (random / greedy / tag-loyal)

Outputs dominance, dead picks, synergy matrix, outcome spread, and the
progress-track check against an enemy HP curve.

Pure Python 3, no dependencies. Run: python buildsim.py [--picks 12] [--runs 20000]
"""
from __future__ import annotations
import argparse, itertools, json, math, random, statistics, sys
from collections import defaultdict
from dataclasses import dataclass, field

# ---------------------------------------------------------------- model ----

BOUNDED = {"crit": 0.95, "pierce": 0.9}   # stats resolved hyperbolically toward a cap
BASE = dict(dmg=10.0, fire=0.0, rate=2.0, count=1.0, split=0.0, crit=0.05, critmult=1.5,
            speed=1.0, size=1.0, chain=0.0, pierce=0.0)

@dataclass
class Mod:
    stat: str
    layer: str          # add | inc | more | bounded
    value: float
    req: frozenset = frozenset()   # tags the ENTITY must carry for this mod to apply

@dataclass
class Trigger:
    on: str             # hit | kill | split
    req: frozenset      # tags required on the source entity
    spawn_tags: frozenset
    n: float            # expected spawns per event
    dmg_frac: float     # spawned entity dmg as fraction of source dmg

@dataclass(eq=False)
class Buff:
    name: str
    tags_add: frozenset = frozenset()   # tags granted to the player's projectiles
    mods: list = field(default_factory=list)
    triggers: list = field(default_factory=list)
    convert: tuple | None = None        # ("phys","fire",0.5): 50% of phys dmg becomes fire (eligible for both pools)
    offer_tags: frozenset = frozenset() # tags this buff is "about" (for offer weighting)
    retrigger: float = 0.0              # extra evaluations of on-hit chain per hit (exponent generator; capped)

def B(name, **kw): return Buff(name, **kw)
T = frozenset
def M(stat, layer, value, req=()): return Mod(stat, layer, value, T(req))

# --------------------------------------------------------------- pool ------
# 26 buffs across 6 tag families. Values deliberately generous so degeneracy
# has room to show up in the sim rather than in the game.
POOL = [
  # flat / generic
  B("Heavy Shot",     mods=[M("dmg","add",5)],                            offer_tags=T({"dmg"})),
  B("Sharpened",      mods=[M("dmg","inc",0.40)],                         offer_tags=T({"dmg"})),
  B("Overclock",      mods=[M("rate","inc",0.35)],                        offer_tags=T({"rate"})),
  B("Twin Barrel",    mods=[M("count","add",1), M("dmg","more",-0.15)],                          offer_tags=T({"count"})),
  B("Brutality",      mods=[M("dmg","more",0.30)],                        offer_tags=T({"dmg"})),
  # crit family (bounded)
  B("Keen Eye",       mods=[M("crit","bounded",0.15)],                    offer_tags=T({"crit"})),
  B("Lethality",      mods=[M("critmult","add",0.5)],                     offer_tags=T({"crit"})),
  B("Executioner",    mods=[M("dmg","more",0.25, req={"crit"})], tags_add=T({"crit"}), offer_tags=T({"crit"})),
  B("Crit Chain",     triggers=[Trigger("hit", T({"crit"}), T({"projectile","shard"}), 0.5, 0.3)], offer_tags=T({"crit","shard"})),
  # fire family
  B("Ignite",         mods=[M("fire","add",4)],                            offer_tags=T({"fire"})),
  B("Phys Mastery",   mods=[M("dmg","inc",0.45, req={"phys"})],           offer_tags=T({"dmg","phys"})),
  B("Inferno",        mods=[M("dmg","more",0.35, req={"fire"})],          offer_tags=T({"fire"})),
  B("Fire Spread",    triggers=[Trigger("kill", T({"fire"}), T({"projectile","fire","ember"}), 2.0, 0.5)], offer_tags=T({"fire","chain"})),
  B("Phys to Fire",   convert=("phys","fire",0.5),                        offer_tags=T({"fire","convert"})),
  # shard family (splits)
  B("Splinter",       mods=[M("split","add",2)], tags_add=T({"shard"}),   offer_tags=T({"shard"})),
  B("Shardstorm",     mods=[M("split","inc",0.5, req={"shard"})],         offer_tags=T({"shard"})),
  B("Shard Damage",   mods=[M("dmg","inc",0.8, req={"shard"})],           offer_tags=T({"shard","dmg"})),
  B("Fission",        triggers=[Trigger("split", T({"shard"}), T({"projectile","shard"}), 1.0, 0.35)], offer_tags=T({"shard","chain"})),
  # speed / size
  B("Velocity",       mods=[M("speed","inc",0.3), M("dmg","inc",0.10)],   offer_tags=T({"speed"})),
  B("Big Shot",       mods=[M("size","inc",0.8), M("pierce","bounded",0.2), M("rate","inc",-0.15)],  offer_tags=T({"size"})),
  B("Momentum",       mods=[M("dmg","more",0.20, req={"speed"})], tags_add=T({"speed"}), offer_tags=T({"speed"})),
  # bounded pierce
  B("Piercing",       mods=[M("pierce","bounded",0.35)],                  offer_tags=T({"pierce"})),
  # chain / retrigger
  B("Echo",           retrigger=1.0,                                      offer_tags=T({"chain"})),
  B("Ricochet",       triggers=[Trigger("hit", T({"projectile"}), T({"projectile"}), 0.4, 0.5)], offer_tags=T({"chain"})),
  # wildcards
  B("Glass Cannon",   mods=[M("dmg","more",0.60), M("rate","more",-0.25)], offer_tags=T({"wild"})),
  B("Everything Fire", convert=("phys","fire",1.0), mods=[M("dmg","inc",0.15)], offer_tags=T({"fire","wild"})),
  B("Swarm",          mods=[M("count","add",2), M("dmg","more",-0.50)],   offer_tags=T({"count","wild"})),
]
BY_NAME = {b.name: b for b in POOL}

# ----------------------------------------------------------- resolver -----

MAX_DEPTH = 6
MAX_RETRIGGER = 3

def resolve_stat(stat: str, mods: list[Mod], tags: frozenset) -> float:
    base = BASE[stat]
    add = inc = 0.0; more = 1.0; bounded = 0.0
    for m in mods:
        if m.stat != stat or not m.req <= tags: continue
        if m.layer == "add": add += m.value
        elif m.layer == "inc": inc += m.value
        elif m.layer == "more": more *= (1 + m.value)
        elif m.layer == "bounded": bounded += m.value
    v = (base + add) * (1 + inc) * more
    if stat in BOUNDED:
        # hyperbolic: a*n/(1+a*n) toward the cap, added to base
        cap = BOUNDED[stat]
        v = base + (cap - base) * (bounded / (1 + bounded))
    return v

def eval_build(buffs: list[Buff]) -> dict:
    """Expected shards/second of the player's output, closed-form with chain expansion."""
    tags = {"projectile", "phys"}
    mods, trigs = [], []
    retrig = 0.0; convert = []
    for b in buffs:
        tags |= b.tags_add
        mods += b.mods; trigs += b.triggers
        retrig += b.retrigger
        if b.convert: convert.append(b.convert)
    tags = frozenset(tags)

    # ---- damage by type. Type-gated mods (req contains a damage type) scale only that
    # portion; converted damage is eligible for BOTH the source and destination pools
    # (the Path of Exile rule). Non-type gates (crit, shard, speed) act as generic gates.
    TYPES = ("phys", "fire")
    def pools(kind):
        """return (inc, more) for generic mods and per-type mods on stat 'dmg'."""
        inc = {"generic": 0.0, **{t: 0.0 for t in TYPES}}
        more = {"generic": 1.0, **{t: 1.0 for t in TYPES}}
        for m in mods:
            if m.stat != "dmg" or m.layer not in ("inc", "more"): continue
            if not (m.req - set(TYPES)) <= tags: continue      # non-type gate unmet
            typ = next((t for t in TYPES if t in m.req), "generic")
            if m.layer == "inc": inc[typ] += m.value
            else: more[typ] *= (1 + m.value)
        return inc, more
    inc, more = pools("dmg")
    flat_generic = sum(m.value for m in mods if m.stat == "dmg" and m.layer == "add" and (m.req - set(TYPES)) <= tags)
    phys_base = BASE["dmg"] + flat_generic
    fire_base = sum(m.value for m in mods if m.stat == "fire" and m.layer == "add")
    conv_part = 0.0
    frac_total = min(1.0, sum(c[2] for c in convert))
    if frac_total > 0:
        conv_part = phys_base * frac_total; phys_base -= conv_part
    if fire_base + conv_part > 0: tags = frozenset(tags | {"fire"})
    if phys_base > 0: tags = frozenset(tags | {"phys"})
    inc, more = pools("dmg")   # re-evaluate now that fire/phys tags are settled
    g_i, g_m = inc["generic"], more["generic"]
    dmg = (phys_base * (1 + g_i + inc["phys"]) * g_m * more["phys"]
         + fire_base * (1 + g_i + inc["fire"]) * g_m * more["fire"]
         + conv_part * (1 + g_i + inc["phys"] + inc["fire"]) * g_m * more["phys"] * more["fire"])

    rate  = max(0.05, resolve_stat("rate", mods, tags))
    count = max(1.0, resolve_stat("count", mods, tags))
    split = max(0.0, resolve_stat("split", mods, tags))
    crit  = resolve_stat("crit", mods, tags)
    cm    = resolve_stat("critmult", mods, tags)
    pierce= resolve_stat("pierce", mods, tags)
    size  = resolve_stat("size", mods, tags)

    hit_mult = (1 + crit * (cm - 1)) * (1 + pierce * 1.2) * (0.7 + 0.3 * size)

    # chain expansion: expected damage from one primary hit including spawned children
    def chain(src_tags: frozenset, depth: int, budget: list) -> float:
        if depth >= MAX_DEPTH or budget[0] <= 0: return 0.0
        total = 0.0
        events = [("hit", 1.0), ("kill", 0.35), ("split", min(1.0, split))]
        for ev, p in events:
            if p <= 0: continue
            for t in trigs:
                if t.on == ev and t.req <= src_tags:
                    n = p * t.n
                    budget[0] -= n
                    child_tags = frozenset(src_tags | t.spawn_tags)
                    total += n * t.dmg_frac * (1 + chain(child_tags, depth + 1, budget))
        return total

    per_hit_budget = [64.0]          # per-frame spawn budget stand-in
    chain_mult = 1 + chain(tags, 0, per_hit_budget)
    chain_mult *= (1 + min(retrig, MAX_RETRIGGER) * 0.6)   # retriggers re-run the chain, capped
    split_mult = 1 + split * 0.35    # each split child does 35% of parent

    dps = dmg * rate * count * hit_mult * split_mult * chain_mult
    return dict(dps=dps, dmg=dmg, rate=rate, count=count, split=split, crit=crit,
                chain=chain_mult, tags=sorted(tags))

# ------------------------------------------------------------ analysis ----

def enemy_hp(pick_index: int) -> float:
    """Enemy HP curve after N picks. Tuned so an average build keeps ~constant TTK."""
    return 30.0 * (1.28 ** pick_index)

def exhaustive(k: int):
    names = [b.name for b in POOL]
    res = []
    for combo in itertools.combinations(names, k):
        d = eval_build([BY_NAME[n] for n in combo])["dps"]
        res.append((d, combo))
    res.sort(reverse=True)
    return res

def marginal_gain(buff: Buff, context: list[Buff]) -> float:
    a = eval_build(context)["dps"]; b = eval_build(context + [buff])["dps"]
    return b / a - 1

def synergy_matrix():
    names = [b.name for b in POOL]
    base = eval_build([])["dps"]
    solo = {n: eval_build([BY_NAME[n]])["dps"] / base for n in names}
    syn = {}
    for a, b in itertools.combinations(names, 2):
        both = eval_build([BY_NAME[a], BY_NAME[b]])["dps"] / base
        syn[(a, b)] = both / (solo[a] * solo[b])   # 1.0 = independent, >1 = synergy, <1 = anti
    return solo, syn

def offer(owned: list[Buff], rng: random.Random, n=3, loyalty=2.5, wild=0.15):
    """Offer n buffs; weight toward tags already in the build, with a wildcard slot."""
    have = set()
    for b in owned: have |= b.offer_tags | b.tags_add
    cands = [b for b in POOL if b not in owned]
    if not cands: return []
    weights = [1.0 + loyalty * len(b.offer_tags & have) for b in cands]
    picks = rng.choices(cands, weights=weights, k=max(1, n - 1)) if cands else []
    picks = list(dict.fromkeys(picks))
    if rng.random() < wild or len(picks) < n:
        rest = [b for b in cands if b not in picks]
        if rest: picks.append(rng.choice(rest))
    while len(picks) < n:
        rest = [b for b in cands if b not in picks]
        if not rest: break
        picks.append(rng.choice(rest))
    return picks[:n]

def montecarlo(runs: int, picks: int, policy: str, seed=1):
    rng = random.Random(seed)
    finals, trajectories = [], []
    pick_count, win_sum = defaultdict(int), defaultdict(float)
    for _ in range(runs):
        owned = []; traj = []
        for i in range(picks):
            offs = offer(owned, rng)
            if not offs: break
            if policy == "random":
                choice = rng.choice(offs)
            elif policy == "greedy":
                choice = max(offs, key=lambda b: marginal_gain(b, owned))
            elif policy == "loyal":
                have = set()
                for b in owned: have |= b.offer_tags | b.tags_add
                choice = max(offs, key=lambda b: (len(b.offer_tags & have), rng.random()))
            else: raise ValueError(policy)
            owned.append(choice)
            traj.append(eval_build(owned)["dps"])
        finals.append(traj[-1]); trajectories.append(traj)
        for b in owned: pick_count[b.name] += 1; win_sum[b.name] += traj[-1]
    return finals, trajectories, pick_count, win_sum

def pct(xs, p):
    xs = sorted(xs); return xs[min(len(xs) - 1, int(p * len(xs)))]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--picks", type=int, default=12)
    ap.add_argument("--runs", type=int, default=20000)
    ap.add_argument("--exhaustive-k", type=int, default=4)
    ap.add_argument("--json", type=str, default="")
    a = ap.parse_args()
    out = {}

    base = eval_build([])["dps"]
    print(f"pool size {len(POOL)} · base dps {base:.1f}\n")

    # --- solo + synergy
    solo, syn = synergy_matrix()
    print("== Solo value (× base dps) ==")
    for n, v in sorted(solo.items(), key=lambda kv: -kv[1]): print(f"  {v:5.2f}  {n}")
    top = sorted(syn.items(), key=lambda kv: -kv[1])[:12]
    anti = sorted(syn.items(), key=lambda kv: kv[1])[:6]
    print("\n== Strongest pair synergies (both / solo_a×solo_b) ==")
    for (x, y), v in top: print(f"  {v:5.2f}  {x} + {y}")
    print("\n== Anti-synergies ==")
    for (x, y), v in anti: print(f"  {v:5.2f}  {x} + {y}")
    out["solo"] = solo; out["synergy_top"] = [(x, y, v) for (x, y), v in top]

    # --- exhaustive k-subsets
    k = a.exhaustive_k
    ex = exhaustive(k)
    d = [x[0] for x in ex]
    print(f"\n== Exhaustive: all {len(ex)} {k}-buff builds ==")
    print(f"  min {min(d):8.1f}  p10 {pct(d,.1):8.1f}  p50 {pct(d,.5):8.1f}  p90 {pct(d,.9):8.1f}  max {max(d):8.1f}")
    print(f"  spread p90/p10 = {pct(d,.9)/pct(d,.1):.2f}×   max/p50 = {max(d)/pct(d,.5):.2f}×")
    print("  top 5:")
    for v, c in ex[:5]: print(f"    {v:8.1f}  {' + '.join(c)}")
    print("  bottom 3:")
    for v, c in ex[-3:]: print(f"    {v:8.1f}  {' + '.join(c)}")
    out["exhaustive"] = dict(k=k, n=len(ex), p10=pct(d,.1), p50=pct(d,.5), p90=pct(d,.9), max=max(d), top=ex[:5])

    # --- dead picks: marginal gain across random contexts
    rng = random.Random(7)
    print(f"\n== Dead-pick scan (marginal gain over 300 random 5-buff contexts) ==")
    dead = []
    for b in POOL:
        gains = []
        for _ in range(300):
            ctx = rng.sample([x for x in POOL if x is not b], 5)
            gains.append(marginal_gain(b, ctx))
        med = statistics.median(gains); lo = pct(gains, .1); hi = pct(gains, .9)
        flag = "DEAD" if hi < 0.05 else ("weak" if med < 0.05 else "")
        dead.append((b.name, med, lo, hi, flag))
    for n, med, lo, hi, flag in sorted(dead, key=lambda t: t[1]):
        print(f"  {med:+6.1%}  (p10 {lo:+6.1%} · p90 {hi:+6.1%})  {n:16s} {flag}")
    out["marginal"] = dead

    # --- monte carlo runs
    print(f"\n== Monte Carlo: {a.runs} runs × {a.picks} picks, offer-of-3, tag-loyal offers ==")
    mc = {}
    for policy in ("random", "loyal", "greedy"):
        finals, trajs, pc, ws = montecarlo(a.runs, a.picks, policy)
        p10, p50, p90, mx = pct(finals,.1), pct(finals,.5), pct(finals,.9), max(finals)
        print(f"  [{policy:6s}] final dps  p10 {p10:9.0f}  p50 {p50:9.0f}  p90 {p90:9.0f}  max {mx:10.0f}   p90/p10 {p90/p10:5.2f}×  max/p50 {mx/p50:6.1f}×")
        mc[policy] = dict(p10=p10, p50=p50, p90=p90, max=mx, finals=finals, trajs=trajs, picks=pc, wins=ws)
    out["mc"] = {k: {kk: vv for kk, vv in v.items() if kk in ("p10","p50","p90","max")} for k, v in mc.items()}

    # --- progress track vs enemy HP: time-to-kill trajectory
    print(f"\n== Progress track (loyal policy): dps percentiles per pick vs enemy HP ==")
    trajs = mc["loyal"]["trajs"]
    print("  pick   hp      p10dps   p50dps   p90dps   ttk_p10  ttk_p50  ttk_p90")
    track = []
    for i in range(a.picks):
        col = [t[i] for t in trajs if len(t) > i]
        hp = enemy_hp(i + 1)
        r = (i+1, hp, pct(col,.1), pct(col,.5), pct(col,.9))
        ttk = [hp / x for x in r[2:]]
        print(f"  {r[0]:4d} {hp:7.0f} {r[2]:9.0f} {r[3]:8.0f} {r[4]:8.0f}   {ttk[0]:6.2f}s  {ttk[1]:6.2f}s  {ttk[2]:6.2f}s")
        track.append(dict(pick=r[0], hp=hp, p10=r[2], p50=r[3], p90=r[4], ttk=ttk))
    out["track"] = track

    # --- dominance: pick-rate vs average final of runs containing it (greedy policy)
    print(f"\n== Dominance (greedy policy): pick rate and avg final dps of runs containing buff ==")
    pc, ws = mc["greedy"]["picks"], mc["greedy"]["wins"]
    overall = statistics.mean(mc["greedy"]["finals"])
    rows = []
    for b in POOL:
        n = pc.get(b.name, 0)
        avg = ws[b.name] / n if n else 0
        rows.append((b.name, n / a.runs, avg / overall if overall else 0))
    for n, pr, lift in sorted(rows, key=lambda t: -t[1]):
        flag = "DOMINANT" if pr > 0.75 and lift > 1.3 else ("never" if pr < 0.05 else "")
        print(f"  pick {pr:5.1%}  lift {lift:4.2f}×  {n:16s} {flag}")
    out["dominance"] = rows

    if a.json:
        with open(a.json, "w") as f: json.dump(out, f, indent=1, default=str)
        print(f"\nwrote {a.json}")

if __name__ == "__main__":
    main()
