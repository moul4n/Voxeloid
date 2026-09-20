# Performance history

Machine:  GPU ___________  driver ________  CPU ___________  RAM ____  monitor ____ Hz
Godot:    4.4.1 stable     window 1920×1080 (2×)   V-Sync off (project + driver panel)

One line per commit tested. Median of three suite runs. `late` is the row that matters.

| date | git | label | scenario | path | p50 ms | p99 ms | max ms | 1% low fps | pass |
|---|---|---|---|---|---|---|---|---|---|
| 2026-09-15 | nogit | headless-smoke (format only, dummy renderer) | late | gpu | 6.90 | 6.90 | 13.79 | 136 | no |
