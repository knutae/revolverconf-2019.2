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
