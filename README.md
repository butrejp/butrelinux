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

### rebase instructions 

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

### verification

these images are signed with sigstore's cosign. you can verify the signature by downloading the cosign.pub file from this repo and running the following command:  
```
cosign verify --key cosign.pub ghcr.io/butrejp/butrelinux
```
if you ever hit ASN.1 invalid signature failure during an upgrade it's because I rotated out the keys.  sorry.  it was probably dependabot's fault.  you can fetch the new keys with the following command
```
sudo curl -Lo /etc/pki/containers/butrelinux.pub https://raw.githubusercontent.com/butrejp/butrelinux/refs/heads/main/cosign.pub
```

## news

### 20260608 release
20260608  
I think this can be considered the first true stable release.  I don't expect to shift things around too much at this stage.  
the only inclusion left that I don't really like is gearlever and I'm investigating alternatives but unfortunately that one gtk app happens to be the one that works the best.  maybe someday appimagelauncher will be the go to, but not until the next major release at earliest.

### distrowatch
20260610  
hey I've got a distrowatch page now.  no idea who submitted it but that's pretty cool.  
visibility wasn't really the intent, I just wanted something that fit my tastes that I didn't have to remove anything from, only needing to add to it depending on the deployment.  I suppose it's distributed, and that makes it a distro.

https://distrowatch.com/table.php?distribution=butrelinux

### experimental appimage management
20260613  
I'm leaving gearlever in place for now but you can probably pretend that it's not there from this point forward as I'm integrating zap (or at least attempting to) for appimage management.  we'll see how it goes.  if it's not too buggy then gearlever will be removed in the next ISO build  
edit: not going great, the database is full of bad links.  it still works fine if you point directly to a github source though.  I'll leave it in place for now, but might experiment with AM instead  
I also changed how tuned log permissions are handled.  should help maybe?  
20260616 UPDATE  
added soar.  left zap in place for now, but it'll be a regression on the next major release

### cosign keys updated
20260520  
run ```sudo curl -Lo /etc/pki/containers/butrelinux.pub https://raw.githubusercontent.com/butrejp/butrelinux/refs/heads/main/cosign.pub``` to get everything sorted again without having to reinstall  
a new iso will be published shortly (done)

### big reorganization
20260708  
https://docs.projectbluefin.io/blog/2026/07/02/organizational-migration-for-bluefin-lts-gdx/  
bluefin is reorganizing and the old bluefin-gdx is getting discontinued, meaning my previous upstream is getting discontinued.  the standard gdx:lts image is staying and will keep building if you want to keep using it, but all work is moving towards the new images, so the day butrelinux:latest stops building is the day it's done.  butrelinux-hwe and butrelinux-nvidia is the new hotness.  new isos will hopefully be built this week.  just bootc switch or rpm-ostree rebase in the mean time if you want to try it, but for now I recommend sticking with the old version, as new just isn't stable yet.  
also, I decided to use this as an opportunity to break out a standard installation and an nvidia installation.  have fun with that amd users
> [!WARNING]  
> [This is an alpha release](https://en.wikipedia.org/wiki/Software_release_life_cycle#Alpha).  when upstream stabilizes, I'll stabilize.
