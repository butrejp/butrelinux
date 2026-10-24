# migration
we've migrated to https://github.com/butrelinux/butrelinux  
existing users can stay on these builds if they want.  they'll keep building, I'll bump paths or whatever when necessary.  
ISOs are still over there in releases if you really want to get into this, and I've retained one on sourceforge for now.

instructions for rebasing to the new version can be found on the new repository.  I suggest cleaning up any state that you left first, but I'm not your mom.


LTO versions on this repository are not currently building.  if you need LTO, switch to ghcr.io/butrelinux/lto or ghcr.io/butrelinux/lto-nvidia.  if you need zfs, switch to ghcr.io/butrejp/butrelinux-hwe or ghcr.io/butrejp/butrelinux-hwe-nvidia.  if you need both, stay on your current tag  
the reason they are not building is because ZFS is currently incompatible with 7.3 due to a bool that was removed in the kernel.  if someone asks, I can either remove zfs from LTO or pin the kernel to 7.2.12 until it builds again, but I strongly suggest moving on to the new butrelinux project.  
