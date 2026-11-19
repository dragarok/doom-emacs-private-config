/*  bias.h – Your words, heard: a phrase list that pulls the decoder toward its entries.
 *
 *  A context graph (an Aho-Corasick trie over each phrase's SentencePiece pieces) and a small beam search over the
 *  TDT decoder that adds a bonus for every piece that continues a phrase, takes the bonus back when the phrase is
 *  left unfinished, and keeps it when the phrase completes.  The scoring is that of k2-fsa's ContextGraph
 *  (icefall/context_graph.py, sherpa-onnx/csrc/context-graph.cc: its hotwords), put on the TDT decoder.
 */
#ifndef HEAR_BIAS_H
#define HEAR_BIAS_H

#include "phonon25.h"

typedef struct HearContext HearContext;

/* Phrases from TEXT, one per line ("#" starts a comment line; "phrase<TAB>boost" gives that phrase its own
 * per-piece boost).  Each phrase also goes in lower-cased and capitalised, and in every way the vocabulary can spell
 * it in its fewest pieces or one more.  Deeper pieces of a phrase get more
 * (boost · (1 + ln depth), HEAR_DEPTH_SCALE scales the log term; 0 makes it flat).  NULL when nothing is left. */
HearContext *hear_context_build(const P25Tokens *tok, const char *text, float boost);
void         hear_context_free(HearContext *c);
int          hear_context_phrases(const HearContext *c);
int          hear_context_nodes(const HearContext *c);

typedef struct {
    P25Token *tokens;
    int       n;
    float     score;      /* acoustic log-probability plus the bonus kept */
    float     am;         /* the acoustic log-probability alone: how well the audio bears it out */
} HearHyp;

/* The bonus the graph gives TOKENS (an unfinished phrase's taken back): to weigh a reading found without it. */
float hear_context_score(const HearContext *c, const P25Token *tokens, int n);

/* Beam TDT decoding over enc [T × 640], biased toward CTX's phrases (CTX may be NULL: a plain beam search).
 * Fills OUT with up to MAX_N distinct hypotheses, best first, and returns how many; free each one's tokens. */
int hear_beam_decode(const P25Model *m, const float *enc, int T, const HearContext *ctx,
                     int beam, HearHyp *out, int max_n);

#endif
