# Sizecoding on Linux

Sizecodeing is the art of creating cool programs that are small. Why? Not because it is easy, but because it is hard.

In the demoscene, 4k and 64k intros are common competitions.

## Baseline

Demo: Solskogen 2019 entry

```bash
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
```

26088 bytes.

## Executable compression

```bash
gzexe bin/solskogen-release
```

7903 bytes.

We can do better with a custom uncompress header:

```sh
#!/bin/sh
X=/tmp/a
dd bs=1 skip=67<$0|xzcat>$X
chmod +x $X
exec $X
```

```bash
cat bin/solskogen-release | xz > bin/solskogen-release.xz
cat uncompress-header bin/solskogen-release.xz > bin/solskogen
chmod a+x bin/solskogen
```

6223 bytes

And tweak the `xz` command to achieve better compression.

```bash
XZ="xz -c -9e --format=lzma --lzma1=preset=9,lc=0,lp=0,pb=0"
cat bin/solskogen-release | $XZ > bin/solskogen-release.xz
cat uncompress-header bin/solskogen-release.xz > bin/solskogen
chmod a+x bin/solskogen
```

6172 bytes

## Shader minifier tool

Use [Shader Minifer](https://github.com/laurentlb/Shader_Minifier) on the fragment shader code. It's a tool written in F# that does what it sounds like.

Some limitations: no dead code elimination, limited support for structs.

```bash
SHADER_MINIFIER=Shader_Minifier/shader_minifier.exe
if [ ! -e $SHADER_MINIFIER ]; then
    pushd Shader_Minifier
    TERM=xterm ./compile.bash
    popd
fi
set -x
mono $SHADER_MINIFIER --preserve-externals fshader.glsl -o gen/shaders.h
```

Uncompressed: 21992 bytes.
Final: 4982 bytes.

## ELFkickers sstrip tool

```bash
readelf -a bin/solskogen-release | less
```

Use the `sstrip` tool from [ELFkickers](https://github.com/BR903/ELFkickers) to remove the section header table from the executable. They are not needed for running the program.

```
SSTRIP=ELFkickers/bin/sstrip
if [ ! -e $SSTRIP ]; then
    pushd ELFkickers
    make
    popd
fi

...

gcc obj/solskogen-release.o $LIBS -o bin/solskogen-release
$SSTRIP bin/solskogen-release
```

Uncompressed: 16408 bytes.
Final: 3779 bytes.

Hey, we're under 4k already!
