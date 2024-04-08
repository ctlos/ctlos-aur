#!/usr/bin/env bash
# @Author: Alex Creio <mailcreio@gmail.com>
# @Date:   16.05.2022 23:31
# @Last Modified by:   creio
# @Last Modified time: 19.05.2022 09:45

repo_name=ctlos-aur
local_repo=/media/files/github/ctlos/ctlos-aur/x86_64
srht_repo=/media/files/srht/ctlos/ctlos-aur/x86_64
repo_osdn=creio@storage.osdn.net:/storage/groups/c/ct/ctlos/ctlos-aur/
repo_keybase=/run/user/1000/keybase/kbfs/public/cvc/ctlos-aur/

if [[ -d "$repo_keybase" ]]; then
  rsync -avrCLP --delete-excluded --delete --exclude={"build",".git*",".*ignore"} "$local_repo"/ "$repo_keybase"
fi
# rsync -avrCLP --delete-excluded --delete "$local_repo" "$repo_osdn"
echo "add pkg, rsync all repo"

git_up() {
  git add --all
  msg="$(date +%d.%m.%Y) Update"
  git commit -a -m "$msg"
  git push
}

cd $local_repo
## fix github symlink
rm $repo_name.{db,files}
cp -f $repo_name.db.tar.gz $repo_name.db
cp -f $repo_name.files.tar.gz $repo_name.files
cd ..
cp -rfv $local_repo $srht_repo
git_up
cd $srht_repo
git_up

echo -e "\033[0;32mDeploy repo Done\033[0m"
