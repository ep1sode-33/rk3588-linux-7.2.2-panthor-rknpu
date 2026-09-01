# Reproducing the kernel

## Upstream source

- Archive: `linux-7.2.2.tar.xz`
- Upstream URL: `https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.2.tar.xz`
- SHA-256:
  `7d0e7ce14f98c43efe880cffbf354a59be45928fdf7170d7333c374ae91c0d83`
- The locally retained archive was checked against the kernel.org signed
  checksum and detached signature before use.

The local source history used pristine commit `b0e6efd` followed by:

```text
b6b0fb6 accel: add initial mainline RKNPU ABI port for RK3588 core0
1f868db arm64: dts: rk3588: combine NPU cores for vendor RKNPU ABI
890a002 accel: rknpu: initialize RK3588 core0 subcore pointers
8965c62 iommu: rockchip: power all RK3588 RKNPU MMU banks
```

The `patches/` directory is the portable representation of those four local
commits. Apply it in lexical order to pristine Linux 7.2.2.

## Toolchain

The validated build used:

```text
aarch64-linux-gnu-gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0
GNU ld 2.42
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
LOCALVERSION=
```

The generated config records
`CONFIG_LOCALVERSION="-rk3588-panthor-rknpu"`.

## Commands

From a clean working directory:

```sh
tar -xf /path/to/linux-7.2.2.tar.xz
git -C linux-7.2.2 apply /path/to/repo/patches/*.patch

mkdir output
cp /path/to/repo/config/config-7.2.2-rk3588-panthor-rknpu output/.config

make -C linux-7.2.2 O="$PWD/output" \
  ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= olddefconfig
make -C linux-7.2.2 O="$PWD/output" \
  ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= \
  -j"$(nproc)" Image dtbs modules
make -C linux-7.2.2 O="$PWD/output" \
  ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= \
  INSTALL_MOD_PATH="$PWD/modules" modules_install
```

Check the release before packaging:

```sh
make -s -C linux-7.2.2 O="$PWD/output" \
  ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= kernelrelease
```

It must print exactly `7.2.2-rk3588-panthor-rknpu`.

## Expected final hashes

```text
b4600f3d36c1a93a9fdb4915e0c2791b1370c3726d0835a105110d05f378a617  Image
da0a28f1642bb12d68063181a77dc125d5fbce29222e40af5872194b7ce893a6  three-core DTB
731fd150169445c84e298f3efd688d51c562b4478f8597e868d3b1cbcc8fe1bb  rknpu.ko
```

The private release contains a complete path-qualified manifest for every
deployment file.

