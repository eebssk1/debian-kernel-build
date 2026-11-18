#!/bin/sh
# serl only: verify a same-version official Linux x86_64 driver for the source tag.
set -eu
series=${NVIDIA_DRIVER_SERIES:-auto}
case "$series" in
    auto|5xx) ;;
    *) echo "Invalid NVIDIA_DRIVER_SERIES: $series (expected auto or 5xx)" >&2; exit 1 ;;
esac
source=$(realpath "$1")
work="$source/.serl"
mkdir -p "$work"

git ls-remote --tags --refs https://github.com/NVIDIA/open-gpu-kernel-modules.git > "$work/refs"
sed -n 's@.*refs/tags/@@p' "$work/refs" | grep -E '^[0-9]+(\.[0-9]+)+$' | sort -Vr > "$work/tags"
if [ "$series" = 5xx ]; then
    # R595 is Production; R580 is Long Term Support (official table below).
    # Only the opt-in 5xx policy is restricted to these stable branches.
    # https://docs.nvidia.com/datacenter/tesla/drivers/supported-drivers-and-cuda-toolkit-versions.html
    # Numeric tags in these branches are NOT stable proof (e.g. Vulkan/beta).
    # Require a standard Linux x86_64 release row positively marked NVIDIA Certified.
    # The official list is bounded; an absent release is rejected, never guessed safe.
    # Use a Turing product (RTX 2080 Ti), not a Maxwell query capped at R580.
    standard='https://www.nvidia.com/Download/processFind.aspx?ctk=0&lang=en-us&lid=1&osid=12&pfid=877&psid=107&qnfslb=01'
    echo 'NVIDIA policy: 5xx stable R595 Production / R580 LTS only; certified standard Linux + same-version official driver' >&2
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
else
    echo 'NVIDIA policy: auto; newest numeric GitHub tag (including 6xx), same-version official driver; no stable-branch filter' >&2
fi
version=
while read -r tag; do
    if [ "$series" = 5xx ]; then
        case "$tag" in
            595.*|580.*) ;;
            *) echo "Skipping NVIDIA $tag: outside allowed 5xx stable branches R595/R580" >&2; continue ;;
        esac
        if ! grep -Fxq "$tag" "$work/standard-releases"; then
            echo "Skipping NVIDIA $tag: not a certified standard Linux release (beta/rc or unlisted)" >&2
            continue
        fi
    fi
    # Source-tag READMEs require a same-version driver and link its XFree86 README:
    # https://github.com/NVIDIA/open-gpu-kernel-modules/blob/620.73.04/README.md
    # https://github.com/NVIDIA/open-gpu-kernel-modules/blob/595.112.07/README.md
    # Use the verified standard runfile convention, not per-build release-note parsing.
    # HEAD only: never download or execute the installer. Do not follow redirects
    # to another product/path; fail closed if this endpoint's contract changes.
    driver_url="https://us.download.nvidia.com/XFree86/Linux-x86_64/$tag/NVIDIA-Linux-x86_64-$tag.run"
    echo "Checking official NVIDIA driver $tag: $driver_url" >&2
    if response=$(curl --disable --silent --show-error --head --proto '=https' \
        --connect-timeout 10 --max-time 30 --output /dev/null \
        --write-out '%{http_code} %{content_type}' "$driver_url"); then
        :
    else
        status=$?
        echo "Cannot query official NVIDIA driver $tag (curl exit $status; response: $response): $driver_url" >&2
        exit 1
    fi
    case "$response" in
        '200 application/octet-stream') version=$tag; break ;;
        '404 '*|'410 '*) echo "Skipping NVIDIA $tag: same-version official driver not published (HTTP ${response%% *}): $driver_url" >&2 ;;
        *) echo "Cannot verify official NVIDIA driver $tag (unexpected HEAD response: $response): $driver_url" >&2; exit 1 ;;
    esac
done < "$work/tags"
if [ -z "$version" ]; then
    echo "No NVIDIA GitHub source tag allowed by '$series' policy has a same-version official driver" >&2
    exit 1
fi
echo "Selected NVIDIA $version (policy: $series; same-version official driver: $driver_url)" >&2
curl --fail --location --retry 3 \
    "https://github.com/NVIDIA/open-gpu-kernel-modules/archive/refs/tags/$version.tar.gz" \
    -o "$work/source.tar.gz"
tar -xzf "$work/source.tar.gz" --strip-components=1 -C "$source"
grep -Fqx "NVIDIA_VERSION = $version" "$source/version.mk"
printf '%s\n' "$version" > "$work/version"
rm "$work/source.tar.gz"
