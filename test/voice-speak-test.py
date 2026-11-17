#!/usr/bin/env python3
"""Speak test phrases at the phone and see what voice would do with them.

The Mac says each phrase aloud (`say`, several voices); the phone, on USB,
listens through the voice app exactly as a long press on the clock island
does; Emacs, in test mode, only plans what it heard and logs it, so your
tasks are never touched.  Afterwards each line is checked against what it
should do, the phone's recording of it is pulled, and a report is written:

  RUN/report.org     what was said, heard and planned; misses first
  RUN/audio/*.wav    what the phone heard, per line

Phrases: a TSV of PHRASE TAB EXPECT (action:NAME, task:WORDS, pick:WORDS,
none), # for comments; see `voice-expect-ok' in lisp/voice-command.el.

  test/voice-speak-test.py test/voice-runs/corpus.tsv --voices Samantha,Rishi
"""

import argparse
import datetime
import os
import re
import subprocess
import sys
import time

PHONE = "/sdcard/Documents/voice-audio"
MARKER = PHONE + "/TEST"
LOG = PHONE + "/test-log.tsv"
LISTENER = "org.futo.voiceinput"


def adb(*args, check=False):
    r = subprocess.run(["adb", *args], capture_output=True, text=True)
    if check and r.returncode:
        sys.exit(f"adb {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout


def log_lines():
    out = adb("shell", f"cat {LOG} 2>/dev/null")
    return [l for l in out.splitlines() if l.strip()]


def top_activity():
    out = adb("shell", "dumpsys activity activities | grep -m1 topResumedActivity")
    return out.strip()


def wait_for(pred, timeout, step=0.25):
    end = time.time() + timeout
    while time.time() < end:
        v = pred()
        if v:
            return v
        time.sleep(step)
    return None


def volume(level=None):
    if level is None:
        return int(subprocess.run(["osascript", "-e", "output volume of (get volume settings)"],
                                  capture_output=True, text=True).stdout.strip() or 0)
    subprocess.run(["osascript", "-e", f"set volume output volume {level}"])


def expect_ok(expect, row):
    """The same rule as `voice-expect-ok', from a log line's fields."""
    kind, action, target, decision = row["kind"], row["action"], row["target"], row["decision"]
    what, _, want = expect.partition(":")
    want = want.strip().lower()
    if what == "action":
        return kind == "action" and action.lower() == want
    if what == "task":
        return kind == "task" and decision == "act" and want in target.lower()
    if what == "pick":
        return kind == "task" and decision == "pick" and want in target.lower()
    return kind == "none" or decision == "none"


FIELDS = ["time", "source", "mode", "heard", "kind", "action", "target", "score",
          "margin", "decision", "ms", "result"]


def parse(line):
    parts = line.split("\t") + [""] * len(FIELDS)
    return dict(zip(FIELDS, parts))


def speak_one(phrase, voice, args):
    """Say PHRASE once; return the log row it produced, or a reason it didn't."""
    before = len(log_lines())
    adb("shell", "input keyevent KEYCODE_WAKEUP")
    x, y = args.island.split(",")
    adb("shell", f"input swipe {x} {y} {x} {y} 1000")
    if not wait_for(lambda: LISTENER in top_activity(), 6):
        return None, "the voice app did not open"
    time.sleep(args.lead)
    subprocess.run(["say", "-v", voice, "-r", str(args.rate), phrase])
    row = wait_for(lambda: (lambda ls: ls[before:] and ls[-1])(log_lines()), args.timeout)
    if not row:
        if LISTENER in top_activity():
            adb("shell", "input keyevent KEYCODE_BACK")
        return None, "nothing came back"
    wait_for(lambda: LISTENER not in top_activity(), 4)
    return parse(row), None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("corpus")
    ap.add_argument("--voices", default="Samantha")
    ap.add_argument("--only", help="regexp: phrases to run")
    ap.add_argument("--volume", type=int, default=60, help="Mac output volume while speaking")
    ap.add_argument("--rate", type=int, default=175, help="words per minute")
    ap.add_argument("--lead", type=float, default=1.0, help="seconds between listening and speaking")
    ap.add_argument("--timeout", type=float, default=15)
    ap.add_argument("--island", default="640,86", help="x,y of the clock island")
    ap.add_argument("--out", help="run directory (default: beside the corpus, by time)")
    args = ap.parse_args()

    cases = []
    with open(args.corpus) as f:
        for line in f:
            line = line.rstrip("\n")
            if not line.strip() or line.startswith("#"):
                continue
            phrase, _, expect = line.partition("\t")
            if args.only and not re.search(args.only, phrase):
                continue
            cases.append((phrase, expect or "none"))
    voices = [v.strip() for v in args.voices.split(",") if v.strip()]

    run = args.out or os.path.join(os.path.dirname(os.path.abspath(args.corpus)),
                                   datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
    os.makedirs(os.path.join(run, "audio"), exist_ok=True)

    adb("get-state", check=True)
    adb("shell", f"mkdir -p {PHONE} && touch {MARKER}")
    old_volume = volume()
    volume(args.volume)
    results = []
    try:
        for voice in voices:
            for phrase, expect in cases:
                row, why = speak_one(phrase, voice, args)
                ok = bool(row) and expect_ok(expect, row)
                results.append(dict(voice=voice, phrase=phrase, expect=expect, row=row, why=why, ok=ok))
                shown = row["heard"] if row else f"({why})"
                print(f"{'ok  ' if ok else 'MISS'} {voice:9} {phrase!r} -> {shown!r}"
                      + ("" if not row else f" {row['kind']}/{row['action']}/{row['target']} {row['decision']}"),
                      flush=True)
                time.sleep(0.8)
    finally:
        volume(old_volume)
        adb("shell", f"rm -f {MARKER}")

    time.sleep(3)  # the last recording is copied 2 s after it is heard
    for r in results:
        if r["row"]:
            stamp = re.sub(r"[-: ]", "", r["row"]["time"])
            stamp = stamp[:8] + "-" + stamp[8:]
            wav = os.path.join(run, "audio", stamp + ".wav")
            adb("pull", f"{PHONE}/{stamp}.wav", wav)
            r["wav"] = os.path.relpath(wav, run) if os.path.exists(wav) else None
    write_report(run, results, args)
    n_ok = sum(r["ok"] for r in results)
    print(f"\n{n_ok} of {len(results)} did what they should.  Report: {run}/report.org")


def write_report(run, results, args):
    def cell(s):
        return str(s or "").replace("|", "/")

    lines = [f"#+title: Voice test {os.path.basename(run)}", "",
             f"Voices: {args.voices}.  Volume {args.volume}, rate {args.rate}.", ""]
    for voice in dict.fromkeys(r["voice"] for r in results):
        rs = [r for r in results if r["voice"] == voice]
        heard_right = sum(1 for r in rs if r["row"] and
                          re.sub(r"[^a-z0-9 ]", "", r["row"]["heard"].lower()).split() ==
                          re.sub(r"[^a-z0-9 ]", "", r["phrase"].lower()).split())
        lines.append(f"- {voice}: {sum(r['ok'] for r in rs)} of {len(rs)} right; "
                     f"{heard_right} heard word for word")
    lines += ["", "* Misses", "",
              "| voice | said | heard | did | task | score | decision | expected | audio |",
              "|-"]
    for r in results:
        if not r["ok"]:
            row = r["row"] or {}
            audio = f"[[file:{r['wav']}][play]]" if r.get("wav") else ""
            lines.append("| " + " | ".join(cell(x) for x in [
                r["voice"], r["phrase"], row.get("heard") or r["why"],
                f"{row.get('kind', '')} {row.get('action', '')}".strip(), row.get("target"),
                row.get("score"), row.get("decision"), r["expect"]]) + f" | {audio} |")
    lines += ["", "* Everything", "", "| ok | voice | said | heard | did | task | score | ms |", "|-"]
    for r in results:
        row = r["row"] or {}
        lines.append("| " + " | ".join(cell(x) for x in [
            "ok" if r["ok"] else "MISS", r["voice"], r["phrase"], row.get("heard") or r["why"],
            f"{row.get('kind', '')} {row.get('action', '')}".strip(), row.get("target"),
            row.get("score"), row.get("ms")]) + " |")
    with open(os.path.join(run, "report.org"), "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
