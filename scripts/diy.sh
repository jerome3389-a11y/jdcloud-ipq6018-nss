#!/bin/bash
# DIY script for jdcloud-ipq6018-nss (run by the workflow's
# "Load custom configuration" step, inside the cloned base tree).
#
# What it does, and only this:
#   1. q6_region 64 MB for RE-SS-01 (user decision 2026-11-05).
#   2. Fetch Argon theme + argon-config (latest master, like the
#      CR880x project; recorded in third-party-sources.txt).
#   3. Fetch the Athena LED app (latest master — user decision
#      2026-11-06: all plugins/software use the latest version on
#      every build; recorded in third-party-sources.txt).
#   4. sing-box latest release (user decision 2026-11-06): the
#      pinned packages feed lags (1.12.25), so resolve the latest
#      SagerNet release on every build and rewrite the feed
#      package's PKG_VERSION + PKG_HASH in place; recorded in
#      third-party-sources.txt via SINGBOX_VERSION.
#   5. Fetch PassWall (latest master) after removing the feed's
#      copy of luci-app-passwall (user decision 2026-11-06: try
#      PassWall; it REPLACES HomeProxy — both manage sing-box and
#      would conflict; recorded in third-party-sources.txt).
#   6. Fork sysctl tunings (min_free_kbytes / swappiness /
#      netdev_max_backlog / printk) on the tree's sysctl.conf.
#   7. Fork rc.local additions (LRU_GEN enable + noatime remount).
#
# Standing rule (user decision 2026-11-06): ALL plugins and
# software use the LATEST version on every build, automatically.
# That is why Argon, Athena LED, PassWall and sing-box are all
# fetched at their latest on every build (master / latest release),
# never a pinned commit. The base tree and the feeds stay PINNED
# (reproducible core); only the plugins/software float to latest.
#
# What it deliberately does NOT do (fork features left out — see the
# parity table and the notes at the end of this script): no LAN IP /
# hostname change (firmware defaults stay 192.168.1.1 / OpenWrt),
# no LuCI "Built by" injection, no log/cpufreq forcing (the target
# files do not exist in the pinned tree — see §8), no CPU voltage
# change, no GCC 13 pin, no MULTI_PROFILE, no sbwml golang fetch
# (the pinned feed's Go 1.26 already satisfies sing-box — see §4).
#
# Helpers fetch_source / replace_checked are the fork's (verified
# clone + marker check + resolved-commit recording; fail-loud text
# replacement with before/after verification). They are copied
# verbatim from jeojeo1225/openwrt-ci-roc-6.x-jdc-ax1800-ipq60xx
# scripts/Roc-script.sh, except fetch_source gains an optional
# 6th argument: a pinned commit the fetched HEAD must equal.

set -Eeuo pipefail
trap 'status=$?; printf "ERROR: command failed at line %s (exit %s): %s\n" "$LINENO" "$status" "$BASH_COMMAND" >&2; exit "$status"' ERR

