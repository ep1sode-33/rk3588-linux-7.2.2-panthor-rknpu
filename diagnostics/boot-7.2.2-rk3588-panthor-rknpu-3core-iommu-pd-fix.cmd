# One-shot validation of the RK3588 combined RKNPU IOMMU power-domain fix.
# The kernel release and module ABI remain unchanged; only the Image and DTB
# use distinct diagnostic filenames.

setenv test_release 7.2.2-rk3588-panthor-rknpu
setenv test_root UUID=4dc2e574-da3e-4e9a-a2ca-069f190e375c
setenv test_image Image-${test_release}-iommu-pd-fix
setenv test_dtb rk3588-orangepi-5-plus-${test_release}-3core-iommu-pd-fix.dtb

if load nvme 0:1 ${kernel_addr_r} ${test_image}; then
    echo "Loaded ${test_image}"
else
    echo "Failed to load IOMMU power-domain test Image"
    exit
fi

if load nvme 0:1 ${ramdisk_addr_r} uInitrd-${test_release}; then
    echo "Loaded test initramfs"
else
    echo "Failed to load test initramfs"
    exit
fi

if load nvme 0:1 ${fdt_addr_r} dtb/rockchip/${test_dtb}; then
    echo "Loaded three-core DTB with IOMMU power-domain fix"
else
    echo "Failed to load IOMMU power-domain test DTB"
    exit
fi

setenv bootargs "root=${test_root} rootwait rootfstype=ext4 rw console=ttyS2,1500000n8 console=tty1 earlycon consoleblank=0 loglevel=7 cma=128M cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 panic=10 watchdog.open_timeout=180 devb_boot_once=3core-iommu-pd-fix"
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
