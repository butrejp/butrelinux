#!/bin/sh

#### derived from https://github.com/jokokucing/Origami-Linux/blob/main/modules/custom-kernel/custom-kernel.sh
#### Patched for Fedora + EL (RHEL / CentOS Stream / Rocky Linux / AlmaLinux) portability.
#### DNF5 is a soft requirement, however DNF4 should work, just may require some minor tweaks.
#### NOTE: this module is largely untested.  caveat emptor.

set -eu

log() { printf '[custom-kernel] %s\n' "$*"; }
err() { printf '[custom-kernel] Error: %s\n' "$*" >&2; }

log "Starting custom-kernel module..."

# ---------------------------------------------------------------------------
# Distro detection (Fedora vs Enterprise Linux derivatives)
# ---------------------------------------------------------------------------
# NOTE: on RHEL/CentOS/Rocky/Alma, /etc/os-release sets ID_LIKE="fedora" (a
# historical artifact), so IS_FEDORA must be decided from ID, never ID_LIKE.

OS_ID=""
OS_ID_LIKE=""
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_ID_LIKE="${ID_LIKE:-}"
fi

IS_FEDORA=false
IS_EL=false
EL_VERSION=""

case "${OS_ID}" in
fedora)
    IS_FEDORA=true
    ;;
rhel | centos | rocky | almalinux | ol | miraclelinux | virtuozzo)
    IS_EL=true
    ;;
*)
    case " ${OS_ID_LIKE} " in
    *" rhel "* | *" centos "*)
        IS_EL=true
        ;;
    esac
    ;;
esac

if [ "${IS_EL}" = "true" ]; then
    EL_VERSION=$(rpm -E %rhel)
fi

if [ "${IS_FEDORA}" != "true" ] && [ "${IS_EL}" != "true" ]; then
    err "Unable to determine base distro from /etc/os-release (ID=${OS_ID:-<unknown>} ID_LIKE=${OS_ID_LIKE:-<unknown>})."
    err "This module only supports Fedora and EL (RHEL/CentOS Stream/Rocky/AlmaLinux) derivatives."
    exit 1
fi

if [ "${IS_FEDORA}" = "true" ]; then
    log "Detected base distro: Fedora"
else
    log "Detected base distro: EL ${EL_VERSION}"
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

KERNEL_TYPE=$(printf '%s' "$1" | jq -r '.kernel // empty')
INITRAMFS=$(printf '%s' "$1"   | jq -r '.initramfs // false')
NVIDIA=$(printf '%s' "$1"      | jq -r '.nvidia // false')
ZFS=$(printf '%s' "$1"         | jq -r '.zfs // false')
SIGNING_KEY=$(printf '%s' "$1" | jq -r '.sign.key // ""')
SIGNING_CERT=$(printf '%s' "$1"| jq -r '.sign.cert // ""')
MOK_PASSWORD=$(printf '%s' "$1"| jq -r '.sign["mok-password"] // ""')
SECURE_BOOT=false

# Default kernel type is distro-dependent. CachyOS kernels are available on
# Fedora and EL 9/10 via COPR, but EL still defaults to ELRepo unless the
# user explicitly opts into a COPR kernel.
if [ -z "${KERNEL_TYPE}" ]; then
    if [ "${IS_FEDORA}" = "true" ]; then
        KERNEL_TYPE="cachyos-lto"
    else
        KERNEL_TYPE="elrepo-ml"
    fi
fi

if [ -z "${SIGNING_KEY}" ] && [ -z "${SIGNING_CERT}" ] && [ -z "${MOK_PASSWORD}" ]; then
    log "SecureBoot signing disabled."
elif [ -f "${SIGNING_KEY}" ] && [ -f "${SIGNING_CERT}" ] && [ -n "${MOK_PASSWORD}" ]; then
    SECURE_BOOT=true
    log "SecureBoot signing enabled."
else
    err "Invalid signing config:"
    err "  sign.key:          ${SIGNING_KEY:-<empty>}"
    err "  sign.cert:         ${SIGNING_CERT:-<empty>}"
    err "  sign.mok-password: ${MOK_PASSWORD:-<empty>}"
    exit 1
fi

