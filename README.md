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
cc $CFLAGS -DDEBUG -c solskogen.c -o obj/solskogen-debug.o
cc obj/solskogen-debug.o $LIBS -o bin/solskogen-debug

# release version
cc $CFLAGS -DNDEBUG -c solskogen.c -o obj/solskogen-release.o
cc obj/solskogen-release.o $LIBS -o bin/solskogen-release
```

Debug: 26560 bytes.
Release: 26176 bytes.

## Executable compression

```bash
gzexe bin/solskogen-release
```

7880 bytes.

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

6183 bytes.

And tweak the `xz` command to achieve better compression.

```bash
XZ="xz -c -9e --format=lzma --lzma1=preset=9,lc=0,lp=0,pb=0"
cat bin/solskogen-release | $XZ > bin/solskogen-release.xz
cat uncompress-header bin/solskogen-release.xz > bin/solskogen
chmod a+x bin/solskogen
```

6143 bytes.

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

Uncompressed: 22080 bytes.
Final: 4961 bytes.

## ELFkickers sstrip tool

```bash
readelf -a bin/solskogen-release | less
```

Use the `sstrip` tool from [ELFkickers](https://github.com/BR903/ELFkickers) to remove the section header table from the executable. It is not needed for running the program.

```
SSTRIP=ELFkickers/bin/sstrip
if [ ! -e $SSTRIP ]; then
    pushd ELFkickers
    make
    popd
fi

...

cc obj/solskogen-release.o $LIBS -o bin/solskogen-release
$SSTRIP bin/solskogen-release
```

Uncompressed: 16656 bytes.
Final: 3741 bytes.

Hey, we're under 4k already!

## Linker tuning

Add `-v` to link command to see the underlying `ld` command. Tune this to reduce the size futher.

```bash
/usr/bin/ld \
    -z relro \
    --hash-style=gnu \
    --eh-frame-hdr \
    -m elf_x86_64 \
    -dynamic-linker \
    /lib64/ld-linux-x86-64.so.2 \
    -o bin/solskogen-release \
    /usr/lib/x86_64-linux-gnu/crt1.o \
    /usr/lib/x86_64-linux-gnu/crti.o \
    /usr/lib/gcc/x86_64-linux-gnu/8/crtbegin.o \
    -L/usr/lib/gcc/x86_64-linux-gnu/8 \
    -L/usr/x86_64-linux-gnu/lib64 \
    -L/usr/lib/x86_64-linux-gnu \
    -L/lib/x86_64-linux-gnu \
    -L/lib64 \
    -L/usr/lib/x86_64-linux-gnu \
    -L/usr/x86_64-linux-gnu/lib \
    -L/usr/lib \
    -L/usr/lib/llvm-7/lib \
    -L/lib \
    -L/usr/lib \
    obj/solskogen-release.o \
    -lGL \
    -lgtk-3 \
    -lgdk-3 \
    -lpangocairo-1.0 \
    -lpango-1.0 \
    -latk-1.0 \
    -lcairo-gobject \
    -lcairo \
    -lgdk_pixbuf-2.0 \
    -lgio-2.0 \
    -lgobject-2.0 \
    -lglib-2.0 \
    -lgcc \
    --as-needed \
    -lgcc_s \
    --no-as-needed \
    -lc \
    -lgcc \
    --as-needed \
    -lgcc_s \
    --no-as-needed \
    /usr/lib/gcc/x86_64-linux-gnu/8/crtend.o \
    /usr/lib/x86_64-linux-gnu/crtn.o
```

```diff
 /usr/bin/ld \
-    -z relro \
+    -z norelro \
+    -z noseparate-code \
+    --orphan-handling=discard \
+    --as-needed \
+    --gc-sections \
     --hash-style=gnu \
