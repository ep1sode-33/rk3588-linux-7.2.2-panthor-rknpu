# Fail-closed default Linux 7.2.2 boot for devb (Orange Pi 5 Plus).
#
# The dispatcher has already armed a vendor-6.1 marker and started the RK3588
# watchdog before sourcing this script.  Userspace clears that marker only
# after the default kernel reaches a network-reachable state.

setenv test_kernel 7.2.2-rk3588-panthor-rknpu
setenv test_root UUID=4dc2e574-da3e-4e9a-a2ca-069f190e375c
setenv test_dtb rk3588-orangepi-5-plus-${test_kernel}-3core.dtb

if load nvme 0:1 ${kernel_addr_r} Image-${test_kernel}; then
    echo "Loaded default Linux ${test_kernel}"
else
    echo "Failed to load default Image; watchdog will select vendor 6.1"
    exit
fi

if load nvme 0:1 ${ramdisk_addr_r} uInitrd-${test_kernel}; then
    echo "Loaded default initramfs"
else
    echo "Failed to load default initramfs; watchdog will select vendor 6.1"
    exit
fi

if load nvme 0:1 ${fdt_addr_r} dtb/rockchip/${test_dtb}; then
    echo "Loaded validated I2C2/three-core RKNPU DTB"
else
    echo "Failed to load default DTB; watchdog will select vendor 6.1"
    exit
fi

setenv bootargs "root=${test_root} rootwait rootfstype=ext4 rw console=ttyS2,1500000n8 console=tty1 earlycon consoleblank=0 loglevel=7 cma=128M cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 panic=10 watchdog.open_timeout=180 devb_boot_default=7.2.2 devb_default_pending=1"
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
