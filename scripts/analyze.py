#!/usr/bin/env python3
"""Summarize a zonestate log.

Every zone_id line in the input carries a tab-separated list of [start end]
pairs.  This script keeps the log structure intact but replaces that list with
the mean and standard deviation of the first (start) number of each pair.  At
the start of every -----00000001----- block it inserts a summary averaging
those two statistics over the zones of each level within that block.

Usage: analyze.py <filename.log>
Writes ./analysis-<filename.log>
"""

import os
import re
import statistics
import sys
from collections import defaultdict

# [000035454146 014018957893] -> captures the pair's contents
PAIR_RE = re.compile(r"\[([^\[\]]*)\]")
LEVEL_RE = re.compile(r"\blevel:\s*(\d+)")
# -----00000001----- : the delimiter starting each snapshot block
BLOCK_RE = re.compile(r"^-{2,}.*-{2,}\s*$")


def summarize(line):
    """Reduce a zone_id line to mean/stddev of its pair-start values.

    Pairs whose first field is not a plain number are dropped: the logs contain
    occasional garbage entries (leaked addresses, binary noise) that would
    otherwise poison the statistics.

    Returns (output_line, level, mean, stddev, skipped).  level is None if the
    line carries no level field; mean and stddev are None for a zone with no
    usable pairs.
    """
    starts = []
    skipped = 0
    for pair in PAIR_RE.findall(line):
        fields = pair.split()
        if fields and fields[0].isascii() and fields[0].isdigit():
            starts.append(int(fields[0]))
        else:
            skipped += 1

    head = line.split("\t", 1)[0].rstrip()
    match = LEVEL_RE.search(head)
    level = int(match.group(1)) if match else None

    if not starts:
        return f"{head}\tmean: N/A, stddev: N/A\n", level, None, None, skipped

    mean = statistics.fmean(starts)
    stddev = statistics.pstdev(starts) if len(starts) > 1 else 0.0
    return (f"{head}\tmean: {mean:.2f}, stddev: {stddev:.2f}\n",
            level, mean, stddev, skipped)


def format_summary(per_level):
    """Build a per-level summary from {level: [(mean, stddev), ...]}."""
    if not per_level:
        return []

    lines = ["Per-level averages:\n"]
    for level in sorted(per_level):
        stats = per_level[level]
        avg_mean = statistics.fmean(m for m, _ in stats)
        avg_stddev = statistics.fmean(s for _, s in stats)
        lines.append(f"L{level}: avg mean = {avg_mean:.2f}, "
                     f"avg stddev = {avg_stddev:.2f}\t({len(stats)} zones)\n")
    return lines


def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {os.path.basename(sys.argv[0])} <filename.log>")

    src = sys.argv[1]
    dst = "analysis-" + os.path.basename(src)
    if os.path.abspath(src) == os.path.abspath(dst):
        sys.exit(f"refusing to overwrite the input file: {src}")

    skipped = 0
    marker = None            # delimiter line of the block being accumulated
    body = []                # its remaining lines
    per_level = defaultdict(list)

    # surrogateescape: the logs are not always valid UTF-8, and undecodable
    # bytes on pass-through lines round-trip unchanged instead of raising.
    with open(src, errors="surrogateescape") as fin, \
            open(dst, "w", errors="surrogateescape") as fout:

        def flush():
            """Emit the accumulated block, summary first."""
            if marker is not None:
                fout.write(marker)
            fout.writelines(format_summary(per_level))
            fout.writelines(body)

        for line in fin:
            if BLOCK_RE.match(line):
                flush()
                marker, body, per_level = line, [], defaultdict(list)
                continue

            if not line.startswith("zone_id:"):
                body.append(line)
                continue

            out, level, mean, stddev, n_bad = summarize(line)
            body.append(out)
            skipped += n_bad
            if level is not None and mean is not None:
                per_level[level].append((mean, stddev))

        flush()

    if skipped:
        print(f"skipped {skipped} non-numeric entries", file=sys.stderr)
    print(dst)


if __name__ == "__main__":
    main()
