#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

IMAGE="${IMAGE:-hwe}"
ISO="${ISO:?ISO must point to the ISO being tested}"

TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-1800}"

RAM_MB="${RAM_MB:-6144}"
CPUS="${CPUS:-4}"
HTTP_PORT="${HTTP_PORT:-8080}"

WORKDIR="${WORKDIR:-${REPO_ROOT}/.smoke}"
DISK="${WORKDIR}/butrelinux-smoke.qcow2"
ISO_KERNEL="${WORKDIR}/vmlinuz"
ISO_INITRD="${WORKDIR}/initrd.img"
KICKSTART="${WORKDIR}/smoke.cfg"

QEMU_LOG="${WORKDIR}/qemu.log"
QEMU_STDOUT_LOG="${WORKDIR}/qemu.stdout.log"

QEMU_PID=""
HTTP_PID=""

mkdir -p "$WORKDIR"

cleanup() {
    local rc=$?

    if [[ -n "${QEMU_PID}" ]] && kill -0 "${QEMU_PID}" 2>/dev/null; then
        kill "${QEMU_PID}" 2>/dev/null || true
        wait "${QEMU_PID}" 2>/dev/null || true
    fi

    if [[ -n "${HTTP_PID}" ]] && kill -0 "${HTTP_PID}" 2>/dev/null; then
        kill "${HTTP_PID}" 2>/dev/null || true
        wait "${HTTP_PID}" 2>/dev/null || true
    fi

    if [[ "$rc" -ne 0 ]]; then
        echo
        echo "===== QEMU SERIAL LOG ====="

        if [[ -f "$QEMU_LOG" ]]; then
            cat "$QEMU_LOG"
        fi

        echo
        echo "===== QEMU STDOUT/STDERR ====="

        if [[ -f "$QEMU_STDOUT_LOG" ]]; then
            cat "$QEMU_STDOUT_LOG"
        fi

        echo
        echo "===== KICKSTART HTTP LOG ====="

        if [[ -f "${WORKDIR}/http.log" ]]; then
            cat "${WORKDIR}/http.log"
        fi
    fi

    exit "$rc"
}

trap cleanup EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required command not found: $1" >&2
        exit 1
    }
}

for command in \
    qemu-system-x86_64 \
    qemu-img \
    xorriso \
    python3 \
    curl
do
    require_command "$command"
done

echo "==> Smoke testing image: ${IMAGE}"

IMAGE_REF="ghcr.io/butrejp/butrelinux-${IMAGE}:latest"

echo "==> Image under test: ${IMAGE_REF}"
echo "==> ISO: ${ISO}"

[[ -f "$ISO" ]] || {
    echo "ERROR: ISO does not exist: $ISO" >&2
    exit 1
}

echo "==> Generating smoke kickstart"

sed \
    "s|@IMAGE@|${IMAGE}|g" \
    "${SCRIPT_DIR}/kickstart.cfg.in" \
    > "$KICKSTART"

echo "==> Smoke kickstart:"
cat "$KICKSTART"

#
# The smoke kickstart is served over QEMU's user-mode network.
#
# QEMU exposes the host as 10.0.2.2 from the guest. We therefore put the
# kickstart directly into WORKDIR before starting the HTTP server.
#


echo "==> Starting Kickstart HTTP server"

(
    cd "$WORKDIR"

    exec python3 \
        -m http.server \
        "$HTTP_PORT" \
        --bind 0.0.0.0
) > "${WORKDIR}/http.log" 2>&1 &

HTTP_PID=$!

echo "==> Waiting for Kickstart HTTP server"

for _ in $(seq 1 30); do
    if curl \
        --silent \
        --fail \
        "http://127.0.0.1:${HTTP_PORT}/smoke.cfg" \
        >/dev/null
    then
        break
    fi

    sleep 1
done

curl \
    --silent \
    --fail \
    "http://127.0.0.1:${HTTP_PORT}/smoke.cfg" \
    >/dev/null

echo "==> Kickstart server is ready"

#
# Extract the installer kernel and initrd from the ISO.
#
# We boot Anaconda directly instead of interacting with the ISO's GRUB menu.
# This is intentional: the production GRUB menu and kickstart remain
# completely untouched.
#

echo "==> Extracting installer kernel"

rm -f "$ISO_KERNEL"

xorriso \
    -osirrox on \
    -indev "$ISO" \
    -extract /images/pxeboot/vmlinuz "$ISO_KERNEL"

[[ -s "$ISO_KERNEL" ]] || {
    echo "ERROR: failed to extract installer kernel"
    exit 1
}

echo "==> Extracting installer initrd"

