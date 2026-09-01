# Linux 7.2.2 RK3588 Panthor + RKNPU deployment

Kernel release: `7.2.2-rk3588-panthor-rknpu`

Target: `devb` (`william@192.168.0.46`), Orange Pi 5 Plus, RK3588,
NVMe root filesystem.

## Current state

- The kernel, DTB and modules built successfully from the verified upstream
  Linux 7.2.2 tarball.
- Mainline Panthor is a module.
- The vendor RKNPU 0.9.6 ABI port is a module.
- Two RKNPU DTBs are available. The conservative DTB enables core 0 only. The
  `-3core` DTB combines all three cores and the four physical NPU MMU register
  banks into one mainline Rockchip IOMMU provider. All cores consequently use
  one DMA domain and observe the same IOVA without private IOMMU APIs.
- The core-0 candidate has booted successfully from NVMe. Root ext4, both
  RTL8125 controllers, the bridge configuration, SSH, Panthor and RKNPU bind
  correctly on `7.2.2-rk3588-panthor-rknpu`.
- The RKNN YOLOv8 baseline passes on core 0 after commit `890a002`. That fix
  performs the RK3588 CNA/CORE subcore setup even when the conservative DTB
  exposes only one IRQ/core.
- The combined three-core candidate is now runtime-validated after commit
  `8965c62`. Its four MMU register banks span all three NPU power domains, so
  the Rockchip IOMMU provider now attaches all three domains and manages all
  six corresponding clocks before touching those banks.
- Panthor and RKNPU bind together. The packaged RKNN YOLOv8 test passes with
  core masks 1, 2, 4 and 7; each individual NPU core generated interrupts and
  every run produced the byte-identical vendor-6.1 baseline output.

## Safety and fallback

devb now has a verified fail-closed, no-serial one-shot dispatcher. The default
`/boot/boot.scr` reads a 16-byte magic value from the reserved raw state sector
at NVMe LBA 61439, clears and verifies the whole sector, and only then loads a
versioned test script. An empty or invalid state always chains to either of two
independent copies of the original vendor 6.1 boot script.

The original boot script is preserved at:

```text
/boot/boot-default-6.1.43-rockchip-rk3588.scr
/boot/boot-default-6.1.43-rockchip-rk3588-backup.scr
```

Both copies retain SHA-256
`11aeff4bd1870a2ff624fe0f30a79ae9bee5baab3b584621a1af6e7d5e3cf989`.
The dispatcher SHA-256 is
`429322f8ba7de70249ddca9abe4e9239eae911456e8b172ca27fe930caf5f369`.

The one-shot path enables the RK3588 hardware watchdog before loading a test
kernel. A conditional systemd keeper takes it over only when the candidate
command line contains `watchdog.open_timeout=180`. If the test kernel hangs
before reaching a healthy userspace/network state, the watchdog resets the
board; the already-cleared state then selects vendor 6.1. This sequence was
tested end-to-end with an intentional watchdog reset. A corrected dispatcher
also resets a watchdog left running across a warm reset, preventing a reset
loop.

The three-core investigation also exercised the failure path with a real early
kernel abort. The one-shot state had already been cleared, and the board
eventually returned to vendor 6.1. A later deliberately isolated fixed boot
reached a healthy 7.2.2 userspace. The watchdog is therefore a recovery aid,
not a guarantee that every shutdown-time kernel failure will reset instantly.

The untouched vendor kernel payloads remain:

```text
68e64f9d664c4ad21ffe90e4c84d745b0e957d999b1ae9919cf0d602852363ce  /boot/Image
db84b45929b0e9c1e706d0f0d8373b6f59fae7fa720db7ff6b4795891f8276dd  /boot/uInitrd
11aeff4bd1870a2ff624fe0f30a79ae9bee5baab3b584621a1af6e7d5e3cf989  /boot/boot.scr
afefb78e51740537dfb44d26f9f58f5d84be7243332e673d4749c55f17f643bb  /boot/dtb/rockchip/rk3588-orangepi-5-plus.dtb
```

The default future reboot still selects vendor 6.1 unless a new one-shot magic
value is explicitly armed.

## Files deployed on devb

