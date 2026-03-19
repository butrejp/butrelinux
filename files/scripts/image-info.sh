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
  "image-name": "$IMAGE_NAME",
  "image-vendor": "$IMAGE_VENDOR",
  "image-tag": "$IMAGE_TAG"
}
EOF

# Edit /usr/lib/os-release using sed
# We use "|" as a delimiter in sed to avoid issues with "/" in URLs
sed -i "s|^VARIANT_ID=.*|VARIANT_ID=gdx|" /usr/lib/os-release
sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"$IMAGE_PRETTY_NAME (Bluefin GDX LTS)\"|" /usr/lib/os-release
sed -i "s|^NAME=.*|NAME=\"$IMAGE_PRETTY_NAME\"|" /usr/lib/os-release
sed -i "s|^ID=.*|ID=$IMAGE_NAME|" /usr/lib/os-release
sed -i "s|^ID_LIKE=.*|ID_LIKE=\"$IMAGE_LIKE\"|" /usr/lib/os-release
sed -i "s|^HOME_URL=.*|HOME_URL=\"$HOME_URL\"|" /usr/lib/os-release
sed -i "s|^SUPPORT_URL=.*|SUPPORT_URL=\"$SUPPORT_URL\"|" /usr/lib/os-release
sed -i "s|^LOGO=.*|LOGO=\"kde-logo-icon\"|" /usr/lib/os-release
sed -i "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"$IMAGE_NAME\"|" /usr/lib/os-release

# Remove specific Red Hat/CentOS bugzilla lines to keep it clean
sed -i "/^REDHAT_BUGZILLA_PRODUCT=/d; /^REDHAT_BUGZILLA_PRODUCT_VERSION=/d; /^REDHAT_SUPPORT_PRODUCT=/d; /^REDHAT_SUPPORT_PRODUCT_VERSION=/d" /usr/lib/os-release
