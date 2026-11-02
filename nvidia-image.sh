#!/bin/sh
# Called only by the serl builddeb patch, after stock modules_install.
set -eu

nvidia=$(realpath "$1")
source=$(realpath "$2")
output=$(realpath "$3")
package=$(realpath "$4")
release=$5
pname=$6
version=${SERL_NVIDIA_VERSION:?}
config="$output/.config"

enabled() {
    grep -qx "$1=y" "$config"
}

enabled CONFIG_MODULES
grep -qx '# CONFIG_DRM_NOUVEAU is not set' "$config"
test -s "$output/Module.symvers"
test -f "$nvidia/COPYING"

# builddeb is run from a recursive kernel make. NVIDIA's wrapper mistakes a
# nonempty KERNELRELEASE for a kbuild include; inherited make overrides can also
# redirect its source/output tree or leak the kernel's ARCH=x86 into NVIDIA.
# Keep KCFLAGS for the kernel interface, not as CFLAGS for OS-agnostic objects.
unset KERNELRELEASE KBUILD_EXTMOD KBUILD_OUTPUT KBUILD_SRC
unset srctree objtree src obj MAKEFLAGS MFLAGS MAKEOVERRIDES
unset KBUILD_CFLAGS KBUILD_CPPFLAGS KBUILD_AFLAGS KBUILD_LDFLAGS

if enabled CONFIG_CC_IS_CLANG; then
    set -- "CC=${CC:?}" CXX=clang++ LD=ld.lld AR=llvm-ar NM=llvm-nm \
        OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip \
        STRIP_CMD=llvm-strip LLVM=1
else
    set -- "CC=${CC:?}" CXX=g++ LD=ld AR=ar NM=nm \
        OBJCOPY=objcopy OBJDUMP=objdump STRIP=strip STRIP_CMD=strip LLVM=
fi

# Enter the official top-level target: first OS-agnostic C/C++ objects, then
# the interface against this build's config, generated headers and symvers.
# Both source and output are explicit: never use the running host's kernel.
set -- "$@" ARCH=x86_64 TARGET_ARCH=x86_64 SYSSRC="$source" SYSOUT="$output" \
    KERNEL_UNAME="$release" NV_VERBOSE=1 \
    'NV_KERNEL_MODULES=nvidia nvidia-modeset nvidia-drm nvidia-uvm nvidia-peermem'
make -C "$nvidia" -j3 "$@" modules

# Use kbuild for installation/stripping, but sign explicitly below: kbuild
# deliberately ignores external-module signing errors. Delay compression until
# signing is complete; neither the source .ko nor any other target is changed.
make -C "$nvidia" -j3 "$@" modules_install \
    INSTALL_MOD_PATH="$package" INSTALL_MOD_DIR=updates/nvidia \
    INSTALL_MOD_STRIP=1 DEPMOD=true \
    CONFIG_MODULE_SIG_ALL= CONFIG_MODULE_COMPRESS_ALL=

if enabled CONFIG_MODULE_SIG; then
    key=$(sed -n 's/^CONFIG_MODULE_SIG_KEY="\(.*\)"$/\1/p' "$config")
    hash=$(sed -n 's/^CONFIG_MODULE_SIG_HASH="\(.*\)"$/\1/p' "$config")
    test -n "$key"
    test -n "$hash"
    case "$key" in
        pkcs11:*|/*) ;;
        *)
            if [ -f "$output/$key" ]; then
                key="$output/$key"
            else
                key="$source/$key"
            fi
            ;;
    esac
    test -s "$output/certs/signing_key.x509"
fi

moddir="$package/lib/modules/$release/updates/nvidia"
for name in nvidia nvidia-modeset nvidia-drm nvidia-uvm nvidia-peermem; do
    module="$moddir/$name.ko"
    test -s "$module"
    test "$(modinfo -F version "$module")" = "$version"
    case "$(modinfo -F vermagic "$module")" in
        "$release "*) ;;
        *) echo "Wrong kernel vermagic: $module" >&2; exit 1 ;;
    esac
    if enabled CONFIG_MODULE_SIG; then
        "$output/scripts/sign-file" "$hash" "$key" \
            "$output/certs/signing_key.x509" "$module"
        test -n "$(modinfo -F signer "$module")"
    fi
    if enabled CONFIG_MODULE_COMPRESS_ALL; then
        if enabled CONFIG_MODULE_COMPRESS_ZSTD; then
            zstd --rm -f -q "$module"
        elif enabled CONFIG_MODULE_COMPRESS_XZ; then
            xz --check=crc32 --lzma2=dict=1MiB -f "$module"
        elif enabled CONFIG_MODULE_COMPRESS_GZIP; then
            gzip -n -f "$module"
        else
            echo 'Unsupported module compression configuration' >&2
            exit 1
        fi
    fi
done

# Regenerate dependency metadata in this image root, never in the host /lib.
depmod -b "$package" "$release"
install -D -m 644 "$nvidia/COPYING" "$package/usr/share/doc/$pname/NVIDIA-COPYING"

# A separate firmware-only archive, with its original installation paths and
# license. It is not another module package and contains no user-space driver.
firmware="$nvidia/.serl/gsp-root"
test "$(cat "$nvidia/.serl/version")" = "$version"
printf 'NVIDIA version: %s\nKernel release: %s\n' "$version" "$release" \
    > "$firmware/usr/share/doc/firmware-nvidia-gsp/serl-build-info"
tar -czf "$nvidia/.serl/gsp.tgz" -C "$firmware" .
mv "$nvidia/.serl/gsp.tgz" "$output/../nvidia-gsp-$version-$release.tgz"
echo "Staged NVIDIA $version modules for $release in $package"
