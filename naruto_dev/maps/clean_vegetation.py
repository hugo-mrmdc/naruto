#!/usr/bin/env python3
"""
Thin out foliage clutter (grass/bush/detail-prop scatter) in a decompiled
Source engine .vmf and set sane fademindist/fademaxdist on what's kept.

Usage:
    python clean_vegetation.py rp_ldt_secteur1_d.vmf -o rp_ldt_secteur1_d_clean.vmf
    python clean_vegetation.py rp_ldt_secteur1_d.vmf --dry-run

The file is streamed line-by-line (it's 1.8M+ lines) instead of loaded as
one big tree, so this stays fast and memory-light.
"""

import argparse
import random
import re
import sys

# (substring to match in the "model" path, keep_ratio, fademindist, fademaxdist)
# keep_ratio: fraction of matching props to KEEP (rest are deleted).
# Lower it for things that are purely decorative clutter, raise it for
# anything that visibly matters (trees, big rocks) — you mostly just want
# fade distances on those, not fewer of them.
RULES = [
    ("grass_03.mdl", 0.35, 1000, 1300),
    ("bush004.mdl", 0.55, 2000, 2500),
    ("nass_detail_props", 0.50, 1500, 2000),
    ("tree_tallpine", 0.85, 4000, 4500),
    ("tree_pine", 0.85, 4000, 4500),
    ("tree01kaizeirnassx3", 0.85, 4000, 4500),
]

# Grass/foliage clutter shows up as all three of these, not just prop_static
# (a lot of it is prop_dynamic_override so it can sway / get per-vertex lighting).
ELIGIBLE_CLASSNAMES = {"prop_static", "prop_dynamic", "prop_dynamic_override"}

ID_RE = re.compile(r'^\s*"id"\s+"(\d+)"')
CLASSNAME_RE = re.compile(r'^\s*"classname"\s+"([^"]*)"')
MODEL_RE = re.compile(r'^\s*"model"\s+"([^"]*)"')
FADEMIN_RE = re.compile(r'^(\s*)"fademindist"\s+"[^"]*"')
FADEMAX_RE = re.compile(r'^(\s*)"fademaxdist"\s+"[^"]*"')


def match_rule(model_path):
    low = model_path.lower()
    for pattern, keep_ratio, fmin, fmax in RULES:
        if pattern.lower() in low:
            return pattern, keep_ratio, fmin, fmax
    return None


def process(lines, rng, dry_run):
    out = []
    stats = {}  # pattern -> [total, kept, fade_fixed]
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        if line.rstrip("\n") == "entity" and i + 1 < n and lines[i + 1].rstrip("\n").strip() == "{":
            block_start = i
            depth = 0
            j = i
            while j < n:
                stripped = lines[j].strip()
                if stripped == "{":
                    depth += 1
                elif stripped == "}":
                    depth -= 1
                    if depth == 0:
                        j += 1
                        break
                j += 1
            block = lines[block_start:j]
            i = j

            block_id = classname = model = None
            for bl in block:
                if classname is None:
                    m = CLASSNAME_RE.match(bl)
                    if m:
                        classname = m.group(1)
                if model is None:
                    m = MODEL_RE.match(bl)
                    if m:
                        model = m.group(1)
                if block_id is None:
                    m = ID_RE.match(bl)
                    if m:
                        block_id = m.group(1)

            rule = None
            if classname in ELIGIBLE_CLASSNAMES and model:
                rule = match_rule(model)

            if rule is None:
                out.extend(block)
                continue

            pattern, keep_ratio, fmin, fmax = rule
            s = stats.setdefault(pattern, [0, 0, 0])
            s[0] += 1

            seed_key = f"{pattern}:{block_id or id(block)}"
            if rng.Random(seed_key).random() >= keep_ratio:
                continue  # drop this entity entirely

            s[1] += 1
            new_block = []
            has_min = has_max = False
            for bl in block:
                mmin = FADEMIN_RE.match(bl)
                mmax = FADEMAX_RE.match(bl)
                if mmin:
                    new_block.append(f'{mmin.group(1)}"fademindist" "{fmin}"\n')
                    has_min = True
                    continue
                if mmax:
                    new_block.append(f'{mmax.group(1)}"fademaxdist" "{fmax}"\n')
                    has_max = True
                    continue
                new_block.append(bl)
            if not has_min or not has_max:
                # insert right after "classname" line, indentation matches siblings
                indent = "\t"
                insert_at = 2  # after "entity" / "{"
                extra = []
                if not has_min:
                    extra.append(f'{indent}"fademindist" "{fmin}"\n')
                if not has_max:
                    extra.append(f'{indent}"fademaxdist" "{fmax}"\n')
                new_block = new_block[:insert_at] + extra + new_block[insert_at:]
                s[2] += 1

            out.extend(new_block)
            continue

        out.append(line)
        i += 1

    return out, stats


class RngFactory:
    """Deterministic per-entity RNG so re-runs with the same seed are reproducible."""

    def __init__(self, seed):
        self.seed = seed

    def Random(self, key):
        return random.Random(f"{self.seed}:{key}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("vmf", help="input .vmf path")
    ap.add_argument("-o", "--output", help="output .vmf path (default: <input>_clean.vmf)")
    ap.add_argument("--seed", default="grass-thin", help="RNG seed, change to get a different random subset")
    ap.add_argument("--dry-run", action="store_true", help="only print stats, don't write a file")
    args = ap.parse_args()

    out_path = args.output or args.vmf.rsplit(".", 1)[0] + "_clean.vmf"

    with open(args.vmf, "r", encoding="utf-8", errors="surrogateescape") as f:
        lines = f.readlines()

    rng = RngFactory(args.seed)
    out_lines, stats = process(lines, rng, args.dry_run)

    total_before = sum(s[0] for s in stats.values())
    total_kept = sum(s[1] for s in stats.values())
    print(f"Entities scanned (matching rules): {total_before}")
    print(f"Entities kept:                     {total_kept}  (removed {total_before - total_kept})")
    print()
    print(f"{'pattern':<24}{'total':>8}{'kept':>8}{'removed':>9}{'fade added':>12}")
    for pattern, (total, kept, fixed) in stats.items():
        print(f"{pattern:<24}{total:>8}{kept:>8}{total - kept:>9}{fixed:>12}")

    if args.dry_run:
        print("\n(dry run, no file written)")
        return

    with open(out_path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
        f.writelines(out_lines)
    print(f"\nWrote {out_path}  ({len(out_lines)} lines, was {len(lines)})")


if __name__ == "__main__":
    sys.exit(main())
