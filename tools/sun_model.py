#!/usr/bin/env python3
"""Simulate the complete first Sun level without running Godot."""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


DEFAULT_CONFIG = Path(__file__).with_name("sun_balance.json")


@dataclass
class Event:
    seconds: float
    kind: str
    detail: str
    game_mass: float
    smu: float
    temperature_mk: float
    core_level: int

    def as_dict(self) -> dict[str, Any]:
        return {
            "seconds": round(self.seconds, 3),
            "clock": format_duration(self.seconds),
            "kind": self.kind,
            "detail": self.detail,
            "game_mass": round(self.game_mass, 3),
            "smu": round(self.smu, 3),
            "temperature_mk": round(self.temperature_mk, 4),
            "core_level": self.core_level,
        }


@dataclass
class Result:
    scenario: str
    description: str
    stellar_profile: str
    completed: bool
    seconds: float
    ignition_seconds: float | None
    helium_unlock_seconds: float | None
    first_compact_seconds: float | None
    automation_crossover_seconds: float | None
    core_level: int
    core_ranks: dict[str, int]
    sun_ranks: dict[str, int]
    generated_mass: float
    core_mass: float
    compacted_mass: float
    loose_mass: float
    ambient_mass: float
    helium_atomic_mass: float
    pre_unlock_singularity_hydrogen_mass: float
    singularity_hydrogen_mass: float
    singularity_helium_mass: float
    passive_solar_helium_mass: float
    peak_overclock: float
    peak_heat: float
    events: list[Event] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        post_unlock_hydrogen_mass = self.singularity_hydrogen_mass - self.pre_unlock_singularity_hydrogen_mass
        return {
            "scenario": self.scenario,
            "description": self.description,
            "stellar_profile": self.stellar_profile,
            "completed": self.completed,
            "seconds": round(self.seconds, 3),
            "clock": format_duration(self.seconds),
            "ignition_clock": format_duration(self.ignition_seconds) if self.ignition_seconds is not None else None,
            "helium_unlock_clock": format_duration(self.helium_unlock_seconds) if self.helium_unlock_seconds is not None else None,
            "first_compact_clock": format_duration(self.first_compact_seconds) if self.first_compact_seconds is not None else None,
            "automation_crossover_clock": format_duration(self.automation_crossover_seconds) if self.automation_crossover_seconds is not None else None,
            "core_level": self.core_level,
            "core_ranks": self.core_ranks,
            "sun_ranks": self.sun_ranks,
            "mass": {
                "generated": round(self.generated_mass, 3),
                "core": round(self.core_mass, 3),
                "compacted": round(self.compacted_mass, 3),
                "loose": round(self.loose_mass, 3),
                "ambient": round(self.ambient_mass, 3),
            },
            "composition": {
                "helium_atomic_mass_relative_to_hydrogen": self.helium_atomic_mass,
                "pre_unlock_singularity_hydrogen_mass": round(self.pre_unlock_singularity_hydrogen_mass, 3),
                "post_unlock_singularity_hydrogen_mass": round(post_unlock_hydrogen_mass, 3),
                "singularity_hydrogen_mass": round(self.singularity_hydrogen_mass, 3),
                "singularity_helium_mass": round(self.singularity_helium_mass, 3),
                "singularity_hydrogen_grains": round(self.singularity_hydrogen_mass, 3),
                "singularity_helium_grains": round(self.singularity_helium_mass / self.helium_atomic_mass, 3),
                "passive_solar_helium_mass": round(self.passive_solar_helium_mass, 3),
            },
            "peak_overclock": round(self.peak_overclock, 4),
            "peak_heat": round(self.peak_heat, 4),
            "events": [event.as_dict() for event in self.events],
        }


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    validate_config(config)
    return config


def validate_config(config: dict[str, Any]) -> None:
    required = ("physical", "source", "ambient", "helium", "core", "compaction", "core_talents", "sun_talents", "scenarios")
    missing = [key for key in required if key not in config]
    if missing:
        raise ValueError("missing config keys: " + ", ".join(missing))
    if float(config["step_seconds"]) <= 0:
        raise ValueError("step_seconds must be positive")
    for scenario_name, scenario in config["scenarios"].items():
        profile = scenario.get("stellar_profile", "balanced")
        if profile not in config["helium"]["profiles"]:
            raise ValueError(f"{scenario_name} uses unknown stellar profile {profile}")
        for tree_name, order_name in (("core_talents", "core_talent_order"), ("sun_talents", "sun_talent_order")):
            counts: dict[str, int] = {}
            for talent_id in scenario[order_name]:
                if talent_id not in config[tree_name]:
                    raise ValueError(f"{scenario_name} uses unknown talent {talent_id}")
                counts[talent_id] = counts.get(talent_id, 0) + 1
                if counts[talent_id] > int(config[tree_name][talent_id]["max_rank"]):
                    raise ValueError(f"{scenario_name} exceeds max rank for {talent_id}")


