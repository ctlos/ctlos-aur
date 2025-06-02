# Ctlos aur

- devtools
- [aurutils](https://github.com/AladW/aurutils)
- [ccm](https://github.com/graysky2/clean-chroot-manager)
- [repoctl](https://github.com/cassava/repoctl)

```bash
yay -S repoctl aurutils clean-chroot-manager
```

Edit path.

```bash
# src sh
service/upgrade-aur.service

# edit src_dir && repo_name
repo.sh

diff --old-line-format='%L' --unchanged-line-format='' x86_64/pkglist.txt pkglist_old.txt
```

Help.

```bash
repo.sh
```

- [~/.config/clean-chroot-manager.conf](https://github.com/creio/dots/blob/master/.config/clean-chroot-manager.conf)

```bash
~/.config/repoctl/config.toml
```

[thanks aurto](https://github.com/alexheretic/aurto).
