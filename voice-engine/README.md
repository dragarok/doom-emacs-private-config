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
| `LISTEN [vocab=F,G] [hangover=MS] [nospeech=MS] [maxsec=S] [partial=MS] [beam=N] [boost=B] [save=0\|1] [tag=WORD]` | 16 kHz mono s16le | `START` · `PARTIAL text` · `END` · `TEXT best` · `ALT other`… · `NONE` · `INFO …` |
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
bonus back (sherpa-onnx's ContextGraph scoring). Defaults: beam 4, boost
3. The files are read again whenever one changes.
