# Compiler output

`mp3cc` writes everything to stdout as plain text, one message per line, and returns the error count as its exit code
(`0` on success). An IDE drives the compiler by parsing these lines; the whole vocabulary is below.

## Progress and result

| Line                                  | Meaning                                              |
|---------------------------------------|------------------------------------------------------|
| `Compiling '<file>'...`               | start of a normal compile                            |
| `Detecting units of '<file>'...`      | start of a `-d` unit-detection pass                  |
| `@<n>`                                | progress percentage, `n` from 0 to 100               |
| `Done - <e> error(s), <w> warning(s)` | final summary, printed only after a successful build |

The exit code is the number of errors, so `0` is success. A *different* non-zero exit with no matching error line means
the process itself died — a bad argument, or a binary the host refused to run (an Android app spawning a non-bionic
build; see [android.md](android.md)).

## Requirement markers

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

## Diagnostics

Errors and warnings carry a code and a source position:

| Line                                                 | Meaning                                    |
|------------------------------------------------------|--------------------------------------------|
| `[Pascal Error] <file>(<line>): E<code> <message>`   | a source-level error (codes ≥ 100)         |
| `[Compiler Error] <file>(<line>): E<code> <message>` | a low-level / internal error (codes < 100) |
| `[Pascal Warning] <file>(<line>): W<code> <message>` | a warning                                  |
| `Fatal error: <message>`                             | the compiler aborted and stopped           |

`<file>` is the bare source file name — the directory is stripped, so resolve it against the path you passed to `-s`.
`<line>` is 1-based. The full message table is `msg()` in [util/error.c](../util/error.c); a selection of the ones you
are most likely to meet:

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
