#!/usr/bin/env bash
git status --porcelain=v1 -b 2>/dev/null | awk '
BEGIN {
  GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; BLUE="\033[34m"; MAGENTA="\033[35m"; CYAN="\033[36m"; RESET="\033[0m"; BOLD="\033[1m"; count=0
}
/^##/ {
  sub(/^## /, "")
  print BOLD MAGENTA " " $0 RESET
  next
}
/^\?\?/ {
  file=substr($0, 4)
  print CYAN "   " RESET file
  count++
  next
}
/^ A/ || /^A / {
  file=substr($0, 4)
  print GREEN "   " RESET file
  count++
  next
}
/^ M/ || /^M / {
  file=substr($0, 4)
  print YELLOW "   " RESET file
  count++
  next
}
/^ D/ || /^D / {
  file=substr($0, 4)
  print RED "   " RESET file
  count++
  next
}
/^ R/ || /^R / {
  file=substr($0, 4)
  print MAGENTA "  ➜ " RESET file
  count++
  next
}
{
  print "  " $0
  count++
}
END {
  if (count == 0) {
    print GREEN "  ✔ Clean working tree" RESET
  }
}
'