rm -f "$ISO_INITRD"

xorriso \
    -osirrox on \
    -indev "$ISO" \
    -extract /images/pxeboot/initrd.img "$ISO_INITRD"

[[ -s "$ISO_INITRD" ]] || {
    echo "ERROR: failed to extract installer initrd"
    exit 1
}

#
# Create a clean VM disk for every test.
#

echo "==> Creating VM disk"

rm -f "$DISK"

qemu-img create \
    -f qcow2 \
    "$DISK" \
    32G


echo "==> Checking KVM access"

if [[ -e /dev/kvm ]]; then
    ls -l /dev/kvm

    if sudo test -r /dev/kvm && sudo test -w /dev/kvm; then
        echo "KVM device is accessible via sudo"
    else
        echo "WARNING: /dev/kvm exists but is not accessible via sudo"
    fi
else
    echo "WARNING: /dev/kvm does not exist"
fi

#
# Boot the Anaconda installer.
#
# -kernel/-initrd bypass the ISO's GRUB menu.
# -drive with the ISO supplies the installation source.
# inst.ks points to our CI-only kickstart.
# inst.ksstrict makes Anaconda fail rather than silently ignoring it.
# inst.noninteractive prevents an accidental interactive install.
#
# QEMU's user network exposes the host at 10.0.2.2.
#

echo "==> Starting QEMU installer"

sudo qemu-system-x86_64 \
    -machine q35,accel=kvm:tcg \
    -cpu max \
    -m "$RAM_MB" \
    -smp "$CPUS" \
    -drive "file=${DISK},if=virtio,format=qcow2" \
    -drive "file=${ISO},media=cdrom,readonly=on" \
    -kernel "$ISO_KERNEL" \
    -initrd "$ISO_INITRD" \
    -append "inst.stage2=hd:LABEL=BUTRELINUX inst.ks=http://10.0.2.2:${HTTP_PORT}/smoke.cfg inst.ksstrict inst.noninteractive console=tty0 console=ttyS0" \
    -nic "user,model=virtio-net-pci" \
    -serial "file:${QEMU_LOG}" \
    -display none \
    -no-reboot \
    > "$QEMU_STDOUT_LOG" 2>&1 &

QEMU_PID=$!

echo "==> Waiting for installation to complete"

deadline=$((SECONDS + TIMEOUT_SECONDS))

while (( SECONDS < deadline )); do
    if grep -q "Installation complete" "$QEMU_LOG" 2>/dev/null; then
        echo "==> Anaconda reports installation complete"
        break
    fi

    if grep -q "BUTRELINUX_SMOKE_FAIL" "$QEMU_LOG" 2>/dev/null; then
        echo "ERROR: installer reported smoke-test failure"
        exit 1
    fi

    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        echo "ERROR: installer QEMU exited before installation completed"
        exit 1
    fi

    sleep 5
done

if ! grep -q "Installation complete" "$QEMU_LOG" 2>/dev/null; then
    echo "ERROR: installation timed out"
    exit 1
fi

echo "==> Waiting for installer QEMU to exit"

while kill -0 "$QEMU_PID" 2>/dev/null; do
    sleep 1
done

wait "$QEMU_PID" || true

QEMU_PID=""

echo "==> Installer VM has stopped"

echo "==> Booting installed system"

sudo qemu-system-x86_64 \
    -machine q35,accel=kvm:tcg \
    -cpu max \
    -m "$RAM_MB" \
    -smp "$CPUS" \
    -drive "file=${DISK},if=virtio,format=qcow2" \
    -nic "user,model=virtio-net-pci" \
    -serial "file:${QEMU_LOG}" \
    -display none \
    -no-reboot \
    > "$QEMU_STDOUT_LOG" 2>&1 &

QEMU_PID=$!

echo "==> Waiting for installed system smoke test"

deadline=$((SECONDS + TIMEOUT_SECONDS))

while (( SECONDS < deadline )); do
    if grep -q "BUTRELINUX_SMOKE_PASS" "$QEMU_LOG" 2>/dev/null; then
        echo
        echo "======================================"
        echo "butrelinux smoke test PASSED"
        echo "======================================"

        exit 0
    fi

    if grep -q "BUTRELINUX_SMOKE_FAIL" "$QEMU_LOG" 2>/dev/null; then
        echo
        echo "======================================"
        echo "butrelinux smoke test FAILED"
        echo "======================================"

        exit 1
    fi

    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        echo
        echo "ERROR: installed-system QEMU exited before reporting a smoke result"
        exit 1
    fi

    sleep 5
done

echo
echo "ERROR: installed-system smoke test timed out"

exit 1
