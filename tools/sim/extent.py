#!/usr/bin/env python3
"""extent.py <sim.json>...: x/y range of the menu-group pieces a simulated screen drew (resolved through Attach)."""
import json, sys, os
for path in sys.argv[1:]:
    d = json.load(open(path)); log = d['Log']
    obj = {e['Id']: dict(e, parent=None, ax=0, ay=0) for e in log if e['K'] == 'Spawn'}
    for e in log:
        if e['K'] == 'Attach' and e.get('Id') in obj:
            obj[e['Id']].update(parent=e.get('Dest'), ax=e.get('OX') or 0, ay=e.get('OY') or 0)
    def pos(i, n=0):
        o = obj[i]
        if o['parent'] in obj and n < 10:
            px, py = pos(o['parent'], n + 1); return px + o['ax'], py + o['ay']
        return o['X'], o['Y']
    xs = []; ys = []
    for i, o in obj.items():
        g = o.get('Group') or ''
        if not g.startswith('Combat_Menu') and not g.startswith('Menu'): continue
        if (o.get('Name') or '') == 'rectangle01': continue
        x, y = pos(i)
        if x is None or (abs(x - 960) < 1 and abs(y - 720) < 1) or y - 720 >= 440: continue
        xs.append(x); ys.append(y)
    name = os.path.basename(path).split('.')[0]
    if xs: print(f"{name:14} ok={d['Ok']!s:5} n={len(xs):4} x {min(xs):6.0f}..{max(xs):6.0f}  y {min(ys):6.0f}..{max(ys):6.0f}  {d['Status'][:60]}")
    else: print(f"{name:14} ok={d['Ok']!s:5} nothing  {d['Status'][:100]}")
