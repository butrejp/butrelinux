WIP. don't try to use it yet.
you must rebase from bluefin-gdx or bluefin-lts, not any fedora version.  this image is based on centos stream 10, not fedora, and cross-rebasing will break things.
there will be no support on my end.  you're on your own if you install this.  the bluebuild guys or the bluefin guys might be able to help you, but don't count on it.

# butrelinux &nbsp; [![bluebuild build badge](https://github.com/butrejp/butrelinux/actions/workflows/build.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build.yml)

a bluefin-gdx lts variant with kde plasma 6, for people who want an immutable centos base with nvidia support and a traditional desktop environment.

## what you get

- kde plasma 6 with wayland
- nvidia drivers and cuda support (inherited from gdx)
- flatpaks: firefox, steam, gear lever, bazaar, calculator
- core tools: fastfetch, micro, btop, nvtop
- distrobox-ready for your actual development environment

local package layering is disabled by default.  use ujust devmode or rpm-ostree install --enable-local-layering if you need it, though the intended workflow is distrobox + flatpaks.

## installation

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

to rebase an existing bluefin lts or gdx installation to the latest build:

first, clean up all the default gnome junk:
```bash
flatpak uninstall --all
```
rebase to the unsigned image, to get the proper signing keys and policies installed:
```bash
rpm-ostree rebase --reboot ostree-unverified-registry:ghcr.io/butrejp/butrelinux:latest
```
wait for the system to reboot, then rebase to the signed image, like so:
```bash
rpm-ostree rebase --reboot ostree-image-signed:docker://ghcr.io/butrejp/butrelinux:latest
```

the latest tag will automatically point to the latest build. that build will still always use the version specified in recipe.yml, so you won't get accidentally updated to the next major version.

## post-rebase setup

since /etc/skel can't touch existing users, copy my kde configuration defaults to your existing user:
```bash
mkdir -p ~/.config && cp -r /etc/skel/.config/* ~/.config/
```
or don't, I'm not your mom.  make whatever config you want
## verification

these images are signed with sigstore's cosign. you can verify the signature by downloading the cosign.pub file from this repo and running the following command:  
```
cosign verify --key cosign.pub ghcr.io/butrejp/butrelinux
```
