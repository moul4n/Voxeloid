#!/usr/bin/env python3

import copy
import json
import unittest
from pathlib import Path

from progression_model import load_config, simulate


CONFIG = Path(__file__).with_name("progression_balance.json")


class ProgressionModelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = load_config(CONFIG)

    def test_config_round_trips_as_json(self) -> None:
        self.assertEqual(1, json.loads(json.dumps(self.config))["model_version"])

    def test_both_envelopes_complete_and_best_is_faster(self) -> None:
        best = simulate(self.config, "best")
        worst = simulate(self.config, "worst")
        self.assertTrue(best.completed)
        self.assertTrue(worst.completed)
        self.assertLess(best.seconds, worst.seconds)
        self.assertGreaterEqual(best.seconds, 6 * 3600)
        self.assertLessEqual(best.seconds, 8 * 3600)
        self.assertGreaterEqual(worst.seconds, 10 * 3600)
        self.assertLessEqual(worst.seconds, 13 * 3600)

    def test_automation_starts_below_manual_then_crosses(self) -> None:
        best = simulate(self.config, "best")
        unlock = next(event for event in best.events if event.detail.endswith("Automatic Invocation"))
        crossover = next(event for event in best.events if event.kind == "automation_crossover")
        self.assertGreater(crossover.seconds, unlock.seconds)
        self.assertLess(crossover.seconds - unlock.seconds, 10 * 60)
        source = self.config["source"]
        for scenario in self.config["scenarios"].values():
            initial_auto = (
                source["automatic_activations_per_second"]
                * source["base_capture_efficiency"]
                * scenario["source_yield_multiplier"]
            )
            self.assertLess(initial_auto, scenario["manual_activations_per_second"])

    def test_focused_first_compact_hits_design_window(self) -> None:
        best = simulate(self.config, "best")
        first = next(event for event in best.events if event.kind == "compact")
        self.assertGreaterEqual(first.seconds, 10 * 60)
        self.assertLessEqual(first.seconds, 15 * 60)

    def test_body_mass_increases_ambient_capture(self) -> None:
        normal = simulate(self.config, "best")
        changed = copy.deepcopy(self.config)
        changed["ambient"]["mass_log10_gain"] = 0.0
        flat = simulate(changed, "best")
        self.assertGreater(normal.ambient_mass, flat.ambient_mass)

    def test_every_compaction_conserves_positive_mass(self) -> None:
        result = simulate(self.config, "best")
        compacts = [event for event in result.events if event.kind == "compact"]
        expected = sum(int(body["compactions"]) for body in self.config["campaign"])
        self.assertEqual(expected, len(compacts))
        self.assertTrue(all(event.amount > 0 for event in compacts))
        generated = result.singularity_mass + result.ambient_mass
        allocated = result.core_assimilated_mass + result.body_mass
        self.assertAlmostEqual(generated, allocated, delta=generated * 1e-9)


if __name__ == "__main__":
    unittest.main()
