# Working in this repository

mp3cc is the MIDletPascal 3.5 compiler — Pascal in, preverified CLDC-1.0 Java class files out. Roughly 37k lines of C
written between 1995 and 2013 for 32-bit Windows, carried onto 64-bit Linux and ARM64. Most of what follows exists
because of that gap.

## Layout

| Directory      | Lines | What it holds                                                                                                                                                                                  |
|----------------|-------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `parser/`      | 10.2k | Recursive descent, one function per grammar rule (`RD_*`). `stdpas.c` declares the built-ins — `DrawText`, `Repaint`, `LoadImage` — and sets the `usesFloat` / `usesPlayer` / `usesSMS` flags. |
| `structures/`  | 5.0k  | Symbol table: blocks, identifiers, types, name table.                                                                                                                                          |
| `classgen/`    | 2.7k  | Class file emission, constant pool, bytecode buffers.                                                                                                                                          |
| `util/`        | 0.8k  | Strings, memory, error reporting.                                                                                                                                                              |
| `lex/`         | 0.6k  | Lexer.                                                                                                                                                                                         |
| `main/`        | 0.4k  | Argument parsing and entry point.                                                                                                                                                              |
| `preverifier/` | 16.8k | Sun's KVM preverifier — see Hazards.                                                                                                                                                           |

Lines beginning `^2` or `^3` in compiler output are not errors. They are the
`requires` mechanism reporting which RTL classes the IDE must bundle into the JAR, driven by those `uses*` flags. `@N`
lines are progress percentages.

## Build and test

```sh
make            # native            -> Release/mp3CC
make arm64      # static aarch64    -> Release-arm64/mp3CC
make android    # static bionic     -> Release-android-{arm64,armv7,x86_64}/mp3CC
make ISDEBUG=1  # symbols, -O0      -> Debug/mp3CC
make clean
```

Build dependencies are in the README. Beyond those, the checks below want `javap`
from a JDK and `qemu-user` to run the ARM binary on an x86 host. `make arm64` is linked static so one binary serves both
ARM Linux and Android `arm64-v8a`, which has no glibc.

`make android` uses Android NDK r29 from `~/Android/android-ndk-r29` by default, targets API 21 and emits static bionic
binaries for all three Android ABIs. The r29 linker gives the 64-bit `arm64-v8a` and `x86_64` outputs 16 KB ELF `LOAD`
alignment by default, while the 32-bit `armeabi-v7a` output remains 4 KB aligned. Override the toolchain with
`NDK=/path/to/android-ndk make android`. Make does not track the compiler path or flags in object dependencies, so use
`make -B android` whenever the NDK or Android flags change; otherwise old objects can be silently reused.

There is no test suite. Verification is done against `testdata/`, which holds stock MIDletPascal projects reduced to the
files the compiler reads. Both `-l`
and `-p` must be passed even when the directory is empty, hence the throwaway
`emptylibs`:

```sh
mkdir -p /tmp/out /tmp/emptylibs
for u in ucore uplatfrm urect ugame catchrect; do
  ./Release/mp3CC -s"testdata/CatchRect/src/$u.pas" -o/tmp/out \
     -l/tmp/emptylibs -p"testdata/CatchRect/libs" -c0 -m2 || echo "FAIL $u"
done
```

CatchRect is the case worth running: five compilation units that must be built in that exact order, because `uses`
resolves through the `.bsf` symbol files earlier runs leave in the output directory, and it is the only project pulling
in an external library. The single-file projects have no `uses` clause at all and exercise much less — useful as a quick
smoke test, not as a regression check.

Check the result is real Java, not just bytes:

```sh
javap -cp /tmp/out M                      # should load and disassemble
javap -v -cp /tmp/out ugame | grep -c StackMap   # must be > 0
```

`StackMap` attributes are the thing to look for. Their absence means the preverifier silently did nothing, and J2ME
devices will reject the class even though `javap` is perfectly happy with it.

### The regression test that actually catches things

Build both architectures and diff their output:

```sh
make && make arm64
mkdir -p /tmp/emptylibs
for arch in x86 arm; do
  [ $arch = arm ] && run="qemu-aarch64 Release-arm64/mp3CC" || run="Release/mp3CC"
  rm -rf /tmp/out-$arch && mkdir -p /tmp/out-$arch
  for u in ucore uplatfrm urect ugame catchrect; do
    $run -s"testdata/CatchRect/src/$u.pas" -o/tmp/out-$arch \
       -l/tmp/emptylibs -p"testdata/CatchRect/libs" -c0 -m2 >/dev/null
  done
done
diff -r /tmp/out-x86 /tmp/out-arm && echo identical
```

The compiler is deterministic, so any divergence between x86-64 and aarch64 is a word-size or sign-extension bug —
exactly the class of defect this codebase is full of. `qemu-aarch64` runs the ARM binary natively enough for this. The
check passes today, which is the point: it is cheap and it fails loudly.

## Hazards

**`-fpermissive -w` in the Makefile is load-bearing, and it hides things.** The code relies on pre-C99 behaviour that
modern GCC rejects outright, so the flags cannot simply be dropped. But they also suppress diagnostics that were real
bugs here. Before trusting any change to the C, rebuild with:

