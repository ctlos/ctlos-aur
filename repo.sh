#!/usr/bin/env bash
# @Author: Alex Creio <mailcreio@gmail.com>
# @Date:   14.05.2022 20:23
# @Last Modified by:   creio
# @Last Modified time: 17.06.2022 18:01

if [[ $EUID == 0 ]]; then
  echo "no root" && exit
fi

## deps: repoctl aurutils clean-chroot-manager
if [[ ! $(command -v repoctl) && ! $(command -v aur) && ! $(command -v ccm) ]]; then
  echo "ERROR, install: yay -S repoctl aurutils clean-chroot-manager" && exit
fi

sh_name=$(basename "$0")
command=${1:-}
arg1=${2:-}

repo_name=ctlos-aur
src_dir=/media/files/github/ctlos/ctlos-aur
repo_dir=$src_dir/x86_64

[[ -s $src_dir/.env ]] && . $src_dir/.env

makepkg_conf=/media/files/github/ctlos/ctlos-aur/conf/makepkg.conf
pacman_conf=/media/files/github/ctlos/ctlos-aur/conf/pacman.conf
ccm_conf=/media/files/github/ctlos/ctlos-aur/conf/clean-chroot-manager.conf

_help() {
  cat << LOL

- init: work user && config
    ./$sh_name init

===========  Usage  ===========

- add: build aur packages & dependencies, add $repo_name
    ./$sh_name add aurutils

- rm: remove packages $repo_name
    ./$sh_name rm aurutils

- addpkg: add package $repo_name
    ./$sh_name addpkg /path/to/aurutils-2.3.1-1-any.pkg.tar.zst

- upgrade: upgrade $repo_name
    ./$sh_name upgrade

- deploy: deploy $repo_name
    ./$sh_name deploy

- list: list $repo_name pkg
    ./$sh_name list

- status: systemd $repo_name
    ./$sh_name status

- up db: $repo_name
    ./$sh_name db

- uninstall: $repo_name
    ./$sh_name uninstall

LOL
}

_ccm_conf() {
  if [[ -f $HOME/.config/clean-chroot-manager.conf ]]; then
    mv -f $HOME/.config/clean-chroot-manager.{conf,conf.bak}
    cp $src_dir/conf/clean-chroot-manager.conf $HOME/.config/clean-chroot-manager.conf
  fi
}

_init() {
  user="${SUDO_USER:-$USER}"
  echo "$user" | tee $src_dir/auruser >/dev/null;

  ## init repo: ~/.config/repoctl/config.toml
  if [ -f "$repo_dir/$repo_name.db.tar.gz" ]; then
    repoctl conf new $repo_dir/$repo_name.db.tar.gz
  else
    repoctl reset
  fi

  if [[ ! $(systemctl --user list-unit-files | grep upgrade-aur >/dev/null) ]]; then
    echo -e "Adding & enabling systemd timer \n" >&2
    service_dir=$HOME/.config/systemd/user
    [ ! -d $service_dir ] && mkdir -p $service_dir
    cp -r $src_dir/service/upgrade-aur{.service,.timer} $service_dir
    systemctl --user daemon-reload
    systemctl --user enable --now upgrade-aur.timer
  fi

  if test -t 1; then
    echo
    read -p "Add [$repo_name] >> /etc/pacman.conf ? [yN] " -n1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo -e "\\n["$repo_name"]\\nSigLevel = Optional TrustAll\\nServer = file://$repo_dir" | sudo tee /etc/pacman.conf
    fi
  fi
  echo
  if test -t 1; then
    read -p "Add $user ALL=(ALL:ALL) NOPASSWD >> /etc/sudoers.d/10_$repo_name ? [yN] " -n1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo -e "\\n$user ALL=(ALL:ALL) NOPASSWD:SETENV: /usr/bin/makechrootpkg" | sudo tee /etc/sudoers.d/10_$repo_name
      echo "$user ALL=(ALL:ALL) NOPASSWD: /usr/bin/mkarchroot" | sudo tee -a /etc/sudoers.d/10_$repo_name
      echo "$user ALL=(ALL:ALL) NOPASSWD: /usr/bin/arch-nspawn" | sudo tee -a /etc/sudoers.d/10_$repo_name
      echo "$user ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacsync $repo_name" | sudo tee -a /etc/sudoers.d/10_$repo_name
      echo "$user ALL=(ALL:ALL) NOPASSWD: /usr/bin/ccm" | sudo tee -a /etc/sudoers.d/10_$repo_name
    fi
  fi
}

