#!/usr/bin/env bash
# Runs the test suite with coverage instrumentation and prints a per-file
# and total line coverage summary from the resulting coverage/lcov.info.
set -uo pipefail

cd "$(dirname "$0")/.."

flutter test --coverage
test_status=$?

awk -F'[:,]' '
  /^SF:/ {
    file = $2
    if (!(file in seen)) {
      seen[file] = 1
      order[++n] = file
    }
    next
  }
  /^DA:/ {
    total[file]++
    if ($3 + 0 > 0) covered[file]++
    next
  }
  END {
    for (i = 1; i <= n; i++) {
      f = order[i]
      pct = total[f] > 0 ? 100 * covered[f] / total[f] : 0
      printf "%-40s %5d/%-5d (%5.1f%%)\n", f, covered[f], total[f], pct
      grand_total += total[f]
      grand_covered += covered[f]
    }
    grand_pct = grand_total > 0 ? 100 * grand_covered / grand_total : 0
    printf "%-40s %5d/%-5d (%5.1f%%)\n", "TOTAL", grand_covered, grand_total, grand_pct
  }
' coverage/lcov.info

exit "$test_status"
