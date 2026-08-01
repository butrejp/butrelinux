# fedora-rpm BlueBuild module

Install Fedora RPM packages into images that are not running Fedora.

## Purpose

This module exists for bootc images based on distributions such as
CentOS Stream / Enterprise Linux where Fedora packages may be desirable.

Example use cases:

- consuming Fedora COPR projects
- testing Fedora-built utilities on EL-compatible systems
- adding packages that do not exist in the base distribution repositories

## Warning

This does not convert the image into Fedora.

Packages are installed into the existing image filesystem using dnf.
Compatibility depends on the package being compatible with the target
userspace.

Recommended targets:

- leaf applications
- self-contained utilities
- statically linked or commonly linked binaries

Use caution with:

- core system libraries
- systemd components
- SELinux policy packages
- kernel-related packages

## Example

```yaml
modules:
  - type: fedora-rpm
    releasever: "44"
    repos:
      - https://copr.fedorainfracloud.org/coprs/theblackdon/dcli-bootc/repo/fedora-44/theblackdon-dcli-bootc-fedora-44.repo
    install:
      - dcli-bootc