if [ "${SECURE_BOOT}" = "true" ]; then
    openssl pkey -in "${SIGNING_KEY}"  -noout >/dev/null 2>&1 \
        || { err "sign.key is not a valid private key"; exit 1; }
    openssl x509 -in "${SIGNING_CERT}" -noout >/dev/null 2>&1 \
        || { err "sign.cert is not a valid X509 cert"; exit 1; }
    _tmp1=$(mktemp); _tmp2=$(mktemp)
    openssl pkey -in "${SIGNING_KEY}"  -pubout        >"${_tmp1}"
    openssl x509 -in "${SIGNING_CERT}" -pubkey -noout >"${_tmp2}"
    if ! cmp -s "${_tmp1}" "${_tmp2}" >/dev/null 2>&1; then
        rm -f "${_tmp1}" "${_tmp2}"
        err "sign.key and sign.cert do not match"
        exit 1
    fi
    rm -f "${_tmp1}" "${_tmp2}"
fi

# ---------------------------------------------------------------------------
# Kernel package resolution
# ---------------------------------------------------------------------------
# REPO_BACKEND says how KERNEL_PACKAGES get fetched:
#   copr   - Fedora COPR (bieszczaders' CachyOS kernel builds; Fedora only)
#   elrepo - ELRepo's kernel-ml/kernel-lt (EL only)

# TRANSIENT: space-separated build-only packages removed from the image after signing.
TRANSIENT="akmods"

case "${KERNEL_TYPE}" in
cachyos-lto)
    REPO_BACKEND="copr"
    COPR_REPO="bieszczaders/kernel-cachyos-lto"
    KERNEL_PKG="kernel-cachyos-lto"
    KERNEL_DEVEL_PKG="kernel-cachyos-lto-devel-matched kernel-cachyos-lto-devel"
    KERNEL_PACKAGES="kernel-cachyos-lto kernel-cachyos-lto-core kernel-cachyos-lto-modules kernel-cachyos-lto-devel-matched"
    ;;
cachyos-lts-lto)
    REPO_BACKEND="copr"
    COPR_REPO="bieszczaders/kernel-cachyos-lto"
    KERNEL_PKG="kernel-cachyos-lts-lto"
    KERNEL_DEVEL_PKG="kernel-cachyos-lts-lto-devel-matched"
    KERNEL_PACKAGES="kernel-cachyos-lts-lto kernel-cachyos-lts-lto-core kernel-cachyos-lts-lto-modules kernel-cachyos-lts-lto-devel-matched"
    ;;
cachyos)
    REPO_BACKEND="copr"
    COPR_REPO="bieszczaders/kernel-cachyos"
    KERNEL_PKG="kernel-cachyos"
    KERNEL_DEVEL_PKG="kernel-cachyos-devel-matched"
    KERNEL_PACKAGES="kernel-cachyos kernel-cachyos-core kernel-cachyos-modules kernel-cachyos-devel-matched"
    ;;
cachyos-rt)
    REPO_BACKEND="copr"
    COPR_REPO="bieszczaders/kernel-cachyos"
    KERNEL_PKG="kernel-cachyos-rt"
    KERNEL_DEVEL_PKG="kernel-cachyos-rt-devel-matched"
    KERNEL_PACKAGES="kernel-cachyos-rt kernel-cachyos-rt-core kernel-cachyos-rt-modules kernel-cachyos-rt-devel-matched"
    ;;
cachyos-lts)
    REPO_BACKEND="copr"
    COPR_REPO="bieszczaders/kernel-cachyos"
    KERNEL_PKG="kernel-cachyos-lts"
    KERNEL_DEVEL_PKG="kernel-cachyos-lts-devel-matched"
    KERNEL_PACKAGES="kernel-cachyos-lts kernel-cachyos-lts-core kernel-cachyos-lts-modules kernel-cachyos-lts-devel-matched"
    ;;
elrepo-ml)
    REPO_BACKEND="elrepo"
    KERNEL_PKG="kernel-ml"
    KERNEL_DEVEL_PKG="kernel-ml-devel"
    KERNEL_PACKAGES="kernel-ml kernel-ml-core kernel-ml-modules kernel-ml-modules-extra kernel-ml-devel"
    ;;