def format_duration(seconds: float | None) -> str:
    if seconds is None:
        return "never"
    total = max(0, int(round(seconds)))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def layer_masses(config: dict[str, Any]) -> list[float]:
    compact = config["compaction"]
    return [float(compact["base_layer_mass"]) * float(compact["layer_growth"]) ** index for index in range(int(compact["layers"]))]


def temperature_mk(config: dict[str, Any], smu: float) -> float:
    physical = config["physical"]
    ignition_fraction = float(physical["ignition_smu"]) / float(physical["target_smu"])
    fraction = max(0.0, min(smu / float(physical["target_smu"]), 1.0))
    ignition_temp = float(physical["ignition_temperature_mk"])
    if fraction <= ignition_fraction:
        progress = fraction / ignition_fraction if ignition_fraction > 0 else 1.0
        return 0.2 + (ignition_temp - 0.2) * progress ** 0.75
    progress = (fraction - ignition_fraction) / (1.0 - ignition_fraction)
    smooth = progress * progress * (3.0 - 2.0 * progress)
    return ignition_temp + (float(physical["finished_temperature_mk"]) - ignition_temp) * smooth


def initial_modifiers(config: dict[str, Any]) -> dict[str, float | bool]:
    core = config["core"]
    return {
        "automation": False,
        "pull_mass": 1.0,
        "auto_rate": 1.0,
        "source_capture": 1.0,
        "ambient_capture": 1.0,
        "core_cost": 1.0,
        "core_mass_gain": float(core["base_mass_log10_gain"]),
        "compact_core_credit": 0.0,
        "heat_coupling": float(core["base_heat_coupling"]),
        "overclock_gain": float(core["base_overclock_gain"]),
        "safe_heat": float(core["base_safe_heat"]),
        "overheat_loss": float(core["base_overheat_loss"]),
        "layer_requirement": 1.0,
        "compact_production": 1.0,
        "fusion_production": 1.0,
    }


def apply_effects(modifiers: dict[str, float | bool], effects: dict[str, Any]) -> None:
    if effects.get("automation_unlock"):
        modifiers["automation"] = True
    mappings = {
        "pull_mass_mult": ("pull_mass", "mul"),
        "auto_rate_mult": ("auto_rate", "mul"),
        "source_capture_mult": ("source_capture", "mul"),
        "ambient_capture_mult": ("ambient_capture", "mul"),
        "core_cost_mult": ("core_cost", "mul"),
        "core_mass_gain_add": ("core_mass_gain", "add"),
        "compact_core_credit_add": ("compact_core_credit", "add"),
        "heat_coupling_add": ("heat_coupling", "add"),
        "overclock_gain_add": ("overclock_gain", "add"),
        "safe_heat_add": ("safe_heat", "add"),
        "overheat_loss_mult": ("overheat_loss", "mul"),
        "layer_requirement_mult": ("layer_requirement", "mul"),
        "compact_production_mult": ("compact_production", "mul"),
        "fusion_production_mult": ("fusion_production", "mul"),
    }
    for effect_name, (modifier_name, operation) in mappings.items():
        if effect_name not in effects:
            continue
        value = float(effects[effect_name])
        current = float(modifiers[modifier_name])
        modifiers[modifier_name] = current * value if operation == "mul" else current + value


def buy_next_talent(
    order: list[str],
    cursor: int,
    definitions: dict[str, Any],
    ranks: dict[str, int],
    modifiers: dict[str, float | bool],
) -> tuple[int, str | None]:
    if cursor >= len(order):
        return cursor, None
    talent_id = order[cursor]
    talent = definitions[talent_id]
    spent = sum(ranks.values())
    if spent < int(talent["requires_spent"]):
        raise ValueError(f"{talent_id} needs {talent['requires_spent']} spent points, found {spent}")
    rank = ranks.get(talent_id, 0) + 1
    if rank > int(talent["max_rank"]):
        raise ValueError(f"{talent_id} exceeds max rank")
    ranks[talent_id] = rank
    apply_effects(modifiers, talent.get("effects", {}))
    return cursor + 1, f"{talent['name']} {rank}/{talent['max_rank']}"