```text
/boot/Image-7.2.2-rk3588-panthor-rknpu
/boot/config-7.2.2-rk3588-panthor-rknpu
/boot/System.map-7.2.2-rk3588-panthor-rknpu
/boot/initrd.img-7.2.2-rk3588-panthor-rknpu
/boot/uInitrd-7.2.2-rk3588-panthor-rknpu
/boot/boot-7.2.2-rk3588-panthor-rknpu.cmd
/boot/boot-7.2.2-rk3588-panthor-rknpu.scr
/boot/dtb/rockchip/rk3588-orangepi-5-plus-7.2.2-rk3588-panthor-rknpu.dtb
/boot/boot-7.2.2-rk3588-panthor-rknpu-3core.cmd
/boot/boot-7.2.2-rk3588-panthor-rknpu-3core.scr
/boot/dtb/rockchip/rk3588-orangepi-5-plus-7.2.2-rk3588-panthor-rknpu-3core.dtb
/lib/modules/7.2.2-rk3588-panthor-rknpu/
/lib/firmware/arm/mali/arch10.8/mali_csffw.bin
```

The promoted three-core kernel and DTB have these SHA-256 hashes:

```text
b4600f3d36c1a93a9fdb4915e0c2791b1370c3726d0835a105110d05f378a617  Image-7.2.2-rk3588-panthor-rknpu
6a6c4a34dc5fa735d81f64e47ee15532cfdf60766691851b678328b8f6dc7f8f  rk3588-orangepi-5-plus-7.2.2-rk3588-panthor-rknpu-3core.dtb
```

The pre-fix promoted files remain on devb as
`Image-7.2.2-rk3588-panthor-rknpu.pre-iommu-pd-fix` and
`rk3588-orangepi-5-plus-7.2.2-rk3588-panthor-rknpu-3core.dtb.pre-iommu-pd-fix`.

The promoted DTB also enables the Orange Pi 5 Plus header I2C2 controller with
the upstream `i2c2m0` pinctrl. Target validation showed `/dev/i2c-2` backed by
`feaa0000.i2c`; env-api returned a healthy live SHT30/QMP6988 sample after the
one-shot reboot. The immediately preceding DTB remains on devb as
`rk3588-orangepi-5-plus-7.2.2-rk3588-panthor-rknpu-3core.pre-i2c2.dtb`.

The corrected RKNPU module SHA-256 is
`731fd150169445c84e298f3efd688d51c562b4478f8597e868d3b1cbcc8fe1bb`.

The versioned target-generated initramfs hashes are:

```text
f0d489b1bb430a7f1274a50aeb35a753f257a9c92a82e2e4c621bb6ffaf472c1  initrd.img-7.2.2-rk3588-panthor-rknpu
3c90827d0aba43b7884330f97776eeac3c9828b08b14144fd9011fd51cdb0cc6  uInitrd-7.2.2-rk3588-panthor-rknpu
```

Panthor firmware was copied from the existing devb blob without modifying the
original. Both files have SHA-256
`60ffa376edec8c402dc0ee9357c685d835ec2e0fb3d0778f303d08a9802d57f1`.

## No-serial one-shot boot

Arm a candidate from the running vendor kernel, then reboot normally:

```sh
/home/william/arm-devb-boot-once.sh core0
sudo reboot
```

The `3core` target is fully validated and selects the combined three-core DTB.
`show` reports the current raw state and `disarm` clears it. A plain reboot
without arming anything still goes to vendor 6.1.

The three-core candidate files have these SHA-256 hashes:

```text
a33be851a88fc6fbc40cd0abf9f15a27dee11ea5ddc8fe7f55df818683d68a7b  boot-7.2.2-rk3588-panthor-rknpu-3core.cmd
b4212e84b461a8d6c7e669d5f9a5feff211a81399171f311f13f09756b2fd26b  boot-7.2.2-rk3588-panthor-rknpu-3core.scr
6a6c4a34dc5fa735d81f64e47ee15532cfdf60766691851b678328b8f6dc7f8f  rk3588-orangepi-5-plus-7.2.2-rk3588-panthor-rknpu-3core.dtb
b4600f3d36c1a93a9fdb4915e0c2791b1370c3726d0835a105110d05f378a617  Image-7.2.2-rk3588-panthor-rknpu
```

The test script loads only versioned files. It deliberately skips the vendor
kernel DT overlays because they are not ABI-compatible with the mainline DTB.
Serial output remains configured for `ttyS2,1500000`, with `earlycon` and log
level 7, but serial access is not required for the one-shot mechanism.

## First-boot checks

Run the packaged non-destructive validation script. It writes its report,
complete dmesg and RKNN output only below `/tmp`; it does not change boot files,
packages or persistent configuration.

```sh
/home/william/validate-7.2.2-rk3588.sh
```

