# hear: the speech engine Emacs talks to (hear.c), on Phonon-2.5's C engine.
#   make            fetch phonon-2.5-c at the pinned commit, build it and ./hear
#   make weights    the model (183 MB download, sha256 checked) into $(MODELS)/phonon-2.5
#   make check      transcribe test phrases with and without the vocabulary
# Builds on the machine that runs it: Termux on the phone, macOS on the Mac.

P25_REPO   ?= https://github.com/eschmidbauer/phonon-2.5-c
P25_COMMIT ?= 510e1f7
P25_DIR    ?= build/phonon-2.5-c
# WebRTC's voice detector, standalone (BSD-3): where speech starts and ends.
FVAD_REPO   ?= https://github.com/dpirch/libfvad
FVAD_COMMIT ?= 532ab66
FVAD_DIR    ?= build/libfvad
MODELS     ?= $(HOME)/.local/share/hear
WEIGHTS_URL = https://huggingface.co/eschmidbauer/phonon-2.5-c/resolve/main/phonon-2.5-c-weights-v1.tar.gz
WEIGHTS_SHA = ed622ca97bc4ec044c7ba5fb69c10985b1b3897e600dbf611840d9a0692b4cfe

UNAME_S := $(shell uname -s)
UNAME_O := $(shell uname -o 2>/dev/null)
# The phone: SDOT int8 dot products, and nothing newer (its kernel turns SVE off, so no -mcpu=native).
ifeq ($(UNAME_O),Android)
  ARCH ?= -march=armv8.2-a+dotprod
  EXTRA = -D_GNU_SOURCE
else ifeq ($(UNAME_S),Darwin)
  ARCH ?= -march=native
else
  ARCH ?= -march=native
  EXTRA = -D_GNU_SOURCE
endif
CC     ?= cc
CFLAGS  = -O3 -ffast-math $(ARCH) -funroll-loops -std=c11 -pthread $(EXTRA)
LIB     = $(P25_DIR)/csrc/libphonon25.a
FVAD_SRC = $(addprefix $(FVAD_DIR)/src/,fvad.c vad/vad_core.c vad/vad_filterbank.c vad/vad_gmm.c vad/vad_sp.c \
             signal_processing/division_operations.c signal_processing/energy.c \
             signal_processing/get_scaling_square.c signal_processing/resample_48khz.c \
             signal_processing/resample_by_2_internal.c signal_processing/resample_fractional.c \
             signal_processing/spl_inl.c)

hear: hear.c bias.c bias.h $(LIB) | $(FVAD_DIR)
	$(CC) $(CFLAGS) -I$(P25_DIR)/csrc -I$(FVAD_DIR)/include -o $@ hear.c bias.c $(FVAD_SRC) $(LIB) -lm

$(FVAD_DIR):
	mkdir -p build
	git clone -q $(FVAD_REPO) $(FVAD_DIR)
	cd $(FVAD_DIR) && git checkout -q $(FVAD_COMMIT)

$(LIB): | $(P25_DIR)
	$(MAKE) -C $(P25_DIR)/csrc libphonon25.a CC="$(CC)" CFLAGS="$(CFLAGS) -Wall"

$(P25_DIR):
	mkdir -p build
	git clone -q $(P25_REPO) $(P25_DIR)
	cd $(P25_DIR) && git checkout -q $(P25_COMMIT)

# The phone's engine built on the Mac (the NDK's clang): `make android`, then put build/android/hear in
# /sdcard/Download/hear-model/, where setup.sh on the phone takes it from when it can't build.
NDK      ?= $(lastword $(sort $(wildcard $(HOME)/Library/Android/sdk/ndk/*)))
NDK_CC    = $(NDK)/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android28-clang
P25_SRC   = $(addprefix $(P25_DIR)/csrc/,blas.c decoder.c encoder.c engine.c json.c mel.c resample.c segment.c \
              tensor_ops.c threadpool.c tokens.c wav.c weights.c)
android: build/android/hear
build/android/hear: hear.c bias.c bias.h | $(P25_DIR) $(FVAD_DIR)
	mkdir -p build/android
	$(NDK_CC) -O3 -ffast-math -march=armv8.2-a+dotprod -funroll-loops -std=c11 -pthread -D_GNU_SOURCE \
	  -I$(P25_DIR)/csrc -I$(FVAD_DIR)/include -o $@ hear.c bias.c $(FVAD_SRC) $(P25_SRC) -lm

weights: $(MODELS)/phonon-2.5/weights.bin
$(MODELS)/phonon-2.5/weights.bin:
	mkdir -p $(MODELS)/phonon-2.5
	curl -fL -o $(MODELS)/phonon-2.5.tar.gz $(WEIGHTS_URL)
	echo "$(WEIGHTS_SHA)  $(MODELS)/phonon-2.5.tar.gz" | sha256sum -c 2>/dev/null \
	  || echo "$(WEIGHTS_SHA)  $(MODELS)/phonon-2.5.tar.gz" | shasum -a 256 -c
	tar -xzf $(MODELS)/phonon-2.5.tar.gz -C $(MODELS)/phonon-2.5 --strip-components=1
	rm $(MODELS)/phonon-2.5.tar.gz

check: hear
	./test/check.sh $(MODELS)/phonon-2.5

clean:
	rm -f hear

.PHONY: weights check clean android
