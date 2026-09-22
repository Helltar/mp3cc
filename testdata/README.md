# Test data

| Project     | What it exercises                                                                                  |
|-------------|----------------------------------------------------------------------------------------------------|
| `Selftest`  | One file that uses everything: every type, statement, extension and runtime helper class.          |
| `CatchRect` | Five units with a real dependency chain, plus an external library. The only multi-module case.     |

There is no test suite. A compiler build is checked by compiling these two with two builds — or on two architectures —
and diffing the class files; the procedure is in [AGENTS.md](../AGENTS.md).

## Selftest

`src/selftest.pas` is written to be the single input that touches the most of the compiler. It compiles in both math
modes (`-m1` and `-m2`), reports every optional runtime class (`^2FS.class` … `^2SM.class`), declares two record
types (`^3R_0.class`, `^3R_1.class`) and deliberately emits one warning, `W464`, from the deprecated `inline()`
spelling.

Run on a phone or an emulator, it checks the results it computes against known answers — integer and string
arithmetic, shifts, real functions within a tolerance, arrays, records, recursion, the `result` and `exit` extensions,
a raw `bytecode … end` block, the record store, a bundled resource and image — and draws the tally. Keys 1 to 5 then
open the parts that need a screen, a network or a phone (forms, HTTP, the player, SMS, drawing), and 0 quits. `res/`
holds the text file and the 8×8 PNG it reads, which go into the JAR next to the classes.

Writing it found two upstream bugs in `parser/parser.c`: the `result` use-after-free and the `extern` declarations
that did not match their definitions.

## CatchRect

`CatchRect` needs `libs/Lib_sensor.class`, a small touch-input helper compiled from `lib_sensor.java`, resolved through
the `-p` switch. Its five units must be compiled in dependency order — `ucore`, `uplatfrm`, `urect`, `ugame`,
`catchrect` — into one output directory, because `uses` resolves through the `.bsf` symbol files earlier runs leave
behind. It came from [AMPASIDE](https://github.com/Helltar/AMPASIDE).
