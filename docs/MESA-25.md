# Mesa 25 on devb

## Installed packages

On Debian 12 bookworm, devb was upgraded from Mesa 22.3.6 to the official
bookworm-backports build on 2026-09-01:

```text
libdrm2                 2.4.123-1~bpo12+1
libegl-mesa0            25.0.7-2~bpo12+1
libgbm1                 25.0.7-2~bpo12+1
libgl1-mesa-dri         25.0.7-2~bpo12+1
mesa-libgallium         25.0.7-2~bpo12+1
mesa-vulkan-drivers     25.0.7-2~bpo12+1
```

The transaction upgraded 12 packages, installed 8 packages, removed none and
used 76 MB of additional space. It also installed `mesa-utils` and
`vulkan-tools` for validation.

The exact install command was:

```sh
sudo apt-get install -y -t bookworm-backports \
  libegl-mesa0 libgl1-mesa-dri libglx-mesa0 libgbm1 \
  mesa-opencl-icd mesa-vulkan-drivers mesa-utils vulkan-tools
```

`william` was added to the existing `render` group so new login sessions can
open `/dev/dri/renderD128` without root.

## Linux 7.2.2 results

The formal three-core one-shot boot reported:

```text
kernel:       7.2.2-rk3588-panthor-rknpu
EGL driver:   panthor
GL vendor:    Mesa
GL renderer:  Mali-G610 (Panfrost)
GL version:   OpenGL ES 3.1 Mesa 25.0.7-2~bpo12+1
PanVK device: Mali-G610, vendor 0x13b5, device 0xa8670000
```

`diagnostics/panthor-egl-smoke.c` was cross-compiled without graphics headers
and run as the unprivileged `william` user on `/dev/dri/renderD128`. It created
a GBM/EGL context, submitted an off-screen GLES clear, waited for completion
and read one pixel back:

```text
PIXEL=68,136,187,255 GL_ERROR=0x0
RESULT=PASS
```

Build it with:

```sh
aarch64-linux-gnu-gcc -std=gnu11 -O2 -Wall -Wextra -Werror \
  -o panthor-egl-smoke diagnostics/panthor-egl-smoke.c -ldl
```

`vulkaninfo --summary` exited zero and enumerated the same Mali-G610 through
PanVK. The packaged RKNN YOLOv8 validation also exited zero and retained its
719974-byte baseline SHA-256:

```text
a2bac49ebb4104df896b57ed48ae2956c4382f47dc924e15a9840edce7abf224
```

No GPU fault, IOMMU fault, synchronous external abort, RKNPU timeout, Oops,
panic or hung task was recorded.

## Vendor Linux 6.1 compatibility

An ordinary reboot selected the unchanged default
`6.1.43-rockchip-rk3588`. Root NVMe, br0, SSH and systemd reached a healthy
state with no failed unit.

That kernel exposes the vendor `/dev/mali0` interface rather than Panthor, so
Mesa 25 correctly falls back to llvmpipe. The RKNPU YOLOv8 test still exited
zero and produced the exact baseline output above. The board was then returned
to 7.2.2 using the validated formal `3core` one-shot target. The raw one-shot
state was consumed and cleared, so the next unarmed reboot still selects 6.1.

## Offline rollback

Before upgrading, the stable Mesa 22.3.6 and libdrm 2.4.114 packages were
downloaded to devb:

```text
/home/william/mesa-rollback-22.3.6/
```

That directory contains 11 `.deb` files plus `SHA256SUMS`. The downgrade was
validated with an APT simulation: ten packages downgrade, `libglapi-mesa`
updates to the latest stable revision, and the backports-only
`mesa-libgallium`/`mesa-vulkan-drivers` packages are removed.

If rollback is required:

```sh
cd /home/william/mesa-rollback-22.3.6
sha256sum -c SHA256SUMS
sudo apt-get install --allow-downgrades ./*.deb
```

Do not run `apt autoremove`; the machine has unrelated packages currently
reported as auto-removable.

## Upstream references

- <https://docs.mesa3d.org/relnotes/24.1.0.html>
- <https://docs.mesa3d.org/relnotes/25.0.0.html>
- <https://packages.debian.org/source/bookworm-backports/arm64/mesa>
