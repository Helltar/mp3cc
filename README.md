# mp3cc

MIDletPascal 3.5 compiler, ported to build and run on modern Linux (x86_64), ARM64 and Android.

The compiler takes MIDletPascal source (`.pas` / `.mpsrc`) and emits preverified CLDC-1.0 Java class files for J2ME.
This is the compiler only — no IDE.

Upstream is
[MPC.3.5.IDE](https://sourceforge.net/p/midletpascal/code/HEAD/tree/MPC.3.5.IDE/)
(Javier Santo Domingo, 2013-02-02), the last official release of the MIDletPascal project, taken at r15. Original code
by Niksa Orlic (1.x–2.0) and Artem (3.0).

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
`~/Android/android-ndk-r29`, API 21). NDK r29 aligns the 64-bit ELF `LOAD` segments for both 4 KB and 16 KB Android page
sizes by default. A glibc-static binary starts fine from `adb shell`, but modern glibc uses syscalls outside the app
seccomp allowlist, so the same file spawned from an app process is killed instantly — no output, no crash log, just a
zombie. The x86_64 target exists so the compiler also works inside the Android Studio emulator, which cannot exec
standalone ARM binaries.

Make does not record the compiler path in object-file dependencies. After changing the NDK or Android compiler flags,
force a complete Android rebuild with `make -B android`; plain `make android` can otherwise reuse objects from the old
toolchain. An alternate NDK can still be selected explicitly:

```sh
NDK=/path/to/android-ndk make -B android
```

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

| Option                | Description                                                                       |
|-----------------------|-----------------------------------------------------------------------------------|
| `-s<source>`          | MIDletPascal source file (`.pas` or `.mpsrc`)                                     |
| `-o<output_dir>`      | Directory for generated `.class` and `.bsf` files                                 |
| `-l<global_lib_dir>`  | Global library directory                                                          |
| `-p<project_lib_dir>` | Project library directory (searched before `-l`)                                  |
| `-c<canvas_type>`     | Canvas mode: `0` plain, `1` full-screen MIDP 2.0, or `2` full-screen Nokia        |
| `-m<math_type>`       | Real numbers: `1` fixed-point (`F.class`, default) or `2` floating (`Real.class`) |

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
[testdata/README.md](testdata/README.md) for their dependency order.

## Compiler output

`mp3cc` writes everything to stdout as plain text, one message per line, and returns the error count as its exit code
(`0` on success). An IDE drives the compiler by parsing these lines; the whole vocabulary is below.

### Progress and result

| Line                                  | Meaning                                              |
|---------------------------------------|------------------------------------------------------|
| `Compiling '<file>'...`               | start of a normal compile                            |
| `Detecting units of '<file>'...`      | start of a `-d` unit-detection pass                  |
| `@<n>`                                | progress percentage, `n` from 0 to 100               |
| `Done - <e> error(s), <w> warning(s)` | final summary, printed only after a successful build |

The exit code is the number of errors, so `0` is success. A *different* non-zero exit with no matching error line means
the process itself died — a bad argument, or a binary the host refused to run (an Android app spawning a non-bionic
build; see [Android](#android)).

### Requirement markers

Lines starting with `^` are not errors. They report the extra files that belong in the JAR, so the IDE knows what to
bundle. They are split across the two passes: `-d` emits only `^0`, the real compile emits `^1`–`^3`.

| Marker       | Pass    | Meaning                                                                         |
|--------------|---------|---------------------------------------------------------------------------------|
| `^0<unit>`   | `-d`    | a Pascal unit reached through `uses`, to be compiled from the source tree       |
| `^1<lib>`    | compile | an external `Lib_<name>.class` the program calls (looked up in `-p`, then `-l`) |
| `^2<class>`  | compile | a runtime (RTL) helper class the program needs — see below                      |
| `^3<record>` | compile | a record class the compiler generated into the output directory itself          |

The `^2` classes are fixed RTL helpers, each requested from a feature the program uses:

| Class                                   | Requested when                     |
|-----------------------------------------|------------------------------------|
| `FS.class`                              | any form / UI routine is used      |
| `S.class`                               | strings, resources or `ImageFrom…` |
| `F.class`                               | real numbers, fixed-point (`-m1`)  |
| `Real.class`, `Real$NumberFormat.class` | real numbers, floating (`-m2`)     |
| `RS.class`                              | any record-store (RMS) routine     |
| `H.class`                               | any HTTP routine                   |
| `P.class`                               | any sound / player routine         |
| `SM.class`                              | any SMS routine                    |

`FW.class`, the MIDlet entry point, is always required but is *not* reported as a `^2` line — the IDE adds it to every
build unconditionally.

### Diagnostics

Errors and warnings carry a code and a source position:

| Line                                                 | Meaning                                    |
|------------------------------------------------------|--------------------------------------------|
| `[Pascal Error] <file>(<line>): E<code> <message>`   | a source-level error (codes ≥ 100)         |
| `[Compiler Error] <file>(<line>): E<code> <message>` | a low-level / internal error (codes < 100) |
| `[Pascal Warning] <file>(<line>): W<code> <message>` | a warning                                  |
| `Fatal error: <message>`                             | the compiler aborted and stopped           |

`<file>` is the bare source file name — the directory is stripped, so resolve it against the path you passed to `-s`.
`<line>` is 1-based. The full message table is `msg()` in [util/error.c](util/error.c); a selection of the ones you are
most likely to meet:

| Code   | Meaning                                                             |
|--------|---------------------------------------------------------------------|
| `E202` | identifier (name) expected                                          |
| `E204` | unexpected token `'…'`                                              |
| `E207` | unexpected end of file                                              |
| `E219` | `break` used outside a loop                                         |
| `E400` | identifier `'…'` already defined                                    |
| `E406` | unknown type `'…'`                                                  |
| `E423` | both sides of `:=` must have the same type                          |
| `E428` | `'…'` is not a procedure, function, variable or unit name           |
| `E434` | only string, char, integer or boolean can be appended to a string   |
| `E443` | a value cannot be assigned to a whole array                         |
| `E446` | arrays inside records are not implemented                           |
| `E448` | failed to load library/unit `'…'`                                   |
| `E459` | identifier `'…'` found in several units — qualify it as `unit.name` |

MIDletPascal is a deliberately small dialect: several standard-Pascal features are rejected rather than compiled.

| Code   | Not supported                 |
|--------|-------------------------------|
| `E211` | sets                          |
| `E212` | enumerated types              |
| `E215` | `with`                        |
| `E431` | nested procedures / functions |
| `E435` | files                         |
| `E442` | `case`                        |

Only three warnings are ever emitted, and compilation continues past all of them: **W210** (`packed` arrays are treated
as ordinary arrays), **W436** (`var` / by-reference parameters are ignored) and **W464** (`inline(…)` is deprecated —
use `bytecode … end`).

## Licence

GPLv3, as in upstream — see `LICENSE.txt`, with the full text in `COPYING`.

`preverifier/` comes from Sun's J2ME CLDC reference implementation and keeps its original copyright headers.