fetch_source() {
    local url="$1"
    local destination="$2"
    local marker="$3"
    local ref="$4"
    local env_name="$5"
    local pinned="${6:-}"
    local actual_commit

    if [[ ! "$env_name" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
        printf 'Invalid environment variable name for %s: %s\n' "$url" "$env_name" >&2
        return 1
    fi

    printf 'Fetching latest %s from %s into %s\n' "$ref" "$url" "$destination"
    rm -rf "$destination"
    git init --quiet "$destination"
    git -C "$destination" remote add origin "$url"
    if ! git -C "$destination" fetch --depth=1 origin "$ref"; then
        printf 'Failed to fetch %s from %s\n' "$ref" "$url" >&2
        return 1
    fi
    git -C "$destination" checkout --quiet --detach FETCH_HEAD

    actual_commit="$(git -C "$destination" rev-parse HEAD)"

    if [ ! -f "$destination/$marker" ]; then
        printf 'Source %s is missing expected file: %s\n' "$url" "$marker" >&2
        return 1
    fi

    # Pinned sources must resolve to exactly the recorded commit;
    # a drift fails the build instead of silently changing the image.
    if [ -n "$pinned" ] && [ "$actual_commit" != "$pinned" ]; then
        printf 'PIN MISMATCH for %s: fetched %s, expected %s\n' "$url" "$actual_commit" "$pinned" >&2
        return 1
    fi

    printf 'Resolved %s to %s\n' "$url" "$actual_commit"
    printf '%s=%s\n' "$env_name" "$actual_commit" >> "$GITHUB_ENV"
}

replace_checked() {
    local file="$1"
    local before="$2"
    local after="$3"
    local expression="$4"

    if [ ! -f "$file" ]; then
        printf 'Required file not found: %s\n' "$file" >&2
        return 1
    fi

    if grep -Eq -- "$before" "$file"; then
        sed -i -E "$expression" "$file"
    elif ! grep -Eq -- "$after" "$file"; then
        printf 'Expected text not found in %s: %s\n' "$file" "$before" >&2
        return 1
    fi

    if ! grep -Eq -- "$after" "$file"; then
        printf 'Replacement did not take effect in %s: %s\n' "$file" "$after" >&2
        return 1
    fi
}

# --- 1. q6_region 64 MB (RE-SS-01 only) ---
# The base tree's ipq6018-512m.dtsi reserves 55 MB (0x3700000) for the
# Q6 NSS region; the kernel's ipq6018.dtsi default is 85 MB. WiFi needs
# at least 54 MB. The fork raises the 512m reservation to 64 MB
# (0x04000000); the user ordered the same for this project.
#
# WHY replace_checked here, not a repo dts/ override file:
#   * one-line value change — a full-file override would duplicate the
#     file and go stale silently if upstream changes it;
#   * replace_checked FAILS LOUDLY if upstream changes the default
#     (drift detection), which is the project's text-error lesson;
#   * it is the fork's proven mechanism (fork build #11 used this
#     exact edit).
# SCOPE (verified from the DTS): ipq6018-512m.dtsi is included ONLY by
# ipq6000-re-ss-01.dts (RE-SS-01). RE-CS-02's chain is
# ipq6010-re-cs.dtsi -> kernel ipq6018.dtsi and never touches this
# file, so Athena keeps the kernel default (85 MB) and is untouched.
# NEVER below 54 MB (0x03600000): WiFi would fail.
replace_checked \
    target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi \
    'reg = <0x0 0x4ab00000 0x0 0x[0-9a-fA-F]+>' 'reg = <0x0 0x4ab00000 0x0 0x04000000>' \
    's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-fA-F]+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/'

# --- 2. Argon theme + config (latest master, CR880x convention) ---
# Not in the base feeds; cloned into package/ (NOT feeds/luci/):
# the build system picks up package/ automatically, while a manual
# clone into feeds/ warns "No feed for package" and the symbols get
# dropped by defconfig (this failed CR880x run #2; the fork clones
# into feeds/luci/ and has no defconfig guard, so a silent drop there
# would go unnoticed). Recorded in third-party-sources.txt by the
# workflow step that calls this script.
rm -rf package/luci-theme-argon package/luci-app-argon-config
fetch_source https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon Makefile master ARGON_THEME_COMMIT
fetch_source https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config Makefile master ARGON_CONFIG_COMMIT

# --- 3. Athena LED app (latest master — RE-CS-02 only in effect) ---
# Fetched for every build (source only); only the re-cs-02 config
# selects luci-app-athena-led + its zh-cn translation, so the
# RE-SS-01 image never contains it. Latest master per the user's
# 2026-11-06 standing rule (all plugins/software use the latest
# version on every build); the resolved commit is recorded in
# third-party-sources.txt. Installed into package/ (not a feed).
# The fork's chmod +x of the init script and helper is kept.
fetch_source https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led Makefile main ATHENA_LED_COMMIT
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

# --- 4. sing-box latest release (user decision 2026-11-06) ---
# sing-box comes from the pinned packages feed (net/sing-box), whose
# version lags (1.12.25 at the pinned feed commit; the feed tip is
# still 1.12.25, so a feed-pin bump does NOT help). The user ordered
# all plugins/software to use the latest version on every build, so
# this step resolves the latest SagerNet release on every build (via
# the /releases/latest redirect — a plain web request, no API and no
# rate limit) and rewrites the feed package's PKG_VERSION + PKG_HASH
# in place. The build then downloads that exact tarball via the
# package's own PKG_SOURCE_URL and verifies it against the new hash.
# The feed's Go (1.26/1.27 available) satisfies sing-box 1.14.4's
# go.mod requirement (go 1.25.5), so no golang fetch is needed.
# Fails loudly if the latest version cannot be resolved, the tarball
# cannot be downloaded/hashed, or the Makefile update does not take
# effect. The resolved version is recorded in third-party-sources.txt
# via SINGBOX_VERSION.
SINGBOX_MAKEFILE="feeds/packages/net/sing-box/Makefile"
if [ ! -f "$SINGBOX_MAKEFILE" ]; then
    printf 'Required file not found: %s\n' "$SINGBOX_MAKEFILE" >&2
    exit 1
fi
SINGBOX_LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/SagerNet/sing-box/releases/latest)"
SINGBOX_VERSION="${SINGBOX_LATEST_URL##*/v}"
if [ -z "$SINGBOX_VERSION" ] || [ "$SINGBOX_VERSION" = "$SINGBOX_LATEST_URL" ]; then
    printf 'Failed to resolve latest sing-box release from %s\n' "$SINGBOX_LATEST_URL" >&2
    exit 1
fi
SINGBOX_TARBALL="$(mktemp)"
if ! curl -fsSL -o "$SINGBOX_TARBALL" "https://codeload.github.com/SagerNet/sing-box/tar.gz/v${SINGBOX_VERSION}"; then
    printf 'Failed to download sing-box %s tarball\n' "$SINGBOX_VERSION" >&2
    rm -f "$SINGBOX_TARBALL"
    exit 1
fi
SINGBOX_HASH="$(sha256sum "$SINGBOX_TARBALL" | awk '{print $1}')"
rm -f "$SINGBOX_TARBALL"
if [ -z "$SINGBOX_HASH" ]; then
    printf 'Failed to hash sing-box %s tarball\n' "$SINGBOX_VERSION" >&2
    exit 1
fi
if ! grep -Eq '^PKG_VERSION:=' "$SINGBOX_MAKEFILE"; then
    printf 'PKG_VERSION line not found in %s\n' "$SINGBOX_MAKEFILE" >&2
    exit 1
fi
if ! grep -Eq '^PKG_HASH:=' "$SINGBOX_MAKEFILE"; then
    printf 'PKG_HASH line not found in %s\n' "$SINGBOX_MAKEFILE" >&2
    exit 1
fi
sed -i -E "s/^PKG_VERSION:=.*/PKG_VERSION:=${SINGBOX_VERSION}/" "$SINGBOX_MAKEFILE"
sed -i -E "s/^PKG_HASH:=.*/PKG_HASH:=${SINGBOX_HASH}/" "$SINGBOX_MAKEFILE"
if ! grep -Fq "PKG_VERSION:=${SINGBOX_VERSION}" "$SINGBOX_MAKEFILE"; then
    printf 'sing-box PKG_VERSION update did not take effect in %s\n' "$SINGBOX_MAKEFILE" >&2
    exit 1
fi
if ! grep -Fq "PKG_HASH:=${SINGBOX_HASH}" "$SINGBOX_MAKEFILE"; then
    printf 'sing-box PKG_HASH update did not take effect in %s\n' "$SINGBOX_MAKEFILE" >&2
    exit 1
fi
printf 'sing-box latest: %s (sha256 %s)\n' "$SINGBOX_VERSION" "$SINGBOX_HASH"
printf 'SINGBOX_VERSION=%s\n' "$SINGBOX_VERSION" >> "$GITHUB_ENV"

# --- 5. PassWall (user decision 2026-11-06: "Passwall试试") ---
# Replaces HomeProxy (removed by the same decision). HomeProxy is a
# light sing-box-only manager; PassWall is the community-standard
# multi-protocol manager (sing-box / Xray / V2Ray / Trojan /
# Shadowsocks, subscriptions, load balancing, ACL rules). Both
# manage sing-box, so they CONFLICT — only one is installed.
# PassWall is fetched at latest master on every build (standing rule
# 2026-11-06), from the Openwrt-Passwall org — the project moved
# from xiaorouji in 2026 (the old xiaorouji/openwrt-passwall URL
# 404s). The repo is a feed whose luci-app-passwall lives in a
# subdirectory, so fetch_source clones it to a temp dir and the
# subdir is copied into package/ (the feed's copy is removed first,
# otherwise the package would be defined twice and the build fails).
# The config enables INCLUDE_SingBox so PassWall uses the sing-box
# core (updated to latest by §4 above). The feed's Go (1.26/1.27)
# satisfies sing-box 1.14.4's go.mod requirement (go 1.25.5), so no
# golang fetch is needed. Installed but unconfigured by default;
# the user adds a node in LuCI to enable it.
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf package/luci-app-passwall
fetch_source https://github.com/Openwrt-Passwall/openwrt-passwall package/.passwall-upstream luci-app-passwall/Makefile main PASSWALL_COMMIT
cp -r package/.passwall-upstream/luci-app-passwall package/luci-app-passwall
rm -rf package/.passwall-upstream
if [ ! -f "package/luci-app-passwall/Makefile" ]; then
    printf 'PassWall copy failed: package/luci-app-passwall/Makefile missing\n' >&2
    exit 1
fi

# --- 6. Fork sysctl tunings (fail loudly if the target is absent) ---
# Copied from the fork's set_sysctl (awk rewrite that drops any
# existing line for the key, then appends key=value). The target
# package/base-files/files/etc/sysctl.conf EXISTS in the pinned tree
# (verified 2026-11-05), so this must succeed — a missing file fails
# the build instead of silently skipping the tuning.
set_sysctl() {
    local key="$1"
    local value="$2"
    local file="package/base-files/files/etc/sysctl.conf"
    local temporary_file="${file}.tmp"

    if [ ! -f "$file" ]; then
        printf 'Required file not found: %s\n' "$file" >&2
        return 1
    fi

    awk -v key="$key" '{
        line = $0
        sub(/^[[:space:]]*/, "", line)
        split(line, parts, "=")
        name = parts[1]
        gsub(/[[:space:]]/, "", name)
        if (name != key) print
    }' "$file" > "$temporary_file"
    printf '%s=%s\n' "$key" "$value" >> "$temporary_file"
    mv "$temporary_file" "$file"
}

