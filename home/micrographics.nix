{ config, lib, pkgs, theme, ... }:

let
  # Today's remaining timed meetings from the calendar's secret iCal address, as
  # JSON [{title, start, end}] in epoch ms. The address is a password, so it lives
  # outside this public repo; without it the script exits 1 and the widget hides
  # its meeting lines.
  nextMeetings = pkgs.writers.writePython3Bin "next-meetings" {
    libraries = with pkgs.python3Packages; [ icalendar recurring-ical-events ];
    flakeIgnore = [ "E501" ];
  } ''
    import datetime
    import json
    import pathlib
    import sys
    import urllib.request

    import icalendar
    import recurring_ical_events

    try:
        url = (pathlib.Path.home() / ".config/micrographics/calendar-url").read_text().strip()
    except FileNotFoundError:
        sys.exit(1)

    with urllib.request.urlopen(url, timeout=30) as response:
        cal = icalendar.Calendar.from_ical(response.read())

    # Google names a primary calendar's feed after its owner's address
    me = "mailto:" + str(cal.get("X-WR-CALNAME", "")).lower()
    now = datetime.datetime.now().astimezone()
    midnight = (now + datetime.timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)


    def aware(t):
        # floating times are local
        return t if t.tzinfo else t.astimezone()


    def declined(event):
        attendees = event.get("ATTENDEE", [])
        if not isinstance(attendees, list):
            attendees = [attendees]
        return any(str(a).lower() == me and a.params.get("PARTSTAT") == "DECLINED" for a in attendees)


    meetings = []
    for event in recurring_ical_events.of(cal).between(now - datetime.timedelta(hours=12), midnight):
        start = event["DTSTART"].dt
        # all-day events carry a date, not a time: not meetings
        if not isinstance(start, datetime.datetime):
            continue
        start = aware(start)
        if "DTEND" in event:
            end = aware(event["DTEND"].dt)
        else:
            end = start + (event["DURATION"].dt if "DURATION" in event else datetime.timedelta())
        if end <= now or event.get("STATUS") == "CANCELLED" or declined(event):
            continue
        meetings.append({
            "title": str(event.get("SUMMARY", "Untitled")),
            "start": int(start.timestamp() * 1000),
            "end": int(end.timestamp() * 1000),
        })

    json.dump(sorted(meetings, key=lambda m: m["start"]), sys.stdout)
  '';

  # After Nothing OS 5's Micrographics lock screen clock: four lines of bold
  # capitals and pictograms, words set in pills and brackets, straight on the
  # wallpaper. It sits on the bottom layer, under windows: seen wherever the
  # corner is bare.
  shell = pkgs.writeTextDir "shell.qml" ''
    import QtQuick
    import QtQuick.Shapes
    import Quickshell
    import Quickshell.Io
    import Quickshell.Wayland

    ShellRoot {
      PanelWindow {
        id: win

        readonly property color ink: "#${theme.fg}"
        readonly property color paper: "#${theme.bg}"
        readonly property int px: 22
        readonly property int weight: Font.Medium
        // pill and bracket outlines
        readonly property real stroke: 1.5
        readonly property string family: "JetBrainsMono Nerd Font"

        // {temp, code, day} from Open-Meteo, or null until the first answer
        property var weather: null
        // today's timed meetings, soonest first: [{title, start, end}] in epoch ms;
        // null while there is no calendar (next-meetings exits 1)
        property var meetings: null
        readonly property var meeting: {
          const now = clock.date.getTime();
          return meetings ? meetings.find(m => m.end > now) ?? null : null;
        }

        anchors { top: true; right: true }
        margins { top: 32; right: 32 }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "micrographics"
        color: "transparent"
        implicitWidth: face.width
        implicitHeight: face.height
        // clicks fall through to the wallpaper
        mask: Region {}

        SystemClock { id: clock; precision: SystemClock.Minutes }

        // WMO weather code -> pictograms and a label
        function sky(w) {
          const c = w.code, d = w.day;
          const sun = "\u{f05a8}", moon = "\u{f0594}", cloud = "\u{f0590}";
          if (c === 0) return { icons: d ? sun : moon, text: d ? "SUNNY" : "CLEAR" };
          if (c <= 2) return { icons: (d ? sun : moon) + cloud, text: d ? "PARTLY SUNNY" : "PARTLY CLOUDY" };
          if (c === 3) return { icons: cloud, text: "OVERCAST" };
          if (c <= 48) return { icons: "\u{f0591}", text: "FOG" };
          if (c <= 57) return { icons: "\u{f0597}", text: "DRIZZLE" };
          if (c <= 67) return { icons: "\u{f0597}", text: "RAIN" };
          if (c <= 77) return { icons: "\u{f0598}", text: "SNOW" };
          if (c <= 82) return { icons: "\u{f0596}", text: "SHOWERS" };
          if (c <= 86) return { icons: "\u{f0598}", text: "SNOW SHOWERS" };
          return { icons: "\u{f0593}", text: "THUNDERSTORM" };
        }

        function span(mins) {
          if (mins < 60) return mins + "MIN";
          const m = mins % 60;
          return Math.floor(mins / 60) + "H" + (m ? String(m).padStart(2, "0") : "");
        }

        // the last line, as [verb, pictogram, bracketed span, suffix]
        readonly property var when: {
          if (!meeting) return null;
          const now = clock.date.getTime();
          if (meeting.start <= now)
            return ["STARTED", "\u{f0e47}", span(Math.round((now - meeting.start) / 60000)), "AGO"];
          const left = Math.round((meeting.start - now) / 60000);
          if (left < 60) return ["STARTS IN", "\u{f051f}", span(left), ""];
          return ["STARTS AT", "\u{f0150}", Qt.formatTime(new Date(meeting.start), "HH:mm"), ""];
        }

        // Montevideo, from the system time zone
        function fetchWeather() {
          const xhr = new XMLHttpRequest();
          xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return;
            const c = JSON.parse(xhr.responseText).current;
            win.weather = { temp: Math.round(c.temperature_2m), code: c.weather_code, day: c.is_day === 1 };
          };
          xhr.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=-34.90&longitude=-56.16&current=temperature_2m,weather_code,is_day");
          xhr.send();
        }
        Timer { interval: 15 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: win.fetchWeather() }

        Process {
          id: agenda
          command: [ "${lib.getExe nextMeetings}" ]
          // a failed fetch prints nothing and keeps the last list
          stdout: StdioCollector {
            onStreamFinished: { try { win.meetings = JSON.parse(this.text) } catch (e) {} }
          }
        }
        Timer { interval: 5 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: agenda.running = true }

        component Word: Text {
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          color: win.ink
          font { family: win.family; weight: win.weight; pixelSize: win.px }
        }

        // pictograms run a size up, so they weigh as much as the capitals
        component Glyph: Word { font.pixelSize: Math.round(win.px * 1.2) }

        // a word in a capsule: filled (ink, paper text) or outlined
        component Pill: Rectangle {
          id: pill
          property alias text: label.text
          property bool filled: false
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          implicitHeight: Math.round(win.px * 1.3)
          implicitWidth: Math.max(implicitHeight, label.implicitWidth + win.px * 0.8)
          radius: height / 2
          color: filled ? win.ink : "transparent"
          border { width: filled ? 0 : win.stroke; color: win.ink }
          Word { id: label; anchors.centerIn: parent; color: pill.filled ? win.paper : win.ink }
        }

        // a word under a rounded corner bracket, open to the right and below
        component Bracket: Item {
          id: chip
          property alias text: label.text
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          implicitHeight: Math.round(win.px * 1.3)
          implicitWidth: label.implicitWidth + win.px * 0.5
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeColor: win.ink
              strokeWidth: win.stroke
              fillColor: "transparent"
              startX: 1; startY: chip.height
              PathLine { x: 1; y: win.px * 0.45 + 1 }
              PathArc { x: win.px * 0.45 + 1; y: 1; radiusX: win.px * 0.45; radiusY: win.px * 0.45 }
              PathLine { x: chip.width; y: 1 }
            }
          }
          Word { id: label; anchors { right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 1 } }
        }

        Item {
          id: face
          // the meeting title elides instead of widening the face
          readonly property int inner: Math.max(line1.implicitWidth, line2.implicitWidth, line4.implicitWidth, win.px * 17)
          width: inner
          height: lines.implicitHeight

          Column {
            id: lines
            spacing: Math.round(win.px * 0.45)

            Row {
              id: line1
              spacing: Math.round(win.px * 0.35)
              Word { text: Qt.formatDate(clock.date, "ddd").toUpperCase() }
              Pill { filled: true; text: Qt.formatDate(clock.date, "d") }
              Pill { text: Qt.formatDate(clock.date, "MMM").toUpperCase() }
              Item { width: win.px * 0.25; height: 1 }
              Word { text: Qt.formatTime(clock.date, "HH:mm") }
              // a terminal's block cursor, blinking
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(win.px * 0.55); height: Math.round(win.px * 1.05)
                color: win.ink
                SequentialAnimation on opacity {
                  loops: Animation.Infinite
                  PropertyAction { value: 1 }
                  PauseAnimation { duration: 600 }
                  PropertyAction { value: 0 }
                  PauseAnimation { duration: 600 }
                }
              }
            }

            Row {
              id: line2
              visible: win.weather !== null
              spacing: Math.round(win.px * 0.35)
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Word { text: win.weather ? win.weather.temp + "°" : "" }
                Pill { text: "C" }
              }
              Glyph { text: win.weather ? win.sky(win.weather).icons : "" }
              Pill { filled: true; text: win.weather ? win.sky(win.weather).text : "" }
            }

            Row {
              id: line3
              visible: win.meetings !== null
              spacing: Math.round(win.px * 0.35)
              Glyph { id: voice; text: win.meeting ? "\u{f05cb}" : "\u{f00ef}" }
              Word {
                width: face.inner - voice.width - parent.spacing
                elide: Text.ElideRight
                text: (win.meeting ? win.meeting.title : "No more meetings").toUpperCase()
              }
            }

            Row {
              id: line4
              visible: win.when !== null
              spacing: Math.round(win.px * 0.35)
              Pill { text: "\u{f0054}" }
              Word { text: win.when ? win.when[0] : "" }
              Glyph { text: win.when ? win.when[1] : "" }
              Bracket { text: win.when ? win.when[2] : "" }
              Word { visible: text !== ""; text: win.when ? win.when[3] : "" }
            }
          }
        }
      }
    }
  '';
in
{
  home.packages = [ nextMeetings ];

  # its own quickshell, apart from clock.nix's peek, supervised the same way
  systemd.user.services.micrographics = {
    Unit = {
      Description = "Micrographics corner clock";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe config.programs.quickshell.package} --path ${shell}/shell.qml";
      Restart = "always";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
