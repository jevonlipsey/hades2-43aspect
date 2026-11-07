#!/usr/bin/env python3
"""compare.py <vanilla.json> <patched.json> [--all]: what the patch changed in one simulated screen."""
import json, sys
v = json.load(open(sys.argv[1]))['Log']; p = json.load(open(sys.argv[2]))['Log']
show_all = '--all' in sys.argv
if len(v) != len(p): print(f"! different call counts: vanilla {len(v)} patched {len(p)}")
def f(x): return '-' if x is None else f"{x:.0f}" if isinstance(x,(int,float)) and abs(x)>=10 else f"{x:.3g}" if isinstance(x,(int,float)) else str(x)
changed = 0
for a, b in zip(v, p):
    keys = ['X','Y','Scale','OX','OY','FontSize','Width','Fraction']
    diff = any(a.get(k) != b.get(k) for k in keys)
    changed += diff
    if diff or show_all:
        label = a.get('Name') or ''
        if a.get('Anim'): label += '/' + a['Anim']
        if a.get('Text'): label += ' "' + a['Text'][:24] + '"'
        vals = ' '.join(f"{k}={f(a.get(k))}>{f(b.get(k))}" if a.get(k)!=b.get(k) else f"{k}={f(a.get(k))}" for k in keys if a.get(k) is not None or b.get(k) is not None)
        print(f"{'*' if diff else ' '} {a['K']:8} {label[:48]:48} {vals}  [{a['Stack'][:90]}]")
print(f"{changed}/{len(v)} calls changed")
