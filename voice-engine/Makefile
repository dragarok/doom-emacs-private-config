# hear: the speech engine Emacs talks to (hear.c), on Phonon-2.5's C engine.
#   make            fetch phonon-2.5-c at the pinned commit, build it and ./hear
#   make weights    the model (183 MB download, sha256 checked) into $(MODELS)/phonon-2.5
#   make check      transcribe test phrases with and without the vocabulary
# Builds on the machine that runs it: Termux on the phone, macOS on the Mac.

P25_REPO   ?= https://github.com/eschmidbauer/phonon-2.5-c
P25_COMMIT ?= 510e1f7
P25_DIR    ?= build/phonon-2.5-c
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

hear: hear.c bias.c bias.h $(LIB)
	$(CC) $(CFLAGS) -I$(P25_DIR)/csrc -o $@ hear.c bias.c $(LIB) -lm

$(LIB): | $(P25_DIR)
	$(MAKE) -C $(P25_DIR)/csrc libphonon25.a CC="$(CC)" CFLAGS="$(CFLAGS) -Wall"

$(P25_DIR):
	mkdir -p build
	git clone -q $(P25_REPO) $(P25_DIR)
	cd $(P25_DIR) && git checkout -q $(P25_COMMIT)

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

.PHONY: weights check clean
