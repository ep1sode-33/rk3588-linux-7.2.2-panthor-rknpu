# Diagnostic one-shot boot: use the complete three-core DT, but ask userspace
# module loading to skip RKNPU.  An explicit `modprobe rknpu` over SSH can then
# exercise probe while its printk stream is observed remotely.

setenv test_kernel 7.2.2-rk3588-panthor-rknpu
setenv test_root UUID=4dc2e574-da3e-4e9a-a2ca-069f190e375c
setenv test_dtb rk3588-orangepi-5-plus-${test_kernel}-3core.dtb

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
    echo "Loaded complete three-core DTB for manual RKNPU probe"
else
    echo "Failed to load complete three-core DTB"
    exit
fi

setenv bootargs "root=${test_root} rootwait rootfstype=ext4 rw console=ttyS2,1500000n8 console=tty1 earlycon consoleblank=0 loglevel=7 cma=128M cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1 panic=10 watchdog.open_timeout=180 modprobe.blacklist=rknpu devb_boot_once=3core-manual-rknpu"
booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
