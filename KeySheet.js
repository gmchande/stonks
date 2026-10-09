.import "Settings.js" as Settings

// What the key sheet shows. Knows nothing of how the keys are handled.

// The key sheet behind the header's ?: every binding, grouped by what it
// touches. The mouse can do all of it too; this is the list for people who
// would rather not reach for it.
function hintGroups(surface, order) {
  var navigate = [
    { key: "↑ ↓", does: "Move the row cursor" },
    { key: "⏎", does: "Feature the cursor row" },
    { key: "1–9", does: "Feature that row" }
  ]
  if (surface !== "window") navigate.push({ key: "tab", does: "Next panel on the bar" })
  var watchlist = [
    { key: "a  +", does: "Add a symbol" },
    { key: "x", does: "Remove the cursor row" },
    { key: "u", does: "Undo a removal" },
    { key: "o", does: "Cycle the list order" }
  ]
  if (Settings.normalizeOrder(order) !== "manual") watchlist.push({ key: "O", does: "Reverse the order" })
  if (Settings.normalizeOrder(order) === "manual") {
    watchlist.push({ key: "J K", does: "Move the cursor row" })
    watchlist.push({ key: "⇧ wheel", does: "Move the hovered row" })
    watchlist.push({ key: "drag", does: "Move a row by hand" })
  }
  return [
    { title: "Navigate", rows: navigate },
    { title: "Chart", rows: [
      { key: "← →", does: "Scrub one chart step" },
      { key: "p", does: "Replay the shown chart" },
      { key: "P", does: "Replay in slow motion" },
      { key: "esc", does: "Clear the scrub" }
    ]},
    { title: "Range", rows: [
      { key: "[ ]", does: "Change the chart range" }
    ]},
    { title: "Lists", rows: [
      { key: ", .", does: "Step lists, scroll kept" },
      { key: "w", does: "Open the list menu" },
      { key: "W", does: "Manage lists" },
      { key: "m", does: "The cursor row's lists" }
    ]},
    { title: "Watchlist", rows: watchlist },
    { title: "Look", rows: [
      { key: "s", does: "Switch smooth and retro" },
      // The change mode is the day's: on a range the hero shows the period,
      // so c changes the rows and, on the day, the hero.
      { key: "c", does: "Cycle the day's change" },
      { key: "r", does: "Refresh quotes" },
      { key: "?", does: "This sheet; esc closes" }
    ]}
  ]
}
