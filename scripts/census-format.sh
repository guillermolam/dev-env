#!/bin/sh
# stdin: machine census. stdout: one row, three count columns.
awk -v color="${CENSUS_COLOR:-0}" '
function cell(code, text) {
	if (color == "1")
		return sprintf("\033[%sm%s\033[0m", code, text)
	return text
}
BEGIN {
	printf "%s\n", cell("1", sprintf("%-16s %10s %13s %10s", "name", "current", "operational", "left"))
}
$1 == "census" { next }
index($0, "workload_a_open=") == 1 { open = $0; next }
index($0, "files_capped=") == 1 { cap = $0; next }
NF >= 4 {
	split($2, a, "=")
	split($3, b, "=")
	split($4, c, "=")
	left = c[2] + 0
	lc = (left == 0 ? "32" : "31")
	printf "%-16s %10s %s %s\n", $1, a[2], cell("32", sprintf("%13s", b[2])), cell(lc, sprintf("%10s", c[2]))
}
END {
	if (open != "") print open
	if (cap != "") print cap
}
'
