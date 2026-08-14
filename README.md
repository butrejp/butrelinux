![screenshot of desktop and fastfetch](https://repository-images.githubusercontent.com/1181869151/6c7b9e65-ee0f-4e1d-8f30-1460aa6408ca)

[![bluebuild build badge](https://github.com/butrejp/butrelinux/actions/workflows/build.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build.yml) [![Build Butrelinux ISO](https://github.com/butrejp/butrelinux/actions/workflows/build_iso_unified.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build_iso_unified.yml) [![Image smoke tests](https://github.com/butrejp/butrelinux/actions/workflows/smoke-test.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/smoke-test.yml)  
[![works on my machine badge](https://cdn.jsdelivr.net/gh/nikku/works-on-my-machine@v0.4.0/badge.svg)](https://github.com/nikku/works-on-my-machine) [![Download butrelinux](https://img.shields.io/sourceforge/dt/butrelinux.svg)](https://butrelinux.sourceforge.io/)
# butrelinux
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
#### 
```bash
# optionally clean up default flatpaks
flatpak uninstall --all
# rebase to the unsigned image, to get the proper signing keys and policies installed:
sudo bootc switch --enforce-container-sigpolicy ghcr.io/butrejp/butrelinux-< VARIANT >:latest --apply
```
after the system reboots:
```bash
# since skel can't touch existing users, optionally copy the default configs to your user profile
# or just make your own config.  I'm not your mom.
mkdir -p ~/.config && cp -r /etc/skel/.config/* ~/.config/
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