elrepo-lt)
    REPO_BACKEND="elrepo"
    KERNEL_PKG="kernel-lt"
    KERNEL_DEVEL_PKG="kernel-lt-devel"
    KERNEL_PACKAGES="kernel-lt kernel-lt-core kernel-lt-modules kernel-lt-modules-extra kernel-lt-devel"
    if [ "${IS_EL}" = "true" ] && [ "${EL_VERSION}" -ge 10 ] 2>/dev/null; then
        log "Warning: ELRepo has not published kernel-lt for EL${EL_VERSION} as of this writing (kernel-ml only); this may fail to install."
    fi
    ;;
*)
    err "Unsupported kernel type: ${KERNEL_TYPE}"
    err "Fedora (COPR-backed): cachyos, cachyos-lts, cachyos-rt, cachyos-lto, cachyos-lts-lto"
    err "EL (ELRepo-backed):   elrepo-ml, elrepo-lt"
    exit 1
    ;;
esac

TRANSIENT="${TRANSIENT} ${KERNEL_DEVEL_PKG}"

case "${REPO_BACKEND}" in
copr)
    # CachyOS kernels are published via COPR for both Fedora and EL (EPEL 9/10).
    : # no-op — valid on all supported distros
    ;;
elrepo)
    if [ "${IS_EL}" != "true" ]; then
        err "Kernel type '${KERNEL_TYPE}' is sourced from ELRepo and is only available on EL-based images."
        err "On Fedora use one of: cachyos, cachyos-lts, cachyos-rt, cachyos-lto, cachyos-lts-lto."
        exit 1
    fi
    ;;
esac

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

disable_kernel_install_hooks() {
    for _f in \
        /usr/lib/kernel/install.d/05-rpmostree.install \
        /usr/lib/kernel/install.d/50-dracut.install
    do
        [ -f "${_f}" ] || continue
        mv "${_f}" "${_f}.bak"
        printf '#!/bin/sh\nexit 0\n' >"${_f}"
        chmod +x "${_f}"
    done
}

restore_kernel_install_hooks() {
    for _f in \
        /usr/lib/kernel/install.d/05-rpmostree.install \
        /usr/lib/kernel/install.d/50-dracut.install
    do
        [ -f "${_f}.bak" ] && mv -f "${_f}.bak" "${_f}"
    done
}

disable_akmodsbuild() {
    _ak="/usr/sbin/akmodsbuild"
    [ -f "${_ak}" ] || { err "akmodsbuild not found: ${_ak}"; return 1; }
    cp -p "${_ak}" "${_ak}.backup" || return 1
    sed '/if \[\[ -w \/var \]\] ; then/,/fi/d' "${_ak}" > "${_ak}.tmp" && mv "${_ak}.tmp" "${_ak}" || return 1
    chmod +x "${_ak}"
}

restore_akmodsbuild() {
    [ -f /usr/sbin/akmodsbuild.backup ] \
        && mv -f /usr/sbin/akmodsbuild.backup /usr/sbin/akmodsbuild
}

sign_kernel() {
    _vmlinuz="/usr/lib/modules/${KERNEL_VERSION}/vmlinuz"
    [ -f "${_vmlinuz}" ] || { err "Kernel image not found: ${_vmlinuz}"; return 1; }
    _tmp=$(mktemp)
    sbsign --key "${SIGNING_KEY}" --cert "${SIGNING_CERT}" --output "${_tmp}" "${_vmlinuz}"
    if ! sbverify --cert "${SIGNING_CERT}" "${_tmp}"; then
        err "Kernel signature verification failed"
        rm -f "${_tmp}"
        return 1
    fi
    cp "${_tmp}" "${_vmlinuz}"
    chmod 0644 "${_vmlinuz}"
    rm -f "${_tmp}"
    sha256sum "${_vmlinuz}" >/tmp/vmlinuz.sha
}

