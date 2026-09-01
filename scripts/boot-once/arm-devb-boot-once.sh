#!/usr/bin/env bash
# Arm, disarm, or inspect devb's fail-closed raw boot-once state sector.

set -euo pipefail

state_device=/dev/nvme0n1
state_lba=61439
expected_p1_start=61440
magic_dir=/boot

usage()
{
	printf 'Usage: %s {show|disarm|wdt61|core0|3core}\n' "$0" >&2
	exit 2
}

[[ $# -eq 1 ]] || usage
action="$1"

[[ "$(cat /sys/class/block/nvme0n1/queue/logical_block_size)" == 512 ]] || {
	printf 'Unexpected NVMe logical block size\n' >&2
	exit 1
}
[[ "$(cat /sys/class/block/nvme0n1/nvme0n1p1/start)" == "${expected_p1_start}" ]] || {
	printf 'Partition 1 no longer starts at LBA %s; refusing raw write\n' "${expected_p1_start}" >&2
	exit 1
}

show_state()
{
	printf 'LBA %s first 32 bytes: ' "${state_lba}"
	sudo dd if="${state_device}" bs=512 skip="${state_lba}" count=1 status=none |
		head -c 32 | od -An -tx1 -v | tr -d ' \n'
	printf '\nASCII: '
	sudo dd if="${state_device}" bs=512 skip="${state_lba}" count=1 status=none |
		head -c 16 | tr -c '[:print:]' '.'
	printf '\n'
}

if [[ "${action}" == show ]]; then
	show_state
	exit 0
fi

case "${action}" in
	disarm)
		magic_file=''
		;;
	wdt61)
		magic_file="${magic_dir}/boot-once-wdt61.magic"
		;;
	core0)
		magic_file="${magic_dir}/boot-once-7.2.2-core0.magic"
		;;
	3core)
		magic_file="${magic_dir}/boot-once-7.2.2-3core.magic"
		;;
	*)
		usage
		;;
esac

sudo dd if=/dev/zero of="${state_device}" bs=512 seek="${state_lba}" count=1 \
	conv=notrunc,fsync status=none

if [[ -n "${magic_file}" ]]; then
	[[ -r "${magic_file}" ]] || {
		printf 'Missing magic file: %s\n' "${magic_file}" >&2
		exit 1
	}
	[[ "$(wc -c <"${magic_file}")" -ge 16 ]] || {
		printf 'Magic file is shorter than 16 bytes\n' >&2
		exit 1
	}
	sudo dd if="${magic_file}" of="${state_device}" bs=512 seek="${state_lba}" \
		count=1 conv=notrunc,fsync status=none
	if ! cmp -n 16 "${magic_file}" \
		<(sudo dd if="${state_device}" bs=512 skip="${state_lba}" count=1 status=none); then
		printf 'Boot-once state readback verification failed\n' >&2
		exit 1
	fi
fi

sync
sudo blockdev --flushbufs "${state_device}"
show_state
