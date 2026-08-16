#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MIME_FOLDER=${HOME}/.local/share/mime
cd $SCRIPT_DIR

if [ ! -d "${MIME_FOLDER}/packages" ]; then
  mkdir "${MIME_FOLDER}/packages"
fi

if [ ! -d "/tmp/applications/" ]; then
  mkdir "/tmp/applications/"
fi

echo Copy Packages
cp -v packages/*.xml ${MIME_FOLDER}/packages/
chmod 770 bin/*.sh
chmod 770 bin/pack_scripts/*.sh
echo

echo Copy Bin
cp -vr bin/* ${HOME}/bin/
echo 

echo Copy Applications to tmp
rsync -av --delete applications/ /tmp/applications/
echo 

ls /tmp/applications/*.desktop | while read file; do 
    echo "FILE NAME: ${file}";
    sed -i "s|\${HOME}|${HOME}|g" "${file}"
    cat "${file}"
    echo 
done
echo Copy Applications from tmp
cp -rv /tmp/applications/* ${HOME}/.local/share/applications/

update-mime-database ${HOME}/.local/share/mime
update-desktop-database ${HOME}/.local/share/applications/
