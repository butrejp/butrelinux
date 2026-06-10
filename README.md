WIP (perpetual). this is more or less feature-complete with no blocking issues but there are a handful of oddities that are mostly upstream issues on epel.  this is meant to be a personal build but I figure I can't be the only person who wants kde and prefers lts release cycles.  

if you use the rebase instructions you must rebase from bluefin-gdx or bluefin-lts, not any fedora version.  this image is based on centos stream 10, not fedora, and cross-rebasing will break things.
there will be no support on my end.  you're on your own if you install this.  the bluebuild guys or the bluefin guys might be able to help you, but don't count on it.

![screenshot of desktop and fastfetch](https://repository-images.githubusercontent.com/1181869151/6c7b9e65-ee0f-4e1d-8f30-1460aa6408ca)

# butrelinux &nbsp; [![bluebuild build badge](https://github.com/butrejp/butrelinux/actions/workflows/build.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build.yml) [![works on my machine badge](https://cdn.jsdelivr.net/gh/nikku/works-on-my-machine@v0.4.0/badge.svg)](https://github.com/nikku/works-on-my-machine) [![Download butrelinux](https://img.shields.io/sourceforge/dt/butrelinux.svg)](https://sourceforge.net/projects/butrelinux/files/latest/download)  

a bluefin-gdx:lts variant for those who want EL10+KDE and Nvidia/hybrid graphics support

local package layering is disabled by default.  you can change this with the command below, though the intended workflow is distrobox + flatpaks.
```bash
sudo sed -i 's/^LockLayering=true/LockLayering=false/' /etc/rpm-ostreed.conf && sudo rpm-ostree reload
```

the ISO is the main installation path, rebase instructions are provided for convenience for existing bluefin lts users.  ISO images are frozen on the unverified registry and do not receive updates until you rebase to the signed ostree image with  
```bash
rpm-ostree rebase --reboot ostree-image-signed:docker://ghcr.io/butrejp/butrelinux:latest
```

## installation  
ISO downloads available here:  
[![Download butrelinux](https://a.fsdn.com/con/app/sf-download-button)](https://sourceforge.net/projects/butrelinux/files/latest/download)  

## rebase instructions 

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

to rebase an existing bluefin lts or gdx installation to the latest build:

```bash
# clean up default bluefin flatpaks
flatpak uninstall --all
# rebase to the unsigned image, to get the proper signing keys and policies installed:
rpm-ostree rebase --reboot ostree-unverified-registry:ghcr.io/butrejp/butrelinux:latest
```
after the system reboots:
```bash
# since skel can't touch existing users, optionally copy the default configs to your user profile
# or just make your own config.  I'm not your mom.
mkdir -p ~/.config && cp -r /etc/skel/.config/* ~/.config/
# rebase to the signed image to complete the installation
rpm-ostree rebase --reboot ostree-image-signed:docker://ghcr.io/butrejp/butrelinux:latest
```

## verification

these images are signed with sigstore's cosign. you can verify the signature by downloading the cosign.pub file from this repo and running the following command:  
```
cosign verify --key cosign.pub ghcr.io/butrejp/butrelinux
```
