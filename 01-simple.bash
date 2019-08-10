#!/bin/bash -e
set -x
mkdir -p gen obj bin
./embed-shader.py > gen/shaders.h

CFLAGS="-fomit-frame-pointer -fno-stack-protector -Wall -Werror -Os"
CFLAGS="$CFLAGS $(pkg-config --cflags gtk+-3.0)"
LIBS="-lGL $(pkg-config --libs gtk+-3.0)"

# debug version
gcc $CFLAGS -DDEBUG -c solskogen.c -o obj/solskogen-debug.o
gcc obj/solskogen-debug.o $LIBS -o bin/solskogen-debug

# release version
gcc $CFLAGS -DNDEBUG -c solskogen.c -o obj/solskogen-release.o
gcc obj/solskogen-release.o $LIBS -o bin/solskogen-release

set +x
stat --printf="debug: %s bytes\n" bin/solskogen-debug
stat --printf="release: %s bytes\n" bin/solskogen-release