sign_kernel_modules() {
    _module_root="/usr/lib/modules/${KERNEL_VERSION}"
    _sign_file="${_module_root}/build/scripts/sign-file"
    [ -x "${_sign_file}" ] \
        || { err "sign-file not found or not executable: ${_sign_file}"; return 1; }
    _tmplist=$(mktemp)
    find "${_module_root}" -type f \( \
        -name "*.ko" -o -name "*.ko.xz" -o -name "*.ko.zst" -o -name "*.ko.gz" \
    \) >"${_tmplist}"
    while IFS= read -r _mod; do
        case "${_mod}" in
        *.ko)
            "${_sign_file}" sha256 "${SIGNING_KEY}" "${SIGNING_CERT}" "${_mod}" \
                || { rm -f "${_tmplist}"; return 1; }
            ;;
        *.ko.xz)
            _raw="${_mod%.xz}"
            xz -d -q "${_mod}"
            "${_sign_file}" sha256 "${SIGNING_KEY}" "${SIGNING_CERT}" "${_raw}" \
                || { rm -f "${_tmplist}"; return 1; }
            xz -z -q "${_raw}"
            ;;
        *.ko.zst)
            _raw="${_mod%.zst}"
            zstd -d -q --rm "${_mod}"
            "${_sign_file}" sha256 "${SIGNING_KEY}" "${SIGNING_CERT}" "${_raw}" \
                || { rm -f "${_tmplist}"; return 1; }
            zstd -q "${_raw}"
            ;;
        *.ko.gz)
            _raw="${_mod%.gz}"
            gunzip -q "${_mod}"
            "${_sign_file}" sha256 "${SIGNING_KEY}" "${SIGNING_CERT}" "${_raw}" \
                || { rm -f "${_tmplist}"; return 1; }
            gzip -q "${_raw}"
            ;;
        esac
    done <"${_tmplist}"
    rm -f "${_tmplist}"
}

create_mok_enroll_unit() {
    _mok_cert="/usr/share/cert/MOK.der"
    _unit_file="/usr/lib/systemd/system/mok-enroll.service"
    _tmp=$(mktemp)
    openssl x509 -in "${SIGNING_CERT}" -outform DER -out "${_tmp}" \
        || { rm -f "${_tmp}"; return 1; }
    mkdir -p "$(dirname "${_mok_cert}")"
    cp "${_tmp}" "${_mok_cert}"
    chmod 0644 "${_mok_cert}"
    rm -f "${_tmp}"
    mkdir -p "$(dirname "${_unit_file}")"
    cat <<EOF > "${_unit_file}"
[Unit]
Description=Enroll MOK key on first boot
ConditionPathExists=${_mok_cert}
ConditionPathExists=!/var/.mok-enrolled

[Service]
Type=oneshot
ExecStart=/bin/sh -c '(echo "${MOK_PASSWORD}"; echo "${MOK_PASSWORD}") | mokutil --import "${_mok_cert}"'
ExecStartPost=/usr/bin/touch /var/.mok-enrolled
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 "${_unit_file}"
    systemctl -f enable mok-enroll.service
    log "Created and enabled mok-enroll.service"
}

# ---------------------------------------------------------------------------
# EL prerequisite repos (EPEL + CRB/PowerTools)
# ---------------------------------------------------------------------------

if [ "${IS_EL}" = "true" ]; then
    log "Enabling EPEL and CRB/PowerTools repos."
    dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${EL_VERSION}.noarch.rpm"
    dnf -y install dnf-plugins-core
    dnf config-manager --set-enabled crb 2>/dev/null \
        || dnf config-manager --set-enabled powertools 2>/dev/null \
        || true
fi

# ---------------------------------------------------------------------------
# Install kernel
# ---------------------------------------------------------------------------

log "Temporarily disabling kernel install scripts."
disable_kernel_install_hooks

log "Removing default kernel packages."
dnf -y remove \
    kernel \
    kernel-core \
    kernel-modules \
    kernel-modules-core \
    kernel-modules-extra \
    kernel-devel \
    kernel-devel-matched || true
