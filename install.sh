#!/usr/bin/env bash

git fetch -v
git pull
./install_all.sh
"${HOME}/bin/github_check.sh"
