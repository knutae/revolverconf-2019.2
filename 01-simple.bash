#!/bin/bash -e
set -x
mkdir -p gen obj bin
./embed-shader.py > gen/shaders.h

CFLAGS="-Wall -Werror -Os"
CFLAGS="$CFLAGS $(pkg-config --cflags gtk+-3.0)"
LIBS="-lGL $(pkg-config --libs gtk+-3.0)"

# debug version
cc $CFLAGS -DDEBUG -c solskogen.c -o obj/solskogen-debug.o
cc obj/solskogen-debug.o $LIBS -o bin/solskogen-debug

# release version
cc $CFLAGS -DNDEBUG -c solskogen.c -o obj/solskogen-release.o
cc obj/solskogen-release.o $LIBS -o bin/solskogen-release

set +x
stat --printf="Debug: %s bytes.\n" bin/solskogen-debug
stat --printf="Release: %s bytes.\n" bin/solskogen-release
