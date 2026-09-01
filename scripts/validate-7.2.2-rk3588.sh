#!/usr/bin/env bash
# Collect a first-boot report for the RK3588 Linux 7.2.2 candidate.
# The only files this script creates are below /tmp (or the supplied output
# directory).  It does not install packages, alter boot files, or reboot.

set -u

expected_release='7.2.2-rk3588-panthor-rknpu'
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_dir="${1:-/tmp/linux-7.2.2-rk3588-validation-${stamp}}"
report="${result_dir}/report.txt"

mkdir -p "${result_dir}"
: >"${report}"

section()
{
	printf '\n===== %s =====\n' "$1" | tee -a "${report}"
}

record()
{
	printf '%s\n' "$*" | tee -a "${report}"
}

run_logged()
{
	local label="$1"
	shift
	printf '\n--- %s ---\n' "${label}" >>"${report}"
	printf '$' >>"${report}"
	printf ' %q' "$@" >>"${report}"
	printf '\n' >>"${report}"
	"$@" >>"${report}" 2>&1
	local rc=$?
	printf '[exit=%d]\n' "${rc}" >>"${report}"
	return 0
}

section 'identity'
running_release="$(uname -r)"
record "expected_release=${expected_release}"
record "running_release=${running_release}"
if [[ "${running_release}" == "${expected_release}" ]]; then
	record 'kernel_release_check=PASS'
else
	record 'kernel_release_check=NOT_THE_7.2.2_CANDIDATE'
fi
run_logged 'uname' uname -a
run_logged 'kernel command line' sed -n '1p' /proc/cmdline
run_logged 'board model' sh -c 'tr -d "\000" </proc/device-tree/model; printf "\n"'
run_logged 'root mount' findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /
run_logged 'boot mount' findmnt -o TARGET,SOURCE,FSTYPE,OPTIONS /boot

section 'kernel configuration and modules'
if [[ -r "/boot/config-${running_release}" ]]; then
	run_logged 'selected kernel options' grep -E '^(CONFIG_(DRM_PANTHOR|ROCKCHIP_RKNPU|IOMMU_SUPPORT|ROCKCHIP_IOMMU|BINFMT_MISC|BPF_JIT|PREEMPT|NVME_CORE|BLK_DEV_NVME|EXT4_FS|KEXEC|KEXEC_FILE))=' "/boot/config-${running_release}"
elif [[ -r /proc/config.gz ]]; then
	run_logged 'selected kernel options' sh -c "zcat /proc/config.gz | grep -E '^(CONFIG_(DRM_PANTHOR|ROCKCHIP_RKNPU|IOMMU_SUPPORT|ROCKCHIP_IOMMU|BINFMT_MISC|BPF_JIT|PREEMPT|NVME_CORE|BLK_DEV_NVME|EXT4_FS|KEXEC|KEXEC_FILE))='"
else
	record 'kernel_config=UNAVAILABLE'
fi
run_logged 'loaded Panthor/RKNPU/IOMMU modules' sh -c "lsmod | grep -Ei 'panthor|rknpu|iommu' || true"
run_logged 'Panthor module metadata' modinfo panthor
run_logged 'RKNPU module metadata' modinfo rknpu

section 'devices and drivers'
run_logged 'DRM device nodes' sh -c 'ls -l /dev/dri 2>&1 || true'
run_logged 'RKNPU legacy device node' sh -c 'ls -l /dev/rknpu 2>&1 || true'
{
	printf '\n--- DRM sysfs driver map ---\n'
	for node in /sys/class/drm/card* /sys/class/drm/renderD*; do
		[[ -e "${node}" ]] || continue
		dev_path="$(readlink -f "${node}/device" 2>/dev/null || true)"
		driver_path="$(readlink -f "${node}/device/driver" 2>/dev/null || true)"
		printf '%s device=%s driver=%s\n' "${node##*/}" "${dev_path:-unknown}" "${driver_path:-unknown}"
	done
} >>"${report}" 2>&1
{
	printf '\n--- network driver map ---\n'
	for node in /sys/class/net/*; do
		[[ -e "${node}" ]] || continue
		driver_path="$(readlink -f "${node}/device/driver" 2>/dev/null || true)"
		printf '%s driver=%s carrier=%s\n' "${node##*/}" "${driver_path:-virtual}" "$(cat "${node}/carrier" 2>/dev/null || printf '?')"
	done
} >>"${report}" 2>&1
run_logged 'PCI devices and active drivers' lspci -nnk
run_logged 'NVMe devices' lsblk -o NAME,PATH,TYPE,SIZE,FSTYPE,MOUNTPOINTS,MODEL
run_logged 'Panthor firmware' sha256sum /lib/firmware/arm/mali/arch10.8/mali_csffw.bin

