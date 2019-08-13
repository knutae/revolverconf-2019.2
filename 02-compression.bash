#!/bin/bash -e
set -x
mkdir -p gen obj bin
./embed-shader.py > gen/shaders.h

CFLAGS="-Wall -Werror -Os"
CFLAGS="$CFLAGS $(pkg-config --cflags gtk+-3.0)"
LIBS="-lGL $(pkg-config --libs gtk+-3.0)"

# release version
cc $CFLAGS -DNDEBUG -c solskogen.c -o obj/solskogen-release.o
cc obj/solskogen-release.o $LIBS -o bin/solskogen-release

XZ="xz -c -9e --format=lzma --lzma1=preset=9,lc=0,lp=0,pb=0"
cat bin/solskogen-release | $XZ > bin/solskogen-release.xz
cat uncompress-header bin/solskogen-release.xz > bin/solskogen
chmod a+x bin/solskogen

set +x
stat --printf="Uncompressed: %s bytes.\n" bin/solskogen-release
stat --printf="Final: %s bytes.\n" bin/solskogen
