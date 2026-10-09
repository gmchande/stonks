import QtQuick
import Quickshell.Hyprland

// Hosts the window, whatever is on the bar, and decides what a request for
// it does with the popup and Hyprland's workspaces. The window itself is
// App's.
Item {
  id: root

  property var shell: null
  property var service: null
  property var updates: null
  property var trendColors: null

  readonly property alias app: app
  readonly property bool opened: app.opened
  // The window as Hyprland lists it, once it is mapped.
  readonly property var toplevel: app.opened ? Hyprland.toplevels.values.find(root.isWindow) || null : null
  // Hyprland has it on a workspace other than the focused one.
  readonly property bool elsewhere: !!toplevel && !!toplevel.workspace && toplevel.workspace !== Hyprland.focusedWorkspace

  function isWindow(t) {
    return t.title === "Stonks" && !!t.wayland && t.wayland.appId === "org.quickshell"
  }

  function popupOpen() {
    return !!shell && typeof shell.isPluginOpen === "function" && shell.isPluginOpen("grvc.stonks")
  }

  // The pill's right-click and IPC toggleWindow: the window open on this
  // workspace, with no popup over it, closes; otherwise it comes forward.
  function toggle() {
    if (app.opened && !elsewhere && !popupOpen()) app.close()
    else open("{}")
  }

  // Opens the window, or brings it forward where it is, closing the popup.
  // The payload may name a symbol and a range.
  function open(payloadJson) {
    var shown = app.opened
    if (popupOpen()) shell.hide("grvc.stonks")
    app.open(payloadJson)
    if (shown) focusWindow()
  }

  // Omarchy 4 configures Hyprland in Lua, where the classic dispatcher
  // syntax fails.
  function focusWindow() {
    if (!toplevel || !toplevel.address) return
    Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + toplevel.address + "\" })")
  }

  App {
    id: app
    service: root.service
    updates: root.updates
    trendColors: root.trendColors
  }
}