set_sysctl vm.min_free_kbytes 16384
set_sysctl vm.swappiness 10
set_sysctl net.core.netdev_max_backlog 10000
set_sysctl kernel.printk '0 0 0 0'

# --- 7. Fork rc.local additions (fail loudly if the target is absent) ---
# Copied from the fork's ensure_rc_command: each command is inserted
# before 'exit 0' exactly once (idempotent on re-runs). The target
# package/base-files/files/etc/rc.local EXISTS in the pinned tree
# and ends with 'exit 0' (verified 2026-11-05), so a missing file
# or a missing 'exit 0' fails the build instead of silently
# skipping the tuning. Unlike the fork, this does NOT create
# rc.local if it is absent — a missing rc.local means the tree
# changed, and that must fail loudly.
ensure_rc_command() {
    local command="$1"
    local rc_local="package/base-files/files/etc/rc.local"

    if [ ! -f "$rc_local" ]; then
        printf 'Required file not found: %s\n' "$rc_local" >&2
        return 1
    fi

    if ! grep -Fqx -- "$command" "$rc_local"; then
        if ! grep -Fqx 'exit 0' "$rc_local"; then
            printf 'Expected exit 0 in %s\n' "$rc_local" >&2
            return 1
        fi
        sed -i "/^exit 0$/i $command" "$rc_local"
    fi

    grep -Fqx -- "$command" "$rc_local"
}

