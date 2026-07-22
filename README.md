# mp3cc

MIDletPascal 3.5 compiler, ported to build and run on modern Linux (x86_64), ARM64 and Android.

The compiler takes MIDletPascal source (`.pas` / `.mpsrc`) and emits preverified CLDC-1.0 Java class files for J2ME.
This is the compiler only — no IDE.

Upstream is
[`MPC.3.5.IDE`](https://sourceforge.net/p/midletpascal/code/HEAD/tree/MPC.3.5.IDE/)
(Javier Santo Domingo, 2013-02-02), the last official release of the
[MIDletPascal project](https://sourceforge.net/p/midletpascal/code/HEAD/tree/), taken at r15. Original code by Niksa
Orlic (1.x–2.0) and Artem (3.0).

## Building

```sh
make            # native            -> Release/mp3CC
make arm64      # static aarch64    -> Release-arm64/mp3CC
make android    # static bionic     -> Release-android-{arm64,armv7,x86_64}/mp3CC
make ISDEBUG=1  # symbols, -O0      -> Debug/mp3CC
```

A native build needs only a C compiler and make. The arm64 target additionally needs the `aarch64-linux-gnu` cross
toolchain; its glibc comes along as a dependency, which is what the static link needs. On Arch:

```sh
sudo pacman -S gcc make                  # native
sudo pacman -S aarch64-linux-gnu-gcc     # plus this for: make arm64
```

The arm64 binary is linked static on purpose, so the same file runs both on ARM Linux and on ARM Android when started
from a shell.

### Android

Binaries that an Android *application* spawns must come from
`make android`, which links static against bionic using the NDK (`NDK=<path> make android`, default
`~/Android/android-ndk-r27c`, API 21). A glibc-static binary starts fine from `adb shell`, but modern glibc uses
syscalls outside the app seccomp allowlist, so the same file spawned from an app process is killed instantly — no
output, no crash log, just a zombie. The x86_64 target exists so the compiler also works inside the Android Studio
emulator, which cannot exec standalone ARM binaries.

## Usage

```sh
mp3CC \
  -s"<source>" \
  -o"<output_dir>" \
  -l"<global_lib_dir>" \
  -p"<project_lib_dir>" \
  -c<canvas_type> \
  -m<math_type> \
  [-r<next_record_id>] \
  [-d]
```

Required options:

| Option                | Description                                                                |
|-----------------------|----------------------------------------------------------------------------|
| `-s<source>`          | MIDletPascal source file (`.pas` or `.mpsrc`)                              |
| `-o<output_dir>`      | Directory for generated `.class` and `.bsf` files                          |
| `-l<global_lib_dir>`  | Global library directory                                                   |
| `-p<project_lib_dir>` | Project library directory                                                  |
| `-c<canvas_type>`     | Canvas mode: `0` plain, `1` full-screen MIDP 2.0, or `2` full-screen Nokia |
| `-m<math_type>`       | Number support: `0` integers only or `2` real numbers                      |

Optional options:

| Option               | Description                             |
|----------------------|-----------------------------------------|
| `-r<next_record_id>` | Initial ID for record types             |
| `-d`                 | Detect required units without compiling |

Both library options are required even when their directories are empty. For example, compile the single-file `Cubes`
project with:

```sh
mkdir -p /tmp/mp3cc-out /tmp/emptylibs
./Release/mp3CC \
  -s"testdata/Cubes/src/cubes.pas" \
  -o"/tmp/mp3cc-out" \
  -l"/tmp/emptylibs" \
  -p"/tmp/emptylibs" \
  -c0 \
  -m2
```

Units must be compiled before the program that uses them, into the same output directory — the compiler resolves `uses`
through the `.bsf` symbol files left there by earlier runs.

`testdata/` holds more MIDletPascal projects for testing a build; see
[`testdata/README.md`](testdata/README.md) for their dependency order.

## Licence

GPLv3, as in upstream — see `LICENSE.txt`, with the full text in `COPYING`.

`preverifier/` comes from Sun's J2ME CLDC reference implementation and keeps its original copyright headers.
