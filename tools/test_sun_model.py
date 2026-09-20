#!/usr/bin/env python3

import copy
import unittest
from pathlib import Path

from sun_model import layer_masses, load_config, simulate, temperature_mk


CONFIG = Path(__file__).with_name("sun_balance.json")


class SunModelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = load_config(CONFIG)

    def test_layer_mass_maps_to_one_solar_mass(self) -> None:
        masses = layer_masses(self.config)
        self.assertEqual(7, len(masses))
        self.assertAlmostEqual(976957.386, sum(masses), places=5)

    def test_temperature_hits_ignition_and_finished_values(self) -> None:
        physical = self.config["physical"]
        self.assertAlmostEqual(physical["ignition_temperature_mk"], temperature_mk(self.config, physical["ignition_smu"]), places=8)
        self.assertAlmostEqual(physical["finished_temperature_mk"], temperature_mk(self.config, physical["target_smu"]), places=8)

    def test_all_scenarios_complete_and_conserve_mass(self) -> None:
        for name in self.config["scenarios"]:
            with self.subTest(name=name):
                result = simulate(self.config, name)
                self.assertTrue(result.completed)
                allocated = result.core_mass + result.compacted_mass + result.loose_mass
                self.assertAlmostEqual(result.generated_mass, allocated, delta=result.generated_mass * 1e-9)

    def test_clicking_is_slower_than_holding(self) -> None:
        clicking = simulate(self.config, "click_no_upgrades")
        holding = simulate(self.config, "hold_no_upgrades")
        self.assertGreater(clicking.seconds, holding.seconds)

    def test_talents_reduce_active_sun_time(self) -> None:
        holding = simulate(self.config, "hold_no_upgrades")
        automation = simulate(self.config, "automation")
        self.assertLess(automation.seconds, holding.seconds)
        self.assertIsNotNone(automation.automation_crossover_seconds)

    def test_first_active_compact_stays_near_opening_target(self) -> None:
        automation = simulate(self.config, "automation")
        self.assertGreaterEqual(automation.first_compact_seconds, 8 * 60)
        self.assertLessEqual(automation.first_compact_seconds, 18 * 60)

    def test_thermal_build_has_strongest_overclock(self) -> None:
        thermal = simulate(self.config, "thermal_overclock")
        others = [simulate(self.config, name) for name in ("automation", "core_mass", "accretion")]
        self.assertGreater(thermal.peak_overclock, max(result.peak_overclock for result in others))

    def test_core_mass_build_keeps_assimilating_after_level_cap(self) -> None:
        mass_build = simulate(self.config, "core_mass")
        automation = simulate(self.config, "automation")
        self.assertEqual(self.config["core"]["sun_level_cap"], mass_build.core_level)
        self.assertGreater(mass_build.core_mass, automation.core_mass)

    def test_upgraded_routes_spend_final_sun_point_on_system_seeding(self) -> None:
        for name in ("automation", "core_mass", "thermal_overclock", "accretion"):
            with self.subTest(name=name):
                result = simulate(self.config, name)
                self.assertEqual(1, result.sun_ranks.get("system_seeding", 0))

    def test_helium_unlocks_after_ignition(self) -> None:
        for name in self.config["scenarios"]:
            with self.subTest(name=name):
                result = simulate(self.config, name)
                self.assertIsNotNone(result.ignition_seconds)
                self.assertIsNotNone(result.helium_unlock_seconds)
                self.assertGreater(result.helium_unlock_seconds, result.ignition_seconds)
                self.assertLess(result.helium_unlock_seconds, result.seconds)

    def test_unlocked_singularity_mix_is_twelve_hydrogen_grains_per_helium_grain(self) -> None:
        result = simulate(self.config, "automation")
        post_unlock_hydrogen = result.singularity_hydrogen_mass - result.pre_unlock_singularity_hydrogen_mass
        hydrogen_grains = post_unlock_hydrogen
        helium_grains = result.singularity_helium_mass / result.helium_atomic_mass
        self.assertAlmostEqual(12.0, hydrogen_grains / helium_grains, places=8)

    def test_hot_design_makes_more_passive_helium_than_cool_design(self) -> None:
        config = copy.deepcopy(self.config)
        base = config["scenarios"]["automation"]
        config["scenarios"]["profile_cool_test"] = {**base, "stellar_profile": "cool"}
        config["scenarios"]["profile_hot_test"] = {**base, "stellar_profile": "hot"}
        cool = simulate(config, "profile_cool_test")
        balanced = simulate(config, "automation")
        hot = simulate(config, "profile_hot_test")
        self.assertGreater(hot.passive_solar_helium_mass, balanced.passive_solar_helium_mass)
        self.assertGreater(balanced.passive_solar_helium_mass, cool.passive_solar_helium_mass)
        self.assertLess(hot.helium_unlock_seconds, balanced.helium_unlock_seconds)
        self.assertLess(balanced.helium_unlock_seconds, cool.helium_unlock_seconds)

    def test_passive_helium_is_not_counted_as_construction_mass(self) -> None:
        result = simulate(self.config, "thermal_overclock")
        allocated = result.core_mass + result.compacted_mass + result.loose_mass
        self.assertAlmostEqual(result.generated_mass, allocated, delta=result.generated_mass * 1e-9)
        self.assertGreater(result.passive_solar_helium_mass, 0.0)
        self.assertNotAlmostEqual(result.generated_mass + result.passive_solar_helium_mass, allocated)


if __name__ == "__main__":
    unittest.main()
