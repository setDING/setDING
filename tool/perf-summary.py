#!/usr/bin/env python3
"""Prints the frame timings that `make perf` wrote (docs/development/performance.md)."""
import glob
import json
import os
import sys

directory = sys.argv[1] if len(sys.argv) > 1 else 'app/build/perf'
columns = [
    ('frame_count', 'frames'),
    ('average_frame_build_time_millis', 'build avg'),
    ('99th_percentile_frame_build_time_millis', 'build p99'),
    ('worst_frame_build_time_millis', 'build worst'),
    ('missed_frame_build_budget_count', 'build >16ms'),
    ('average_frame_rasterizer_time_millis', 'raster avg'),
    ('99th_percentile_frame_rasterizer_time_millis', 'raster p99'),
    ('worst_frame_rasterizer_time_millis', 'raster worst'),
    ('missed_frame_rasterizer_budget_count', 'raster >16ms'),
]
print('| Scenario | ' + ' | '.join(name for _, name in columns) + ' |')
print('|---' * (len(columns) + 1) + '|')
for path in sorted(glob.glob(os.path.join(directory, '*.timeline_summary.json'))):
    data = json.load(open(path))
    cells = [
        f'{data[key]:.1f}' if isinstance(data[key], float) else str(data[key])
        for key, _ in columns
    ]
    print(f"| {os.path.basename(path).split('.')[0]} | " + ' | '.join(cells) + ' |')
memory = os.path.join(directory, 'memory.json')
if os.path.exists(memory):
    print('\nMemory (RSS / max RSS in MB):')
    for step, value in json.load(open(memory)).items():
        print(f"  {step}: {value['rssMb']} / {value['maxRssMb']}")
