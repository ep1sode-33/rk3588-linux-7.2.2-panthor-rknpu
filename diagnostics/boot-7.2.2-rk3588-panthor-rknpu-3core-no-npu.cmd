# Diagnostic one-shot boot: use the three-core DT topology but disable both
# the combined RKNPU device and its combined IOMMU provider.

setenv test_kernel 7.2.2-rk3588-panthor-rknpu
setenv test_root UUID=4dc2e574-da3e-4e9a-a2ca-069f190e375c
setenv test_dtb rk3588-orangepi-5-plus-${test_kernel}-3core-no-npu.dtb

if load nvme 0:1 ${kernel_addr_r} Image-${test_kernel}; then
    echo "Loaded Linux ${test_kernel}"
else
    echo "Failed to load test Image"
    exit
fi

if load nvme 0:1 ${ramdisk_addr_r} uInitrd-${test_kernel}; then
    echo "Loaded test initramfs"
else
    echo "Failed to load test initramfs"
    exit
fi

if load nvme 0:1 ${fdt_addr_r} dtb/rockchip/${test_dtb}; then
    echo "Loaded three-core isolation DTB with NPU disabled"
else
    echo "Failed to load three-core isolation DTB"
    exit
fi

setenv bootargs "root=${test_root} rootwait rootfstype=ext4 rw console=ttyS2,1500000n8 console=tty1 earlycon consoleblank=0 loglevel=7 cma=128M cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 panic=10 watchdog.open_timeout=180 devb_boot_once=3core-no-npu"
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
