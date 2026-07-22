# mp3cc

MIDletPascal 3.5 compiler, ported to build and run on modern Linux (x86_64) and
ARM64.

The compiler takes MIDletPascal source (`.pas` / `.mpsrc`) and emits preverified
CLDC-1.0 Java class files for J2ME. This is the compiler only — no IDE.

Upstream is
[`MPC.3.5.IDE`](https://sourceforge.net/p/midletpascal/code/HEAD/tree/MPC.3.5.IDE/)
(Javier Santo Domingo, 2013-02-02), the last official release of the
[MIDletPascal project](https://sourceforge.net/p/midletpascal/code/HEAD/tree/),
taken at r15. Original code by Niksa Orlic (1.x–2.0) and Artem (3.0).

## Building

```sh
make            # native            -> Release/mp3CC
make arm64      # static aarch64    -> Release-arm64/mp3CC
make ISDEBUG=1  # symbols, -O0      -> Debug/mp3CC
```

A native build needs only a C compiler and make. The arm64 target additionally
needs the `aarch64-linux-gnu` cross toolchain; its glibc comes along as a
dependency, which is what the static link needs. On Arch:

```sh
sudo pacman -S gcc make                  # native
sudo pacman -S aarch64-linux-gnu-gcc     # plus this for: make arm64
```

The arm64 binary is linked static on purpose, so the same file runs both on ARM
Linux and on Android under `arm64-v8a`, where there is no glibc to link against.

## Usage

```sh
mp3CC -s"<source>" -o"<output_dir>" -l"<global_lib_dir>" -p"<project_lib_dir>" \
      -c<canvas_type> -m<math_type> [-r<next_record_id>] [-d]
```

`-c0` plain canvas, `-c1` full screen, `-c2` full Nokia. `-m0` integer only,
`-m2` real number support. `-d` only detects units without compiling. Both `-l`
and `-p` are required even when the directories are empty.

Units must be compiled before the program that uses them, into the same output
directory — the compiler resolves `uses` through the `.bsf` symbol files left
there by earlier runs.

`testdata/` holds MIDletPascal projects to compile when testing a build.

## Licence

GPLv3, as in upstream — see `LICENSE.txt`, with the full text in `COPYING`.

`preverifier/` comes from Sun's J2ME CLDC reference implementation and keeps its
original copyright headers.
