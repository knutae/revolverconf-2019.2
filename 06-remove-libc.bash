#!/bin/bash -e
mkdir -p gen obj bin

SHADER_MINIFIER=Shader_Minifier/shader_minifier.exe
if [ ! -e $SHADER_MINIFIER ]; then
    pushd Shader_Minifier
    TERM=xterm ./compile.bash
    popd
fi
set -x

SSTRIP=ELFkickers/bin/sstrip
if [ ! -e $SSTRIP ]; then
    pushd ELFkickers
    make
    popd
fi

mono $SHADER_MINIFIER --preserve-externals fshader.glsl -o gen/shaders.h

CFLAGS="-fomit-frame-pointer -fno-stack-protector -Wall -Werror -Os"
CFLAGS="$CFLAGS $(pkg-config --cflags gtk+-3.0)"
LIBS="-lGL $(pkg-config --libs gtk+-3.0)"

# release version
cc $CFLAGS -DNDEBUG -c 06-solskogen.c -o obj/solskogen-release.o
/usr/bin/ld \
    -z norelro \
    -z noseparate-code \
    --orphan-handling=discard \
    --as-needed \
    --gc-sections \
    --hash-style=gnu \
    --no-eh-frame-hdr \
    --no-ld-generated-unwind-info \
    -m elf_x86_64 \
    -dynamic-linker \
    /lib64/ld-linux-x86-64.so.2 \
    -o bin/solskogen-release \
    obj/solskogen-release.o \
    obj/minlibc.o \
    -lGL \
    -lgtk-3 \
    -lgobject-2.0
$SSTRIP bin/solskogen-release

XZ="xz -c -9e --format=lzma --lzma1=preset=9,lc=0,lp=0,pb=0"
cat bin/solskogen-release | $XZ > bin/solskogen-release.xz
cat uncompress-header bin/solskogen-release.xz > bin/solskogen
chmod a+x bin/solskogen

set +x
stat --printf="Uncompressed: %s bytes.\n" bin/solskogen-release
stat --printf="Final: %s bytes.\n" bin/solskogen