def simulate(config: dict[str, Any], scenario_name: str) -> Result:
    if scenario_name not in config["scenarios"]:
        raise ValueError(f"unknown scenario: {scenario_name}")
    scenario = config["scenarios"][scenario_name]
    physical = config["physical"]
    source = config["source"]
    ambient = config["ambient"]
    helium = config["helium"]
    core = config["core"]
    compact = config["compaction"]
    base_layers = layer_masses(config)
    total_base_mass = sum(base_layers)
    layer_smu = [mass / total_base_mass * float(physical["target_smu"]) for mass in base_layers]

    dt = float(config["step_seconds"])
    maximum_seconds = float(config["maximum_hours"]) * 3600.0
    manual_end = float(scenario["manual_input_duration_minutes"]) * 60.0
    manual_activations = float(scenario["manual_activations_per_second"])
    target_core_level = min(int(scenario["target_core_level"]), int(core["sun_level_cap"]))
    stellar_profile = str(scenario.get("stellar_profile", "balanced"))
    profile = helium["profiles"][stellar_profile]
    core_order = scenario["core_talent_order"]
    sun_order = scenario["sun_talent_order"]

    modifiers = initial_modifiers(config)
    core_ranks: dict[str, int] = {}
    sun_ranks: dict[str, int] = {}
    core_cursor = 0
    sun_cursor = 0
    core_level = 0
    core_progress = 0.0
    core_mass = 0.0
    loose_mass = 0.0
    compacted_mass = 0.0
    generated_mass = 0.0
    ambient_mass = 0.0
    pre_unlock_singularity_hydrogen_mass = 0.0
    singularity_hydrogen_mass = 0.0
    singularity_helium_mass = 0.0
    passive_solar_helium_mass = 0.0
    completed_smu = 0.0
    layer_index = 0
    production_multiplier = 1.0
    heat_spike = 0.0
    peak_overclock = 1.0
    peak_heat = 0.0
    elapsed = 0.0
    ignition_seconds: float | None = None
    helium_unlock_seconds: float | None = None
    first_compact_seconds: float | None = None
    crossover_seconds: float | None = None
    events: list[Event] = []

    def current_readout() -> tuple[float, float]:
        if layer_index >= len(base_layers):
            smu = float(physical["target_smu"])
        else:
            requirement = base_layers[layer_index] * float(modifiers["layer_requirement"])
            partial = min(loose_mass / max(requirement, 1e-9), 1.0) * layer_smu[layer_index]
            smu = min(completed_smu + partial, float(physical["target_smu"]))
        return smu, temperature_mk(config, smu) * float(profile["temperature_multiplier"])

    while elapsed < maximum_seconds and layer_index < len(base_layers):
        smu, body_temp = current_readout()
        if ignition_seconds is None and smu >= float(physical["ignition_smu"]) and body_temp >= float(physical["ignition_temperature_mk"]):
            ignition_seconds = elapsed
            events.append(Event(elapsed, "ignition", "Sustained hydrogen fusion", compacted_mass + loose_mass, smu, body_temp, core_level))

        if ignition_seconds is not None:
            mass_fraction = max(0.0, min(smu / float(physical["target_smu"]), 1.0))
            temperature_fraction = max(0.0, body_temp / float(physical["finished_temperature_mk"]))
            passive_rate = (
                float(helium["passive_full_sun_mass_per_second"])
                * mass_fraction ** float(helium["passive_mass_exponent"])
                * temperature_fraction ** float(helium["passive_temperature_exponent"])
                * float(profile["passive_helium_multiplier"])
                * float(modifiers["fusion_production"])
            )
            passive_solar_helium_mass += passive_rate * dt
            if helium_unlock_seconds is None and passive_solar_helium_mass >= float(helium["discovery_signal_mass_equivalent"]):
                helium_unlock_seconds = elapsed
                events.append(Event(elapsed, "helium_unlock", "Helium pattern learned by the singularity", compacted_mass + loose_mass, smu, body_temp, core_level))

        heat = body_temp / float(physical["finished_temperature_mk"]) * float(modifiers["heat_coupling"]) + heat_spike
        overclock = 1.0 + max(0.0, heat - float(core["base_overclock_threshold"])) * float(modifiers["overclock_gain"])
        overheat = max(0.0, heat - float(modifiers["safe_heat"]))
        retention = max(0.45, 1.0 - overheat * float(modifiers["overheat_loss"]))
        peak_overclock = max(peak_overclock, overclock)
        peak_heat = max(peak_heat, heat)

        mass_bonus = 1.0 + float(modifiers["core_mass_gain"]) * math.log10(1.0 + core_mass / float(core["mass_bonus_scale"]))
        fusion_bonus = float(modifiers["fusion_production"]) if ignition_seconds is not None else 1.0
        common = (
            float(source["base_capture_efficiency"])
            * float(modifiers["pull_mass"])
            * float(modifiers["source_capture"])
            * production_multiplier
            * mass_bonus
            * overclock
            * retention
            * fusion_bonus
        )
        active_manual = manual_activations if elapsed < manual_end else 0.0
        auto_activations = float(source["automatic_activations_per_second"]) * float(modifiers["auto_rate"]) if modifiers["automation"] else 0.0
        manual_rate = active_manual * float(source["manual_mass_per_activation"]) * common
        automatic_rate = auto_activations * common
        if crossover_seconds is None and modifiers["automation"] and automatic_rate > manual_activations * float(source["manual_mass_per_activation"]):
            crossover_seconds = elapsed
            events.append(Event(elapsed, "automation_crossover", "Automation exceeds the configured manual rate", compacted_mass + loose_mass, smu, body_temp, core_level))

        body_game_mass = compacted_mass + loose_mass
        capture_chance = min(
            float(ambient["maximum_capture_chance"]),
            float(ambient["base_capture_chance"]) + float(ambient["mass_log10_gain"]) * math.log10(1.0 + body_game_mass / float(ambient["mass_scale"])),
        )
        ambient_rate = (
            float(ambient["visible_flybys_per_second"])
            * float(ambient["average_mass_per_flyby"])
            * capture_chance
            * float(modifiers["ambient_capture"])
            * retention
        )
        gained_source = (manual_rate + automatic_rate) * dt
        gained_ambient = ambient_rate * dt
        if helium_unlock_seconds is None:
            pre_unlock_singularity_hydrogen_mass += gained_source
            singularity_hydrogen_mass += gained_source
        else:
            helium_source = gained_source * float(helium["singularity_mass_fraction_after_unlock"])
            singularity_helium_mass += helium_source
            singularity_hydrogen_mass += gained_source - helium_source
        gained = gained_source + gained_ambient
        generated_mass += gained
        ambient_mass += gained_ambient

        core_share = (
            float(scenario["core_allocation_fraction"])
            if core_level < target_core_level
            else float(scenario.get("post_cap_core_allocation_fraction", 0.0))
        )
        if core_share > 0.0:
            assimilated = gained * core_share
            core_mass += assimilated
            core_progress += assimilated
            loose_mass += gained - assimilated
        else:
            loose_mass += gained

        while core_level < target_core_level:
            cost = float(core["base_level_cost"]) * float(core["level_cost_growth"]) ** core_level * float(modifiers["core_cost"])
            if core_progress + 1e-9 < cost:
                break
            core_progress -= cost
            core_level += 1
            core_cursor, purchase = buy_next_talent(core_order, core_cursor, config["core_talents"], core_ranks, modifiers)
            smu, body_temp = current_readout()
            events.append(Event(elapsed, "core_level", f"Core {core_level}: {purchase or 'point unspent'}", compacted_mass + loose_mass, smu, body_temp, core_level))

        requirement = base_layers[layer_index] * float(modifiers["layer_requirement"])
        if loose_mass + 1e-9 >= requirement:
            loose_mass -= requirement
            compacted_mass += requirement
            completed_smu += layer_smu[layer_index]
            layer_index += 1
            if first_compact_seconds is None:
                first_compact_seconds = elapsed
            sun_cursor, purchase = buy_next_talent(sun_order, sun_cursor, config["sun_talents"], sun_ranks, modifiers)
            credit = requirement * float(modifiers["compact_core_credit"])
            core_progress += credit
            production_multiplier *= float(compact["base_production_multiplier"]) * float(modifiers["compact_production"])
            heat_spike += float(compact["heat_spike"])
            smu, body_temp = current_readout()
            detail = f"Layer {layer_index}/{len(base_layers)}"
            if purchase:
                detail += f", Sun talent {purchase}"
            if credit > 0:
                detail += f", {credit:.0f} Core growth credit"
            events.append(Event(elapsed, "compact", detail, compacted_mass + loose_mass, smu, body_temp, core_level))

        decay = 0.5 ** (dt / float(compact["heat_spike_half_life_seconds"]))
        heat_spike *= decay
        elapsed += dt

    smu, body_temp = current_readout()
    if ignition_seconds is None and smu >= float(physical["ignition_smu"]) and body_temp >= float(physical["ignition_temperature_mk"]):
        ignition_seconds = elapsed
    completed = layer_index >= len(base_layers)
    allocated = core_mass + compacted_mass + loose_mass
    if abs(generated_mass - allocated) > max(1e-6, generated_mass * 1e-9):
        raise AssertionError(f"mass not conserved: generated={generated_mass}, allocated={allocated}")
    return Result(
        scenario=scenario_name,
        description=scenario["description"],
        stellar_profile=stellar_profile,
        completed=completed,
        seconds=elapsed,
        ignition_seconds=ignition_seconds,
        helium_unlock_seconds=helium_unlock_seconds,
        first_compact_seconds=first_compact_seconds,
        automation_crossover_seconds=crossover_seconds,
        core_level=core_level,
        core_ranks=core_ranks,
        sun_ranks=sun_ranks,
        generated_mass=generated_mass,
        core_mass=core_mass,
        compacted_mass=compacted_mass,
        loose_mass=loose_mass,
        ambient_mass=ambient_mass,
        helium_atomic_mass=float(helium["atomic_mass_relative_to_hydrogen"]),
        pre_unlock_singularity_hydrogen_mass=pre_unlock_singularity_hydrogen_mass,
        singularity_hydrogen_mass=singularity_hydrogen_mass,
        singularity_helium_mass=singularity_helium_mass,
        passive_solar_helium_mass=passive_solar_helium_mass,
        peak_overclock=peak_overclock,
        peak_heat=peak_heat,
        events=events,
    )


