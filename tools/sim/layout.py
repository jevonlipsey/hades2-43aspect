#!/usr/bin/env python3
"""layout.py <sim.json>: resolved screen positions (following Attach) of everything a simulated screen drew."""
import json, sys
log = json.load(open(sys.argv[1]))['Log']
obj = {}
for e in log:
    if e['K'] == 'Spawn': obj[e['Id']] = dict(e, parent=None, ax=0, ay=0, texts=[])
for e in log:
    if e['K'] == 'Attach' and e.get('Id') in obj:
        o = obj[e['Id']]; o['parent'] = e.get('Dest'); o['ax'] = e.get('OX') or 0; o['ay'] = e.get('OY') or 0
    if e['K'] == 'Teleport' and e.get('Id') in obj and e.get('Dest') is None:
        o = obj[e['Id']]; o['X'] = e.get('OX', o['X']); o['Y'] = e.get('OY', o['Y'])
    if e['K'] == 'Text' and e.get('Id') in obj: obj[e['Id']]['texts'].append(e)
def pos(i, d=0):
    o = obj.get(i)
    if o is None or d > 10: return (None, None)
    if o['parent'] in obj:
        px, py = pos(o['parent'], d + 1)
        if px is not None: return (px + o['ax'], py + o['ay'])
    return (o['X'], o['Y'])
for i, o in obj.items():
    x, y = pos(i)
    lab = (o.get('Name') or '') + ('/' + o['Anim'] if o.get('Anim') else '')
    t = ' | '.join(f"{(tx.get('Text') or '')[:22]} ox={tx.get('OX')} oy={tx.get('OY')} w={tx.get('Width')} fs={tx.get('FontSize')}" for tx in o['texts'])
    fx = lambda v: '-' if v is None else f"{v:.0f}"
    print(f"{i} {lab[:44]:44} x={fx(x):>5} y={fx(y):>5} s={o.get('Scale') or 1:<5} g={o.get('Group')} {t[:120]}  [{o['Stack'].split('<')[2] if o['Stack'].count('<')>=2 else o['Stack']}]")