```sh
make clean && make CFLAGS="-O0 -g" LEGACY="-std=gnu89 -fcommon -fpermissive \
  -Wimplicit-function-declaration"
```

It should be silent. All 13 implicit declarations that existed originally were resolved; a new one is a genuine defect,
not noise.

**Assume every `long` was meant to be 32 bits.** This is Sun and Borland-era code where `unsigned long` means "u4". On
LP64 that assumption breaks in two ways that compile cleanly and fail at runtime: byte-assembly expressions that
overflow
`int` before being widened, and pointers stuffed through `int`. See the
`get4bytes` and `mem_alloc` entries below for what each looks like in practice.

**Never write a literal `\` as a path separator.** Use `PATH_SEP_CHAR` /
`PATH_SEP_STR` from `util/strings.h`, or `LOCAL_DIR_SEPARATOR` inside
`preverifier/`. Upstream had eight hardcoded backslashes; they produced files named `output\M.class` on Linux, which is
a valid filename, so nothing errored — the compiler just wrote its output into a junk file and later failed to find it.

**`lex/lex.yy.c` is not generated.** The name says flex output, but there is no
`.l` file anywhere and never was one here — Artem replaced the original generated lexer by hand in 3.0.003 and kept the
filename. It is 563 readable lines, and
`yyrestart` takes a filename rather than a `FILE*`, which is the quickest tell. Edit it directly; do not look for a
grammar to regenerate it from.

**`parser/parser.c` is ISO-8859-1, and some search tools skip it in silence.** It is the only file in the tree that is
not UTF-8. GNU grep and ripgrep read it as text and find everything in it; tools that drop non-UTF-8 files as binary do
not — Claude Code's bundled `grep` (ugrep run with `-I`) returns no match and exit 1, no warning, unless it is given
`-a`. That hides 6800 lines of the parser, so an empty tree-wide search is not evidence that something is unused. The
standing example is `-r<next_record_id>`: the two lines that make it work,
`new_type->unique_record_ID = next_record_ID; next_record_ID++;`, live in this file and nowhere else, and the option has
been written off as dead code because of it.

**Two preverifiers exist.** `preverifier/` is Sun's and is the one that runs.
`classgen/preverify.c` is MIDletPascal's own stack-map generator, disabled upstream (see the commented `//PREVERIFY`
call in `structures/block.c`). Don't confuse them when grepping; `preverify_bytecode` and `stack_map_*` belong to the
dormant one.

**`preverifier/` is imported third-party code** — Sun's, in a visibly different style from the rest, and it keeps its
own copyright headers. The two halves are fully decoupled: no `#include` crosses the boundary in either direction (the
ones at the top of `preverifier/main.c` are inside a comment block, which is why the build survives the missing
`main/static_entry.h` they reference). The only coupling is through `VerifyFile` and the global `output_path`. Keep it
that way — changes there should be the minimum needed to build.

## Why the code looks like this

Upstream is
[`MPC.3.5.IDE`](https://sourceforge.net/p/midletpascal/code/HEAD/tree/MPC.3.5.IDE/)
from the MIDletPascal SourceForge SVN at r15, targeting 32-bit MSVC. Six classes of fix were needed. The interesting
ones:

- **`string_list.c` never included `memory.h`.** `mem_alloc` fell back to an implicit `int` declaration, truncating
  every returned pointer to 32 bits. Immediate segfault on any real program.
- **`get4bytes()` in `classloader.c` sign-extended the class file magic.**
  `ptr[0] << 24` for `0xCA` overflows `int`; widening the negative result to a 64-bit `unsigned long` yields
  `0xFFFFFFFFCAFEBABE`, which never matches
  `JAVA_CLASSFILE_MAGIC`. Every compile died with "Bad magic number". Harmless on ILP32, where the extension is
  truncated away.
- **Windows path separators hardcoded in eight places**, across `parser.c`,
  `block.c`, `classgen.c` and `preverifier/main.c`.
- **`pow()` called without `math.h`**, so real-constant parsing read an implicit
  `int` return. Affects `-m2` only.
- **`convert_md.c` had unbalanced braces in its `#ifdef UNIX` branch** — dead code inherited unchanged from 2.0.2 that
  had evidently never been compiled by anyone.
- The `windows.h` / WOW64 `WM_COPYDATA` block in `main.c` and `_stricmp` in
  `name_table.h` are now behind `WIN32`.

`MPC.3.1.LINUX` in the upstream repository is not a working Linux port despite the name — it contains only a Makefile
and one patched header, and does not build. That Makefile was the starting point for this one.

To see exactly what this fork changed, diff a pristine `MPC.3.5.IDE` from
[upstream](https://sourceforge.net/p/midletpascal/code/HEAD/tree/MPC.3.5.IDE/)
against this tree. `--strip-trailing-cr` matters — upstream is CRLF throughout:

```sh
diff -ru --strip-trailing-cr /path/to/MPC.3.5.IDE .
```

## Conventions

Ordinary `//` and `/* */` comments added to this tree are lowercase throughout, as are git commit subjects. Identifiers
and acronyms keep their real casing (`PATH_SEP_STR`, `LP64`, `CLDC`) wherever they appear, including at the start of a
sentence. Upstream's own comments are left as they were found.

Commit bodies explain the failure mode, not just the change — most fixes here are invisible without knowing what broke
and on which architecture.
