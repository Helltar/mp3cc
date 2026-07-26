# Android builds

```sh
make android                                # default NDK, all three ABIs
NDK=/path/to/android-ndk make -B android    # alternate NDK
```

`make android` links static against bionic with Android NDK r29 (`~/Android/android-ndk-r29` by default), targeting API
21, and builds all three Android ABIs at once.

## Why bionic and not the static glibc build

A glibc-static binary — what `make arm64` produces — starts fine from `adb shell`, but modern glibc uses syscalls
outside the app seccomp allowlist. Spawned from an app process the same file is killed instantly: no output, no crash
log, just a zombie. Anything an Android *application* launches has to come from `make android`.

## ABIs

| Output directory         | ABI           | ELF `LOAD` alignment |
|--------------------------|---------------|----------------------|
| `Release-android-arm64`  | `arm64-v8a`   | 16 KB                |
| `Release-android-armv7`  | `armeabi-v7a` | 4 KB                 |
| `Release-android-x86_64` | `x86_64`      | 16 KB                |

The r29 linker gives the two 64-bit outputs 16 KB page alignment by default; the 32-bit one stays 4 KB. The `x86_64`
target exists so the compiler also works inside the Android Studio emulator, which cannot exec standalone ARM binaries.

## Rebuilds

Make does not record the compiler path in object-file dependencies. After changing the NDK or the Android compiler
flags, force a complete rebuild with `make -B android` — plain `make android` can otherwise reuse objects from the old
toolchain.