ensure_rc_command 'echo 7 > /sys/kernel/mm/lru_gen/enabled'
ensure_rc_command 'mount -o remount,noatime,nodiratime /'

# --- 8. Fork tunings NOT applied (targets absent in the pinned tree) ---
# Log settings (circular, size 64) and the cpufreq performance
# governor are SKIPPED, not silently skipped: the fork's steps guard
# them with `if [ -f ... ]` and print "Skipping…" when the file is
# absent. In the pinned LiBwrt tree there is NO
# package/base-files/files/etc/config/ directory at all, so both
# targets (etc/config/system, etc/config/cpufreq) are absent and
# the fork's steps would have been no-ops on this tree. If a later
# base-tree bump adds those files, add the tunings here with
# replace_checked (fail loud), not with an if-guard.
# Also deliberately NOT added (per the user's 取其精华去其糟粕 rule):
# "Built by Roc" LuCI status injection (fork author's branding);
# CONFIG_GCC_VERSION_13 pin (risky, no benefit stated); CPU 1.5 GHz
# voltage tweak (commented out in the fork itself — not in the user's
# live firmware); MULTI_PROFILE + PER_DEVICE_ROOTFS (the scaffold's
# per-device configs + caller all-default already cover both
# devices); CONFIG_DEFAULT_TCP_CONG (dropped by defconfig; 99-custom
# sets BBR at first boot); the fork's "# CONFIG_FEED_* is not set"
# lines (stale; feeds are enabled via feeds.conf); the disabled
# fs/bluetooth/ikconfig/ir/sound/usb-audio/nfc/hamradio lines
# (no-ops on this tree).

echo "=== DIY OK ==="
