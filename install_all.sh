#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
MIME_FOLDER="${HOME}/.local/share/mime"
cd "$SCRIPT_DIR" || exit

if [ ! -d "${MIME_FOLDER}/packages" ]; then
    mkdir "${MIME_FOLDER}/packages"
fi

if [ ! -d "/tmp/applications/" ]; then
    mkdir "/tmp/applications/"
fi

if [ ! -d "${HOME}/bin/" ]; then
    mkdir "${HOME}/bin/"
fi

echo Copy Packages
rsync -av packages/ "${MIME_FOLDER}/packages/"
chmod 770 bin/*.sh
chmod 770 bin/pack_scripts/*.sh
echo

echo Copy Bin
rsync -av bin/ "${HOME}/bin/"
echo

echo Copy Applications to tmp
rsync -av --delete applications/ /tmp/applications/
echo

find /tmp/applications/*.desktop | while read -r file; do
    echo "FILE NAME: ${file}"
    sed -i "s|\${HOME}|${HOME}|g" "${file}"
    cat "${file}"
    echo
done

echo Copy Applications from tmp
rsync -av /tmp/applications/ "${HOME}/.local/share/applications/"

echo
echo Copy icons
rsync -av .icons/ "${HOME}/AppImages/.icons/"
echo

update-mime-database "${HOME}/.local/share/mime"
update-desktop-database "${HOME}/.local/share/applications/"