post_repo() {
  sudo pacsync $repo_name >/dev/null;
}

_repo_sync() {
  old_dir=$PWD
  cd $repo_dir
  repo-add -n -R -q $repo_name.db.tar.zst *.pkg.tar.zst
  rm -rf $repo_dir/$repo_name.{db,files}
  cp -f $repo_dir/$repo_name.db.tar.zst $repo_name.db
  cp -f $repo_dir/$repo_name.files.tar.zst $repo_name.files
  cd $old_dir
  post_repo
}

list_pkg() {
  pacman -Sl $repo_name | awk '{print $2}' | tee $repo_dir/pkglist.txt >/dev/null;
  cp -r $repo_dir/pkglist.txt $src_dir/pkglist.txt
}

if [ "$command" == "add" ] && [ -n "$arg1" ]; then
  cd $src_dir/build
  ### Down src list: repoctl down -r $(cat $src_dir/pkglist.txt)
  repoctl down -r "${@:2}" || exit
  _ccm_conf
  for pkg in "${@:2}"; do
    (
      cd $pkg
      sudo ccm S
      cd ..
      rm -rf $pkg
    )
  done
  cd $src_dir
  post_repo
  list_pkg
  echo -e "./$sh_name install: sudo pacman -Syy "${*:2}"" >&2

elif [ "$command" == "addpkg" ] && [ -n "$arg1" ]; then
  repoctl add "${@:2}"
  post_repo
  list_pkg
  echo -e "./$sh_name install: sudo pacman -Syy "${*:2}"" >&2

elif [ "$command" == "rm" ] && [ -n "$arg1" ]; then
  repoctl remove "${@:2}"
  post_repo
  list_pkg

