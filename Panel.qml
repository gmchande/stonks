import QtQuick
import qs.Commons
import qs.Ui

// The watchlist popup. Owns popup lifecycle, keys, and look; the body reads
// the service and owns the list, search, scrub, help, and the motion when
// the chart changes.
Panel {
  id: root
  moduleName: "grvc.stonks"
  ipcTarget: "grvc.stonks"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var plugin: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("grvc.stonks") : null
  readonly property var service: plugin ? plugin.service : null
  readonly property var updates: plugin ? plugin.updates : null
  readonly property var trendColors: plugin ? plugin.trendColors : null
  readonly property string featuredSymbol: service ? service.featuredSymbol : ""
  readonly property string range: service ? service.range : "1D"
  readonly property int panelWidth: Style.space(480)
  // The popup shows up to six whole rows under its fixed content. Stated in
  // rows, so a different font or text size still gets six.
  readonly property int maxRows: 6
  readonly property int heightCap: panel.verticalContentInset + body.chromeHeight
    + maxRows * body.rowPitch - body.rowGap
  // The card's height for what the body shows: whole rows up to the cap, so
  // the footer ends the popup with no gap, or a view's own height.
  readonly property int fittedCardHeight: panel.fittedContentHeight(body.fittedHeight(
    Math.min(root.heightCap, panel.availableCardHeight > 0 ? panel.availableCardHeight : root.heightCap)
      - panel.verticalContentInset), root.heightCap)
  // While the popup is open its edge eases to that height, so a view that
  // changes it moves the edge instead of jumping it; the body lays out at
  // the new height at once and the card's edge reveals or covers it, the
  // footer or the search field riding it. The shell's card is an item
  // inside a full-screen surface, so no window resizes. Closing stops the
  // edge where it is for the fade. An open from closed settles it before
  // the first frame; one during the close's fade eases from where it is.
  property real cardHeight: 0
  onFittedCardHeightChanged: if (root.opened) easeEdge()
  NumberAnimation { id: edgeEase; target: root; property: "cardHeight"; duration: 160; easing.type: Easing.OutCubic }
  function easeEdge() {
    edgeEase.stop()
    edgeEase.to = root.fittedCardHeight
    edgeEase.start()
  }

  // The first visit there ever was says how Stonks is moved and changed,
  // once: the service saves that it has. A popup opened while the service
  // still reads its file says it as soon as the service is ready. A visit
  // whose footer has a notice ahead of the hint (the data file can't be
  // read, an update waits) neither shows nor records it: a later one does.
  function offerHint() {
    if (!root.opened || !service || !service.pluginsReady || service.hinted || body.notice !== "") return
    body.showFirstRunHint()
    service.persist({ hinted: true })
  }
  readonly property bool serviceReady: !!service && service.pluginsReady === true
  onServiceReadyChanged: offerHint()

  // Where the card stands along the bar, held from an open until the next.
  // The shell places the card under its anchor live (KeyboardPanel's
  // `cardOrigin`), and the pill widens or narrows as `c` or a featured
  // symbol changes what it says, which moved the open card sideways. So the
  // card's anchor is a stand-in, put where the pill is as the popup opens
  // from closed; an open during the close fade keeps it, since the card is
  // still on screen. It sits on the bar window's content, the item the shell
  // measures the anchor against, so the shell sees it move.
  Item {
    id: heldAnchor
    parent: panel.anchorWindow ? panel.anchorWindow.contentItem : null
    visible: false
  }
  function holdPlace() {
    if (!root.anchorItem || !heldAnchor.parent) return
    var at = root.anchorItem.mapToItem(heldAnchor.parent, 0, 0)
    heldAnchor.x = at.x
    heldAnchor.y = at.y
    heldAnchor.width = root.anchorItem.width
    heldAnchor.height = root.anchorItem.height
  }

  // The views reset as the popup opens, before its first frame, not as it
  // closes: the card fades out showing what you were looking at. Shown
  // first, so the body reads the service again (its held inputs) and the
  // reset lays out the latest. An open while open changes nothing on screen.
  function open() {
    var opening = !root.opened
    var fading = opening && panel.visible
    root.controller.show()
    // Before the hint is offered: the footer's notices go ahead of it.
    if (updates) updates.check()
    if (opening) {
      body.resetInteraction()
      offerHint()
      if (fading) easeEdge()
      else {
        holdPlace()
        edgeEase.stop()
        root.cardHeight = root.fittedCardHeight
      }
    }
    requestFundamentals()
    if (opening) body.motion.revealChart()
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    body.freeze()
    edgeEase.stop()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
  }

  // The cap and P/E for the symbol on show while the popup is open; the
  // service asks for the chart's history itself.
  function requestFundamentals() {
    if (root.opened && service && featuredSymbol) service.fetchFundamentals(featuredSymbol)
  }

  function refresh() {
    if (service) service.refresh()
    requestFundamentals()
  }

  function refocusKeys() { Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() }) }

  onFeaturedSymbolChanged: requestFundamentals()

  KeyboardPanel {
    id: panel
    anchorItem: heldAnchor
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.panelWidth)
    contentHeight: Math.round(root.cardHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // The body is laid out at the card's new height while the edge eases.
      clip: true
      blocked: body.ownsKeys
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) body.moveCursor(dy)
        if (dx !== 0) body.nudgeScrub(dx)
      }
      onActivateRequested: body.featureSymbol(body.watchlist.cursorRow)
      onCloseRequested: {
        if (body.showingHelp) body.showingHelp = false
        else if (!body.endScrub()) root.close()
      }
      onDeleteRequested: body.removeRow(body.watchlist.cursorRow)
      onTabRequested: function(direction) {
        body.showingHelp = false
        root.switchPanel(direction)
      }
      onTextKey: function(t) {
        if (t === "?") body.toggleHelp()
        else if (t === "a" || t === "+") body.startAdding()
        else if (t === "c") body.cycleChangeMode()
        else if (t === "r") root.refresh()
        else if (t === "[") body.stepRange(-1)
        else if (t === "]") body.stepRange(1)
        else if (t === "p") body.replay(false)
        else if (t === "P") body.replay(true)
        else if (t === "s") body.toggleStyle()
        else if (t === "o") body.cycleOrder()
        else if (t === "O") body.reverseOrder()
        else if (t === "w") body.openListMenu()
        else if (t === "W") body.openManageLists()
        else if (t === "m") body.openSymbolLists(body.watchlist.cursorRow)
        else if (t === "u") body.undoRemoval()
        else if (t === ",") body.stepList(-1)
        else if (t === ".") body.stepList(1)
        else if (t === "J") body.moveSelected(1)
        else if (t === "K") body.moveSelected(-1)
        else if (t >= "1" && t <= "9") body.featureAt(Number(t) - 1)
      }

      StonksBody {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.fittedCardHeight - panel.verticalContentInset
        // The card's edge as it eases: the footer and the field ride it.
        edge: Math.round(root.cardHeight) - panel.verticalContentInset
        service: root.service
        updates: root.updates
        surfaceOpen: root.opened
        failClosedHeader: true
        chartHeight: Style.space(190)
        foreground: root.bar ? root.bar.foreground : Color.foreground
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        upColor: root.trendColors ? root.trendColors.up : Color.foreground
        downColor: Color.urgent
        // The card's colour, opaque whatever the theme's popup alpha.
        ground: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
        onKeysReleased: root.refocusKeys()
      }
    }
  }
}
