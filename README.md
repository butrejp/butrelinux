![screenshot of desktop and fastfetch](https://repository-images.githubusercontent.com/1181869151/65e42a48-070b-4285-ab3d-896a793c9f78)

[![bluebuild build badge](https://github.com/butrejp/butrelinux/actions/workflows/build.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build.yml) [![Build Butrelinux ISO](https://github.com/butrejp/butrelinux/actions/workflows/build_iso_unified.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/build_iso_unified.yml) [![Image smoke tests](https://github.com/butrejp/butrelinux/actions/workflows/smoke-test.yml/badge.svg)](https://github.com/butrejp/butrelinux/actions/workflows/smoke-test.yml)  
[![works on my machine badge](https://cdn.jsdelivr.net/gh/nikku/works-on-my-machine@v0.4.0/badge.svg)](https://github.com/nikku/works-on-my-machine) [![Download butrelinux](https://img.shields.io/sourceforge/dt/butrelinux.svg)](https://butrelinux.sourceforge.io/)
# butrelinux
a bluefin-lts variant for those who want EL10+KDE

local package layering is disabled by default.  you can change this with the command below, though the intended workflow is distrobox + flatpaks.
```bash
sudo givemethekeys unlock
```

<details>
    <summary>givemethekeys usage</summary> 

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
</details>

## installation  
ISO downloads available here:  
[![Download butrelinux](https://a.fsdn.com/con/app/sf-download-button)](https://butrelinux.sourceforge.io/)  
the ISO is the main installation path, rebase instructions are provided for convenience for existing bluefin lts users.  


<details>
    <summary>rebase instructions</summary> 

if you use the rebase instructions you must rebase from a centos stream derived image such as bluefin-lts, not any fedora version.  this image is based on centos stream 10, not fedora, and cross-rebasing will break things.  

> [!WARNING]  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

to rebase an existing EL10 based installation to the latest build:
#### 
```bash
# optionally clean up default flatpaks
flatpak uninstall --all
```
```bash
# switch to the signed image and reboot:
sudo bootc switch --enforce-container-sigpolicy ghcr.io/butrejp/butrelinux-< VARIANT >:latest --apply
```
after the system reboots:
```bash
# since skel can't touch existing users, optionally copy the default configs to your user profile
# or just make your own config.  I'm not your mom.
mkdir -p ~/.config && cp -r /etc/skel/.config/* ~/.config/
```
</details>


<details>
    <summary>verification</summary> 

these images are signed with sigstore's cosign. you can verify the signature by downloading the cosign.pub file from this repo and running the following command:  
```
cosign verify --key cosign.pub ghcr.io/butrejp/butrelinux-< VARIANT >
```
if you ever hit ASN.1 invalid signature failure during an upgrade it's because I rotated out the keys.  sorry.  it was probably dependabot's fault.  you can fetch the new keys with the following command
```
sudo curl -Lo /etc/pki/containers/butrelinux.pub https://raw.githubusercontent.com/butrejp/butrelinux/refs/heads/main/cosign.pub
```
this shouldn't ever be an issue, but it's worth documenting.
</details>

<details>
    <summary>AI disclosure</summary> 

AI is used in planning stages for some scripts (enable-extras, custom-kernel.sh) and for current placeholder documentation.  It is also frequently used for commit messages.  
AI does not write code used in this repository, however being based on Bluefin, CentOS Stream 10, and ultimately the Linux kernel, plenty of AI code exists upstream.  
If that's enough to make you consider not using this distribution, I suggest trying 9Front instead.  

</details>

## future migration

I'll be slowly migrating butrelinux over to an organization at https://github.com/butrelinux in the coming weeks, and more importantly dropping bluefin as my upstream, going straight to centos stream 10.  since gdx is gone using bluefin as my upstream isn't really getting me anything at this stage other than tech debt imposed by someone else's AI agent that I've had to work around.  the new upstream will come on the new organization, not under this repository.  if I keep bluebuild as my tooling I'm probably gonna fork it like silverblue does, as I've got enough custom modules to justify it at this stage.  

I also plan to introduce/reintroduce some variants, most notably LTS (bluefin turned their lts variant into regular ass bluefin, the fuckers), kernel-ml (I don't understand why they're importing a fc44 package for this.  fresh kernels for el10 just exist), and hyperscale (this is the nearest to what bluefin is doing with their HWE branch.), and of course keeping the LTO variant, with nvidia versions for all four.  

new tags will look something like ```ghcr.io/butrelinux/lts-nvidia:latest``` or ```ghcr.io/butrelinux/ml:latest```.  it should be pretty intuitive.  
