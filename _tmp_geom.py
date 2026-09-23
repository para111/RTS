import re, math, json

html = open(r'c:\Users\nanami\Desktop\FB\WG.html', encoding='utf-8').read()
head = html.split('redForbiddenZones:')[0]
wb = re.search(r'walkableBoundary:\s*\[(.*?)\n\s*\],', head, re.S).group(1)
wb_pts = [(float(a), float(b)) for a, b in re.findall(r'x:\s*([-\d.]+),\s*y:\s*([-\d.]+)', wb)]

zones_text = html.split('redForbiddenZones:')[1]
zones = []
for z in re.findall(r'\[\s*((?:\{.*?\}\s*,?\s*)+)\]', zones_text, re.S)[:2]:
    zones.append([(float(a), float(b)) for a, b in re.findall(r'x:\s*([-\d.]+),\s*y:\s*([-\d.]+)', z)])
print('walkable pts', len(wb_pts), 'zones', [len(z) for z in zones])


def inside(x, y, poly):
    r = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            if x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-6) + x1:
                r = not r
    return r


def dist_to_poly(x, y, poly):
    best = 1e9
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        L = dx * dx + dy * dy
        t = 0 if L == 0 else max(0, min(1, ((x - x1) * dx + (y - y1) * dy) / L))
        best = min(best, math.hypot(x - (x1 + t * dx), y - (y1 + t * dy)))
    return best


def blocked(x, y):
    return any(inside(x, y, z) for z in zones)


def walkable(x, y):
    return inside(x, y, wb_pts) and not blocked(x, y)


def safe(x, y, clearance=19):
    if not walkable(x, y):
        return False
    return all(dist_to_poly(x, y, z) >= clearance - 0.0001 for z in zones)


for p in [(3200, 2300), (1114, 1653), (3061, 2029), (3300, 1990), (3400, 1000), (627, 1500)]:
    print(p, 'insideWB', inside(*p, wb_pts), 'blocked', blocked(*p), 'safe', safe(*p))

# 走廊剖面：x=3100 处从 y=2200 到 y=2340 的可行走范围
for x in (3100, 3200, 3300, 3400):
    ok = [y for y in range(2150, 2360, 2) if walkable(x, y)]
    red = [y for y in range(2150, 2360, 2) if blocked(x, y)]
    print('x=', x, 'walkable y', (min(ok), max(ok)) if ok else None, 'red y', (min(red), max(red)) if red else None)
