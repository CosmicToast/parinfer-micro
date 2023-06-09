#!/bin/sh
[ $# -ge 1 ] || set -- HEAD
git archive -o tmp.zip "$1"
# NOTE: submodule is taken from the working tree
bsdtar -caf "$1".zip @tmp.zip parinfer-lua/
rm tmp.zip