The script records kernel/config/module state, NVMe and network drivers,
Panthor/RKNPU render-node bindings, relevant dmesg lines and Mesa capabilities.
It also runs the existing YOLOv8 RKNN demo with a 180-second timeout and records
the output image hash. On the vendor 6.1 baseline, the same model and executable
completed `rknn_run` successfully, detected the expected bus and people, and
generated a 719974-byte `out.png` with SHA-256
`a2bac49ebb4104df896b57ed48ae2956c4382f47dc924e15a9840edce7abf224`.

The corrected 7.2.2 core-0 run generated the same detections and an output with
the identical byte size and SHA-256. The shared NPU/IOMMU interrupt counter
advanced from 1 to 57 during that run. RGA is currently unavailable, but the
demo's CPU image-conversion fallback succeeds; this does not affect NPU
inference validation.

The fixed combined topology was then tested with explicit RKNN core masks:

```text
mask 1: IRQ  56, 0, 0 -> 112, 0, 0
mask 2: IRQ 112, 0, 0 -> 112,56, 0
mask 4: IRQ 112,56, 0 -> 112,56,56
mask 7: IRQ 112,56,56 -> 177,81,81
```

All four runs exited successfully and generated the same 719974-byte output
and SHA-256 as the vendor baseline. No synchronous external abort, IOMMU fault,
RKNPU timeout, Oops, panic or hung task was recorded. Both the NPU consumer and
combined IOMMU supplier returned to runtime-suspended state after validation.
The complete packaged validation report on devb is
`/tmp/linux-7.2.2-rk3588-validation-3core-iommu-pd-fix-9e6e4cff`.

devb was upgraded from Mesa 22.3.6 to the Debian bookworm-backports Mesa
25.0.7 packages after the kernel-only validation. Panthor userspace support
started in Mesa 24.1, and Mesa 25.0 enabled PanVK by default for v10 GPUs such
as the G610. Relevant upstream release notes:

- <https://docs.mesa3d.org/relnotes/24.1.0.html>
- <https://docs.mesa3d.org/relnotes/25.0.0.html>

On the formal three-core 7.2.2 boot, Mesa reports `Mali-G610 (Panfrost)`,
OpenGL ES 3.1 and PanVK device `Mali-G610`. A header-free GBM/EGL smoke test
submitted a real off-screen clear/readback and returned pixel
`68,136,187,255` with `GL_ERROR=0` and `RESULT=PASS`. The same boot also passed
the RKNN baseline and recorded no GPU, NPU or IOMMU fault.

The default vendor 6.1 boot was tested after the Mesa upgrade. It remained
healthy, with NVMe root, br0, services and RKNN all passing. Its proprietary
`/dev/mali0` interface is not Panthor, so Mesa correctly exposes llvmpipe there;
the RKNN output remained byte-identical to the baseline. See `docs/MESA-25.md`
for package versions, evidence and the tested offline downgrade command.

The combined three-core RKNPU topology, Mesa/Panthor userspace and no-serial
one-shot recovery path are validated. Keeping vendor 6.1 as the default is now
an operational policy choice rather than an unresolved GPU or NPU blocker.

## Rebuild inputs

- Full generated config: `boot/config-7.2.2-rk3588-panthor-rknpu`
- Migrated vendor config and fragments: `config/`
- RKNPU source patch series: `patches/`
- First-boot validation: `validate-7.2.2-rk3588.sh`
- Source commits:
  - `b6b0fb6` (`accel: add initial mainline RKNPU ABI port for RK3588`)
  - `1f868db` (`arm64: dts: rk3588: combine NPU cores for vendor RKNPU ABI`)
  - `890a002` (`accel: rknpu: initialize RK3588 core0 subcore pointers`)
  - `8965c62` (`iommu: rockchip: power all RK3588 RKNPU MMU banks`)
- Final IOMMU power-domain patch:
  `patches/0004-iommu-rockchip-power-all-RK3588-RKNPU-MMU-banks.patch`
  (SHA-256
  `969dc472e5a7fd2f3b95a62fceebfbac7dac119be527c9789df8dd9bb222120d`)

`update-initramfs` must not be called directly on this devb installation for a
test kernel: `/etc/initramfs/post-update.d/99-uboot` rewrites the default
`/boot/uInitrd`. Use the lower-level command instead:

```sh
sudo /usr/sbin/mkinitramfs \
  -o /boot/initrd.img-7.2.2-rk3588-panthor-rknpu \
  7.2.2-rk3588-panthor-rknpu
sudo mkimage -A arm64 -O linux -T ramdisk -C gzip \
  -n uInitrd-7.2.2-rk3588-panthor-rknpu \
  -d /boot/initrd.img-7.2.2-rk3588-panthor-rknpu \
  /boot/uInitrd-7.2.2-rk3588-panthor-rknpu
```