rm -rf /usr/lib/modules/* || true

log "Resolving kernel source (${KERNEL_TYPE}, backend: ${REPO_BACKEND})."
case "${REPO_BACKEND}" in
copr)
    dnf -y install dnf-plugins-core
    log "Enabling COPR repo: ${COPR_REPO}"
    dnf -y copr enable "${COPR_REPO}"
    log "Installing kernel packages: ${KERNEL_PACKAGES}"
    # shellcheck disable=SC2086
    dnf -y install $KERNEL_PACKAGES akmods
    ;;
elrepo)
    log "Enabling ELRepo kernel channel."
    dnf -y install "https://www.elrepo.org/elrepo-release-${EL_VERSION}.el${EL_VERSION}.elrepo.noarch.rpm"
    log "Installing kernel packages: ${KERNEL_PACKAGES}"
    # shellcheck disable=SC2086
    dnf -y --enablerepo=elrepo-kernel install $KERNEL_PACKAGES akmods
    ;;
esac

KERNEL_VERSION=$(rpm -q "${KERNEL_PKG}" --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1) || exit 1
log "Kernel version: ${KERNEL_VERSION}"
KERNEL_SOURCE="/usr/src/kernels/${KERNEL_VERSION}"

log "Restoring kernel install scripts."
restore_kernel_install_hooks

log "Cleaning up kernel source repo configuration."
case "${REPO_BACKEND}" in
copr)
    rm -f /etc/yum.repos.d/*copr*
    ;;
elrepo)
    dnf -y remove elrepo-release || true
    rm -f /etc/yum.repos.d/elrepo*.repo
    ;;
esac

# ---------------------------------------------------------------------------
# Build v4l2loopback
# ---------------------------------------------------------------------------

log "Building v4l2loopback module for kernel: ${KERNEL_VERSION}"

log "Enabling RPM Fusion Free repo."
if [ "${IS_FEDORA}" = "true" ]; then
    dnf -y install \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
else
    dnf -y install \
        "https://download1.rpmfusion.org/free/el/rpmfusion-free-release-${EL_VERSION}.noarch.rpm"
fi

dnf install -y --setopt=install_weak_deps=False --setopt=tsflags=noscripts \
    akmod-v4l2loopback
TRANSIENT="${TRANSIENT} akmod-v4l2loopback"

# Some kernels (e.g. ELRepo kernel-ml) intentionally do not provide
# kernel-uname-r, causing akmods' DNF install step to fail even though the
# build itself succeeds. We ignore that error and handle installation manually.
akmods --force --verbose --kernels "${KERNEL_VERSION}" --kmod v4l2loopback || true

_kmod_rpm=$(find /var/cache/akmods/v4l2loopback -maxdepth 1 \
    -name "kmod-v4l2loopback-*.rpm" ! -name "*failed*" 2>/dev/null | head -n1)

if [ -n "$_kmod_rpm" ] && [ -f "$_kmod_rpm" ]; then
    _rpm_name=$(rpm -qp --queryformat '%{NAME}\n' "$_kmod_rpm" 2>/dev/null)
    if [ -n "$_rpm_name" ] && ! rpm -q "$_rpm_name" >/dev/null 2>&1; then
        log "Installing built kmod RPM (bypassing kernel-uname-r dependency): ${_kmod_rpm}"
        rpm -ivh --nodeps "$_kmod_rpm"
    else
        log "kmod RPM already installed, skipping manual install."
    fi
    depmod -a "${KERNEL_VERSION}"
    rm -f /var/cache/akmods/v4l2loopback/*.failed.log
else
    # No cached RPM — determine if it was a real build failure
    _fail_found=false
    for _f in /var/cache/akmods/v4l2loopback/*-for-"${KERNEL_VERSION}".failed.log; do
        [ -f "${_f}" ] && _fail_found=true && break
    done
    if [ "${_fail_found}" = "true" ]; then
        err "v4l2loopback akmod build failed:"
        for _f in /var/cache/akmods/v4l2loopback/*-for-"${KERNEL_VERSION}".failed.log; do
            [ -f "${_f}" ] && cat "${_f}"
        done
        exit 1
    fi
    # akmods may have succeeded and cleaned up the RPM itself. Verify the module exists.
    if ! find "/lib/modules/${KERNEL_VERSION}/extra/v4l2loopback/" -name "v4l2loopback.ko*" | grep -q .; then
        err "v4l2loopback kmod not found after build"
        exit 1
    fi
fi

log "Cleaning RPM Fusion Free repo."
dnf -y remove rpmfusion-free-release
rm -f /etc/yum.repos.d/rpmfusion-free*.repo

# restore_akmodsbuild

# ---------------------------------------------------------------------------
# Build OpenZFS (DKMS)
# ---------------------------------------------------------------------------
# ZFS isn't in RPM Fusion (its CDDL license keeps it out of the akmods/RPM
# Fusion ecosystem entirely), and OpenZFS's own precompiled "kABI-tracking
# kmod" packages are only verified against the distro's own stock kernel -
# neither applies to a swapped-in custom kernel. This always builds via DKMS
# against ${KERNEL_VERSION} explicitly, which is also the zfs-release repo's
# default mode on both Fedora and EL, so no repo-switching is needed.
#
# NOTE: DKMS builds can fail against very new/non-distribution kernels
# (elrepo-ml especially, and fresh CachyOS bumps) if OpenZFS hasn't caught
# up to a recent kernel API change yet - that's an upstream compatibility
# gap, not a bug here. Check https://github.com/openzfs/zfs/issues if the
# build below fails.
#
# NOTE: zfs-dkms/dkms are deliberately NOT added to TRANSIENT. Removing
# zfs-dkms via dnf fires its %preun, which calls `dkms remove` and deletes
# the very .ko files we just built for ${KERNEL_VERSION} - unlike akmods'
# kmod-* packages (a separate, already-compiled RPM from the akmod-*
# build-only package), DKMS has no such split: the build tooling and the
# built module are the same package here, so it stays installed.

if [ "${ZFS}" = "true" ]; then
    log "Building OpenZFS (DKMS) for kernel: ${KERNEL_VERSION}"

    ZFS_BUILD_TOOLS="gcc make elfutils-libelf-devel"
    # shellcheck disable=SC2086
    dnf -y install dkms $ZFS_BUILD_TOOLS

    if [ "${IS_FEDORA}" = "true" ]; then
        dnf -y install "https://zfsonlinux.org/fedora/zfs-release-3-1$(rpm --eval '%{dist}').noarch.rpm"
    else
        dnf -y install "https://zfsonlinux.org/epel/zfs-release-3-0$(rpm --eval '%{dist}').noarch.rpm"
    fi

    # zfs-dkms Requires: kernel-devel <= 6.17.999, but CachyOS 7.1.5 provides
    # kernel-devel = 7.1.5 which fails the version check. Download and force-
    # install to bypass the artificial version bound.
    dnf -y download --disableexcludes=all zfs zfs-dkms
    rpm -Uvh zfs-*.rpm zfs-dkms-*.rpm --nodeps
    rm -f zfs-*.rpm zfs-dkms-*.rpm

    _zfs_ver=$(rpm -q --queryformat '%{VERSION}\n' zfs-dkms 2>/dev/null)
    log "Building OpenZFS ${_zfs_ver} DKMS module for ${KERNEL_VERSION}."
    if ! dkms install -m zfs -v "${_zfs_ver}" -k "${KERNEL_VERSION}" --force; then
        err "OpenZFS DKMS build failed for kernel ${KERNEL_VERSION}."
        err "OpenZFS 2.2.10 likely does not support Linux 7.1 yet - check https://github.com/openzfs/zfs/issues."
        exit 1
    fi

    if ! find "/usr/lib/modules/${KERNEL_VERSION}" -name "zfs.ko*" | grep -q .; then
        err "zfs.ko not found under /usr/lib/modules/${KERNEL_VERSION} after DKMS build."
        exit 1
    fi

    depmod "${KERNEL_VERSION}"

    log "Cleaning up ZFS repo configuration."
    dnf -y remove zfs-release || true
    rm -f /etc/yum.repos.d/zfs*.repo

    TRANSIENT="${TRANSIENT} ${ZFS_BUILD_TOOLS}"
fi
fi

# ---------------------------------------------------------------------------
# Build Nvidia via upstream .run payload
# ---------------------------------------------------------------------------
# NOTE: this section is largely distro-agnostic (it builds against the
# upstream vendor .run installer, not RPM Fusion/dkms), so package names
# below are the same list for Fedora and EL. dkms itself now comes from EPEL
# on EL (enabled above); a couple of the Wayland/Mesa runtime packages (e.g.
# egl-wayland) may additionally need CRB (also enabled above) depending on
# your EL derivative and release channel - verify availability for your
# specific EL10 build if the install step below fails on a package name.

if [ "${NVIDIA}" = "true" ]; then
    log "Starting upstream NVIDIA payload build for kernel ${KERNEL_VERSION}."

    # 1. Added explicit Mesa drivers to ensure software fallback works in VMs
    NVIDIA_BUILD_TOOLS="dkms gcc make perl elfutils-libelf-devel checkpolicy selinux-policy-devel clang llvm lld"
    NVIDIA_RUNTIME_DEPS="libglvnd libglvnd-egl libglvnd-gles libglvnd-glx libglvnd-opengl egl-x11 egl-wayland2 egl-gbm xorg-x11-server-Xwayland mesa-dri-drivers mesa-vulkan-drivers mesa-libEGL mesa-libGL"

    # shellcheck disable=SC2086
    dnf install -y --setopt=install_weak_deps=False --setopt=tsflags=noscripts --setopt=skip_unavailable=1 $NVIDIA_BUILD_TOOLS $NVIDIA_RUNTIME_DEPS curl tar bzip2 policycoreutils

    if [[ ! -d "$KERNEL_SOURCE" ]]; then
        err "Missing kernel source path after installing devel package: $KERNEL_SOURCE"
        exit 1
    fi

    # 2. Resolve the latest NVIDIA version from the directory listing.
    #    latest.txt tracks the stable/production branch; scanning the
    #    directory picks up the newest feature branch as well.
    #    NOTE: feature branch drivers (e.g. 610.x) may be beta quality.
    log "Resolving latest NVIDIA version from download.nvidia.com..."
    NVIDIA_VERSION=$(curl -fsSL https://download.nvidia.com/XFree86/Linux-x86_64/ | \
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | \
        sort -V | \
        tail -n 1)

    if [ -z "$NVIDIA_VERSION" ]; then
        err "Failed to resolve latest NVIDIA version from directory listing."
        exit 1
    fi

    NVIDIA_RUN="NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run"
    NVIDIA_URL="https://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/${NVIDIA_RUN}"

    log "Selected NVIDIA version: ${NVIDIA_VERSION}"
    log "Downloading: ${NVIDIA_URL}"

    _tmpdir="$(mktemp -d)"
    curl -fL "$NVIDIA_URL" -o "$_tmpdir/$NVIDIA_RUN"
    chmod +x "$_tmpdir/$NVIDIA_RUN"

    log "Extracting NVIDIA installer payload..."
    (
        cd "$_tmpdir"
        "./$NVIDIA_RUN" --extract-only
    )

    NVIDIA_SRC_DIR="$_tmpdir/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}"
    if [[ ! -d "$NVIDIA_SRC_DIR" ]]; then
        err "Extracted NVIDIA source directory not found: $NVIDIA_SRC_DIR"
        exit 1
    fi

    # 3. Compile and Install (REMOVED --install-libglvnd so Fedora controls display routing!)
    log "Running NVIDIA installer with Clang/LLVM overrides..."
    env CC=clang LLVM=1 LD=ld.lld IGNORE_CC_MISMATCH=1 "$NVIDIA_SRC_DIR/nvidia-installer" \
        --silent \
        --accept-license \
        --no-questions \
        --no-nouveau-check \
        --no-backup \
        --no-check-for-alternate-installs \
        --kernel-name="${KERNEL_VERSION}" \
        --kernel-source-path="${KERNEL_SOURCE}" \
        --utility-prefix=/usr \
        --opengl-prefix=/usr \
        --compat32-prefix=/usr \
        --x-prefix=/usr

    rm -rf "$_tmpdir"

    # 4. Apply standard configuration files
    mkdir -p /etc/modprobe.d /usr/lib/udev/rules.d /usr/lib/dracut/dracut.conf.d

    cat <<'EOF' > /etc/modprobe.d/nvidia.conf
blacklist nouveau
options nouveau modeset=0
options nvidia-drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
    chmod 0644 /etc/modprobe.d/nvidia.conf

    cat <<'EOF' > /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
force_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_peermem nvidia_drm "
omit_drivers+=" nouveau "
EOF
    chmod 0644 /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

    cat <<'EOF' > /usr/lib/udev/rules.d/60-nvidia.rules
KERNEL=="nvidia", RUN+="/usr/bin/nvidia-modprobe -c 0 -u"
KERNEL=="nvidia_uvm", RUN+="/usr/bin/nvidia-modprobe -c 0 -u"
EOF
    chmod 0644 /usr/lib/udev/rules.d/60-nvidia.rules

    mkdir -p /usr/lib/bootc/kargs.d
    cat <<'EOF' > /usr/lib/bootc/kargs.d/90-nvidia.toml
kargs = [
"rd.driver.blacklist=nouveau",
"modprobe.blacklist=nouveau",
"rd.driver.pre=nvidia",
"nvidia-drm.modeset=1",
"nvidia-drm.fbdev=1"
]
EOF
    chmod 0644 /usr/lib/bootc/kargs.d/90-nvidia.toml

    # 5. Enable systemd services
    systemctl enable nvidia-powerd.service >/dev/null 2>&1 || true
    systemctl enable nvidia-persistenced.service >/dev/null 2>&1 || true

    # 6. Install NVIDIA Container Toolkit
    log "Installing NVIDIA Container Toolkit..."
    curl -fsSL --retry 5 --create-dirs \
        https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
        -o /etc/yum.repos.d/nvidia-container-toolkit.repo
    dnf install -y --setopt=skip_unavailable=1 nvidia-container-toolkit
    rm -f /etc/yum.repos.d/nvidia-container-toolkit.repo

    log "Installing Container Toolkit CDI auto-generation unit."
    mkdir -p /usr/lib/systemd/system
    cat <<'EOF' > /usr/lib/systemd/system/nvctk-cdi.service
[Unit]
Description=NVIDIA Container Toolkit CDI auto-generation
ConditionFileIsExecutable=/usr/bin/nvidia-ctk
ConditionPathExists=!/etc/cdi/nvidia.yaml
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 /usr/lib/systemd/system/nvctk-cdi.service

    mkdir -p /usr/lib/systemd/system-preset
    cat <<'EOF' > /usr/lib/systemd/system-preset/70-nvctk-cdi.preset
enable nvctk-cdi.service
EOF
    chmod 0644 /usr/lib/systemd/system-preset/70-nvctk-cdi.preset

    # 7. Mark ONLY the compilers/build tools for removal, preserving the GUI libraries
    # shellcheck disable=SC2086
    TRANSIENT="${TRANSIENT} $NVIDIA_BUILD_TOOLS"

    # Generate module dependencies
    depmod "${KERNEL_VERSION}"
fi

# ---------------------------------------------------------------------------
# SecureBoot signing
# ---------------------------------------------------------------------------

if [ "${SECURE_BOOT}" = "true" ]; then
    log "Signing the kernel."
    sign_kernel || exit 1

    log "Signing kernel modules."
    sign_kernel_modules || exit 1

    log "Creating MOK enroll unit."
    create_mok_enroll_unit || exit 1
fi

# ---------------------------------------------------------------------------
# Remove transient build packages
# ---------------------------------------------------------------------------

log "Removing transient build packages: ${TRANSIENT}"
# shellcheck disable=SC2086
dnf -y remove $TRANSIENT || true

_residual=$(rpm -qa --queryformat '%{NAME}\n' | grep -E '^akmod-|(-devel-matched)$' || true)
if [ -n "${_residual}" ]; then
    log "Removing residual build packages: ${_residual}"
    # shellcheck disable=SC2086
    dnf -y remove $_residual || true
fi

log "Removing kernel build trees."
rm -rf /usr/lib/modules/*/build /usr/lib/modules/*/source /usr/src/nvidia-*

log "Removing akmods build artefacts."
rm -rf /var/cache/akmods /var/lib/dkms

log "Cleaning DNF caches."
dnf -y clean all || true
rm -rf /var/cache/dnf/* /var/tmp/dnf-* || true

# ---------------------------------------------------------------------------
# Initramfs
# ---------------------------------------------------------------------------

if [ "${INITRAMFS}" = "true" ]; then
    log "Generating initramfs."
    _tmp=$(mktemp)
    DRACUT_NO_XATTR=1 /usr/bin/dracut \
        --no-hostonly \
        --kver "${KERNEL_VERSION}" \
        --reproducible \
        --add ostree \
        -f "${_tmp}" \
        -v || exit 1
    mkdir -p "/usr/lib/modules/${KERNEL_VERSION}"
    cp "${_tmp}" "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"
    chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"
    rm -f "${_tmp}"
fi

# ---------------------------------------------------------------------------
# Final integrity checks
# ---------------------------------------------------------------------------

if [ "${SECURE_BOOT}" = "true" ]; then
    sha256sum -c /tmp/vmlinuz.sha || { err "Kernel modified after signing."; exit 1; }
    rm -f /tmp/vmlinuz.sha
    log "Integrity check passed."
fi

if [ "${NVIDIA}" = "true" ]; then
    for _name in nvidia nvidia-drm nvidia-modeset nvidia-peermem nvidia-uvm; do
        if ! find "/usr/lib/modules/${KERNEL_VERSION}" -name "${_name}.ko*" | grep -q .; then
            err "Missing Nvidia module: ${_name}.ko*"
            exit 1
        fi
    done
    log "All Nvidia modules present."
fi

log "Custom kernel installation complete."