def print_text(results: list[Result], verbose: bool) -> None:
    print("Voxeloid first-Sun model")
    print("scenario             profile   total       ignition    helium      first compact  auto>manual  peak OC  passive He")
    for result in results:
        print(
            f"{result.scenario:<20} {result.stellar_profile:<9} {format_duration(result.seconds):<11} "
            f"{format_duration(result.ignition_seconds):<11} {format_duration(result.helium_unlock_seconds):<11} "
            f"{format_duration(result.first_compact_seconds):<14} {format_duration(result.automation_crossover_seconds):<12} "
            f"{result.peak_overclock:.2f}x    {result.passive_solar_helium_mass:.1f}"
        )
        if verbose:
            for event in result.events:
                print(f"  {format_duration(event.seconds)}  {event.kind:<20} {event.detail}  {event.smu:.1f} SMU  {event.temperature_mk:.2f} MK")


def write_csv(path: Path, results: list[Result]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        fields = ("scenario", "seconds", "clock", "kind", "detail", "game_mass", "smu", "temperature_mk", "core_level")
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for result in results:
            for event in result.events:
                row = event.as_dict()
                row["scenario"] = result.scenario
                writer.writerow(row)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--scenario", default="all", help="Scenario name, or all")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--csv", type=Path)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--manual-rate", type=float, help="Override manual activations per second")
    parser.add_argument("--manual-minutes", type=float, help="Override how long manual input continues")
    parser.add_argument("--layer-base", type=float, help="Override the first logical layer requirement")
    parser.add_argument("--layer-growth", type=float, help="Override geometric layer growth")
    parser.add_argument("--core-cap", type=int, help="Override the Sun Core-level cap")
    parser.add_argument("--stellar-profile", choices=("cool", "balanced", "hot"), help="Override the stellar design")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        config = load_config(args.config)
        if args.layer_base is not None:
            if args.layer_base <= 0:
                raise ValueError("layer base must be positive")
            config["compaction"]["base_layer_mass"] = args.layer_base
        if args.layer_growth is not None:
            if args.layer_growth <= 1:
                raise ValueError("layer growth must be greater than one")
            config["compaction"]["layer_growth"] = args.layer_growth
        if args.core_cap is not None:
            if args.core_cap < 0:
                raise ValueError("core cap cannot be negative")
            config["core"]["sun_level_cap"] = args.core_cap
        names = list(config["scenarios"]) if args.scenario == "all" else [args.scenario]
        for name in names:
            if name not in config["scenarios"]:
                raise ValueError(f"unknown scenario: {name}")
            if args.manual_rate is not None:
                if args.manual_rate < 0:
                    raise ValueError("manual rate cannot be negative")
                config["scenarios"][name]["manual_activations_per_second"] = args.manual_rate
            if args.manual_minutes is not None:
                if args.manual_minutes < 0:
                    raise ValueError("manual minutes cannot be negative")
                config["scenarios"][name]["manual_input_duration_minutes"] = args.manual_minutes
            if args.stellar_profile is not None:
                config["scenarios"][name]["stellar_profile"] = args.stellar_profile
        results = [simulate(config, name) for name in names]
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError, AssertionError) as exc:
        print(f"sun model error: {exc}", file=sys.stderr)
        return 2
    if args.csv:
        write_csv(args.csv, results)
    if args.json:
        json.dump([result.as_dict() for result in results], sys.stdout, indent=2)
        print()
    else:
        print_text(results, args.verbose)
    return 0 if all(result.completed for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
