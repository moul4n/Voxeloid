def run(f=0.4, layers=40, r=1.25, M0=100.0, tier_every=5, dens=2.0,
        R0=10.0, up=1.12, C0=400.0, cmult=1.20, Umax=None, cap=500_000_000):
    t=0; n=0; U=0; bank=0.0; lm=0.0; last=0; per=[]
    while n < layers and t < cap:
        d = dens ** (n // tier_every)
        gained = R0*(up**U)*d
        lm += gained*(1-f); bank += gained*f
        while (Umax is None or U < Umax) and bank >= C0*(cmult**U):
            bank -= C0*(cmult**U); U += 1
        t += 1
        if lm >= M0*(r**n):
            per.append(t-last); last=t; lm=0.0; n+=1
    ok = (n>=layers)
    assert not ok or abs(sum(per)-t)<1e-6, "duration bookkeeping"
    return (t if ok else None), U, per

def line(name, **kw):
    t,U,p = run(**kw)
    if t is None: print(f"{name:24s}  walled out"); return
    g = lambda i: f"{p[i]:6.0f}" if i<len(p) else "     -"
    rising = all(p[i] <= p[i+5]*1.02 for i in range(0,35,5))
    print(f"{name:24s} {t/60:7.1f}m U={U:3d} {'RISING' if rising else 'falls '}  "
          f"L1{g(0)} L10{g(9)} L20{g(19)} L30{g(29)} L40{g(39)}   L40/L10 {p[39]/p[9]:5.1f}x")

print("=== run 1's settings, measured correctly ===")
line("unlimited upgrades", r=1.25, dens=2.0, Umax=None)

print("\n=== cap the building tree — a world has finite room to build on ===")
for um in [12,18,25,40]: line(f"  Umax={um}", r=1.25, dens=2.0, Umax=um)

print("\n=== plus a steeper threshold ===")
for r in [1.30,1.35,1.40]: line(f"  r={r} Umax=18", r=r, dens=2.0, Umax=18)

print("\n=== plus smaller density steps ===")
for D in [1.5,1.8,2.2]: line(f"  dens x{D} r=1.35", r=1.35, dens=D, Umax=18)

print("\n=== candidate: r=1.35, dens x1.8, 18 buildings ===")
t,U,p = run(f=0.4, r=1.35, dens=1.8, Umax=18)
print(f"  total {t/60:.0f} min, {U} buildings, total checks out ({sum(p)==t})\n")
for k in range(0,40,5):
    seg=p[k:k+5]
    print(f"    tier {k//5}  layers {k+1:2d}-{k+5:2d}: " + " ".join(f"{x:5.0f}" for x in seg) + f"   = {sum(seg)/60:5.1f} min")
print(f"\n  final layer is {p[39]/p[0]:.0f}x layer 1 and {p[39]/p[9]:.1f}x layer 10")
drops = [k//5 for k in range(5,40,5) if p[k] < p[k-1]]
print(f"  tiers that give a visible relief drop: {drops if drops else 'none'}")

print("\n=== eat/seal still a real choice at these settings? ===")
for f in [0,.2,.3,.4,.5,.6,.8]:
    t,U,p = run(f=f, r=1.35, dens=1.8, Umax=18)
    print(f"  eat {f:3.0%}: " + (f"{t/60:7.1f} min   last layer {p[39]:5.0f}s" if t else "walled out"))

print("\n\n=== grid: which settings give a 45-90 min world with a real final push? ===")
print("  r     dens  Umax   best-eat  total   L1    L20    L40   L40/L10  monotonic")
best=[]
for r in [1.26,1.28,1.30,1.32]:
    for D in [1.8,2.0,2.2]:
        for um in [14,16,18,20]:
            res=[(run(f=f,r=r,dens=D,Umax=um),f) for f in (.2,.3,.4,.5)]
            res=[(t,U,p,f) for (t,U,p),f in res if t]
            if not res: continue
            t,U,p,f = min(res)
            if not (45*60 <= t <= 95*60): continue
            mono = sum(1 for i in range(1,40) if p[i]>=p[i-1])
            best.append((abs(t-65*60), r,D,um,f,t,p,mono))
best.sort()
for _,r,D,um,f,t,p,mono in best[:8]:
    print(f"  {r}  {D}   {um}     {f:.0%}   {t/60:5.1f}m {p[0]:5.0f} {p[19]:6.0f} {p[39]:6.0f}  {p[39]/p[9]:6.1f}x   {mono}/39")

if best:
    _,r,D,um,f,t,p,mono = best[0]
    print(f"\n=== pick: r={r}, density x{D}, {um} buildings, eat {f:.0%} ===")
    for k in range(0,40,5):
        seg=p[k:k+5]
        print(f"    tier {k//5}  layers {k+1:2d}-{k+5:2d}: " + " ".join(f"{x:5.0f}" for x in seg) + f"   = {sum(seg)/60:5.1f} min")
    print(f"\n  world total {t/60:.0f} min | layer 1 {p[0]:.0f}s | layer 40 {p[39]/60:.1f} min | final is {p[39]/p[0]:.0f}x the first")
    print(f"  rising on {mono} of 39 steps; the dips are the element-tier reliefs")
    print("\n  eat/seal sweep at these settings:")
    for ff in [0,.1,.2,.3,.4,.5,.7]:
        tt,_,pp = run(f=ff,r=r,dens=D,Umax=um)
        print(f"    eat {ff:3.0%}: " + (f"{tt/60:6.1f} min" if tt else "walled out"))
