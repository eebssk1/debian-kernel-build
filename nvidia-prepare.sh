#!/bin/sh
# serl only: pair the newest published source tag with official GSP firmware.
set -eu
source=$(realpath "$1")
work="$source/.serl"
repo=https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64
mkdir -p "$work"

git ls-remote --tags --refs https://github.com/NVIDIA/open-gpu-kernel-modules.git > "$work/refs"
sed -n 's@.*refs/tags/@@p' "$work/refs" | \
    grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' | sort -Vr > "$work/tags"
test -s "$work/tags"
curl --fail --location --retry 3 "$repo/Packages.gz" -o "$work/Packages.gz"
gzip -dc "$work/Packages.gz" > "$work/Packages"
# Sort package revisions too, so a reissued firmware package wins for its tag.
awk 'BEGIN { RS=""; FS="\n" }
    {
        package=version=file=hash=""
        for (i=1; i<=NF; i++) {
            if ($i ~ /^Package: /) package=substr($i,10)
            if ($i ~ /^Version: /) version=substr($i,10)
            if ($i ~ /^Filename: /) file=substr($i,11)
            if ($i ~ /^SHA256: /) hash=substr($i,9)
        }
        if (package == "firmware-nvidia-gsp" && version && file && hash) {
            tag=version; sub(/-.*/, "", tag)
            print tag, version, file, hash
        }
    }' "$work/Packages" | sort -Vr > "$work/firmware-index"
version=
while read -r tag; do
    match=$(awk -v tag="$tag" '$1 == tag { print $3, $4; exit }' "$work/firmware-index")
    if [ -n "$match" ]; then
        version=$tag
        break
    fi
    echo "Skipping NVIDIA $tag: no matching official standalone GSP package" >&2
done < "$work/tags"
if [ -z "$version" ]; then
    echo 'No GitHub NVIDIA source tag has matching official GSP firmware' >&2
    exit 1
fi
file=${match%% *}
hash=${match#* }
case "$file" in
    ./firmware-nvidia-gsp_"$version"-*_amd64.deb) ;;
    *) echo "Unexpected firmware package path: $file" >&2; exit 1 ;;
esac
printf '%s\n' "$hash" | grep -Eq '^[0-9a-f]{64}$'
echo "Selected NVIDIA $version (newest source tag with matching GSP)" >&2
curl --fail --location --retry 3 \
    "https://github.com/NVIDIA/open-gpu-kernel-modules/archive/refs/tags/$version.tar.gz" \
    -o "$work/source.tar.gz"
tar -xzf "$work/source.tar.gz" --strip-components=1 -C "$source"
grep -Fqx "NVIDIA_VERSION = $version" "$source/version.mk"
curl --fail --location --retry 3 "$repo/${file#./}" -o "$work/gsp.deb"
printf '%s  %s\n' "$hash" "$work/gsp.deb" | sha256sum -c -
case "$(dpkg-deb -f "$work/gsp.deb" Version)" in
    "$version"-*) ;;
    *) echo 'Firmware package version mismatch' >&2; exit 1 ;;
esac
# Extraction only: never install the deb or run its maintainer scripts.
dpkg-deb -x "$work/gsp.deb" "$work/firmware"
found=false
for base in lib/firmware usr/lib/firmware; do
    dir="$work/firmware/$base/nvidia/$version"
    [ -d "$dir" ] || continue
    test -s "$dir/gsp_tu10x.bin"
    test -s "$dir/gsp_ga10x.bin"
    mkdir -p "$work/gsp-root/$base/nvidia"
    cp -a "$dir" "$work/gsp-root/$base/nvidia/"
    found=true
done
test "$found" = true
# Retain all files in that version directory (including R610+ ucodes), and
# the original package copyright/license required for binary redistribution.
install -D -m 644 "$work/firmware/usr/share/doc/firmware-nvidia-gsp/copyright" \
    "$work/gsp-root/usr/share/doc/firmware-nvidia-gsp/copyright"
printf '%s\n' "$version" > "$work/version"
rm "$work/source.tar.gz" "$work/gsp.deb"
