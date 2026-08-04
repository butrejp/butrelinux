#!/usr/bin/env bash
set -ouex pipefail

IMAGE_VENDOR="butrejp"
IMAGE_NAME="butrelinux"
IMAGE_PRETTY_NAME="butrelinux"
IMAGE_TAG="latest"
IMAGE_LIKE="centos rhel fedora"

HOME_URL="https://github.com/butrejp/butrelinux"
SUPPORT_URL="https://github.com/butrejp/butrelinux/issues"

# Update the Image Info JSON (used by some uBlue update tools)
IMAGE_INFO="/usr/share/ublue-os/image-info.json"
mkdir -p /usr/share/ublue-os
cat >$IMAGE_INFO <<EOF
{
  "image-name": "$IMAGE_NAME-lts",
  "image-vendor": "$IMAGE_VENDOR",
  "image-tag": "$IMAGE_TAG",
  "image-ref": "ostree-image-signed:docker://ghcr.io/$IMAGE_VENDOR/$IMAGE_NAME-lts"
}
EOF

# Edit /usr/lib/os-release using sed
# We use "|" as a delimiter in sed to avoid issues with "/" in URLs
sed -i "s|^VARIANT_ID=.*|VARIANT_ID=lts|" /usr/lib/os-release
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"$IMAGE_PRETTY_NAME\"|" /usr/lib/os-release
sed -i "s|^NAME=.*|NAME=\"$IMAGE_PRETTY_NAME\"|" /usr/lib/os-release
sed -i "s|^ID=.*|ID=$IMAGE_NAME|" /usr/lib/os-release
sed -i "s|^ID_LIKE=.*|ID_LIKE=\"$IMAGE_LIKE\"|" /usr/lib/os-release
sed -i "s|^HOME_URL=.*|HOME_URL=\"$HOME_URL\"|" /usr/lib/os-release
sed -i "s|^SUPPORT_URL=.*|SUPPORT_URL=\"$SUPPORT_URL\"|" /usr/lib/os-release
sed -i "s|^LOGO=.*|LOGO=\"kde-logo-icon\"|" /usr/lib/os-release
sed -i "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"$IMAGE_NAME\"|" /usr/lib/os-release

sed -i "/^REDHAT_BUGZILLA_PRODUCT=/d; /^REDHAT_BUGZILLA_PRODUCT_VERSION=/d; /^REDHAT_SUPPORT_PRODUCT=/d; /^REDHAT_SUPPORT_PRODUCT_VERSION=/d" /usr/lib/os-release

# Extract the existing VERSION_ID to keep the CPE version dynamic
VERSION_ID=$(grep '^VERSION_ID=' /usr/lib/os-release | cut -d'"' -f2)

# Update CPE_NAME and remaining upstream vendor metadata
sed -i "s|^CPE_NAME=.*|CPE_NAME=\"cpe:2.3:o:butre:$IMAGE_NAME:${VERSION_ID}:*:*:*:*:*:*:*\"|" /usr/lib/os-release
sed -i "s|^VENDOR_NAME=.*|VENDOR_NAME=\"butre\"|" /usr/lib/os-release
sed -i "s|^VENDOR_URL=.*|VENDOR_URL=\"$HOME_URL\"|" /usr/lib/os-release
sed -i "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"$SUPPORT_URL\"|" /usr/lib/os-release
