# Manual, one-shot three-core RKNPU test boot for devb (Orange Pi 5 Plus).
#
# This script does not replace /boot/boot.scr and does not apply vendor-kernel
# DT overlays. From the U-Boot serial prompt, run:
#
#   load nvme 0:1 0x9000000 boot-7.2.2-rk3588-panthor-rknpu-3core.scr
#   source 0x9000000

setenv test_kernel 7.2.2-rk3588-panthor-rknpu
setenv test_root UUID=4dc2e574-da3e-4e9a-a2ca-069f190e375c
setenv test_dtb rk3588-orangepi-5-plus-${test_kernel}-3core.dtb

if load nvme 0:1 ${kernel_addr_r} Image-${test_kernel}; then
    echo "Loaded Linux ${test_kernel}"
else
    echo "Failed to load test Image; leaving the existing boot files untouched"
    exit
fi

if load nvme 0:1 ${ramdisk_addr_r} uInitrd-${test_kernel}; then
    echo "Loaded test initramfs"
else
    echo "Failed to load test initramfs"
    exit
fi

if load nvme 0:1 ${fdt_addr_r} dtb/rockchip/${test_dtb}; then
    echo "Loaded combined three-core RKNPU DTB"
else
    echo "Failed to load three-core test DTB"
    exit
fi

setenv bootargs "root=${test_root} rootwait rootfstype=ext4 rw console=ttyS2,1500000n8 console=tty1 earlycon consoleblank=0 loglevel=7 cma=128M cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 panic=10 watchdog.open_timeout=180 devb_boot_once=3core"
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
