"""Invariants that a later engine implementation must preserve."""
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import unittest

from generate import (BIOMES, EPSILON, EXTENT, SECTOR, SIDE, SPACING,
                      extract_sector, generate, stable_id)


class TerrainTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.world = generate(731)

    def test_same_seed_repeats_and_another_seed_changes_world(self):
        self.assertEqual(self.world, generate(731))
        other = generate(732)
        self.assertNotEqual(self.world["grid"]["height_m"], other["grid"]["height_m"])
        self.assertNotEqual(self.world["grid"]["biome_weights"], other["grid"]["biome_weights"])

    def test_addresses_do_not_depend_on_python_hash_or_unrelated_calls(self):
        wanted = stable_id("tree", 731, -12, 44)
        for index in range(100):
            stable_id("lamp", 731, index, 44)
        self.assertEqual(wanted, stable_id("tree", 731, -12, 44))
        self.assertNotEqual(wanted, stable_id("lamp", 731, -12, 44))
        self.assertNotEqual(wanted, stable_id("tree", 732, -12, 44))
        command = [sys.executable, "-B", "-c", "from generate import stable_id; print(stable_id('tree',731,-12,44))"]
        for hash_seed in ("1", "984"):
            result = subprocess.check_output(command, cwd=Path(__file__).parent,
                                             env={**os.environ, "PYTHONHASHSEED": hash_seed}, text=True)
            self.assertEqual(result.strip(), wanted)

    def test_sector_order_and_all_shared_samples_are_identical(self):
        addresses = [(x, z) for z in range(EXTENT // SECTOR) for x in range(EXTENT // SECTOR)]
        before = json.dumps(self.world, sort_keys=True)
        reference = {address: extract_sector(self.world, *address) for address in addresses}
        for ordering in (list(reversed(addresses)), sorted(addresses, key=lambda p: stable_id("order", 93, *p))):
            self.assertEqual(reference, {address: extract_sector(self.world, *address) for address in ordering})
        unique = {}
        duplicates, shared_water = 0, 0
        for sector in reference.values():
            for sample in sector["samples"]:
                coordinate = (sample["x_m"], sample["z_m"])
                if coordinate in unique:
                    duplicates += 1
                    shared_water += sample["water_surface_m"] is not None
                    # Includes normals, weights, water levels, flow graph and stable ID.
                    self.assertEqual(unique[coordinate], sample)
                else:
                    unique[coordinate] = sample
        self.assertGreater(duplicates, 1000)
        self.assertGreater(shared_water, 0)
        self.assertEqual(len(unique), SIDE * SIDE)
        self.assertEqual(before, json.dumps(self.world, sort_keys=True))
        # A consumer editing its extracted sample cannot corrupt the shared source.
        extracted = extract_sector(self.world, 0, 0)
        extracted["samples"][0]["normal"][0] = 999
        extracted["samples"][0]["biome_weights"][0] = 999
        self.assertEqual(before, json.dumps(self.world, sort_keys=True))

    def test_all_drainage_paths_reach_outlet_without_cycles(self):
        parent = self.world["grid"]["downstream"]
        outlet = self.world["outlet_index"]
        self.assertEqual([i for i, value in enumerate(parent) if value < 0], [outlet])
        resolved = {outlet}
        for start in range(len(parent)):
            path, index = set(), start
            while index not in resolved:
                self.assertNotIn(index, path, "cycle in drainage")
                path.add(index)
                nxt = parent[index]
                self.assertGreaterEqual(nxt, 0)
                z, x = divmod(index, SIDE)
                nz, nx = divmod(nxt, SIDE)
                self.assertTrue(max(abs(x - nx), abs(z - nz)) == 1)
                index = nxt
            resolved.update(path)
        self.assertEqual(len(resolved), SIDE * SIDE)

    def test_rivers_remain_connected_and_never_run_uphill(self):
        grid = self.world["grid"]
        self.assertGreater(sum(grid["river"]), 10)
        self.assertGreater(sum(grid["lake"]), 0)
        for index, nxt in enumerate(grid["downstream"]):
            if nxt >= 0:
                self.assertGreaterEqual(grid["routing_height_m"][index] - grid["routing_height_m"][nxt], EPSILON - 1e-9)
                if grid["river"][index]:
                    self.assertTrue(grid["river"][nxt], "river disappears before its outlet")
                    self.assertGreater(grid["water_surface_m"][index], grid["water_surface_m"][nxt])
                    self.assertGreater(grid["flow_units"][nxt], grid["flow_units"][index])
            if grid["water_surface_m"][index] is not None:
                self.assertGreater(grid["water_depth_m"][index], 0)
                self.assertAlmostEqual(grid["height_m"][index] + grid["water_depth_m"][index], grid["water_surface_m"][index])
        self.assertAlmostEqual(self.world["summary"]["rain_total_units"], self.world["summary"]["outlet_flow_units"], places=7)

    def test_fields_are_finite_and_weights_and_normals_are_normalized(self):
        grid = self.world["grid"]
        for index in range(SIDE * SIDE):
            weights, normal = grid["biome_weights"][index], grid["normal"][index]
            self.assertEqual(len(weights), len(BIOMES))
            self.assertTrue(all(math.isfinite(value) and 0 <= value <= 1 for value in weights))
            self.assertAlmostEqual(sum(weights), 1)
            self.assertAlmostEqual(sum(value * value for value in normal), 1)
            self.assertGreater(normal[1], 0)
            self.assertTrue(math.isfinite(grid["height_m"][index]))
            self.assertTrue(0 <= grid["moisture"][index] <= 1)
        for address in ((-1, 0), (0, 8)):
            with self.assertRaises(ValueError):
                extract_sector(self.world, *address)


if __name__ == "__main__":
    unittest.main()
