# RK3588 Linux 7.2.2 with Panthor and RKNPU

Reproducible source inputs, boot files and validation material for the
Orange Pi 5 Plus (`RK3588`) kernel release:

```text
7.2.2-rk3588-panthor-rknpu
```

The kernel combines the upstream Panthor DRM driver with a vendor-compatible
RKNPU 0.9.6 ABI port. The combined RKNPU topology exposes all three NPU cores
through one mainline Rockchip IOMMU domain.

## Validated state

- NVMe root, both RTL8125 NICs, Linux bridge and SSH work on Linux 7.2.2.
- Panthor and RKNPU bind at the same time.
- RKNN inference passes separately on NPU cores 0, 1 and 2, and with all three
  cores enabled.
- Every RKNN validation run produced the byte-identical vendor-6.1 baseline
  output.
- The Orange Pi 5 Plus header I2C2 bus is enabled with the upstream `i2c2m0`
  pinctrl; `/dev/i2c-2` and the SHT30/QMP6988 env-api sampling were validated
  on the target.
- A no-serial, watchdog-backed one-shot boot path returns to vendor Linux 6.1
  unless a candidate boot is explicitly armed.

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for the evidence, exact hashes,
fallback design and deployment details.

Mesa 25 installation, Panthor/PanVK results and the tested offline rollback are
documented in [docs/MESA-25.md](docs/MESA-25.md).

## Repository contents

- `patches/`: ordered patch series against pristine Linux 7.2.2.
- `config/`: final kernel config plus the migrated vendor config evidence.
- `boot/`: U-Boot scripts and both validated DTBs. Large build artifacts are
  attached to the private GitHub release rather than committed to Git.
- `scripts/boot-once/`: no-serial one-shot dispatcher and watchdog keeper.
- `scripts/validate-7.2.2-rk3588.sh`: non-destructive first-boot validation.
- `diagnostics/`: DT overlays, isolated DTBs and the RKNN core-mask preload
  source used to identify and prove the three-power-domain IOMMU fix.

## Rebuild

The upstream archive and toolchain details are in
[docs/REPRODUCING.md](docs/REPRODUCING.md). The short form is:

```sh
tar -xf linux-7.2.2.tar.xz
cd linux-7.2.2
git apply /path/to/this-repo/patches/*.patch
cp /path/to/this-repo/config/config-7.2.2-rk3588-panthor-rknpu .config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  O=/path/to/output LOCALVERSION= olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
  O=/path/to/output LOCALVERSION= -j"$(nproc)" Image dtbs modules
```

Do not omit `LOCALVERSION=`: the deployed modules and initramfs expect the
exact release `7.2.2-rk3588-panthor-rknpu`.

## Large artifacts

The build output directory is intentionally excluded. The prepared private
release bundle contains the exact validated Image, DTBs, modules, initramfs,
firmware, boot scripts and a SHA-256 manifest:

```text
rk3588-linux-7.2.2-panthor-rknpu-deployment.tar.zst
990a19cbb9312bef60e7af32972871a902b221c1ef264817e688a88c3e1c69fe
```
