![screenshot of desktop and fastfetch](https://repository-images.githubusercontent.com/1181869151/6c7b9e65-ee0f-4e1d-8f30-1460aa6408ca)

# butrelinux &nbsp; [![bluebuild build badge](https://github.com/butrejp/butrelinux/actions/workflows/build.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build.yml) [![works on my machine badge](https://cdn.jsdelivr.net/gh/nikku/works-on-my-machine@v0.4.0/badge.svg)](https://github.com/nikku/works-on-my-machine) [![Download butrelinux](https://img.shields.io/sourceforge/dt/butrelinux.svg)](https://butrelinux.sourceforge.io/)  

a bluefin-lts variant for those who want EL10+KDE

local package layering is disabled by default.  you can change this with the command below, though the intended workflow is distrobox + flatpaks.
```bash
sudo givemethekeys unlock
```
```
Usage: givemethekeys <command> [options]

Commands:
  unlock    Allow rpm-ostree package layering
  lock      Restore default layering lock
  status    Show current layering lock status
  help      Show this help

Options:
  -y, --yes    Skip confirmation prompt (unlock only)
```
the ISO is the main installation path, rebase instructions are provided for convenience for existing bluefin lts users.  

## installation  
ISO downloads available here:  
[![Download butrelinux](https://a.fsdn.com/con/app/sf-download-button)](https://butrelinux.sourceforge.io/)  

### rebase instructions 

if you use the rebase instructions you must rebase from a centos stream derived image such as bluefin-lts, not any fedora version.  this image is based on centos stream 10, not fedora, and cross-rebasing will break things.  

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

to rebase an existing EL10 based installation to the latest build:
#### amd/intel
```bash
# optionally clean up default flatpaks
flatpak uninstall --all
# rebase to the unsigned image, to get the proper signing keys and policies installed:
rpm-ostree rebase --reboot ostree-unverified-registry:ghcr.io/butrejp/butrelinux-hwe:latest
```
after the system reboots:
```bash
# since skel can't touch existing users, optionally copy the default configs to your user profile
# or just make your own config.  I'm not your mom.
mkdir -p ~/.config && cp -r /etc/skel/.config/* ~/.config/
# rebase to the signed image to complete the installation
rpm-ostree rebase --reboot ostree-image-signed:docker://ghcr.io/butrejp/butrelinux-hwe:latest
```
#### nvidia
```bash
flatpak uninstall --all
rpm-ostree rebase --reboot ostree-unverified-registry:ghcr.io/butrejp/butrelinux-nvidia:latest
```
after the system reboots:
```bash
mkdir -p ~/.config && cp -r /etc/skel/.config/* ~/.config/
rpm-ostree rebase --reboot ostree-image-signed:docker://ghcr.io/butrejp/butrelinux-nvidia:latest
```
alternatively, there's butrelinux-lts or just butrelinux (legacy GDX image).  if you're not sure whether you should install these two, you probably shouldn't.  

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

20260714 UPDATE  
ISOs are out.  have at it.  
also got a unified iso in the works but matrix builds are easy so split installers came first  

20260715 UPDATE  
unified iso was easier than I thought.  they've been available since yesterday.  still tweaking, so expect fresh releases to come regularly, but installer behavior shouldn't change much.  once I get it all sorted out it'll be monthly builds pushed automatically

### new experimental branch
20260802  
this isn't really for users (though it might be worth checking out in a VM), but you can start to see some ideas of where I'm taking this.  for example, I just crammed the cachyos lto kernel onto an el10 userspace.  I've also started building a module to inject fedora packages in a more sane way than I had previously done (and abandoned for good reason).  
if a shakedown run clears then these things will make it into the standard images.  the ultimate goal is to hopefully make multilib happen on el10 and ship a gaming variant that doesn't rely on giving podman your gpu.  we'll see how that goes though, don't expect a miracle.    
