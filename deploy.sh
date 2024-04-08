#!/usr/bin/env bash
# @Author: Alex Creio <mailcreio@gmail.com>
# @Date:   16.05.2022 23:31
# @Last Modified by:   creio
# @Last Modified time: 19.05.2022 09:45

repo_name=ctlos-aur
arch=x86_64
local_repo=/media/files/github/ctlos/ctlos-aur/
srht_repo=/media/files/srht/ctlos/ctlos-aur/
repo_osdn=creio@storage.osdn.net:/storage/groups/c/ct/ctlos/ctlos-aur/
repo_keybase=/run/user/1000/keybase/kbfs/public/cvc/ctlos-aur/

if [[ -d "$repo_keybase" ]]; then
  rsync -avrCLP --delete-excluded --delete --exclude={"build",".git*",".*ignore"} "$local_repo/$arch/" "$repo_keybase"
fi
# rsync -avrCLP --delete-excluded --delete "$local_repo" "$repo_osdn"
echo "add pkg, rsync all repo"

git_up() {
  git add --all
  msg="$(date +%d.%m.%Y) Update"
  git commit -a -m "$msg"
  git push
}

cd $local_repo/$arch
## fix github symlink
rm $repo_name.{db,files}
cp -f $repo_name.db.tar.gz $repo_name.db
cp -f $repo_name.files.tar.gz $repo_name.files
cd ..
git_up

if [[ -d "$srht_repo" ]]; then
  rsync -avrCLP --delete --exclude={"build",".git*"} "$local_repo" "$srht_repo"
  cd $srht_repo
  git_up
fi

echo -e "\033[0;32mDeploy repo Done\033[0m"