elif [ "$command" == "upgrade" ]; then
  ## Clean aurutils cache
  aurutils_cache=/home/$(cat $src_dir/auruser)/.cache/aurutils/sync/
  if [ -d "$aurutils_cache" ]; then
    rm -rf "$aurutils_cache"
  fi

  aur_outdated=($(aur repo --database=$repo_name --list | aur vercmp | awk '{print $1}'))

  readonly AURVCS=${AURVCS:-.*-(cvs|svn|git|hg|bzr|darcs)$}

  vcs_pkgs=$(aur repo --database=$repo_name --list | cut -f1 | grep -E "$AURVCS" || true)
  if [ -n "$vcs_pkgs" ]; then
    echo "Checking $(echo "$vcs_pkgs" | wc -l) VCS packages matching "$AURVCS" for updates..." >&2
    #### init vcs sync cache (aurutils v3 args with ||-fallback to v2 args)
    aur sync $vcs_pkgs \
      --no-ver-argv --no-view --no-build --database=$repo_name >/dev/null 2>&1 \
    || aur sync $vcs_pkgs \
      --no-ver-shallow --print --database=$repo_name >/dev/null 2>&1

    mapfile -t git_outdated < <($src_dir/aur-vercmp-devel --database=$repo_name | awk '{print $1}')
    if [ "${#git_outdated[@]}" -gt 0 ]; then
      aur_outdated+=("${git_outdated[@]}")
    fi
  fi
  echo 'asd'
  echo ${#aur_outdated[@]}

  if [ ${#aur_outdated[@]} -gt 0 ]; then
    repoctl rm "${aur_outdated[@]}"

    cd $src_dir/build
    repoctl down -r "${aur_outdated[@]}"
    _ccm_conf
    for pkg in "${aur_outdated[@]}"; do
      (
        cd $pkg
        sudo ccm S
        cd ..
        rm -rf $pkg
      )
    done
    cd $src_dir
    echo " ./$sh_name: upgrade Repo Done!" >&2
  else
    echo " ./$sh_name: None upgrade!" >&2
  fi
  post_repo
  paccache -rk1 -c $repo_dir

  pacman -Sl $repo_name | awk '{print $2}' | tee $repo_dir/pkglist.txt >/dev/null;
  DIFF_RES=$(diff --old-line-format='%L' --unchanged-line-format='' $repo_dir/pkglist.txt $src_dir/pkglist.txt)
  if [ $DIFF_RES ]; then
    ### send to telegram error
    if [ -n "$TOKEN_TG" ]; then
      ALERT="Error diff pkgs $repo_name >>>%0A $DIFF_RES"
      echo "$ALERT"
      curl -s -X POST https://api.telegram.org/bot$TOKEN_TG/sendMessage \
        -d text="$ALERT" \
        -d chat_id=$CHAT_ID_TG
    fi
    exit 1
  else
    cp -r $repo_dir/pkglist.txt $src_dir/pkglist.txt
  fi

  ### deploy
  if [ ${#aur_outdated[@]} -gt 0 ]; then
    echo " ./$sh_name: Deploy run" >&2
    $src_dir/deploy.sh >/dev/null 2>&1
  fi
  ### send to telegram Update
  if [ ${#aur_outdated[@]} -gt 0 ] && [ -n "$TOKEN_TG" ]; then
    ALERT="Update, new ver pkgs $repo_name >>>%0A ${aur_outdated[@]}"
    echo "$ALERT"
    curl -s -X POST https://api.telegram.org/bot$TOKEN_TG/sendMessage \
      -d text="$ALERT" \
      -d chat_id=$CHAT_ID_TG
  fi

elif [ "$command" == "status" ]; then
  echo_status() {
    echo "Timers: systemctl --user list-timers"
    list_timers=$(systemctl --user list-timers -a)
    echo "  $(echo "$list_timers" | head -n1 | cut -c1-"$COLUMNS")"
    echo "$list_timers" \
     | grep -E 'aur' \
     | sed 's/^/  /' \
     | cut -c1-"$COLUMNS"
    echo
    echo "Recent logs: journalctl --user -eu upgrade-aur --since '1.5 hours ago'"
    journalctl --user -eu upgrade-aur --since '1.5 hours ago' \
     | sed 's/^/  /' \
     | cut -c1-"$COLUMNS"
    echo
    echo "Log warnings: journalctl --user -eu upgrade-aur --since '1 week ago' | grep -v 'Skipping all source file integrity' | grep -E 'ERROR|WARNING' -A5 -B5"
    log_warns=$(
      journalctl --user -eu upgrade-aur --since '1 week ago' \
       | grep -v 'Skipping all source file integrity' \
       | grep -E 'ERROR|WARNING' -A5 -B5 --color=always \
       | sed 's/^/  /'
    )
    if [ -n "$log_warns" ]; then
      echo "$log_warns" | cut -c1-"$COLUMNS"
    else
      echo 'None'
    fi
  }
  sudo pacsync $repo_name >/dev/null;
  cd $src_dir
  git status
  echo
  echo_status | less -RF

elif [ "$command" == "list" ]; then
  pacman -Sl $repo_name --color=always | sed 's/^/  /'
  echo -e "\n  $repo_name "$(pacman -Sql $repo_name | wc -l)" packages: pacman -Sl $repo_name"

elif [ "$command" == "deploy" ]; then
  $src_dir/deploy.sh

elif [ "$command" == "init" ]; then
  _init

elif [ "$command" == "db" ]; then
  _repo_sync

elif [ "$command" == "uninstall" ]; then
  echo "./$sh_name: disable systemd timer" >&2
  systemctl --user disable --now upgrade-aur.timer || true
  systemctl --user disable upgrade-aur.service || true

  echo "./$sh_name: Clean $repo_dir" >&2
  rm -rf $repo_dir/* 2>/dev/null || true

  echo "./$sh_name: Removing $repo_name /etc/pacman.conf" >&2
  sudo sed -i "/\[$repo_name\]/,+2d" /etc/pacman.conf

  echo "./$sh_name: Removing ${SUDO_USER:-$USER} ALL = NOPASSWD /etc/sudoers.d/10_$repo_name" >&2
  sudo rm /etc/sudoers.d/10_$repo_name

else
  _help
fi
