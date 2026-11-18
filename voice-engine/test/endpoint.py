#!/usr/bin/env python3
"""End-pointing bench: does hear stop when you stop, and only then?

    test/endpoint.py SOCKET --noise ROOM.wav[@FROM-TO] SPEECH.wav... [--pre 1.2] [--post 6] [--opts "k=v ..."]

Each SPEECH file is played as one stream: PRE seconds of room noise, the
speech, POST seconds of room noise (looped from ROOM.wav, seconds FROM to
TO of it), sent to a running `hear serve` at SOCKET as `hear client` does.
The engine says where it found speech (INFO at ...); this prints, per file:

    late   how long after the speech file ends the engine said END (good: about
           the hangover, 1 s; "never" means it ran to the stream's end)
    start  whether speech was found at all, and where
    text   what it heard

and, with --silence, streams of room noise alone, which should give NONE.
Recordings of your voice stay outside the repo: pass them as files.
"""
import argparse, os, socket, struct, sys, wave


def read_wav(path):
    w = wave.open(path)
    assert w.getframerate() == 16000 and w.getnchannels() == 1 and w.getsampwidth() == 2, path
    return w.readframes(w.getnframes())


def noise(room, seconds):
    need = int(seconds * 16000) * 2
    out = bytearray()
    while len(out) < need:
        out += room[: need - len(out)]
    return bytes(out)


def run(sock, stream, opts):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock)
    s.sendall(("LISTEN " + opts + "\n").encode())
    replies = b""
    s.setblocking(True)
    # Send in 100 ms pieces, reading replies as they come: the server stops
    # reading once it has heard the end.
    for i in range(0, len(stream), 3200):
        s.settimeout(None)
        try:
            s.sendall(stream[i : i + 3200])
        except OSError:            # the engine stopped reading: it has its answer
            break
        s.settimeout(0.0)
        try:
            while True:
                chunk = s.recv(65536)
                if not chunk:
                    break
                replies += chunk
        except (BlockingIOError, socket.timeout):
            pass
        if b"\nEND" in b"\n" + replies:
            break
    try:
        s.shutdown(socket.SHUT_WR)
    except OSError:
        pass
    s.settimeout(30)
    try:
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            replies += chunk
    except socket.timeout:
        replies += b"\nTIMEOUT"
    s.close()
    lines = replies.decode(errors="replace").splitlines()
    info = {}
    for l in lines:
        if l.startswith("INFO at "):
            info = dict(kv.split("=", 1) for kv in l[8:].split())
    text = next((l[5:] for l in lines if l.startswith("TEXT ")), "NONE" if "NONE" in lines else "?")
    return info, text, lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("socket")
    ap.add_argument("speech", nargs="*")
    ap.add_argument("--noise", required=True, help="ROOM.wav or ROOM.wav@FROM-TO (seconds)")
    ap.add_argument("--pre", type=float, default=1.2)
    ap.add_argument("--post", type=float, default=6.0)
    ap.add_argument("--opts", default="tag=bench save=0")
    ap.add_argument("--silence", type=int, default=0, help="also this many noise-only streams")
    a = ap.parse_args()
    path, _, span = a.noise.partition("@")
    room = read_wav(path)
    if span:
        f, t = (float(x) for x in span.split("-"))
        room = room[int(f * 16000) * 2 : int(t * 16000) * 2]
    bad = 0
    print(f"{'file':28} {'late':>6} {'start':>6}  why     text")
    for p in a.speech:
        sp = read_wav(p)
        stream = noise(room, a.pre) + sp + noise(room, a.post)
        speech_end = int((a.pre + len(sp) / 32000) * 1000)
        info, text, _ = run(a.socket, stream, a.opts)
        why = info.get("why", "?")
        late = int(info["end"]) - speech_end if why == "quiet" else None
        ok = why == "quiet" and late is not None and late < 2000
        bad += not ok
        print(f"{os.path.basename(p)[:28]:28} {('never' if late is None else str(late)):>6} "
              f"{info.get('start', '-'):>6}  {why:7} {text}")
    for i in range(a.silence):
        start = int(i * len(room) / max(1, a.silence) / 2) & ~1
        stream = noise(room[start:] + room[:start], 8.0)
        info, text, _ = run(a.socket, stream, a.opts)
        ok = text == "NONE"
        bad += not ok
        print(f"{'(room noise only)':28} {'':>6} {info.get('start', '-'):>6}  {info.get('why', '?'):7} {text}")
    print(f"{bad} not right")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
