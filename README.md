WIP.  don't try to use it yet.  
you must rebase from bluefin-gdx or bluefin-lts, not any fedora version  
there will be no support on my end.  you're on your own if you install this.  the bluebuild guys or the bluefin guys might be able to help you, but don't count on it.

# butrelinux &nbsp; [![bluebuild build badge](https://github.com/butrejp/butrelinux/actions/workflows/build.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build.yml)

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing Bluefin installation to the latest build:
- First, clean up all the default gnome junk
  ```
  flatpak uninstall --all # use with caution.  not all the flatpaks you might actually want are set up in the recipe yet
  ```

- Rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/butrejp/butrelinux:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/butrejp/butrelinux:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/butrejp/butrelinux
```
