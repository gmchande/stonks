import QtQuick
import Quickshell.Io
import qs.Commons
import "Tones.js" as Tones
// Up and down, from the current theme: up its green (`Tones.upColor`), down
// the shell's urgent, its red. The shell's Color keeps only five roles, so
// the green is read from the theme's colors.toml here. A theme switch
// replaces the theme's files and then pushes its palette to the shell, so a
// change of the shell's colours is when the file is new: it is read again
// then.
Item {
  id: root

  // The green as colors.toml spells it, "" when the theme has none.
  property string green: ""

  readonly property color up: Tones.upColor(green, Color.urgent, Color.foreground)
  readonly property color down: Color.urgent

  // A theme switch puts the theme's files in place and then hands the shell
  // its palette and its shell.toml (`Color.loadColors`, `Color.loadShell`),
  // so either is when the file is read again; up follows as the read lands.
  // The shell's values are reassigned on every theme applied, so a theme
  // whose foreground, accent, and red match the last one's is read too.
  FileView {
    id: colors
    path: Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: root.green = Tones.themeColor(text(), ["green", "color2"])
    onLoadFailed: root.green = ""
  }

  Connections {
    target: Color
    function onForegroundChanged() { colors.reload() }
    function onAccentChanged() { colors.reload() }
    function onUrgentChanged() { colors.reload() }
    function onShellValuesChanged() { colors.reload() }
  }
}