-    --eh-frame-hdr \
+    --no-eh-frame-hdr \
+    --no-ld-generated-unwind-info \
     -m elf_x86_64 \
     -dynamic-linker \
     /lib64/ld-linux-x86-64.so.2 \
     -o bin/solskogen-release \
     /usr/lib/x86_64-linux-gnu/crt1.o \
-    /usr/lib/x86_64-linux-gnu/crti.o \
-    /usr/lib/gcc/x86_64-linux-gnu/8/crtbegin.o \
-    -L/usr/lib/gcc/x86_64-linux-gnu/8 \
-    -L/usr/x86_64-linux-gnu/lib64 \
-    -L/usr/lib/x86_64-linux-gnu \
-    -L/lib/x86_64-linux-gnu \
-    -L/lib64 \
-    -L/usr/lib/x86_64-linux-gnu \
-    -L/usr/x86_64-linux-gnu/lib \
-    -L/usr/lib \
-    -L/usr/lib/llvm-7/lib \
-    -L/lib \
-    -L/usr/lib \
     obj/solskogen-release.o \
     -lGL \
     -lgtk-3 \
-    -lgdk-3 \
-    -lpangocairo-1.0 \
-    -lpango-1.0 \
-    -latk-1.0 \
-    -lcairo-gobject \
-    -lcairo \
-    -lgdk_pixbuf-2.0 \
-    -lgio-2.0 \
     -lgobject-2.0 \
-    -lglib-2.0 \
-    -lgcc \
-    --as-needed \
-    -lgcc_s \
-    --no-as-needed \
     -lc \
-    -lgcc \
-    --as-needed \
-    -lgcc_s \
-    --no-as-needed \
-    /usr/lib/gcc/x86_64-linux-gnu/8/crtend.o \
     /usr/lib/x86_64-linux-gnu/crtn.o
```

Resulting `ld` command:

```bash
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
    /usr/lib/x86_64-linux-gnu/crt1.o \
    obj/solskogen-release.o \
    -lGL \
    -lgtk-3 \
    -lgobject-2.0 \
    -lc \
    /usr/lib/x86_64-linux-gnu/crtn.o
```

Uncompressed: 9016 bytes.
Final: 3311 bytes.

## Linking without libc

If we try to link without `-lc`, we get an unresolved `__libc_start_main` from `crt1.o`. Some tutorials suggest using a `_start` function at the entry point instead of `main`, and not linking `crt1.o` at all, but that doesn't seem to work when loading shared libraries (it segfaults).

As a simpler solution, let's try implementing our own minimal versions `__libc_start_main` and other functions referenced by `crt1.o`.

```c
// minlibc.c
extern int main();

// Minimal implementations of crt1.o libc functions.
// With these defined, we don't need to link libc. Probably.
void __libc_csu_init() {}
void __libc_csu_fini() {}
void __libc_start_main() { main(); }
```

Compile and link this instead of `-lc` and `ctrn.o`.

```bash
cc $CFLAGS -DNDEBUG -c solskogen.c -o obj/solskogen-release.o
cc $CFLAGS -c minlibc.c -o obj/minlibc.o
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
    /usr/lib/x86_64-linux-gnu/crt1.o \
    obj/solskogen-release.o \
    obj/minlibc.o \
    -lGL \
    -lgtk-3 \
    -lgobject-2.0
```

Uncompressed: 8752 bytes.
Final: 3110 bytes.

## Customizing the C runtime (crt1.o)

Inspecting the C runtime object with `objdump -D /usr/lib/x86_64-linux-gnu/crt1.o` shows a `.eh_frame` which is used for exception handling. This is not needed for our C program. Let's try to get rid of it.

```bash
objcopy --remove-section .eh_frame /usr/lib/x86_64-linux-gnu/crt1.o obj/crt1.o
```

Uncompressed: 8752 bytes.
Final: 3099 bytes.

We saved a whooping 11 bytes in the compressed binary. (Perhaps there are more bytes to save by implemeting our own minimal version of `crt1.o`?)
