# 1BRC — One Billion Row Challenge (Python + Zig)

A dual-language (Python and Zig) take on the One Billion Row Challenge with a focus on reproducible baselines, iterative optimizations, and clear benchmark tracking.


## Goals

I aim to measure and optimize performance of reading 1 billion rowss of data, aggregating the results, and writing the results to a file in both Python and Zig.

- Establish clean baselines; optimize I/O, parsing, aggregation, memory, and parallelism.
- Record each change with evidence and keep runs comparable across time and machines.

## Problem Summary

Input is `City;Value` lines, output is min/mean/max per city.

- Example line: `Hamburg;12.1` → aggregate by city; print sorted results.


## Repo Structure
- `python/` — Python implementation(s)
  - `src/` — main source
  - `scripts/` — helpers (data generator, bench harness)
  - `requirements.txt` or `pyproject.toml` — dependency metadata
- `zig/` — Zig implementation(s)
  - `src/` — main source
  - `build.zig` — build configuration
- `datasets/` — input data (not committed if very large)


## Quick Start

Minimal commands to run each language once code exists.

- Place dataset at `datasets/measurements.txt`.
- Python : `python python/src/main.py`
- Zig : `zig build -Doptimize=ReleaseFast`


## Environment & Reproducibility

Capture hardware, OS, toolchain, and dataset so results are comparable.

- OS: Windows 11
- CPU : 12th Gen Intel(R) Core(TM) i7-12700H (2.30 GHz)
- RAM: 16 GB
- Storage: NVMe
- Python: `3.12.3`,
- Zig: `15.1`

## Benchmarking Methodology
- Run each benchmark 5 times
- Discard the fastest and slowest runs
- Report the mean of the remaining runs

## Results Snapshot

| Run ID | Lang | Elapsed (s) | Notes |
|---|---|---|---|
| 000 | python | 631.8175502618154 | Baseline |


## Optimization Roadmap

### Python

#### Baseline
The baseline implementation is simple and goes line by line through the entire file and uses a dictionary that maintians the min, mean, sum and count of every station visited. Finally we sort the keys in the hashMap (station Name) and then store the final output. 

Some optimizations have been done such as using a fixed size array for the min, mean and max values, this will make sure that we have continguous memory and there aren't any unneccessary memory copies. This can be made faster with the use of numpy and I will try that next.

### Zig

## Data Management (git ignored due to size)

- Default path: `datasets/measurements.txt`
- Small correctness set: `datasets/10mill.txt`.
- Answer set : `datasets/answer.txt`


## Scripts

- `scripts/validate.py` — compared the output between the run and the reference.
