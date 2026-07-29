# mp3cc

MIDletPascal 3.5 compiler, ported from 32-bit Windows to modern 64-bit Linux (x86_64, ARM64) and Android.

MIDletPascal source in, preverified CLDC-1.0 Java class files for J2ME out. This is the compiler only — no IDE.

## Building

```sh
make            # native            -> Release/mp3CC
make arm64      # static aarch64    -> Release-arm64/mp3CC
make android    # static bionic     -> Release-android-{arm64,armv7,x86_64}/mp3CC
make ISDEBUG=1  # symbols, -O0      -> Debug/mp3CC
```

A native build needs only a C compiler and make. `make arm64` additionally needs the `aarch64-linux-gnu` cross
toolchain; its glibc comes along as a dependency, which is what the static link needs. On Arch:

```sh
sudo pacman -S gcc make                  # native
sudo pacman -S aarch64-linux-gnu-gcc     # plus this for: make arm64
```

The arm64 binary is linked static on purpose, so the same file runs on ARM Linux and on ARM Android when started from a
shell. Binaries that an Android *application* spawns need `make android` instead — see
[docs/android.md](docs/android.md).

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

| Required              | Description                                                                       |
|-----------------------|-----------------------------------------------------------------------------------|
| `-s<source>`          | MIDletPascal source file (`.pas` or `.mpsrc`)                                     |
| `-o<output_dir>`      | Directory for generated `.class` and `.bsf` files                                 |
| `-l<global_lib_dir>`  | Global library directory                                                          |
| `-p<project_lib_dir>` | Project library directory (searched before `-l`)                                  |
| `-c<canvas_type>`     | Canvas mode: `0` plain, `1` full-screen MIDP 2.0, or `2` full-screen Nokia        |
| `-m<math_type>`       | Real numbers: `1` fixed-point (`F.class`, default) or `2` floating (`Real.class`) |

| Optional             | Description                                        |
|----------------------|----------------------------------------------------|
| `-r<next_record_id>` | First ID for this run's record classes — see below |
| `-d`                 | Detect required units without compiling            |

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

Record types are numbered per run rather than per project: each one declared becomes `R_<id>.class`, counting up from
`-r<next_record_id>`, or from `0` when the option is left out. A build that compiles several modules into one output
directory therefore has to hand each run the next free ID — take the highest `^3R_<n>.class` marker reported so far and
add one. Without it every module starts over at `R_0` and their record classes overwrite each other in the output
directory: the module compiled last wins, and the earlier ones go on referencing fields that class no longer has.
Nothing reports this, and the type check does not catch it either, because record types are compared by that ID rather
than by their fields.

## Documentation

| Document                                           | What is in it                                                             |
|----------------------------------------------------|---------------------------------------------------------------------------|
| [docs/compiler-output.md](docs/compiler-output.md) | Progress lines, requirement markers, error and warning codes, exit status |
| [docs/android.md](docs/android.md)                 | NDK builds, the three ABIs, why a glibc binary dies inside an app         |
| [testdata/README.md](testdata/README.md)           | Sample projects for testing a build, and their dependency order           |

## Upstream

[MPC.3.5.IDE](https://sourceforge.net/p/midletpascal/code/HEAD/tree/MPC.3.5.IDE/)
(Javier Santo Domingo, 2013-02-02), the last official release of the MIDletPascal project, taken at r15. Original code
by Niksa Orlic (1.x–2.0) and Artem (3.0).

## Licence

GPLv3, as in upstream — see `LICENSE.txt`, with the full text in `COPYING`.

`preverifier/` comes from Sun's J2ME CLDC reference implementation and keeps its original copyright headers.
