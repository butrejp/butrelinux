# migration
we've migrated to https://github.com/butrelinux/butrelinux  

I'm turning off builds here and archiving this repository because bluefin's current development status does not make sense.  use the new version based directly on centos
in short, bluefin reorganized in like june, and is now reorganizing again, but the docs aren't representative of anything current, and lts is seemingly in flux.  I'm not going to chase their bullshit for an old image.

for existing users:
```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/butrelinux/lts:latest
```

I won't be forcing this switch as ZFS is still broken on kernel 7.3.  if you need zfs, good luck.
