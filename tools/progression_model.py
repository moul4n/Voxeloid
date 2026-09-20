#!/usr/bin/env python3
"""Deterministic wall-clock progression model for Voxeloid.

The model is deliberately separate from Godot. It turns balance data into an
auditable timeline without pretending to simulate rendering or particle motion.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable


DEFAULT_CONFIG = Path(__file__).with_name("progression_balance.json")


@dataclass
class Event:
    seconds: float
    kind: str
    body: str
    detail: str
    amount: float = 0.0

    def as_dict(self) -> dict[str, Any]:
        return {
            "seconds": round(self.seconds, 3),
            "clock": format_duration(self.seconds),
            "kind": self.kind,
            "body": self.body,
            "detail": self.detail,
            "amount": round(self.amount, 3),
        }


@dataclass
class Modifiers:
    automation_unlocked: bool = False
    pull_mass: float = 1.0
    automatic_rate: float = 1.0
    source_capture: float = 1.0
    ambient_capture: float = 1.0
    core_cost: float = 1.0
    layer_requirement: float = 1.0


@dataclass
class Result:
    scenario: str
    description: str
    completed: bool
    seconds: float
    core_level: int
    talents: list[str]
    singularity_mass: float
    ambient_mass: float
    manual_mass: float
    automatic_mass: float
    core_assimilated_mass: float
    body_mass: float
    events: list[Event] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "scenario": self.scenario,
            "description": self.description,
            "completed": self.completed,
            "seconds": round(self.seconds, 3),
            "clock": format_duration(self.seconds),
            "core_level": self.core_level,
            "talents": self.talents,
            "mass": {
                "singularity": round(self.singularity_mass, 3),
                "manual": round(self.manual_mass, 3),
                "automatic": round(self.automatic_mass, 3),
                "ambient": round(self.ambient_mass, 3),
                "core_assimilated": round(self.core_assimilated_mass, 3),
                "bodies_and_loose": round(self.body_mass, 3),
            },
            "events": [event.as_dict() for event in self.events],
        }


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    validate_config(config)
    return config


def validate_config(config: dict[str, Any]) -> None:
    required = ("step_seconds", "maximum_hours", "source", "ambient", "core", "compaction", "campaign", "scenarios")
    missing = [key for key in required if key not in config]
    if missing:
        raise ValueError("missing config keys: " + ", ".join(missing))
    if not config["campaign"]:
        raise ValueError("campaign must contain at least one body")
    if float(config["step_seconds"]) <= 0:
        raise ValueError("step_seconds must be positive")
    talent_ids = set(config["core"]["talents"])
    for name, scenario in config["scenarios"].items():
        unknown = set(scenario["talent_order"]) - talent_ids
        if unknown:
            raise ValueError(f"scenario {name} has unknown talents: {sorted(unknown)}")


def format_duration(seconds: float) -> str:
    total = max(0, int(round(seconds)))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def _apply_talent(modifiers: Modifiers, effects: dict[str, float]) -> None:
    if effects.get("automation_unlocked", 0.0) > 0:
        modifiers.automation_unlocked = True
    modifiers.pull_mass *= float(effects.get("pull_mass_multiplier", 1.0))
    modifiers.automatic_rate *= float(effects.get("automatic_rate_multiplier", 1.0))
    modifiers.source_capture *= float(effects.get("source_capture_multiplier", 1.0))
    modifiers.ambient_capture *= float(effects.get("ambient_capture_multiplier", 1.0))
    modifiers.core_cost *= float(effects.get("future_core_cost_multiplier", 1.0))
    modifiers.layer_requirement *= float(effects.get("layer_requirement_multiplier", 1.0))


def simulate(config: dict[str, Any], scenario_name: str) -> Result:
    if scenario_name not in config["scenarios"]:
        raise ValueError(f"unknown scenario: {scenario_name}")

    source = config["source"]
    ambient = config["ambient"]
    core = config["core"]
    compaction = config["compaction"]
    scenario = config["scenarios"][scenario_name]
    campaign = config["campaign"]
    talents_data = core["talents"]
    talent_order = scenario["talent_order"]

    dt = float(config["step_seconds"])
    maximum_seconds = float(config["maximum_hours"]) * 3600.0
    manual_end = float(scenario["manual_input_duration_minutes"]) * 60.0
    manual_activation_rate = float(scenario["manual_activations_per_second"])
    source_yield = float(scenario.get("source_yield_multiplier", 1.0))
    ambient_yield = float(scenario.get("ambient_yield_multiplier", 1.0))

    elapsed = 0.0
    body_index = 0
    body = campaign[body_index]
    body_compactions = 0
    body_bound = 0.0
    body_loose = 0.0
    body_production = 1.0
    global_legacy = 1.0
    next_compact_at = 0.0

    core_level = 0
    core_progress = 0.0
    modifiers = Modifiers()
    chosen_talents: list[str] = []

    singularity_mass = 0.0
    manual_mass = 0.0
    automatic_mass = 0.0
    ambient_mass = 0.0
    core_assimilated_mass = 0.0
    completed_body_mass = 0.0
    crossover_recorded = False
    events: list[Event] = [Event(0.0, "body_start", body["name"], "Campaign begins")]

    while elapsed < maximum_seconds:
        body_mass = body_bound + body_loose
        manual_activations = manual_activation_rate if elapsed < manual_end else 0.0
        automatic_activations = 0.0
        if modifiers.automation_unlocked:
            automatic_activations = float(source["automatic_activations_per_second"]) * modifiers.automatic_rate

        common_source_mass = (
            modifiers.pull_mass
            * float(source["base_capture_efficiency"])
            * modifiers.source_capture
            * body_production
            * global_legacy
            * source_yield
        )
        manual_rate = manual_activations * float(source["manual_mass_per_activation"]) * common_source_mass
        automatic_rate = automatic_activations * common_source_mass
        singularity_rate = manual_rate + automatic_rate

        capture_chance = min(
            float(ambient["maximum_capture_chance"]),
            float(ambient["base_capture_chance"])
            + float(ambient["mass_log10_gain"])
            * math.log10(1.0 + body_mass / float(ambient["mass_scale"])),
        )
        ambient_rate = (
            float(ambient["visible_flybys_per_second"])
            * float(ambient["average_mass_per_flyby"])
            * capture_chance
            * modifiers.ambient_capture
            * global_legacy
            * ambient_yield
        )

        if (
            not crossover_recorded
            and modifiers.automation_unlocked
            and automatic_rate > manual_activation_rate * float(source["manual_mass_per_activation"])
        ):
            events.append(Event(elapsed, "automation_crossover", body["name"], "Automatic source rate exceeds the unmodified manual activation rate", automatic_rate))
            crossover_recorded = True

        gained_singularity = singularity_rate * dt
        gained_ambient = ambient_rate * dt
        gained_total = gained_singularity + gained_ambient
        singularity_mass += gained_singularity
        manual_mass += manual_rate * dt
        automatic_mass += automatic_rate * dt
        ambient_mass += gained_ambient

        target_core_level = min(int(body["target_core_level"]), len(talent_order))
        if core_level < target_core_level:
            core_share = float(scenario["core_allocation_fraction"])
            assimilated = gained_total * core_share
            core_progress += assimilated
            core_assimilated_mass += assimilated
            body_loose += gained_total * (1.0 - core_share)
        else:
            body_loose += gained_total

        while core_level < target_core_level:
            level_cost = (
                float(core["base_level_cost"])
                * float(core["level_cost_growth"]) ** core_level
                * modifiers.core_cost
            )
            if core_progress + 1e-9 < level_cost:
                break
            core_progress -= level_cost
            talent_id = talent_order[core_level]
            talent = talents_data[talent_id]
            core_level += 1
            chosen_talents.append(talent_id)
            _apply_talent(modifiers, talent.get("effects", {}))
            events.append(Event(elapsed, "core_level", body["name"], f"Core level {core_level}: {talent['name']}", level_cost))

        layer_requirement = (
            float(body["base_layer_mass"])
            * float(body["layer_growth"]) ** body_compactions
            * modifiers.layer_requirement
        )
        overfill_ratio = max(1.0, float(scenario["compact_overfill_ratio"]))
        compact_mass = layer_requirement * overfill_ratio
        if body_loose + 1e-9 >= compact_mass and elapsed >= next_compact_at:
            body_loose -= compact_mass
            body_bound += compact_mass
            body_compactions += 1
            overfill_bonus = 1.0 + float(compaction["overfill_log_bonus"]) * math.log(overfill_ratio)
            body_production *= float(compaction["production_multiplier"]) * overfill_bonus
            next_compact_at = elapsed + float(scenario["compact_reaction_seconds"])
            events.append(Event(elapsed, "compact", body["name"], f"Layer {body_compactions}/{body['compactions']}", compact_mass))

            if body_compactions >= int(body["compactions"]):
                events.append(Event(elapsed, "body_complete", body["name"], "Body complete", body_bound))
                completed_body_mass += body_bound
                global_legacy *= float(body["legacy_multiplier"])
                body_index += 1
                if body_index >= len(campaign):
                    return Result(
                        scenario=scenario_name,
                        description=scenario["description"],
                        completed=True,
                        seconds=elapsed,
                        core_level=core_level,
                        talents=chosen_talents,
                        singularity_mass=singularity_mass,
                        ambient_mass=ambient_mass,
                        manual_mass=manual_mass,
                        automatic_mass=automatic_mass,
                        core_assimilated_mass=core_assimilated_mass,
                        body_mass=completed_body_mass + body_loose,
                        events=events,
                    )
                body = campaign[body_index]
                body_compactions = 0
                body_bound = 0.0
                # Remaining loose matter becomes seed material for the next site.
                body_production = 1.0
                next_compact_at = elapsed + float(scenario["compact_reaction_seconds"])
                events.append(Event(elapsed, "body_start", body["name"], "Construction begins"))

        elapsed += dt

    return Result(
        scenario=scenario_name,
        description=scenario["description"],
        completed=False,
        seconds=elapsed,
        core_level=core_level,
        talents=chosen_talents,
        singularity_mass=singularity_mass,
        ambient_mass=ambient_mass,
        manual_mass=manual_mass,
        automatic_mass=automatic_mass,
        core_assimilated_mass=core_assimilated_mass,
        body_mass=completed_body_mass + body_bound + body_loose,
        events=events,
    )


def selected_events(result: Result) -> Iterable[Event]:
    for event in result.events:
        if event.kind in {"core_level", "automation_crossover", "compact", "body_complete"}:
            yield event


def print_text(results: list[Result], verbose: bool) -> None:
    print("Voxeloid progression envelope")
    print("scenario  complete  total       first compact  auto beats manual core")
    for result in results:
        first_compact = next((event for event in result.events if event.kind == "compact"), None)
        crossover = next((event for event in result.events if event.kind == "automation_crossover"), None)
        print(
            f"{result.scenario:<9} {str(result.completed):<9} {format_duration(result.seconds):<11} "
            f"{format_duration(first_compact.seconds) if first_compact else 'never':<14} "
            f"{format_duration(crossover.seconds) if crossover else 'never':<16} {result.core_level}"
        )
        for event in result.events:
            if event.kind == "body_complete":
                print(f"  {event.body:<22} {format_duration(event.seconds)}")
        if verbose:
            for event in selected_events(result):
                print(f"    {format_duration(event.seconds)}  {event.kind:<20} {event.body}: {event.detail}")


def write_csv(path: Path, results: list[Result]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=("scenario", "seconds", "clock", "kind", "body", "detail", "amount"))
        writer.writeheader()
        for result in results:
            for event in result.events:
                row = event.as_dict()
                row["scenario"] = result.scenario
                writer.writerow(row)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--scenario", default="all", help="Scenario name, or 'all'")
    parser.add_argument("--json", action="store_true", help="Write full JSON to standard output")
    parser.add_argument("--csv", type=Path, help="Write the event timeline as CSV")
    parser.add_argument("--verbose", action="store_true", help="Print every progression event")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        config = load_config(args.config)
        names = list(config["scenarios"]) if args.scenario == "all" else [args.scenario]
        results = [simulate(config, name) for name in names]
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        print(f"progression model error: {exc}", file=sys.stderr)
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
