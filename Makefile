# mp3CC - MIDletPascal 3.5 compiler, linux/arm build
#
#   make                 native build            -> release/mp3CC
#   make arm64           static aarch64 build    -> release-arm64/mp3CC
#   make android         static bionic builds    -> release-android-*/mp3CC
#   make ISDEBUG=1       unoptimised + symbols   -> debug/mp3CC
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
	DESTDIR ?= debug
else
	CFLAGS += -O2
	LDFLAGS += -s
	DESTDIR ?= release
endif

ifeq ($(STATIC),1)
	LDFLAGS += -static
endif

CPPC = $(CC) $(DEFS) $(LEGACY) $(CFLAGS)

MAINS=main
CLASSGENS=constant_pool classgen bytecode preverify
LEXS=lex.yy
UTILS=error memory strings
ifeq ($(ANDROID),1)
	UTILS += android_tls
endif
PARSERS=parser stdpas
STRUCTURES=block identifier type type_list name_table string_list unit
PREVERS=file convert_md classresolver stubs classloader util \
   check_class sys_support jar_support check_code jar \
   inlinejsr main

# $(DESTDIR) itself is left out: mkdir -p makes it, and as a target of its own it
# would be the phony release or debug target
DIRS=$(DESTDIR)/classgen $(DESTDIR)/lex $(DESTDIR)/main \
   $(DESTDIR)/parser $(DESTDIR)/preverifier $(DESTDIR)/structures \
   $(DESTDIR)/util

ITEMS=$(CLASSGENS:%=classgen/%) $(LEXS:%=lex/%) $(MAINS:%=main/%) \
   $(PARSERS:%=parser/%) $(PREVERS:%=preverifier/%) \
   $(STRUCTURES:%=structures/%) $(UTILS:%=util/%)

all: release

re: clean all

clean:
	rm -rf release debug release-arm64 release-android-*

debug:
	$(MAKE) ISDEBUG=1

arm64:
	$(MAKE) CROSS=aarch64-linux-gnu- STATIC=1 DESTDIR=release-arm64

# android builds link static against bionic via the ndk. a glibc-static binary
# starts from adb shell but is killed by the app seccomp filter when spawned
# from an application process, so the ndk toolchain is required here.
# ndk r29 gives the 64-bit binaries 16 kb load-segment alignment by default.
# clang has no -fpermissive for c, the -Wno-* set below is its equivalent.
NDK ?= $(HOME)/Android/android-ndk-r29
NDK_BIN = $(NDK)/toolchains/llvm/prebuilt/linux-x86_64/bin
CLANG_LEGACY = -std=gnu89 -fcommon -w -Wno-int-conversion \
   -Wno-implicit-function-declaration -Wno-implicit-int \
   -Wno-incompatible-function-pointer-types -Wno-incompatible-pointer-types \
   -Wno-return-type

android: android-arm64 android-armv7 android-x86_64

android-arm64:
	$(MAKE) CC=$(NDK_BIN)/aarch64-linux-android21-clang STATIC=1 ANDROID=1 \
	   DESTDIR=release-android-arm64 LEGACY="$(CLANG_LEGACY)"

android-armv7:
	$(MAKE) CC=$(NDK_BIN)/armv7a-linux-androideabi21-clang STATIC=1 ANDROID=1 \
	   DESTDIR=release-android-armv7 LEGACY="$(CLANG_LEGACY)"

android-x86_64:
	$(MAKE) CC=$(NDK_BIN)/x86_64-linux-android21-clang STATIC=1 ANDROID=1 \
	   DESTDIR=release-android-x86_64 LEGACY="$(CLANG_LEGACY)"

release: $(DIRS) $(DESTDIR)/mp3CC

$(DIRS):
	mkdir -p $@

# Clang otherwise emits emulated TLS, which cannot raise PT_TLS alignment
$(DESTDIR)/util/android_tls.o: util/android_tls.c | $(DIRS)
	$(CPPC) -fno-emulated-tls -c -o $@ $<

$(DESTDIR)/%.o : %.c | $(DIRS)
	$(CPPC) -c -o $@ $<

$(DESTDIR)/mp3CC: $(ITEMS:%=$(DESTDIR)/%.o)
	$(CPPC) $(LDFLAGS) -o $@ $^ -lm

.PHONY: all re clean debug release arm64 android android-arm64 android-armv7 android-x86_64
