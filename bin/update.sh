#! /bin/bash
temp_dir=$(mktemp -d)
cd "${0%/*}" >/dev/null 2>&1 || :
cd ../
dir=`pwd`

\cp -rf $dir/log/ "$temp_dir"
\cp -f $dir/config.inc "$temp_dir"
echo "Backup $dir"

git fetch origin
git reset --hard origin/master

\cp -rf "$temp_dir"/log/* $dir/log/
\cp -f  "$temp_dir"/config.inc $dir/
echo "Restore $temp_dir"

echo "Crontab reinstall"
