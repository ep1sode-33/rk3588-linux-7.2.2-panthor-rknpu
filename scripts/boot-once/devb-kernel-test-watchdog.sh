#!/usr/bin/env bash
# Take over the boot-enabled watchdog only after the test kernel, NVMe root,
# IPv4 connectivity, and ssh listener are all present.

set -euo pipefail

expected_release=7.2.2-rk3588-panthor-rknpu
deadline=$((SECONDS + 150))

[[ "$(uname -r)" == "${expected_release}" ]] || exit 1
grep -qw 'watchdog.open_timeout=180' /proc/cmdline || exit 1
findmnt -n -o OPTIONS / | grep -qw rw || exit 1

ready=no
while (( SECONDS < deadline )); do
	if ip -4 -o address show scope global | grep -q . &&
		ss -H -ltn | grep -Eq '[:.]22[[:space:]]'; then
		ready=yes
		break
	fi
	sleep 2
done

[[ "${ready}" == yes ]] || exit 1

printf 'Taking over RK3588 watchdog on %s\n' "$(uname -r)"
exec 3>/dev/watchdog
while :; do
	printf '\0' >&3
	sleep 20
done
