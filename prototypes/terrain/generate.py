#!/usr/bin/env python3
"""Finite terrain/hydrology reference; Python standard library only, not a game."""
import argparse
import base64
import hashlib
import heapq
import json
import math
from pathlib import Path
import struct
import zlib

VERSION = "oozing-basin-reference-1"
EXTENT, SPACING, SECTOR = 3200, 25, 400
SIDE = EXTENT // SPACING + 1
MASK = (1 << 64) - 1
EPSILON = 0.005  # Numerical drainage grade, not a physical lake simulation.
BIOMES = ("steppe", "tall_grass", "forest", "floodplain", "rock")
COLORS = ((198, 170, 80), (142, 177, 82), (43, 106, 91), (107, 181, 156), (150, 129, 161))


def clamp(value, lo=0.0, hi=1.0):
    return max(lo, min(hi, value))


def random01(seed, x, z, salt=0):
    """Addressed randomness: no mutable RNG and no process-dependent hash()."""
    value = (seed ^ (x * 0x9E3779B185EBCA87) ^ (z * 0xC2B2AE3D27D4EB4F) ^ salt) & MASK
    value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & MASK
    value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & MASK
    value ^= value >> 31
    return (value >> 11) / float(1 << 53)


def stable_id(kind, seed, x, z):
    address = json.dumps([VERSION, kind, seed, x, z], separators=(",", ":"))
    return hashlib.blake2b(address.encode("utf-8"), digest_size=12).hexdigest()


def noise(seed, x, z, scale, salt=0):
    x, z = x / scale, z / scale
    ix, iz = math.floor(x), math.floor(z)
    tx, tz = x - ix, z - iz
    tx, tz = tx * tx * (3 - 2 * tx), tz * tz * (3 - 2 * tz)
    a = random01(seed, ix, iz, salt) * (1 - tx) + random01(seed, ix + 1, iz, salt) * tx
    b = random01(seed, ix, iz + 1, salt) * (1 - tx) + random01(seed, ix + 1, iz + 1, salt) * tx
    return 2 * (a * (1 - tz) + b * tz) - 1


def raw_height(seed, x, z):
    """Continuous global-coordinate field for this single, deliberately shaped basin."""
    u, v = (x - EXTENT / 2) / 1600, (z - EXTENT / 2) / 1600
    warp = 100 * noise(seed, x, z, 900, 1)
    broad = 42 * noise(seed, x + warp, z, 820, 2)
    detail = 14 * noise(seed, x, z, 250, 3) + 4 * noise(seed, x, z, 90, 4)
    # Mountains, a winding valley, a gorge and two hollows are independent of sectors.
    peak_a = 320 * math.exp(-((u + .59) ** 2 / .11 + (v + .37) ** 2 / .27))
    peak_b = 270 * math.exp(-((u - .66) ** 2 / .15 + (v + .12) ** 2 / .35))
    channel = .16 * math.sin(4.8 * v + random01(seed, 0, 0, 83))
    valley = 85 * math.exp(-((u - channel) / .20) ** 2)
    gorge = 36 * math.exp(-((u - channel) / .047) ** 2) * math.exp(-((v - .50) / .25) ** 2)
    hollow = 60 * math.exp(-((u + .17) ** 2 / .035 + (v + .05) ** 2 / .016))
    hollow += 42 * math.exp(-((u - .43) ** 2 / .025 + (v - .34) ** 2 / .018))
    return 128 + 64 * (1 - v) + 130 * abs(u) ** 1.7 + peak_a + peak_b + broad + detail - valley - gorge - hollow


def neighbors(index, side=SIDE):
    z, x = divmod(index, side)
    for dz in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if (dx or dz) and 0 <= x + dx < side and 0 <= z + dz < side:
                yield (z + dz) * side + x + dx, math.hypot(dx, dz) * SPACING


def priority_flood(heights, outlet):
    """A closed finite watershed with one outlet; parent is always finalized earlier."""
    levels = [None] * len(heights)
    parent = [-1] * len(heights)
    levels[outlet] = heights[outlet]
    queue, order = [(heights[outlet], outlet)], []
    while queue:
        level, index = heapq.heappop(queue)
        order.append(index)
        for nxt, _ in neighbors(index):
            if levels[nxt] is None:
                levels[nxt] = max(heights[nxt], level + EPSILON)
                parent[nxt] = index
                heapq.heappush(queue, (levels[nxt], nxt))
    return levels, parent, order


def water_distances(wet):
    distances = [0.0 if flag else math.inf for flag in wet]
    queue = [(0.0, index) for index, flag in enumerate(wet) if flag]
    heapq.heapify(queue)
    while queue:
        distance, index = heapq.heappop(queue)
        if distance != distances[index]:
            continue
        for nxt, step in neighbors(index):
            candidate = distance + step
            if candidate < distances[nxt]:
                distances[nxt] = candidate
                heapq.heappush(queue, (candidate, nxt))
    return distances