section 'kernel log'
if sudo -n true >/dev/null 2>&1; then
	sudo -n dmesg >"${result_dir}/dmesg.txt" 2>&1
else
	dmesg >"${result_dir}/dmesg.txt" 2>&1
fi
dmesg_rc=$?
record "dmesg_capture_exit=${dmesg_rc}"
if [[ ${dmesg_rc} -eq 0 ]]; then
	run_logged 'relevant kernel messages' grep -Ei 'panthor|mali|rknpu|rknn|iommu|firmware|nvme|pcie|r8169|error|fail|warn|timeout|fault' "${result_dir}/dmesg.txt"
else
	record 'dmesg_capture=FAILED'
fi

section 'userspace graphics'
run_logged 'Mesa packages' sh -c "dpkg-query -W -f='\${binary:Package}\t\${Version}\n' 'libgl1-mesa-dri*' 'libegl-mesa0*' 'libgbm1*' 'mesa-vulkan-drivers*' 2>&1 || true"
if command -v eglinfo >/dev/null 2>&1; then
	run_logged 'EGL information' timeout 30 eglinfo -B
else
	record 'eglinfo=NOT_INSTALLED'
fi
if command -v vulkaninfo >/dev/null 2>&1; then
	run_logged 'Vulkan summary' timeout 30 vulkaninfo --summary
else
	record 'vulkaninfo=NOT_INSTALLED'
fi

section 'RKNN YOLOv8 smoke test'
rknn_root='/home/william/tryyolo/rknn_model_zoo'
rknn_demo="${rknn_root}/build/build_rknn_yolov8_demo_rk3588_linux_aarch64_Release/rknn_yolov8_demo"
rknn_model="${rknn_root}/examples/yolov8/model/yolov8.rknn"
rknn_image="${rknn_root}/examples/yolov8/model/bus.jpg"
rknn_labels="${rknn_root}/examples/yolov8/model/coco_80_labels_list.txt"
rknn_work="${result_dir}/rknn-yolov8"
rknn_rc=125

if [[ -x "${rknn_demo}" && -r "${rknn_model}" && -r "${rknn_image}" && -r "${rknn_labels}" ]]; then
	run_logged 'RKNN demo hash' sha256sum "${rknn_demo}"
	run_logged 'RKNN runtime dependencies' ldd "${rknn_demo}"
	mkdir -p "${rknn_work}/model"
	ln -s "${rknn_model}" "${rknn_work}/model/yolov8.rknn"
	ln -s "${rknn_image}" "${rknn_work}/model/bus.jpg"
	ln -s "${rknn_labels}" "${rknn_work}/model/coco_80_labels_list.txt"
	(
		cd "${rknn_work}" || exit 124
		timeout --signal=TERM --kill-after=10 180 "${rknn_demo}" model/yolov8.rknn model/bus.jpg
	) >"${rknn_work}/run.log" 2>&1
	rknn_rc=$?
	record "rknn_demo_exit=${rknn_rc}"
	if [[ ${rknn_rc} -eq 0 && -s "${rknn_work}/out.png" ]]; then
		record 'rknn_smoke_test=PASS'
		run_logged 'RKNN output image' sha256sum "${rknn_work}/out.png"
		run_logged 'RKNN output image size' stat -c '%n %s bytes' "${rknn_work}/out.png"
	else
		record 'rknn_smoke_test=FAIL'
	fi
	run_logged 'RKNN run log' sed -n '1,260p' "${rknn_work}/run.log"
else
	record 'rknn_smoke_test=SKIPPED_MISSING_INPUT'
	record "demo=${rknn_demo}"
	record "model=${rknn_model}"
	record "image=${rknn_image}"
	record "labels=${rknn_labels}"
fi

section 'summary'
record "report=${report}"
record "dmesg=${result_dir}/dmesg.txt"
record "rknn_exit=${rknn_rc}"
record 'No boot files, packages, or persistent system configuration were changed.'

printf '\nValidation report: %s\n' "${report}"
