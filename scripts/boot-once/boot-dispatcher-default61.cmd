# Fail-closed boot-once dispatcher for devb (Orange Pi 5 Plus).
#
# The normal path always sources the preserved vendor 6.1 boot script.  A
# candidate is selected only when raw NVMe LBA 61439 contains one of the exact
# 16-byte magic values installed alongside this script.  The state sector is
# zeroed and read back before a candidate script is entered.

# A DesignWare watchdog-triggered warm reset leaves the watchdog counting on
# this board.  Enable its two clocks, then assert and deassert both WDT0 reset
# lines before doing any storage I/O.  This is harmless on a cold boot and
# prevents a consumed one-shot from becoming an early-boot reset loop.
mw.l 0xfd7c083c 0x00030000 1
mw.l 0xfd7c0a1c 0x00300030 1
mw.l 0xfd7c0a1c 0x00300000 1

setenv once_target fallback
setenv once_consumed no
setenv once_state_addr 0x0e000000
setenv once_magic_addr 0x0e001000
setenv once_verify_addr 0x0e002000
setenv once_script_addr 0x0e100000
setenv once_state_lba 0xefff

echo "devb fail-closed boot dispatcher"

mw.b ${once_state_addr} 0 0x200
mw.b ${once_magic_addr} 0 0x200

if nvme scan; then
    if nvme device 0; then
        if nvme read ${once_state_addr} ${once_state_lba} 1; then
            mw.b ${once_magic_addr} 0 0x200
            if fatload nvme 0:1 ${once_magic_addr} boot-once-wdt61.magic; then
                if cmp.b ${once_state_addr} ${once_magic_addr} 0x10; then
                    setenv once_target wdt61
                fi
            fi

            mw.b ${once_magic_addr} 0 0x200
            if fatload nvme 0:1 ${once_magic_addr} boot-once-7.2.2-core0.magic; then
                if cmp.b ${once_state_addr} ${once_magic_addr} 0x10; then
                    setenv once_target core0
                fi
            fi

            mw.b ${once_magic_addr} 0 0x200
            if fatload nvme 0:1 ${once_magic_addr} boot-once-7.2.2-3core.magic; then
                if cmp.b ${once_state_addr} ${once_magic_addr} 0x10; then
                    setenv once_target 3core
                fi
            fi
        fi
    fi
fi

if test "${once_target}" != "fallback"; then
    echo "Consuming one-shot target: ${once_target}"
    mw.l ${once_state_addr} 0 0x80
    if nvme write ${once_state_addr} ${once_state_lba} 1; then
        mw.b ${once_verify_addr} 0xff 0x200
        if nvme read ${once_verify_addr} ${once_state_lba} 1; then
            if cmp.b ${once_state_addr} ${once_verify_addr} 0x200; then
                setenv once_consumed yes
            fi
        fi
    fi
fi

if test "${once_consumed}" = "yes"; then
    if test "${once_target}" = "wdt61"; then
        setenv once_script boot-default-6.1.43-rockchip-rk3588.scr
        setenv extraboardargs "watchdog.open_timeout=30 panic=10 devb_boot_once=wdt61"
    fi
    if test "${once_target}" = "core0"; then
        setenv once_script boot-7.2.2-rk3588-panthor-rknpu.scr
    fi
    if test "${once_target}" = "3core"; then
        setenv once_script boot-7.2.2-rk3588-panthor-rknpu-3core.scr
    fi

    echo "Starting RK3588 watchdog before ${once_target}"
    mw.l 0xfd7c083c 0x00030000 1
    mw.l 0xfd7c0a1c 0x00300000 1
    mw.l 0xfeaf0004 0x000000ff 1
    mw.l 0xfeaf000c 0x00000076 1
    mw.l 0xfeaf0000 0x00000001 1
    mw.l 0xfeaf000c 0x00000076 1

    if fatload nvme 0:1 ${once_script_addr} ${once_script}; then
        source ${once_script_addr}
    fi

    echo "One-shot script returned; watchdog will reset the board"
fi

echo "Booting preserved vendor 6.1 fallback"
if fatload nvme 0:1 ${once_script_addr} boot-default-6.1.43-rockchip-rk3588.scr; then
    source ${once_script_addr}
fi
if fatload nvme 0:1 ${once_script_addr} boot-default-6.1.43-rockchip-rk3588-backup.scr; then
    source ${once_script_addr}
fi

echo "Both preserved fallback scripts failed; resetting"
reset
