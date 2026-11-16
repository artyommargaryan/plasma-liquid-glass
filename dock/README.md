# dock/ - task manager with hover magnification

A standalone build of Plasma's task manager applet (`applets/taskmanager` of
[plasma-desktop](https://invent.kde.org/plasma/plasma-desktop), tag `v6.8.2`, GPL-2.0-or-later, see the SPDX
headers of each file) under its own ids, so it installs next to the stock one:

- `org.liquidglass.taskmanager` - the plugin
- `org.liquidglass.icontasks` - "Icons-Only Task Manager (Liquid Glass)", the variant a dock uses

Changes against upstream (2026-11-16):

- **Hover magnification** (`magnification`, percent, 100 = off; slider on the widget's Appearance page). The icon
  under the pointer grows to that size; a neighbour swells only as the pointer nears it. Only the icon is
  transformed and it grows upwards from its bottom edge, so the layout and the indicator under it do not move.
  The icon is rendered at the magnified size, so it stays sharp. Growth stops at the top of the panel window.
  Code: `qml/Task.qml` (`zoomMax`, `zoomFactor`), `qml/main.qml` (`zoomPointerX`, `zoomEpoch`).
- While magnification is on, the hover frame and the icon's hover brightening are off.
- `magnificationPreviewX` (hidden): magnify as if the pointer were at that x inside the widget; for screenshots.
- Ids, `CMakeLists.txt` (standalone), metadata without translations. Strings keep Plasma's translation domain.

It is built against the installed Plasma and has to be rebuilt after a Plasma update, like the glass effect:

    cmake -S dock -B dock/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build dock/build -j
    sudo cmake --install dock/build

The sources follow Plasma 6.8; on another Plasma version, replace them with that version's `applets/taskmanager`
and re-apply the changes above. The idea of a magnifying fork of the task manager comes from
[macos-tahoe-liquid-kde](https://github.com/lestercorderomurillo/macos-tahoe-liquid-kde); no code of it is used here.
