#!/usr/bin/env python3
"""Summarize the zonestate logs in the current directory.

Every zone_id line in a log carries a tab-separated list of [start end] pairs.
For each zonestate_* file this script does two things:

  * writes ./analysis-<filename>, which keeps the log structure intact but
    replaces each pair list with the mean and standard deviation of the first
    (start) number of the pairs, and inserts a per-level average of those two
    statistics at the start of every -----00000001----- block;
  * rewrites the log in place, with each zone's pairs sorted by their first
    number.

Usage: analyze.py
"""

import glob
import os
import re
import statistics
import sys
from collections import defaultdict

# Logs to process, relative to the working directory.
SOURCE_GLOB = "zonestate_*"
# Every mean/stddev is divided by this before printing.
SCALE = 1e11
# Decimal places used for the scaled values.
PRECISION = 4

TMP_SUFFIX = ".sorted.tmp"

# [000035454146 014018957893] -> captures the pair's contents
PAIR_RE = re.compile(r"\[([^\[\]]*)\]")
LEVEL_RE = re.compile(r"\blevel:\s*(\d+)")
# -----00000001----- : the delimiter starting each snapshot block
BLOCK_RE = re.compile(r"^-{2,}.*-{2,}\s*$")


def pair_start(contents):
    """First number of a pair's contents, or None if it is not a plain number.

    The logs contain occasional garbage entries (leaked addresses, binary
    noise) that would otherwise poison the statistics and the ordering.
    """
    fields = contents.split()
    if fields and fields[0].isascii() and fields[0].isdigit():
        return int(fields[0])
    return None


def fmt(value):
    return f"{value / SCALE:.{PRECISION}f}"


def summarize(line):
    """Reduce a zone_id line to mean/stddev of its pair-start values.

    Returns (output_line, level, mean, stddev, skipped).  level is None if the
    line carries no level field; mean and stddev are None for a zone with no
    usable pairs.  mean and stddev are returned unscaled.
    """
    starts = []
    skipped = 0
    for contents in PAIR_RE.findall(line):
        start = pair_start(contents)
        if start is None:
            skipped += 1
        else:
            starts.append(start)

    head = line.split("\t", 1)[0].rstrip()
    match = LEVEL_RE.search(head)
    level = int(match.group(1)) if match else None

    if not starts:
        return f"{head}\tmean: N/A, stddev: N/A\n", level, None, None, skipped

    mean = statistics.fmean(starts)
    stddev = statistics.pstdev(starts) if len(starts) > 1 else 0.0
    return (f"{head}\tmean: {fmt(mean)}, stddev: {fmt(stddev)}\n",
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
        lines.append(f"L{level}: avg mean = {fmt(avg_mean)}, "
                     f"avg stddev = {fmt(avg_stddev)}\t({len(stats)} zones)\n")
    return lines


def sort_pairs(line):
    """Reorder a zone_id line's pairs by their first number, ascending.

    Pair text is copied verbatim, so only the ordering changes.  The sort is
    stable, keeping duplicates adjacent in their original order; entries with a
    non-numeric first field cannot be ordered and are moved to the end.
    """
    matches = list(PAIR_RE.finditer(line))
    if not matches:
        return line

    numeric, unsortable = [], []
    for match in matches:
        start = pair_start(match.group(1))
        if start is None:
            unsortable.append(match.group(0))
        else:
            numeric.append((start, match.group(0)))
    numeric.sort(key=lambda item: item[0])

    head = line[:matches[0].start()].rstrip()
    pairs = [text for _, text in numeric] + unsortable
    return head + "\t" + "\t".join(pairs) + ("\n" if line.endswith("\n") else "")


def write_analysis(src, dst):
    """Write the summarized copy.  Returns the count of skipped entries."""
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

    return skipped


def sort_in_place(src):
    """Rewrite src with every zone's pairs sorted, via an atomic replace."""
    tmp = src + TMP_SUFFIX
    try:
        with open(src, errors="surrogateescape") as fin, \
                open(tmp, "w", errors="surrogateescape") as fout:
            for line in fin:
                fout.write(sort_pairs(line) if line.startswith("zone_id:")
                           else line)
        os.replace(tmp, src)
    except OSError:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def main():
    if len(sys.argv) > 1:
        sys.exit(f"usage: {os.path.basename(sys.argv[0])}"
                 f"  (processes ./{SOURCE_GLOB})")

    sources = sorted(p for p in glob.glob(SOURCE_GLOB)
                     if os.path.isfile(p) and not p.endswith(TMP_SUFFIX))
    if not sources:
        sys.exit(f"no {SOURCE_GLOB} files in {os.getcwd()}")

    failed = 0
    for src in sources:
        dst = "analysis-" + src
        try:
            skipped = write_analysis(src, dst)
            sort_in_place(src)
        except OSError as exc:
            print(f"{src}: {exc}", file=sys.stderr)
            failed += 1
            continue
        note = f", skipped {skipped} non-numeric entries" if skipped else ""
        print(f"{src} -> {dst}, pairs sorted in place{note}")

    if failed:
        sys.exit(f"{failed} of {len(sources)} files failed")


if __name__ == "__main__":
    main()
