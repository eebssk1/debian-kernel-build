#!/bin/sh
# serl only: pair the newest allowed stable standard release with same-version GSP.
set -eu
source=$(realpath "$1")
work="$source/.serl"
repo=https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64
mkdir -p "$work"

git ls-remote --tags --refs https://github.com/NVIDIA/open-gpu-kernel-modules.git > "$work/refs"
sed -n 's@.*refs/tags/@@p' "$work/refs" | sort -Vr > "$work/tags"
# R595 is Production; R580 is Long Term Support (official table below).
# Deliberately do not follow global "latest production": it can move to 6xx+.
# https://docs.nvidia.com/datacenter/tesla/drivers/supported-drivers-and-cuda-toolkit-versions.html
# Numeric tags in these branches are NOT stable proof (e.g. Vulkan/beta).
# Require a standard Linux x86_64 release row positively marked NVIDIA Certified.
# The official list is bounded; an absent release is rejected, never guessed safe.
# Use a Turing product (RTX 2080 Ti), not a Maxwell query capped at R580.
standard='https://www.nvidia.com/Download/processFind.aspx?ctk=0&lang=en-us&lid=1&osid=12&pfid=877&psid=107&qnfslb=01'
echo 'NVIDIA policy: 5xx stable R595 Production / R580 LTS only; certified standard Linux + exact GSP' >&2
if ! curl --fail --location --retry 3 "$standard" -o "$work/standard.html"; then
    echo 'Cannot fetch official NVIDIA standard Linux release list' >&2
    exit 1
fi
awk 'BEGIN { RS="</tr>" }
    /<tr id="driverList">/ &&
    /Linux x64 \(AMD64\/EM64T\) Display Driver<\/a>/ &&
    /alt=["\047]NVIDIA Certified["\047]/ && tolower($0) !~ /beta|release candidate|>nfb</ {
        if (match($0, /<td class="gridItem">[[:space:]]*(580|595)\.[0-9]+(\.[0-9]+)?[[:space:]]*<\/td>/)) {
            tag=substr($0, RSTART, RLENGTH)
            gsub(/<[^>]*>|[[:space:]]/, "", tag)
            print tag
        }
    }' "$work/standard.html" | sort -Vu > "$work/standard-releases"
if [ ! -s "$work/standard-releases" ]; then
    echo 'No certified R595/R580 standard Linux releases found; refusing unverified tags' >&2
    exit 1
fi
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
    case "$tag" in
        595.*|580.*) ;;
        *) echo "Skipping NVIDIA $tag: outside allowed 5xx stable branches R595/R580" >&2; continue ;;
    esac
    if ! grep -Fxq "$tag" "$work/standard-releases"; then
        echo "Skipping NVIDIA $tag: not a certified standard Linux release (beta/rc or unlisted)" >&2
        continue
    fi
    match=$(awk -v tag="$tag" '$1 == tag { print $3, $4; exit }' "$work/firmware-index")
    if [ -n "$match" ]; then
        version=$tag
        break
    fi
    echo "Skipping NVIDIA $tag: no matching official standalone GSP package" >&2
done < "$work/tags"
if [ -z "$version" ]; then
    echo 'No allowed certified R595/R580 GitHub source tag has matching official GSP firmware' >&2
    exit 1
fi
file=${match%% *}
hash=${match#* }
case "$file" in
    ./firmware-nvidia-gsp_"$version"-*_amd64.deb) ;;
    *) echo "Unexpected firmware package path: $file" >&2; exit 1 ;;
esac
printf '%s\n' "$hash" | grep -Eq '^[0-9a-f]{64}$'
echo "Selected NVIDIA $version (newest certified standard R595/R580 tag with matching GSP: ${file#./})" >&2
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
