# hear

Speech to text for Emacs, kept loaded: Phonon-2.5 run by
[phonon-2.5-c](https://github.com/eschmidbauer/phonon-2.5-c) (fetched at a
pinned commit, built here), with a beam search that is pulled toward your
own words (`bias.c`). The same program runs in Termux on the phone and on
the Mac. Why and how, with measurements and references:
[docs/voice-engine.org](../docs/voice-engine.org).

```sh
./setup.sh                      # build, and the model into ~/.local/share/hear/phonon-2.5
./hear file ~/.local/share/hear/phonon-2.5 x.wav --vocab words.txt
./hear serve WEIGHTS SOCKET --vocab words.txt --save DIR
./hear client SOCKET partial=400 < audio.s16le   # 16 kHz mono s16le
./hear send SOCKET PING
make check                      # vocabulary on synthetic speech (macOS `say`)
```

Emacs runs it (`lisp/voice/voice-engine.el`); Emacs Home's island streams
the microphone to it (`emacs-home/.../Hear.java`).

## Protocol

A client opens with one line, then (for `LISTEN`) raw audio:

| Request | Then | Answers, one line each |
|---|---|---|
| `LISTEN [vocab=F,G] [hangover=MS] [nospeech=MS] [maxsec=S] [partial=MS] [beam=N] [boost=B] [save=0\|1] [tag=WORD] [tail=MS] [preroll=MS] [pad=MS] [snr=DB] [vadmode=0-3]` | 16 kHz mono s16le | `START` · `PARTIAL text` · `END` · `TEXT best` · `ALT other`… · `NONE` · `INFO …` |
| `FILE /path.wav [vocab=…]` | – | `TEXT`, `ALT`…, `INFO` |
| `PING` | – | `PONG phonon-2.5 phrases=N` |
| `QUIT` | – | `BYE`, and it exits |

Shutting the write side means "done, decode now"; closing the socket
means cancel. Any engine that answers this way can replace it.

## Your words

One phrase per line (`phrase<TAB>boost` for its own boost). Each also
goes in lower-cased and capitalised, in every way the model's pieces can
spell it in the fewest pieces or one more. A piece that continues a phrase
gets `boost · (1 + ln depth)`; leaving the phrase unfinished takes the
bonus back (sherpa-onnx's ContextGraph scoring), but not what a shorter
phrase it passed through earned: "doom" and "doom ayu light" are both
heard. Defaults: beam 4, boost 3. The files are read again whenever one
changes; Emacs keeps a second one, list.txt, with the entries of the list
open in the minibuffer (boost 4).

Your words tip close calls; they never outvote the audio. The model also
searches by itself, each of its readings gets the bonus your words would
give it, and the best of both is the answer: a search pulled toward
"Switch to 8th workspace" loses "switch to a light theme" from its beam
otherwise. Another reading is offered only within `--margin` nats (10)
of what the model, alone, finds likeliest.
