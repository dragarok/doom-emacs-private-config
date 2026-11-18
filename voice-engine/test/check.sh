#!/bin/sh
# Score the vocabulary: synthetic phrases (macOS say), each with the words it must come out with.
# test/check.sh WEIGHTS [hear options…]   — needs test/expect.tsv (phrase TAB words that must appear)
W=$1; shift
D=${TMPDIR:-/tmp}/hear-check; mkdir -p "$D"
hits=0; total=0
while IFS='	' read -r phrase want; do
  for v in Samantha Daniel Rishi; do
    f="$D/$(echo "$phrase-$v" | tr ' ' _).wav"
    [ -f "$f" ] || say -v $v -o "$f" --data-format=LEI16@16000 "$phrase"
    got=$(./hear file "$W" "$f" "$@" 2>/dev/null | cut -f2)
    ok=1; for w in $want; do echo "$got" | grep -qi -- "$(echo $w | tr _ ' ')" || ok=0; done
    total=$((total+1)); hits=$((hits+ok))
    [ $ok = 1 ] || printf '  miss %-9s %-34s -> %s\n' "$v" "$phrase" "$got"
  done
done < "${EXPECT:-test/expect.tsv}"
echo "$hits/$total"
