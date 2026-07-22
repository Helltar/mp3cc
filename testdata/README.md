# Test data

| Project                               | What it exercises                                                                          |
|---------------------------------------|--------------------------------------------------------------------------------------------|
| `CatchRect`                           | Five units with a real dependency chain, plus an external library. The case worth running. |
| `Cubes`, `Space`, `Tank`, `Tentaculi` | Single-file programs, no `uses` clause. Shallow but quick.                                 |

`CatchRect` needs `libs/Lib_sensor.class`, a small touch-input helper compiled from `lib_sensor.java`, resolved through
the `-p` switch. Its five units must be compiled in dependency order — `ucore`, `uplatfrm`, `urect`, `ugame`,
`catchrect` — into one output directory, because `uses` resolves through the
`.bsf` symbol files earlier runs leave behind.

These copies came from [AMPASIDE](https://github.com/Helltar/AMPASIDE).