def normal_at(heights, x, z):
    # Global halo: at internal sector edges use the actual neighbor, never a sector clamp.
    xa, xb, za, zb = max(x - 1, 0), min(x + 1, SIDE - 1), max(z - 1, 0), min(z + 1, SIDE - 1)
    dx = (heights[z * SIDE + xb] - heights[z * SIDE + xa]) / ((xb - xa) * SPACING)
    dz = (heights[zb * SIDE + x] - heights[za * SIDE + x]) / ((zb - za) * SPACING)
    length = math.sqrt(dx * dx + dz * dz + 1)
    return [-dx / length, 1 / length, -dz / length]


def generate(seed=731):
    heights = [raw_height(seed, x * SPACING, z * SPACING) for z in range(SIDE) for x in range(SIDE)]
    outlet = min(range((SIDE - 1) * SIDE, SIDE * SIDE), key=lambda i: (heights[i], i))
    levels, parents, order = priority_flood(heights, outlet)
    rain = [1 + .35 * noise(seed, (i % SIDE) * SPACING, (i // SIDE) * SPACING, 700, 8) for i in range(len(heights))]
    flow = rain[:]
    for i in reversed(order):
        if parents[i] >= 0:
            flow[parents[i]] += flow[i]
    river = [value >= 160 for value in flow]
    lake = [levels[i] - height > 1.5 for i, height in enumerate(heights)]
    wet = [a or b for a, b in zip(river, lake)]
    distances = water_distances(wet)
    for i, flag in enumerate(river):
        if flag:
            heights[i] = min(heights[i], levels[i] - (.45 + min(2, math.sqrt(flow[i]) * .035)))
    normals, moisture, temperatures, weights, dominant = [], [], [], [], []
    for i, height in enumerate(heights):
        z, x = divmod(i, SIDE)
        normal = normal_at(heights, x, z)
        slope = math.sqrt(normal[0] ** 2 + normal[2] ** 2) / normal[1]
        m = clamp(.43 + .30 * noise(seed, x * SPACING, z * SPACING, 980, 31) + .25 * math.exp(-distances[i] / 240))
        t = clamp(.95 - height / 750 + .10 * noise(seed, x * SPACING, z * SPACING, 1250, 32))
        rocky = clamp((slope - .25) / .75 + (height - 340) / 260)
        values = [math.exp(-((m - .29) / .20) ** 2 - ((t - .73) / .45) ** 2) * (1 - rocky),
                  math.exp(-((m - .53) / .17) ** 2 - ((t - .68) / .40) ** 2) * (1 - rocky),
                  math.exp(-((m - .78) / .23) ** 2 - ((t - .56) / .40) ** 2) * (1 - rocky),
                  .90 * math.exp(-distances[i] / 65) * (1 - rocky), .035 + 2 * rocky]
        total = sum(values)
        values = [value / total for value in values]
        normals.append(normal)
        moisture.append(m)
        temperatures.append(t)
        weights.append(values)
        dominant.append(max(range(len(values)), key=lambda k: values[k]))
    grid = {"height_m": heights, "routing_height_m": levels,
            "water_surface_m": [levels[i] if wet[i] else None for i in range(len(heights))],
            "water_depth_m": [levels[i] - heights[i] if wet[i] else 0 for i in range(len(heights))],
            "lake": lake, "river": river, "flow_units": flow, "downstream": parents,
            "moisture": moisture, "temperature": temperatures, "normal": normals,
            "biome_weights": weights, "biome": dominant}
    return {"generator_version": VERSION, "seed": seed, "extent_m": EXTENT,
            "sector_size_m": SECTOR, "spacing_m": SPACING, "side_samples": SIDE,
            "outlet_index": outlet, "biome_names": BIOMES,
            "summary": {"height_min_m": min(heights), "height_max_m": max(heights),
                        "river_samples": sum(river), "lake_samples": sum(lake),
                        "rain_total_units": sum(rain), "outlet_flow_units": flow[outlet],
                        "biome_sample_counts": {name: dominant.count(j) for j, name in enumerate(BIOMES)}},
            "limits": ["finite single watershed", "closed boundary except one outlet", "25m diagnostic grid",
                       "no runtime water, caves, collisions, erosion, NPCs, Earth fragments or game renderer"], "grid": grid}


def extract_sector(world, sx, sz):
    """Closed 17×17 samples include shared edges; extraction is a pure lookup."""
    if not (0 <= sx < EXTENT // SECTOR and 0 <= sz < EXTENT // SECTOR):
        raise ValueError("sector coordinates must be in 0..7")
    stride = SECTOR // SPACING
    samples = []
    for z in range(sz * stride, (sz + 1) * stride + 1):
        for x in range(sx * stride, (sx + 1) * stride + 1):
            index = z * SIDE + x
            sample = {"id": stable_id("sample", world["seed"], x, z), "x_m": x * SPACING, "z_m": z * SPACING}
            sample.update({name: value[index][:] if isinstance(value[index], list) else value[index]
                           for name, value in world["grid"].items()})
            samples.append(sample)
    return {"sector": [sx, sz], "samples": samples}


def png_bytes(width, height, pixels):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    rows = b"".join(b"\x00" + pixels[z * width * 3:(z + 1) * width * 3] for z in range(height))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b"")


def palette(fraction):
    stops = [(27, 77, 95), (84, 145, 119), (191, 171, 105), (164, 127, 142), (233, 223, 220)]
    position = clamp(fraction) * (len(stops) - 1)
    lo = min(int(position), len(stops) - 2)
    blend = position - lo
    return [a * (1 - blend) + b * blend for a, b in zip(stops[lo], stops[lo + 1])]


def render_panel(world, mode, scale=4):
    size, pixels, grid = SIDE * scale, bytearray(SIDE * SIDE * scale * scale * 3), world["grid"]
    low, high = min(grid["height_m"]), max(grid["height_m"])
    for i, height in enumerate(grid["height_m"]):
        z, x = divmod(i, SIDE)
        if mode == 0:
            color = palette((height - low) / (high - low))
        elif mode == 1:
            color = [sum(grid["biome_weights"][i][j] * COLORS[j][channel] for j in range(len(BIOMES))) for channel in range(3)]
        else:
            gray = 58 + 88 * (height - low) / (high - low)
            color = [gray * .90, gray, gray * 1.06]
        normal = grid["normal"][i]
        shade = clamp(.74 + .38 * (-normal[0] * .50 + normal[1] * .75 - normal[2] * .43), .5, 1.15)
        color = [int(clamp(value * shade, 0, 255)) for value in color]
        if grid["water_surface_m"][i] is not None:
            color = [28, 148, 183] if grid["lake"][i] else [85, 218, 223]
        for dz in range(scale):
            for dx in range(scale):
                pixel = color
                if (x % 16 == 0 and dx == 0) or (z % 16 == 0 and dz == 0):
                    pixel = [int(value * .70) for value in color]
                offset = ((z * scale + dz) * size + x * scale + dx) * 3
                pixels[offset:offset + 3] = bytes(pixel)
    return size, pixels


def write_preview(world, directory):
    panels = [render_panel(world, mode) for mode in range(3)]
    size = panels[0][0]
    combined = bytearray()
    for z in range(size):
        for _, pixels in panels:
            combined.extend(pixels[z * size * 3:(z + 1) * size * 3])
    (directory / "preview.png").write_bytes(png_bytes(size * 3, size, combined))
    width, height = size * 3 + 96, size + 220
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
           '<rect width="100%" height="100%" fill="#142c32"/>',
           '<g font-family="Arial, sans-serif" fill="#edf1df">',
           '<text x="24" y="36" font-size="25">OOZING · один водосбор Кромы</text>',
           f'<text x="24" y="62" font-size="15">Seed {world["seed"]} · 3,2 × 3,2 км · сетка 25 м · тёмные линии — сектора 400 × 400 м</text>']
    titles = ["Высота и формы рельефа", "Непрерывные веса биомов", "Вода и единый южный выход"]
    for index, ((_, pixels), title) in enumerate(zip(panels, titles)):
        x = 24 + index * (size + 24)
        payload = base64.b64encode(png_bytes(size, size, pixels)).decode("ascii")
        svg.append(f'<text x="{x}" y="94" font-size="18">{title}</text>')
        svg.append(f'<image x="{x}" y="108" width="{size}" height="{size}" href="data:image/png;base64,{payload}"/>')
    y = 108 + size + 28
    labels = ["Степь", "Высокая трава", "Лес", "Пойма", "Камень"]
    for index, (label, color) in enumerate(zip(labels, COLORS)):
        x = 24 + index * 180
        svg.append(f'<rect x="{x}" y="{y - 13}" width="18" height="18" fill="rgb{color}"/>')
        svg.append(f'<text x="{x + 27}" y="{y}" font-size="15">{label}</text>')
    svg.append(f'<text x="{24 + 5 * 180}" y="{y}" font-size="15" fill="#55dadf">Реки: светлые · озёра: синие</text>')
    svg.append(f'<text x="24" y="{y + 29}" font-size="15">Диагностика алгоритма. Не скриншот игры. Водная сетка схематична; ширина русла здесь не моделируется.</text>')
    svg.append(f'<text x="24" y="{y + 53}" font-size="15">Север сверху. Все стоки этого конечного бассейна достигают назначенного выхода; соседние бассейны ещё не реализованы.</text></g></svg>')
    (directory / "preview.svg").write_text("\n".join(svg), encoding="utf-8")


def rounded(value):
    if isinstance(value, float):
        return round(value, 6)
    if isinstance(value, dict):
        return {key: rounded(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [rounded(item) for item in value]
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=731)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.output is None:
        args.output = Path(__file__).resolve().parent / "outputs" / f"seed-{args.seed}"
    world = generate(args.seed)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "terrain.json").write_text(json.dumps(rounded(world), ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    write_preview(world, args.output)
    print(json.dumps({"output": str(args.output.resolve()), "summary": rounded(world["summary"])}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
