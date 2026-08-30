#!/usr/bin/env python3
"""waybar -- niri focused-window title, with an e-ink resolve on focus change.

Replaces the built-in niri/window module. The built-in sets its label straight
from IPC and gives no hook between "title arrived" and "label drawn", and GTK3
CSS -- which waybar does support -- can animate colour and opacity but never
text CONTENT. So the animation has to come from the data side: a continuous
script emitting one JSON line per frame, which waybar renders as it reads.

WHY A RESOLVE AND NOT A GLITCH. The rest of this bar is e-ink discipline: no
fills, no shadows, marks rather than decoration. Random-letter glitch is a
cyberpunk idiom and would read as borrowed. But real e-ink does have a
transition -- the partial-refresh settle, where the field develops out of grey
and the ink darkens as it sets. That is what this reproduces: a field of light
shade resolving into the title, @faint hardening to @muted.

TWO FACTS FROM THE FONT AND THE COMPOSITOR SHAPE THIS:

1. GeistMono advances exactly 7px for EVERY glyph at 12px -- letters, spaces,
   and the shade blocks below all measured identically. Every frame therefore
   uses the NEW title's character count, so the label's width is fixed for the
   whole animation. Nothing reflows, and the centred workspace dots cannot
   jitter while it runs. On a proportional font this effect shivers the bar.

2. Window titles churn constantly. Sampling niri's event stream for three
   seconds caught WindowOpenedOrChanged three times for a single window -- a
   terminal spinner rewriting its own title. Animating every title change would
   leave the bar permanently scrambling. So the trigger is a change of focused
   window ID; a title edit on the window that already has focus swaps silently.
"""

import json
import os
import random
import subprocess
import sys
import threading
import time

# Light shade, not a solid block: the palette avoids large fills, and a row of
# solid blocks would be exactly that. U+2591 reads as undeveloped wash instead.
GHOST = "░"

STEPS = 7          # e-ink settles in visible steps, so a low frame count is
FRAME = 0.025      # the honest look here, not a limitation. ~175ms total.


def emit(text, resolving):
    """One waybar frame. 'resolving' picks @faint over @muted -- see style.css.

    Colour rides on a CSS class rather than pango markup because a span would
    need a literal hex, and the palette's build.py --audit rejects any colour
    on disk that is not a name from the generated ramp.
    """
    line = {"text": text, "class": "resolving" if resolving else ""}
    sys.stdout.write(json.dumps(line) + "\n")
    sys.stdout.flush()


class State:
    """Latest compositor state. Written by the reader thread, read by the
    renderer -- the two must not block each other, or a burst of title churn
    arriving mid-animation would stall the frames."""

    def __init__(self):
        self.lock = threading.Lock()
        self.windows = {}      # id -> {title, workspace_id}
        self.ws_output = {}    # workspace_id -> output name
        self.focused = None    # window id
        self.output = os.environ.get("WAYBAR_OUTPUT_NAME")

    def visible(self):
        """(id, title) of the window this bar should describe, or (None, "").

        Honours the output the bar lives on, which is what separate-outputs did
        on the built-in module. With one monitor this never filters anything,
        but it keeps the behaviour correct if a second one is plugged in.
        """
        with self.lock:
            w = self.windows.get(self.focused)
            if not w:
                return None, ""
            if self.output:
                out = self.ws_output.get(w.get("workspace_id"))
                # Unknown workspace -> show it. Failing open keeps the title on
                # screen if the map is momentarily stale; failing closed would
                # blank the bar.
                if out is not None and out != self.output:
                    return None, ""
            return self.focused, w.get("title") or ""

    def apply(self, event):
        with self.lock:
            for kind, data in event.items():
                if kind == "WorkspacesChanged":
                    self.ws_output = {
                        ws["id"]: ws.get("output") for ws in data["workspaces"]
                    }
                elif kind == "WindowsChanged":
                    self.windows = {
                        w["id"]: w for w in data["windows"]
                    }
                    for w in data["windows"]:
                        if w.get("is_focused"):
                            self.focused = w["id"]
                elif kind == "WindowOpenedOrChanged":
                    w = data["window"]
                    self.windows[w["id"]] = w
                    if w.get("is_focused"):
                        self.focused = w["id"]
                elif kind == "WindowFocusChanged":
                    self.focused = data.get("id")
                elif kind == "WindowClosed":
                    self.windows.pop(data["id"], None)
                    if self.focused == data["id"]:
                        self.focused = None


def reader(state):
    """Tail niri's event stream, respawning it if it ever dies -- waybar keeps
    this script alive for the whole session, so a compositor restart or a
    dropped socket must not leave the module permanently frozen."""
    while True:
        try:
            proc = subprocess.Popen(
                ["niri", "msg", "--json", "event-stream"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
            )
            for line in proc.stdout:
                line = line.strip()
                if not line:
                    continue
                try:
                    state.apply(json.loads(line))
                except (ValueError, KeyError):
                    continue          # malformed frame: skip, keep the stream
        except OSError:
            pass
        time.sleep(1)


def resolve_frames(title):
    """Yield the title developing out of a ghost field.

    Cells resolve in a random order rather than left to right: e-ink develops
    across the whole field at once, where a left-to-right reveal reads as a
    typewriter. Spaces are left as spaces so word shapes stay visible through
    the transition and the ghost stays airy rather than becoming a solid band.
    """
    chars = list(title)
    slots = [i for i, c in enumerate(chars) if not c.isspace()]
    random.shuffle(slots)

    # STEPS - 1 frames: the fully-resolved frame is NOT yielded here. The
    # caller emits it, because that is also the frame that drops the class and
    # hardens @faint to @muted -- emitting it from both places rendered it twice.
    for step in range(STEPS - 1):
        frac = step / (STEPS - 1)
        settled = set(slots[: round(frac * len(slots))])
        yield "".join(
            c if (i in settled or c.isspace()) else GHOST
            for i, c in enumerate(chars)
        )


def main():
    state = State()
    threading.Thread(target=reader, args=(state,), daemon=True).start()

    # niri dumps WorkspacesChanged/WindowsChanged the moment the stream opens,
    # over a local socket. Waiting for it costs nothing and stops the module
    # rendering one blank frame -- and then animating a second time -- on every
    # waybar start or reload.
    for _ in range(50):
        if state.visible()[0] is not None:
            break
        time.sleep(0.01)

    shown_id, shown_text = object(), None   # sentinel: force a first render

    while True:
        wid, title = state.visible()

        if wid != shown_id:
            # A different window has focus. Animate -- but re-read state every frame
            # so that rapid alt-tabbing retargets mid-flight instead of playing
            # a stale animation to completion.
            for frame in resolve_frames(title):
                live_id, live_title = state.visible()
                if live_id != wid:
                    break                    # superseded; restart on next pass
                emit(frame, resolving=frame != title)
                time.sleep(FRAME)
            else:
                shown_id, shown_text = wid, title
                emit(title, resolving=False)  # settle at @muted
                continue
        elif title != shown_text:
            # Same window, new title -- the churn case. Swap silently.
            shown_text = title
            emit(title, resolving=False)

        time.sleep(FRAME)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
