# mp3CC - MIDletPascal 3.5 compiler, linux/arm build
#
#   make                 native build            -> Release/mp3CC
#   make arm64           static aarch64 build    -> Release-arm64/mp3CC
#   make ISDEBUG=1       unoptimised + symbols   -> Debug/mp3CC
#
# the arm64 target is built static on purpose: the same binary then runs both
# on arm linux and on android (arm64-v8a), where there is no glibc to link to.

CROSS ?=
CC = $(CROSS)gcc

# this is 2006-era c written for 32-bit msvc. modern gcc rejects by default
# what it relies on, so the legacy dialect is pinned explicitly:
#   -std=gnu89   k&r-style definitions, no c99+ scoping changes
#   -fcommon     tentative definitions merged across units (pre-gcc10 default)
#   -fpermissive downgrade c23 hard errors back to warnings
LEGACY = -std=gnu89 -fcommon -fpermissive -w
DEFS = -DLINUX -DUNIX

ifeq ($(ISDEBUG),1)
	CFLAGS += -g -O0
	DESTDIR ?= Debug
else
	CFLAGS += -O2
	LDFLAGS += -s
	DESTDIR ?= Release
endif

ifeq ($(STATIC),1)
	LDFLAGS += -static
endif

CPPC = $(CC) $(DEFS) $(LEGACY) $(CFLAGS)

MAINS=main
CLASSGENS=constant_pool classgen bytecode preverify
LEXS=lex.yy
UTILS=error memory strings
PARSERS=parser stdpas
STRUCTURES=block identifier type type_list name_table string_list unit
PREVERS=file convert_md classresolver stubs classloader util \
   check_class sys_support jar_support check_code jar \
   inlinejsr main

DIRS=$(DESTDIR) $(DESTDIR)/classgen $(DESTDIR)/lex $(DESTDIR)/main \
   $(DESTDIR)/parser $(DESTDIR)/preverifier $(DESTDIR)/structures \
   $(DESTDIR)/util

ITEMS=$(CLASSGENS:%=classgen/%) $(LEXS:%=lex/%) $(MAINS:%=main/%) \
   $(PARSERS:%=parser/%) $(PREVERS:%=preverifier/%) \
   $(STRUCTURES:%=structures/%) $(UTILS:%=util/%)

all: release

re: clean all

clean:
	rm -rf Release Debug Release-arm64 Release-android-*

debug:
	$(MAKE) ISDEBUG=1

arm64:
	$(MAKE) CROSS=aarch64-linux-gnu- STATIC=1 DESTDIR=Release-arm64

# android builds link static against bionic via the ndk. a glibc-static binary
# starts from adb shell but is killed by the app seccomp filter when spawned
# from an application process, so the ndk toolchain is required here.
# clang has no -fpermissive for c, the -Wno-* set below is its equivalent.
NDK ?= $(HOME)/Android/android-ndk-r27c
NDK_BIN = $(NDK)/toolchains/llvm/prebuilt/linux-x86_64/bin
CLANG_LEGACY = -std=gnu89 -fcommon -w -Wno-int-conversion \
   -Wno-implicit-function-declaration -Wno-implicit-int \
   -Wno-incompatible-function-pointer-types -Wno-incompatible-pointer-types \
   -Wno-return-type

android: android-arm64 android-armv7 android-x86_64

android-arm64:
	$(MAKE) CC=$(NDK_BIN)/aarch64-linux-android21-clang STATIC=1 \
	   DESTDIR=Release-android-arm64 LEGACY="$(CLANG_LEGACY)"

android-armv7:
	$(MAKE) CC=$(NDK_BIN)/armv7a-linux-androideabi21-clang STATIC=1 \
	   DESTDIR=Release-android-armv7 LEGACY="$(CLANG_LEGACY)"

android-x86_64:
	$(MAKE) CC=$(NDK_BIN)/x86_64-linux-android21-clang STATIC=1 \
	   DESTDIR=Release-android-x86_64 LEGACY="$(CLANG_LEGACY)"

release: $(DIRS) $(DESTDIR)/mp3CC

$(DIRS):
	mkdir -p $@

$(DESTDIR)/%.o : %.c | $(DIRS)
	$(CPPC) -c -o $@ $<

$(DESTDIR)/mp3CC: $(ITEMS:%=$(DESTDIR)/%.o)
	$(CPPC) $(LDFLAGS) -o $@ $^ -lm

.PHONY: all re clean debug release arm64 android android-arm64 android-armv7 android-x86_64
