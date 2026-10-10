# Contributing to Stonks

The project's rules, for people and agents alike.

A watchlist for the Omarchy shell (Quickshell): a bar pill, a popup with a
day chart you can scrub, and a tiled app window that keeps working with the
pill turned off. Stack is QML plus one plain JavaScript module, because
shell plugins must be QML and the shell already ships the UI kit, theme
tokens, and popup machinery. No build step, no gems, no Node runtime at
run time.

## Simplicity

- Simple means untangled, not short or familiar: each piece changes on its own. Complecting is the fault to refuse: state braided with time, one component knowing two concerns, a flag that couples two paths, a result that depends on hidden order.
- Before a task, untangle what you are about to touch if there is a genuine chance. After every task the code is simpler than before: fewer concerns tangled together, which line and file counts don't measure.
- No speculative robustness: no handling for cases this data and its users cannot produce.
- Delete what nothing uses.

## Run it

- Run your checkout as the plugin: clone it to
  `~/.config/omarchy/plugins/grvc.stonks` (README, Install by hand).
  After a change, restart the shell (`omarchy restart shell`). Hot reload
  is not enough: `Plugin.qml` is `keepLoaded`, and a reload can leave the
  previous window alive and answering IPC with stale code.
- Reload plugins: `omarchy-shell shell rescanPlugins`
- Enable in the bar: `omarchy plugin enable grvc.stonks center`
- Open the window: `omarchy-shell grvc.stonks openWindow '{}'` (or a
  payload naming a `symbol` and a `range`); toggle it:
  `omarchy-shell grvc.stonks toggleWindow`, which a key binding can run;
  Omarchy gives plugins no way to add one, so none is a default.
- Open the popup: `omarchy-shell shell toggle grvc.stonks`, as the bar's
  number keys do; the shell opens the focused screen's pill's popup.
- Validate the manifest: `omarchy plugin validate .`

## Verify it

- `test/all.sh` runs everything and exits non-zero on any failure: `bun test` for the rule files (loaded by `test/load.js`), `test/boundaries.sh` (which files may run a command, touch a file, start a feed, or name an endpoint, the one IPC target, and Hyprland only in the window's host; pure rule files with no colour of their own; no literal colours; a bar entry holding only the pill's forms; no `Sprite.qml`), QML lint against the installed shell (`test/lint.sh`: a missing or failing linter, or any diagnostic outside its baseline, fails; the baseline is the named `Style`, `Color`, and inherited `bar` members the shell types as `QtObject`, and a counted list of known warnings to fix; `test/lint.sh self-check` shows a missing linter, an unqualified access, and an outer id read in a file without `pragma ComponentBehavior: Bound` failing it), `omarchy plugin validate` on what a clone holds (the tracked files as they are in the checkout, an uncommitted edit counting, never an ignored one such as `out/`, so a tracked link still fails it), `desktop-file-validate` on the launcher entry, `bun test/mark-svg.js check` (the launcher icon is the mark as `Cells.markLevels` draws it), `test/qml/crash-check.sh` (how a test's Quickshell ends, on a stand-in: a crash, a timeout, an interrupt, and runs side by side), fifteen Quickshell harnesses under `test/qml/` (quote runs and the history queue, and service persistence, a data file that can't be read never written over, which symbols ask for a cap and P/E, on the real feeds, and the version watch on its manifest; `popup.sh` for the real Panel and a real pill, the first-run hint through a restarted Service, and the footer's notices on the next open and their clicks; `popup-motion.sh` for the popup card's edge on rendered frames, through the real Panel and Service with real keys: a list switch either way, the key sheet closing, a removal and its undo, an add that lands, a membership change from elsewhere, and the list menu each ease the edge in 160 ms with the footer riding it whole over the rows, and an open from closed holds its fitted height; `pointer.sh` for pointer, wheel, and search on the shared body; four for the window's keys and pointer on the real Service, split by flow: `window-rows.sh` (removal, the sorted view's guards, help, moves by keys, drag, and the wheel, the cursor, rows held by a close, the footer's notices), `window-search.sh` (results that belong to their query, the lookup preview, one preview across two surfaces), `window-adds.sh` (adds held until their price, landing, late and double adds, adds from search), and `window-motion.sh` (repaints, replays, the day and the hero, draw-ins on rendered frames, the first open's and one on a busy machine among them, a closing surface held); `lists.sh` for named watchlists with real keys; `range.sh` for the real `Plugin.qml` with two pills: the shared chart range through the window, the payload, and a restarted service, the window opened and closed by the pill's right-click and IPC against the popup and another workspace, IPC with no pill, the pill's day on every range, its icon form as the mark, read from its drawn cells, falling on a down day and climbing on an up one, and its own form in the right section across moves, up in the theme's green, following a theme switch, one that changes only the green too, and the foreground on Hackerman, and no history fetched with no surface open; `overnight.sh` for overnight prices through the real Service and window on a clock it sets, at saved moments from `test/fixtures/overnight`: who Robinhood is asked for and when, the 1D chart as one New York day on a weekday, a weekend, and Sunday night, the overnight line and its dimming, and none for a quiet symbol, an index, a cryptocurrency, or the weekend, on the first live night (`live-2026-10-05`) a quiet symbol kept on Friday's chart and a print alone after midnight drawn and scrubbed in both looks and the line on 1M at rest and scrubbed, a night held open across midnight (`2026-10-06-2300` to `2026-10-07-1153`): Tuesday's chart until Wednesday's first print, then Wednesday's, measured from Tuesday's close at rest, scrubbed, and since the open, and the listing sweep's moments (`sweep-2026-10-07-0100`, `sweep-2026-10-07-1455`): PSIX and BLDP, which Robinhood does not trade all day, asked about once and never for their prints, with no overnight line from a stray night trade and Yahoo's day from the left edge, laid out a print a step, the keys stepping print to print, and SPY on Yahoo's day while Robinhood's instruments are down, then its calendar day when they answer, Tokyo's line, and its row's drawn pixels, broken across its lunch, and, for a reader in New York, Tokyo's next open naming JST and a Nasdaq scrub naming no zone, and the S&P 500 at 06:00 and 01:00 with no pre-market, no tail after its close, and its next open; `fetch.sh` for the fetch policy through the real Plugin, Service, window, and two pills on a clock it sets, at saved moments from `test/fixtures/overnight` (`fetch-2026-10-07` and the 14:55 sweep): requests per listing (a busy stock, a thin one, an ETF, an index, a cryptocurrency, London, Tokyo at lunch, Toronto) at 06:05, 11:00, 16:35, 23:00, and Saturday noon, with nothing open and with the window open, each within one of its market's cadence; an offline start on saved quotes, said as old, warning only 90 s after the ask ("! No data" on a row with nothing saved), the no-answer ladder, and the quotes saved again at once and within ten minutes; an open mid-session finding the rows fresh, asking only for the stale in one run, with no "!" or "As of" on any frame; `r` twice sending one run; Yahoo refusing, an answer let through before the refusal reopening nothing, a lone request per pause, "! Update overdue" from 90 s, a range failing at once, the asks nobody watches dropped, and recovery; a network back within seconds, and a preview held meanwhile fetched after; 50 symbols past the budget, a range picked then still getting its history; rows a day old kept warm by their calendars, the S&P 500's (the US calendar) among them; the pill's wheel; an add's run of its own; a removal and its undo fetching nothing; a preview fetched once; and, in a second run, a US holiday while London and Toronto trade; and `layout.sh`, which asserts that nothing moves across looks, featured symbols, ranges, lists, and both surface widths, measuring the price and change as displayed, that both info lines, and the line under the price on 1M, are whole, and that a coin under a cent (SHIB-USD) and a six-figure price (BRK-A) show their own decimals in the hero in both looks, the row, and a scrub), and the offscreen renders of `StonksBody` and the pill into `out/render/`, each in an installed Omarchy theme where the shell reads the current one (the theme its state's name ends with, else Tokyo Night), including `w22-*` (the 22-symbol list, both surfaces and looks at identical state), `popup-overnight-*` (the saved overnight moments in both looks, the live night's lone prints, its 1M hero at rest and scrubbed, and the day-window moments of 3 to 7 October, `2026-10-*`, among them 01:00 scrubbed), `popup-sweep-*` (the listing sweep, every kind of listing on 1D in both looks: NBIS, PSIX, SPY, BLDP, the S&P 500, BTC-USD, SHEL.L, and 7203.T on 7 October at 14:55, 01:00, and 06:00, and Saturday 3 October at noon; and SHIB-USD, RY.TO, BRK-A, and BRK-B in session on 8 October at 10:54), `popup-fill-*` (the 1D wash on an up, a down, and a crossing day in both looks, in Tokyo Night and in Kanagawa), `theme-<look>-<theme>` (the gallery: the popup on a crossing day and every pill form, in Tokyo Night, Catppuccin Latte, Hackerman, and White; `render.sh theme-smooth-<theme>` renders any installed theme), `popup-hint-*` (the first-run hint in the footer), `popup-notice-*` (the footer's notices), `fetch-saved-*` (quotes kept from an earlier session, each saying its day) and `fetch-overdue-*` (a refresh unanswered for 90 s), in both looks, `pill-sheet.png` (the real pill in every bar style and look, the icon form on a down and an up day, on a horizontal and a vertical bar, and in the right section with no form picked there, beside Omarchy's Bluetooth icon to size it against; `pill-sheet-large` the same at the shell's text size 16), and `sprite-candidates.png`. Needs the Wayland session. The harnesses and renders run side by side, each with its own HOME, QML cache, and fake curl and `omarchy` state, and a reader in New York (`TZ`, `lib.sh`), so the suite takes as long as its longest, the offscreen renders: about two minutes. An interrupt stops every harness's process group and waits for them to empty.
- Tests are few and end to end. A new behaviour gets a step in a flow harness that drives the real Service and surfaces with real keys and pointer (like `lists.sh`), or an offscreen render; not a unit test of the function behind it.
- A change to what a chart, row, or figure shows is planned, built, and checked on every kind of listing it can meet, at each moment it touches: a busy US stock, a thin one with no extended-hours trades, an ETF, an index, a cryptocurrency, and a non-US listing. The 1D calendar day was checked on NBIS alone and drew a thin stock's morning empty.
- Before adding a test, name the user-visible behaviour it protects and the regression that would fail it. If an existing flow already catches that regression, extend that flow or add nothing. A bug fix's test must fail on the code before the fix.
- `bun test` is for pure data rules a flow cannot pin down cheaply: parsers against saved responses (`test/saved.test.js`), calendars and number formatting (`test/model.test.js`). A test that reads a saved answer goes in `saved.test.js`, so the pure rules run on any clone.
- The saved Yahoo and Robinhood answers under `test/fixtures/` are private: their terms don't allow republishing them. The tests read the checkout's own `test/fixtures/`, else its main checkout's, so a linked worktree needs no copy (`test/fixtures-dir.sh`), and never through a link. Without them, `saved.test.js`, the Quickshell harnesses, and the renders skip, each saying why, and the rest runs: the pure rules, the boundaries, lint and its self-check, the frame checker's, the tophat's, and the crash handling's self-checks, the mark, the launcher entry, and `omarchy plugin validate`. `test/all.sh` ends "ALL PASS" only when nothing skipped, otherwise "PASSED, N SKIPPED (no saved answers)".
- `finish` fails a run on a FAIL line, a `TypeError`, `ReferenceError`, or `Error:` in the log, a Qt warning naming a plugin file (`stonks_warnings`: a binding loop, a `setPaused()`, a handler turned away), a host's budget holding a request back (only `fetch.sh`, whose long list does it on purpose, sets `STONKS_BUDGET_EXPECTED`), a timeout, a non-zero exit, or a missing finish line: under Quickshell a step that throws still exits 0.
- Every Quickshell a test starts goes through `quickshell_run` (`test/qml/quickshell.sh`; `run_qs` and `render.sh` call it). Its crash handler is off (`QS_DISABLE_CRASH_HANDLER`): on a crash it would fork a crash reporter and start Quickshell again in the crashed pid, which reruns a harness from the top into the same log, where it can pass. So a crash is the started pid dying on its signal, and fails the run with `FAIL Quickshell crashed: SIGABRT (6), pid N; its core dump: coredumpctl info N`: read the core; a rerun is not a fix. Any other non-zero exit, such as the 255 of a file that fails to load, adds `FAIL Quickshell exited with code N; its log says why`: there is no core to read. Exit 1, a harness's own failure, adds nothing: its FAIL lines already say it. Each run is a process group of its own, stopped as the run ends however it ends (a pass, a failure, a timeout, a crash, an interrupt), and everything it starts carries the run's mark (`STONKS_RUN`, `test/procs.sh`, the tophat's idea), so a process that left the group is found by the mark, never by name, stopped, and fails the run.
- Each `quickshell_run` gives its Quickshell a runtime folder of its own (`XDG_RUNTIME_DIR`), linking every entry of the session's but `quickshell/`, and removes it as the run ends, however it ends: Quickshell 0.3.1 leaves each instance's folder, with its logs, in `$XDG_RUNTIME_DIR/quickshell`, and tens of thousands of test runs filled the session's. Its name is short and in `/tmp`, whatever `TMPDIR` says: Hyprland's sockets under it must fit a Unix socket's 107 bytes. A run whose folder can't be made never starts Quickshell, and one whose Quickshell says it saved in the session's folder fails; `crash-check.sh` proves these with its stand-in.
- A harness ends Quickshell only through `HarnessExit.qml` (set its `exitCode`, then start it), which waits until no `TestCase` is running; `test/boundaries.sh` fails any other `Qt.exit` or `Qt.quit` under `test/`. An exit during QtTest's `wait()` tears the engine down inside that wait and aborts with a core dump, so a harness keeps no watchdog of its own: its script's `run_qs` timeout is its one timeout, and the TERM that ends it leaves no core (Quickshell 0.3.1 doesn't handle TERM).
- `test/qml/fetch-day.sh`, run by hand and not by `test/all.sh` (it takes minutes), counts a weekday and a weekend of glances for a long list's shape through the real Service and window, and estimates the bytes: the numbers a change to fetching is weighed by.
- A render fails when its log has a runtime error or a Qt warning naming a plugin file, or it wrote no fresh picture: `render.qml` exits 0 once it has grabbed a frame. It grabs 300 ms in; the live dot, retro's live cap, and a text cursor never settle, so a render that shows one changes with that wait.
- Count fake-curl calls through a new `FileView` for each read; after `reload()`, `text()` can still return the old count.
- The popup's window (`PanelWindow`) does not load on the offscreen platform. Popup flows drive the real `Panel` in `popup.sh`, under the Wayland session, without mapping it: the script patches `open: false` into its copy of `Panel.qml`. An unmapped pill has no bar window to place a card from, so `popup.sh` copies the shell's `Ui` and lets its `KeyboardPanel` take the bar window and the pill's spot from the flow; the shell's own placement runs on them. A second pill sits on an item the flow hands its card and its `HeldAnchor` as the bar window's content, so the shell places the card from the pill's own spot as the pill changes width; `pointer.sh`, whose window maps offscreen, shows a `HeldAnchor` finding a real bar window through its pill. An unmapped popup renders no frames, so `popup-motion.sh` puts its copy of `Panel.qml`'s card in `CardWindow.qml`, a plain window around the shell's own `BorderSurface` that copies only what lives on `KeyboardPanel` itself, its lines named in its comment: keep them in step when the shell changes.
- `keys.sh` presses every key the key sheet draws and the README's table lists, with real keys through the real popup (in `CardWindow.qml`) and window, a row ending "(popup)" or "(window)" on that surface alone, and fails on a key that changes nothing the surface shows. A new key goes in the README's table; one that needs something to act on (a range to step back from, a removal to undo) gets that in the walk's `setups`.
- A script patches its copies of plugin files only through `patch_copy` (`lib.sh`), which stops the script before Quickshell starts when a patch changes nothing. The feed harnesses (`run.sh`, `history.sh`) and `overnight.sh`, whose later moments hold one symbol's day, patch a 200 ms retry pause into theirs.
- An order of file events Quickshell can't be made to hold is stepped through a stand-in: `service.sh` patches `DataFileStandIn.qml` in for the data file's `FileView` in a second copy of `Service.qml`. The stand-in keeps only what Quickshell 0.3.1's `FileView` does there, each named from its source; a change to the data file's handling that leans on more of `FileView` adds it there first, from that source.
- A check on motion reads it on its frames, from a change handler on the animated property, and a wait waits on an event (`within`, `tryVerify`); a fixed sleep into an animation or a debounce fails on a slow frame.
- What a motion looks like is judged on rendered frames, not on the property behind it: `FrameGrab.qml` grabs an item on every frame and `frames.js` judges them (`frame_tools`, `lib.sh`), as `window-motion.sh` does for the draw-in, the window's first open in a fresh process (judged from its first painted frame: every canvas paints a frame late on a window's first show), a held chart, a day half gone (`aapl-noon`, AAPL's day cut at noon, its ink's end held against its newest print), the header's animal crossfading across the close and changing at once on a new symbol (`turn`, `turn:0`), and a closing surface, `layout.sh` for a live day held while the next chart loads, and `popup-motion.sh` for the popup card's edge (`edge`, `edgeheld`), its travel read from where the card stood before the mark. A property can move while the picture shows nothing. Offscreen, Qt renders on its own cadence while animations advance on QtCore's 16 ms clock, and `afterAnimating` fires on every render, so a frame is kept only when the clock has ticked since the last one, and timed by that tick, or by the mark when it came after: timed by the render, a late clock showed each moment later than it was, and a 160 ms edge read as 230 under the suite's load. `window-motion.sh` holds a draw-in's renders longer and longer on purpose, a busy machine, which frames timed by the render read as about 420 ms. `frames.js` reads a draw-in's length and start, and an edge's, from its frames' own curve, never from the mark, so a late start or a busy machine's uneven frames move neither; a draw-in is read across its ink's extent, taken from the last frame's own ink (`drawin:ink`), never from the painter, so a day partly gone is judged on its own sweep and a sweep that stops short and shows the rest at its end fails. `bun test/qml/frames.js self-check`, run by `test/all.sh`, shows wrong pictures failing it: 0, 160, and 400 ms, on even and uneven frames, a start 200 ms late, a chart that begins a quarter or 60% drawn, hidden ink, a slit, a chart cut short, whole at once, a tail, a half day swept across the whole plot, swept to 45% with the rest shown at its end, or cut short; an edge that jumps, never moves, takes 100, 240, or 400 ms, starts 200 ms late, jumps 60% at the mark, or shows rows through the footer riding it; an open that grows; an animal that turns in 60 or 320 ms, starts 200 ms late, changes at once where it should turn or turns where it should change at once, fades out and then in through nothing or away for good, or changes at once through a blank frame, 320 ms late, or back and forth; and a right draw-in in retro's whole columns, a half day swept to its newest print in either look, a right edge, and a right turn, on uneven frames too, passing. `window-motion.sh` runs the same capture and judge on a real draw-in made 160 ms, 400 ms, none, and one starting 60% drawn, and each fails.
- Visual checks are those renders (`test/qml/render.sh`). Whoever built a visible change tries it by hand before its pull request, the way a user would, through the everyday flows end to end whatever the change names: open the popup from the pill, add a symbol through search, switch lists, remove and undo, feature a row, change the range and look, and use the window. Motion is judged frame by frame from a recording; a screenshot can't show it.
- A limit blamed on the shell is confirmed in its code (`/usr/share/omarchy/shell/`) before a change designs around it.

## Layout

- `manifest.json` — plugin id, kinds (`service`, `bar-widget`), defaults,
  and the bar-pill schema. It declares no `panel`, so the shell sends
  `shell toggle grvc.stonks` and the bar's number keys to the pill's popup
  (`shell.qml`, `isBarWidgetPanelPlugin`).
- `Plugin.qml` — the manifest's service entry: composes the data service,
  the theme's up and down, the version watch, the window's host, and the
  IPC target side by side. The pills and the popup reach them through
  `serviceFor("grvc.stonks")` as `service`, `trendColors`, `updates`,
  `windowHost`, and `ipc`.
- `TrendColors.qml` — up and down from the current theme: up its green
  (`Tones.upColor`), read from the theme's `colors.toml`, since the shell's
  `Color` keeps only five roles; down the shell's urgent. A theme switch
  puts the files in place and then hands the shell its palette and its
  shell.toml, so a change of the shell's colours or values is when it reads
  the file again, a theme that changes only its green included.
- `Updates.qml` — the version watch: `omarchy plugin update` moves the
  files under a service the shell keeps loaded, which runs its old code
  until the shell restarts. It reads the manifest's version as it starts,
  and again as a surface opens (`check`), where the notice shows, so no
  missed file event hides it; while the manifest names another, a
  downgrade too, `newVersion` names it; one with no version, or half
  written, changes nothing. `restart()` runs `omarchy restart shell` detached, so it
  outlives the shell it stops; while the session is locked that command
  refuses, and the notice stays for a later click.
- `WindowHost.qml` — hosts the window, pill or none, and decides what a
  request for it does: `toggle()` (the pill's right-click, IPC `toggleWindow`)
  closes a window on the focused workspace with no popup open, and
  otherwise does `open()`, which closes the popup and opens the window, or
  brings it forward from another workspace (Hyprland's focus dispatch).
  The popup opening leaves the window as it is.
- `IpcTarget.qml` — the one IPC target, `grvc.stonks`: `refresh` (every
  pill acknowledges it), `next`, `prev`, the popup's verbs through the
  shell, `toggleWindow`, and `openWindow` with a payload. Its handler's
  every property is offered over IPC, so its wiring sits on the item
  around it.
- `calendars.json` — exchange schedules the header uses after Yahoo goes
  silent, the US early closes, the US overnight session the 1D chart
  and the overnight line keep to, and each zone's names by offset ("EDT",
  "EST").
- `Service.qml` — the one data owner: quote, history, fundamentals,
  all-day, and overnight feeds, calendars, the data
  file at `~/.config/omarchy/grvc.stonks.json`, the last good quotes at
  `~/.cache/grvc.stonks/quotes.json`, one gate per host (`Gate.qml`), and
  the clock timer.
  Its writes of the data file are synchronous (`blockWrites`):
  Quickshell's async write skipped a change back to a value still being
  written, and the file's watch then read the older one back over it.
  Quickshell ignores a reload asked for while a read of the file is in
  flight, and lets go of a read only after its handlers have run, so a
  change notice that comes during one is held and the file read again once
  they have (`readDataFile`, `dataReadEnded`); a write of its own drops a
  read in flight unheard, which ends it too.
  `library` is All, whose every symbol gets one first answer; `symbols` is the current
  list's rows; `range` is the chart range the popup and the window share.
  Quotes are asked for each second as they fall due (`askDue`): of
  `watched`, the featured symbol, every stock, ETF, and index in All
  through its own regular session (`Market.staysWarm`: Yahoo's periods,
  or the calendar's for a quote held from an earlier day; one with no
  calendar, an index on an exchange none covers, on the slow clock once its periods are past), so an open
  finds the rows fresh, and all of All while a surface is open, those whose
  last answer, ok or failed, is as old as their own market's cadence
  (`Market.quoteCadence`); an open surface's hero takes the interval in
  extended hours. An open asks for nothing by itself: it makes All watched,
  and what is due goes at once.
  It asks for the history the open surfaces' heroes show on that range,
  one request at a time: the featured symbol's while a surface is open
  (each body says so, `surfaceShown`), and a resting preview's; the day, or
  no surface, asks for none, and a cache under fifteen minutes is enough. `refresh()` is a
  user's (`r`, IPC): every watched quote answered more than 10 s ago, the
  overnight prints unless asked for in the last 10 s, so a second press adds
  nothing, and, while a surface is open
  on a range, every one of those histories fresh, in turn, a
  failed one included. When Yahoo's gate reopens, the heroes' history is
  asked again. An open surface asks for the featured symbol's cap and
  P/E (on open, a symbol change, and its own `r`), and only an equity's;
  one asked before the symbol's first quote goes when that quote lands.
  Robinhood is asked only while a surface is open (`askOvernight`): for
  `overnightSymbols`, the stocks and ETFs on a calendar with the overnight
  session, decided by their quotes, whether it trades each all day, once a
  day (`Overnight.allDayDue`, a failure asked again five minutes on); and
  for `allDaySymbols`, those it does, their prints: for each one it has not
  answered for, every five minutes while a night trades or an answer has
  failed, and once after a night ends (`Overnight.overnightDue`, on the
  service's clock, passed as it asks).
  `view` is what the surfaces show of the settings as one value (hero,
  range, list, its key, order and direction, rows, sorted rows, All, and
  `chart`, the chart asked for), so a change of it is
  whole; handlers read it, not bindings derived from it, which may lag.
  A list's key (`listKey`) is its identity for the session: a rename keeps
  it, so a rename is no switch, and a name a rename or a delete freed names
  another list.
  `chart` is the view's chart once it can be drawn (`Chart.viewChart`),
  null while it is on its way; what a surface shows meanwhile is its own
  (`ChartMotion`). `chart.quote` is Yahoo's quote as it came, the headline
  and the day's figures; `chart.day` is what the 1D chart draws and a scrub
  of it reads. A US stock or ETF waits on 1D for Robinhood's word on
  whether it trades it all day. One it does waits for Robinhood's prints
  too, and its `chart.day` is its New York calendar day
  (`Overnight.dayChart`), with `chart.latest`, the newest print of all,
  once that answer is in, on every range, though no range waits for it;
  one it does not, or a failed answer, has Yahoo's own day
  (`Overnight.sessionDay`). Each is built again only when its quote or its
  prints are new (`keepDay`), the preview's too: one in All has its chart as
  it does featured; a US listing outside All, never asked of Robinhood,
  has Yahoo's own day. A symbol
  added to All is `arriving` until its first answer (a quote, or a first
  fetch that failed for good): a member, saved and fetched, in no list's
  rows, keys, or scroll. Pill routes (wheel, IPC next/prev) go to it
  directly (`featureStep`). `previewSymbol` is the search result a
  surface's hero shows unadded (`preview`, never saved), and `previewView`
  the view with it as the hero. One search previews at a time
  (`previewSurface`): another surface's search that starts choosing takes
  it, and the first search closes; a surface that closes or goes ends its
  own. Once the choice has rested on a result 250 ms (`previewRests`), its
  range's history and cap and P/E are asked for, and, outside All, its
  quote, once, from a feed of its own that no timer or `r` refreshes. An
  add of the preview takes its answer: a quote, featured at once, or a
  failed first fetch, so the add is done there and its row says it failed.
- `BarWidget.qml` — the pill; owns the popup loader. Middle click steps its
  form: sparkline, arrow, text (the symbol, the row's price, and the change),
  and icon, Stonks' mark (`StonksMark`) alone in one icon slot on either
  bar, whose hover names the symbol and its change. The sparkline's and the
  arrow's hover names the company and the phase; the text's, which shows its
  words already, says nothing. While a warning's "!" shows, every form's
  hover says what it means, in the popup's words (`Figures.freshnessText`).
  The shell copies a hover's words only as the pointer enters, so while it
  stays a warning that starts, ends, or changes its words goes to the bar
  again: an answer that lands takes the warning out of the bubble, and the
  text form's bubble with it. A new figure alone leaves an open bubble as
  it opened, so a resting pointer sees no blink. A vertical bar draws the
  first three alike, the symbol over its change narrowed to five characters
  from the rows' own figure (`Format.narrowPct`), so the two agree, and
  coloured by it, so there a middle-click switches between that and the
  icon, and a saved arrow or text stays saved for a horizontal bar until it
  does.
  It reads its section from the bar's layout
  (`bar.layoutConfig`): in the right section its form is `barStyleRight`,
  the icon until a middle-click there writes one, and elsewhere `barStyle`.
  Its right-click asks the window's host to toggle the window.
- `Panel.qml` — the popup: lifecycle, keys, look, and the popup layout. The
  card is placed under its pill in whatever section of the bar it sits (the
  shell's `KeyboardPanel` without `centerOnBar`, which put it at the bar's
  centre), where the pill was as it opened from closed: the shell follows
  its anchor live (`KeyboardPanel`'s `cardOrigin`), so the anchor is a
  stand-in held there (`HeldAnchor.qml`, on the bar window's content, which
  it finds through the pill, never through the card that finds its window
  through it), and nothing pressed in the open popup (`c` into "open", a
  narrower featured symbol) moves it sideways; the next open takes the
  pill's new place. The first visit there ever shows the body's
  first-run hint, on opening or once the service is ready if it opened
  first, and has the service save `hinted`, so no visit after it, a
  restart included, shows it again. A visit whose footer shows a notice
  (the data file can't be read, an update waits) neither shows nor saves
  it; the next visit without one does. Its height is the list's whole rows under
  the cap (`StonksBody.fittedHeight`). The header's `?` (or the key) swaps
  everything under the header for the key sheet, and the popup takes the
  sheet's height. While the card is open, its edge eases to a new height
  in the house 160 ms OutCubic; the body lays out at that height at once,
  and the footer at its bottom rides the edge (`StonksBody.edge`). An open
  from closed settles it before the first
  frame; one during the close fade eases from where it is. The
  shell's card is an item in a full-screen surface, so no window resizes.
  An open while open changes nothing. Closing only fades: everything that
  moves stops where it is (`StonksBody.freeze`, `still`): the edge, the
  chart's draw-in and replay, the live marks, the look icon's step, the
  header animal's turn, the breadth rule's ends, a held drag, the rows,
  and the footer's note, which
  outlives its timer. What is shown stays, the chart, figures, and rows as
  they are, whatever the pointer or another surface does, since the body
  reads the service only while open; the next open takes the latest. The
  closing body takes no press, click, wheel, or scrub. Each view starts
  fresh as it next opens, after the surface shows, so the reset lays out,
  and settles, what it reads.
- `App.qml` — the tiled window (`FloatingWindow` titled "Stonks"). Window
  lifecycle, the payload (one change: `Service.summon`), keys, and
  look; Escape closes. Like the popup, it resets its views as it opens, not
  as it closes.
- `StonksBody.qml` — shared body both surfaces compose: header, hero band,
  list, search, footer, help, and historical range view; it composes the
  chart's motion (`ChartMotion`) and routes input to it. It acts through
  the service, and reads it only while its surface is open, in one block of
  held inputs (view, quotes, entries, cap and P/E, lists, members, arriving, the last
  removal, change mode, look, asks, clock, the preview's receipt, whether the
  data file can be read, the version waiting): from a close to the next
  open nothing it shows changes, the clock included, so a tick derives
  nothing there. While its search is open its view is the service's
  `previewView` for the choice (`previewTo`), which closing search, or the
  surface, ends.
  A surface passes its look, decodes its keys, and takes the
  keys back on `keysReleased`. Opening a view or acting on the rows closes
  the key sheet, and search, first, in either surface.
- `ChartMotion.qml` — owns the chart a surface presents (`chart`), its
  draw-in, and its moment: the scrub, the replay that drives it, and the
  hold. It takes the view's chart once it can be drawn and keeps the one on
  show, whole and still, while the one asked for is on its way (`loading`);
  `chart` is a binding over the view and the chart last presented, so no
  handler reads it out of step. It measures the chart it owns (history,
  quote, geometry, the last print, where the moment sits) from that chart
  and the look alone; the body reads those measures and passes nothing back.
  Every change of the chart it presents draws in from the left in 320 ms
  OutCubic, sweeping from the left edge to the newest drawn print, so a day
  partly gone takes its whole time, whatever made it: a symbol from any
  trigger, a range, a held
  chart's replacement landing, a retry that lands, and a surface opening
  (`revealChart`). It decides once per change of the body's view and first
  ends the last motion (a draw-in, a replay). The painters draw what it
  presents, as far as it has revealed, and decide nothing.
- `Watchlist.qml` — rows, drag, cursor, wheel, and scroll-to-row. One
  cursor, as in the shell's own panels (`Ui/CursorSurface.qml`): moving the
  pointer puts it on the row under it, the wheel on the row it brings under
  a still pointer, a key one row on from wherever it is, and a click on the
  row clicked, which stops the list where it is, a glide or a touchpad's
  settle, as a flicking list stops under a finger, so the row stays under
  the pointer; a lifted row keeps it while the wheel scrolls the list under
  it; the pointer leaving the list leaves it there. Pointer and wheel read
  the list where it is headed, as the cursor always does, so mid-glide they
  name the row that will rest under the pointer. Only a real move within
  the rows counts (`RowPointer.qml`): the first place the pointer is seen
  at, as it comes in or as a view opens or shows again under it, is only
  where it starts, so a view keeps the cursor it opened on. As the rows show
  again (from behind the key sheet or a view), the surface opens, or a list
  view opens, the pointer rests where it is first seen after, and reports
  within 2 px of that place are that resting pointer (`RowPointer.rest`):
  the compositor can report it again a pixel off as the view comes back.
  Any farther report is a hand's move and counts. And rows gliding under a
  still pointer, as a key scrolls them, never hand it the cursor. The list
  views follow the same rule. It is always on a row in sight (`cursorRow`):
  a cursor of your own while any of its row is in sight; without one (every
  open clears it, `reopen`; on another list), the featured row when that is
  in sight, else the first whole row in sight. The scrollbar moving your
  cursor out of sight, or the rows changing under it, lets it go; the rows
  hidden behind the key sheet or a view do not, though the popup's card,
  and the list with it, shrinks to them: the cursor stays, a key acts on
  it, and it is judged again a turn after the rows come back; removing
  the cursor's row (`x`, Delete, Backspace, or a right- or middle-click,
  which puts the cursor there first) hands the cursor to the row that
  takes its place, the next one, or the one before when it was the last
  (`StonksBody.removeRow`). Every symbol in All keeps its row
  across lists: a list shows its members and hides the rest, so a
  switch builds nothing, and lays the rows out at once, where this surface
  last left that list (the top on its first visit); a new order or
  direction lays them out at once where the list is scrolled. Rows
  never draw through each other: a row slides only if it was in sight
  before and after, one whose place is new (added or brought back) takes
  its sorted place and fades in there even while the pointer holds the
  list, and a moving row carries the surface's ground
  (`StonksBody.ground`), the one travelling farther on top. A removal that
  shortens a list scrolled to its end moves only the rows above the gap.
  A key or a move scrolls the list only by gliding (the wheel's 160 ms),
  so a move past the edge carries the rows along and the moved row stays
  still on screen. Shift and the wheel move the row the wheel started on a
  place a notch, however finely the wheel ticks, until the pointer moves.
  Signals out feature/remove/lists/move/reorder; the body acts on them
  through the service, and every removal goes through `StonksBody.removeRow`.
- `Hero.qml`, `HeaderStatus.qml`, `HeroBand.qml`, `AddFooter.qml`,
  `HelpSheet.qml` — shared value-in pieces the body composes. The header
  starts with the day's animal and ends in the look and `?`. The listing
  line names its currency once: a pair's name that ends with it ("Bitcoin
  USD") is not followed by it again (`Figures.listingMeta`). The footer
  says a note in the foreground for a moment, held while the pointer is on
  it, a removal's with "click or u to undo" said whole, so a long list name
  is what gets cut; under it, until what it says is fixed, a notice, in the
  foreground too: "grvc.stonks.json can't be read, so changes aren't being
  saved", whose click does nothing, ahead of "Updated to x · restart the
  shell", whose click restarts it. Above it, quietly, the body's `hint` for
  the visit, a line of its own that never takes the place of "+ Add a
  symbol" and takes no click.
- `LookIcon.qml` — the look a click switches to, as a small line chart, the
  way a button shows what pressing it does (the chart already shows the
  current look): Stonks' mark (`Cells.markPoints`) in cells (`StonksMark`)
  in smooth, and as a curve in retro, stepping between them column by
  column in 200 ms as the look changes, and settled on the other look as a
  surface opens. A click on it switches the look, as `s` does, and hovering
  says so: "Switch to retro (s)" or "Switch to smooth (s)", in a tooltip
  under the header, its right edge on the header's, so it stays inside the
  card; the shell's own place, above the icon, drew across the card's edge.
- `BreadthRule.qml` — the rule between the list's name, with a dim TODAY
  after it, and its order, drawn as the list's breadth (`Figures.listBreadth`, the rows' own tones
  counted); cells in retro, counts on hover. Its ends ease only when the
  same list's breadth changes (a refresh, an add, a removal, a membership
  change) while the surface is open and the rows show; a list switch, an
  open, or the rows showing again sets them at once, and the rule's length
  never eases them. While search or a list view covers the rows,
  the header names the list only: TODAY, the rule, and the order hide, the
  line keeping its height, and the rule rests.
- `ListMenu.qml` — the list menu: lists with counts, a check on the
  current one, "New list…" as an inline name field, and "Manage lists…".
  Owns its keys while open, like search. Its edge is drawn over its ground:
  Qt draws a border in place of a fill, so a translucent one shows the rows
  under it.
- `ManageLists.qml` — rename, reorder, and delete named lists, in the rows'
  place; delete asks in the row. `SymbolLists.qml` — one symbol's tick box
  per list (`m`, or Ctrl-click a row); it takes no click within the
  double-click interval of opening, since a Ctrl-click opens it under the
  pointer. Both own their keys while open (`StonksBody.ownsKeys`) and share
  `ListAction.qml`, the caption-sized word that acts.
- `SymbolSearch.qml` — the search field, results, debounce, and Yahoo
  lookup; the body handles `picked` / `chose` / `cancelled`. The
  keyboard owns the choice Enter adds, and tells every change of it
  (`chose`); the pointer tints, a click chooses, and only the chosen
  row's Add takes a result. The field's placeholder says what to type and
  names the list it adds to. Results fill down under the field in whole
  rows only. Every row keeps the button's slot, sized to the wider of Add
  and Show, so the exchange codes hold one column, and one symbol column,
  the answer's widest symbol, which the name gives way to until it is down
  to half their shared room. The last
  answer stays on screen while a new query is out, dimmed and not
  takeable; only an empty field clears it. An empty answer says "No
  matches", a lookup with no answer says so differently, both under the
  field, and the hint offers Enter only while there are results. Every way
  of taking a result goes through
  `accept`, which takes none for an earlier query.
- `StonksMark.qml` — Stonks' mark in cells (`Cells.markLevels`): each
  column's cap lit and its stem faint, climbing, or mirrored to fall on a
  down day, so the shape carries the direction without colour. The pill's
  icon form and the look icon's retro cells. At icon size (`solid`, the
  pill's icon form) each column is one bar at full ink, so it reads beside
  the bar's glyphs where faint stems scatter into dots; the dip keeps it
  from reading as a signal meter.
- `share/stonks.desktop`, `share/grvc.stonks.svg` — the launcher entry and
  its icon, which the README has users copy; do not install them from this
  repo. The icon is the mark, climbing, its columns solid as at icon size,
  in one green that reads on light and dark launchers, written by
  `bun test/mark-svg.js` from `Cells.markLevels`; `test/all.sh` fails when
  the file is not that drawing.
- `QuoteFeed.qml` — the quote runs: every symbol asked for goes in one
  curl over one connection, and a run's answers land together. Two lanes,
  first answers and refreshes, so an add never waits behind a refresh; the
  pill's symbol first, then the longest asked. `asked` holds each symbol
  asked for and not yet answered, with when: freshness calls one overdue
  after 90 s. A bad answer (another 5xx, cut short, over its cap) is tried
  three times; a missing symbol (404) fails at once; a refusal or no answer
  is the host's, so it stays asked and the gate paces it. A run still out
  after 20 s is stopped. An ask for a symbol no longer watched is dropped.
  It fetches All: a symbol that leaves a named list keeps its quote; one
  that leaves All takes its quote and entry with it, and an undo brings them
  back (`restore`). Quotes saved from an earlier session are `seed`ed as
  "saved" until their first answer. An answer with nothing
  new keeps the quote already shown, so no line repaints for it.
- `Gate.qml` — one host's gate, Yahoo's and Robinhood's, which every
  request to it asks first: a budget (Yahoo 80, refilling 40 a minute,
  about 38 symbols a minute; Robinhood 20, refilling 10), whose last 10
  runs of the list leave to single requests (a history, a search, cap and
  P/E, a preview), and a pause: no answer waits 2 s doubling to 60, a 429
  or 503 a minute doubling to 30, each ±20%, then one request alone, whose
  answer alone reopens the host: each request carries the `ticket` it was
  let through on, and an answer to one let through before the latest pause
  can only refuse. On the service's clock, read as it is (`clock`), never a
  binding's copy. Every feed but quotes fails at once while its host is
  paused, a turn later, out of the change that asked.
- `HistoryFeed.qml` — the fifteen-minute history cache for the one chart the
  service wants; one curl, one retry of a bad answer. `entries` holds answers only; what is
  on its way is `wanted`, which the view never reads, so a request is no
  change of the view. A want is cleared before its answer is told, so a
  reader of `entries` can want the next chart from its change handler.
- `FundamentalsFeed.qml` — Yahoo's dated cap and P/E, one symbol at a time,
  kept for the day; two curls in turn, the snapshots, then the closes on
  their dates. A failed fetch keeps the last good figures and is asked
  again the next time they are wanted.
- `AllDayFeed.qml` — Robinhood's keyless instruments for every US stock and
  ETF, one request for all: whether it trades each all day, its 24 Hour
  Market (`all_day_tradability`, `Overnight.parseAllDay`), stamped with the
  time the service asked. An answer holds a day; a failure keeps the last
  good one, is not all-day without one, and is asked again five minutes
  on. `entries` holds answers only; symbols asked for while one request is
  out go once it is answered.
- `OvernightFeed.qml` — Robinhood's keyless historicals for every listing
  it trades all day, one request for all, stamped with the time the
  service asked (`askedAt`): the bars that traded (`Overnight.parseOvernight`), by the
  Yahoo symbols asked, for the 1D chart's hours outside Yahoo's day. It asks
  for a day each time, and the answer replaces the prints it keeps:
  span=day is the last 288 five-minute slots of the 24/5 week, so across a
  weekend it reaches back into Friday (seen on Sunday 4 October, 22:58 ET:
  Thursday 22:55 onward), as far as any 1D chart reaches.
  `entries` holds answers only; a failure keeps the last good prints, and
  symbols asked for while one request is out go once it is answered.
- `RangeSelector.qml` — the shared one-line range token control.
- `WatchlistRow.qml` — one row; value-in, signals out. Owns the press-and-
  move gesture that lifts a row; the watchlist positions it and the others.
  A double-click, on a row, the list, or the footer, is one click: its
  second would land on whatever took the first one's place. On the list, a
  click within the double-click interval of the last, at its place, does
  nothing, whatever button and whichever row is under it by then
  (`Watchlist.clickRow`): a right double-click removes one row. The wheel,
  a key, or a row's move (Shift and the wheel, `J` `K`) starts another
  gesture, and the next click acts, even one Qt takes for a double-click's
  second press, when that pair's first press was the list's last click: a
  row hands every click, the second too, to the list to decide. Another
  list, a new open, or the rows hidden behind a view forget the last click.
  A removal hands the cursor on without moving a list whose next row is in
  sight (`Watchlist.handTo`).
- `CursorBar.qml` — the cursor's one mark, a bar down a row's left edge, on
  the watchlist's rows and in every list view.
- `DayChart.qml`, `Sparkline.qml`, `DrawnAnimal.qml` — the smooth look's
  Canvas drawings: the charts, and the header's bull and bear, one 1.5 px
  round line in the day's colour with the hero's wash inside.
  Every line is drawn from its own quote or history, so it redraws only when
  that data does, never with the clock or the change mode. Only what is on
  show draws: the hidden look's hero chart and price digits and the rows'
  hidden-look drawings rest, drawing nothing and following no scrub, and a
  row outside the current list derives and draws nothing at all; shown
  again (`s`, a list switch), they draw before that frame. Rows of the current list scrolled out of view stay
  drawn. Each chart,
  retro's too, is layers that paint only when what they draw changes: the
  baseline, the data's ink under a clip the draw-in widens (whole columns in
  retro, the ticks drawing in with them), and the scrub marks, so a draw-in
  and a scrub repaint no line.
- `PixelChart.qml`, `PixelSprite.qml`, `BlockDigits.qml` — the retro look's
  pixel columns (hero, rows, and the bar pill), bull/bear sprite, and block
  price digits, drawn as cells from `Cells.blockCells`.
- The rule files: pure functions shared by the QML and the tests, one
  concern each, carrying no drawing and reading no clock. Each QML file
  imports only the ones it uses.
  - `Format.js` — how numbers and moments are checked and written:
    prices, changes and their signs, durations, clock times, the names of
    days and months.
  - `Fetch.js` — the one curl every feed runs: a run of URLs over one
    connection, compressed, each answer capped and followed by a line that
    says what came back (`answers`, `answerKind`). Needs curl 8.4.
  - `Quote.js` — Yahoo's day answer and the day's prices read off it: the
    session its bars describe, the stray-bucket filter, the headline, the
    change, each print's session.
  - `Market.js` — exchange calendars and sessions: `calendars.json`'s
    rules, the phase and bells, the header's words, a print's clock in its
    exchange's time, and each symbol's refresh cadence (`quoteCadence`).
  - `Overnight.js` — Robinhood's word on which listings it trades all day,
    its prints, and the 1D chart's day built from them.
  - `History.js` — ranges: Yahoo's history answer, its stats, bars, dates,
    and words.
  - `Fundamentals.js` — the cap and P/E and the key stats line.
  - `Figures.js` — what a quote shows: the `rowModel` projection the hero,
    rows, and bar pill all read (figures only), the breadth, the day's info
    line, the line under the price, freshness, the pill's arrow.
  - `Chart.js` — which chart a view shows, and how it is laid out and
    scrubbed.
  - `Tones.js` — how the theme's colours are put to work: which is up, how
    much quieter secondary text is, and how strongly a wash lies over the
    ground (`washAlpha`).
  - `Settings.js` — the data file's settings and lists, and every rule
    that changes them.
  - `KeySheet.js` — what the key sheet shows.
  - `Search.js` — Yahoo's symbol lookup.
  - `Cells.js` — the cell drawings: block digits, the bull and the bear,
    the mark's levels.
- `test/tophat.sh`, `test/live.sh` — the maintainer's tools for their own
  machine, not needed to contribute: a tophat in a nested Hyprland on a
  laptop screen beside another, which starts on the demo watchlist
  (`test/tophat/demo.json`; `test/tophat/drive.py` sends its pointer
  gestures and modified keys over one Wayland connection, on `wayland.py`,
  vendored unmodified from omarchy-computer-use with its `LICENSE`), or with
  `start --fresh` as a new user's machine: Stonks not installed, no saved
  settings, and a terminal open where `omarchy plugin add stonks --enable`
  installs the run's commit from its clone at `~/stonks`; and a live
  plugin worktree. `test/tophat.sh self-check` runs anywhere.
- `test/procs.sh` — process groups and run marks, which the tophat and the
  Quickshell runs (`test/qml/quickshell.sh`) share.
- `test/hooks/post-checkout` — copies the main checkout's local
  `AGENTS.md` into a new worktree (Agents).

## Domain rules

- Quotes come from Yahoo's unofficial chart endpoint, every symbol due in
  one curl run, and the search endpoint for adding symbols. No API key.
  Quotes stay on the chart endpoint, not spark: only its bars carry the
  opens the stray filter and the day's open need. If the endpoint
  changes, only its file's URL and parser move (`Quote.js`, `History.js`,
  `Search.js`, `Fundamentals.js`). Overnight prints, and the
  1D chart's hours before Yahoo's day, come from Robinhood's keyless
  historicals (`5minute`, `span=day`, `bounds=24_5`), one
  request for the list, its bars that did not trade (`interpolated`) dropped;
  whether Robinhood trades a listing all day, from its keyless instruments
  (`all_day_tradability`), one request for the list. Robinhood's data is
  for personal use: the README says so plainly, and nothing shows
  Robinhood's logo.
- Overnight trading is 20:00 to 04:00 New York time, Sunday to Thursday
  nights, never the night before a market holiday (`calendars.json`, the
  US calendar's `overnight`). Only a stock or an ETF on a listing whose
  calendar has it can get one, decided from Yahoo's quote, never from what
  Robinhood's prints answer: it answers BTC with a bitcoin ETF, and an index
  or a cryptocurrency with nothing. Of those, only one Robinhood trades all
  day, as its instruments say (NBIS, SPY), gets one; any other's night
  trades are strays (PSIX's 2 shares at 23:10, BLDP's 6 at 00:35, read as
  +5.34%), never shown. The overnight print is its own line under
  the price, "OVERNIGHT", its own time, its move against the regular close;
  it shows while it is the newest print, so a pre-market print takes over,
  and a symbol that has not traded tonight keeps its after-hours line. It
  dims once 20 minutes old: Robinhood's newest bar is five to ten minutes
  late, so a liquid name never dims. It is never the headline, and never in
  the day's high, low, change, rows, breadth, or pill, which stay Yahoo's.
  The line under the price, overnight, pre-market, or after-hours, shows
  at rest on every range; a scrub's price is a past one, so the line rests
  then and the baseline's legend takes its place.
- Historical ranges use Yahoo's returned OHLC columns and actual granularity;
  they never claim an adjustment, date precision, or coverage Yahoo did not send.
- The info block is two lines of one shape, its columns shared: a title,
  then the low, a thin rule with a tick where the price sits, and the high,
  then two facts. The first line is the day (`Figures.dayLine`: its session
  as the title, OPEN and VOL) or, on a range, that range
  (`History.rangeLine`: SINCE for a listing younger than it, the dates of
  its low and high, then the bars of that young listing's sparse answer);
  the second, on every range, the 52 weeks (`Fundamentals.yearLine`: MKT
  CAP and P/E, an equity's only), so the two rules stand in one column and
  the ticks say where the price sits in both. The rule is the breadth
  rule's ink and 2 px, in cells in retro (`Cells.RULE_*`). A day past
  Yahoo's 52-week mark widens the 52-week range to it: both highs (or
  lows) read the same, in that direction's colour. Each line names only
  what is known, never what
  is missing: an unknown end leaves an empty track and no tick, an unknown
  fact an empty slot. Every column is as wide as the widest figure its
  slots can hold at the listing's digits (`Format.widest`: its largest
  price, VOL as 999.9M, which `Format.compactNumber` never exceeds, a cap
  as 999.9B with room for its currency on a pence listing, a P/E as 99.9,
  a date with its year), never today's figures, and a slot stays when its
  fact is missing (a young listing's BARS after its eighth bar), so a
  refresh moves only the tick. The geometry changes only with the symbol,
  the range, a price gaining a digit, or a range whose start passes a
  young listing's first day, where SINCE and BARS go. The rule takes the
  room the columns leave; a trailing column that still does not fit (a
  coin under a cent's VOL, a young listing's high date and bars in the
  popup) is left out whole, never cut. The cap and P/E come from
  Yahoo's fundamentals timeseries: dated snapshots, weeks or months apart,
  each taken at its date's close, with no share count. Each is moved with
  the headline price from its own date's close, so the cap is an estimate.
  A cap more than 120 days older than the price is left out, and so is a
  P/E while the latest trailing diluted EPS is not above zero. Only
  equities are asked, never on the quote timer. An answer is kept for the
  day; a failure keeps the last good figures and is asked again the next
  time they are wanted (an open, a symbol change, `r`), so one timeout never
  hides the cap for a day. A price Yahoo sends as 0 (London's day high and
  low and 52-week low before its session) is not known yet, and both info
  lines leave it out (`Quote.knownPrice`).
- Session phases (pre-market, opening bell, lunch lull, power hour, closing
  bell, after hours, closed) come from the exchange's own trading periods in
  the response, in the exchange's timezone. Never assume New York. Yahoo
  describes one session per response, the one its bars are
  (`meta.tradingPeriods`), and still owns today; its current period moves
  on to the next session first (Monday's at 00:36 New York, the bars still
  Friday's). The bars' session is the chart's, the open's, and the info
  line's; the current period stands in for an answer without trading
  periods, and gives the phase and the bell once the clock has left the
  bars' session and entered it (`Market.clockSession`), so a quote held
  without a fetch turns at the boundary itself.
  The 1D info line's title is the day its figures are: the bars' session,
  or the coming one once Yahoo has sent its high and low as 0 (London
  before its session), with no open then. After the close,
  on weekends and holidays, and between Tokyo's segments, the next open
  comes from `calendars.json`, never from arithmetic on today's session.
  Past a calendar's `validThrough` the header says the schedule is
  unavailable instead of guessing. The header leads with the state
  ("CLOSED · OPENS MON 09:30"), not with what is missing, and while the
  opening bell, lunch lull, power hour, or closing bell lasts it leads with
  that ("POWER HOUR · CLOSES IN 40M"). On a holiday it leads with the
  holiday as `calendars.json` names it, less "observed" or "(substitute
  day)" (`Market.holidayName`), so the longest fits the popup beside its
  next open; the file keeps its source's names, since it is renewed from
  it. A countdown rounds up to the minute,
  so its last minute reads 1M. Every exchange time shown (the next open, the
  close, the lunch break's end, a scrub's "AT", "AS OF", the overnight
  print's, an intraday range's) is the exchange's clock, with its zone's
  name only where that differs from the reader's at that moment
  (`Format.zoned`, by UTC offset): "09:00 JST" for Tokyo in New York,
  nothing for Nasdaq in New York or Toronto. The names come from
  `calendars.json`, else Yahoo's `timezone`, else the offset ("UTC+5:30").
  An index has its regular session alone: Yahoo still sends it pre- and
  post-market periods and repeats its close through the evening, and
  `Quote.parseChart` drops both, so it never says PRE-MARKET and its line
  ends at its last bar; its exchanges (S&P, DOW, NASDAQ) are on the US
  calendar, which names its next open.
- The headline price is Yahoo's regular-market quote with its own
  timestamp (`Quote.headlineQuote`), never the last chart bucket. A bucket
  stamped at the bell is post-market. Freshness is three separate facts:
  the quote's time, an ask still unanswered, and the refresh outcome
  (`Figures.freshness`): a refresh asked for and unanswered for 90 s is
  overdue, quietly, "! Update overdue · As of"; a row nobody asked for is
  never late, and no cadence enters the rule. A quote saved from an earlier
  session says when it is from, its day too when not today ("AS OF FRI
  16:00"), with no live mark, until its first answer. Live
  has one mark, the chart's breathing dot, and it needs a quote under two
  minutes old; the header puts nothing in front of its words, so a range
  change or a scrub moves nothing there. An aged quote is said plainly, in
  the hero as in its row; only a warning (overdue, failed) takes the "!".
- The bar pill shows the featured symbol's day as it stands now, what its
  row shows unscrubbed (`rowModel`), on every range, in every bar style and look, the vertical
  bar too: the bar is always on screen, and a glance at it asks how it is
  now. Its icon form is that day as the mark's colour and shape alone: it
  climbs, or falls on a down day, the same cells in both looks.
  It names no range and fetches nothing for itself. Where the pill sits is
  the bar's (drag it to another section) and its form is its own setting
  for that section: in the right section, among the bar's bare icons,
  `barStyleRight`, the icon until a middle-click there picks another; in the
  centre and left, `barStyle`. A move never changes either, so each section
  brings back its own. The popup and the
  window keep the shared range. The rows' figures and the list's breadth
  are the day's on every range, and while the list's rows are shown its
  header says TODAY.
- The popup sizes itself to what it is showing: on the rows, whole rows for
  the list shown, up to six (`Panel.maxRows`), an empty named list keeping
  one, with the footer one gap under them; otherwise the key sheet's own
  height, a list view's own height, or, as search opens and before any
  typing, the search field and a full set of results, or the rows' height
  when that is taller, the spare room under the results, so the card's
  edge holds still while you type. Whatever changes the height (a list
  switch, a removal, an add that lands, an undo, a membership change from
  the other surface, a view opening or closing), the card's edge eases
  there with the footer riding it; the footer carries the card's ground
  (`StonksBody.ground`), so a growing edge carries it over the rows instead
  of drawing its words through them. Search's field opens under the list's
  header, where the rows were, and stays there from its open through every
  answer, its results filling down under it. An open list menu taller than
  the rows makes room for itself and for the footer one gap under it. On a
  bottom or side bar, where the shell anchors the card's far edge, each of
  these moves the card itself, as search and the key sheet do. The
  window's minimum height is its fixed content plus one whole row, where
  search shows its field and one whole result, and past
  720 its body keeps that width and centres.
- All is the library: every symbol, fetched once each. Named lists are
  subsets of All, may be empty, and a symbol can be in several. Adding on a
  named list adds to it and to All; removing on a named list removes that
  membership only; removing on All removes the symbol from every list. The
  rules live in `Settings.js` as settings-in, settings-out functions
  (`withSymbolAdded`, `withMembership`, …). While search is open the hero
  shows its choice, unadded: the top result as an answer lands, then
  wherever the arrows or a click move it, under the hold rule; the rows,
  the pill, and the featured symbol stay as they were, and Escape puts the
  featured symbol back. Enter, or the chosen row's Add, adds what the hero
  shows: with its quote in, its row joins at its place and it is featured
  at once, the chart unchanged. A result already in the list on screen
  (`members`, arriving ones too) says Show, and the field's hint "⏎ show":
  Enter or Show features its row the way a click does, a failed first
  fetch's too, and adds nothing; one still arriving is featured once its
  first answer is in, a failed one too. A symbol you add without its answer is fetched
  ahead of any refresh and stays out of the rows until its first answer,
  and the view stays on what you were looking at; then its row joins at
  its place, the list eases it into view once (the wheel's 160 ms glide),
  and once the list and the row rest it is featured the way a click
  features a row, from where the row ended up. A hero chosen before then,
  or a switch to a list without it, ends the landing, and a chosen hero
  keeps the chart; the new row still joins at its place. A second add before
  the first's answer takes the chart; each row still joins at its own place
  when its own answer lands. An add whose first fetch fails is done there:
  the view stays, and its row joins saying it failed. A manual reorder
  while an add is out keeps it in the saved order. Switching lists never changes
  the featured symbol. All cannot be renamed, moved, or deleted; deleting the
  current list goes to All.
- All always keeps one symbol (`Settings.canRemove`); a refused removal says
  why in the footer for a moment. A removal by `x` (or Delete in the
  window), a right- or middle-click on a row, or unticking All in a
  symbol's lists names the symbol in the footer for five seconds, longer
  while the pointer is on the note, and `u`, or a click on that note, puts
  it back where it was in every list
  (`Settings.withRemovalUndone`, from the settings the service kept), with the
  quote the service kept, so it needs no fetch; its row joins at its place
  and the list eases it into view. A hero a removal or its undo
  moves draws its chart in, as any change of the chart does. A hero
  chosen since stays chosen. `u` takes back the service's last removal,
  from either surface, long after its note has gone, until the next change
  to what the lists hold (an add, a membership, a hand-made order, a list
  made, renamed, moved, or deleted, here or in the data file;
  `Settings.listsHeld`), which ends the offer and the note with it; a sort,
  a switch, a feature, or a close keeps it. With nothing to take back, `u`
  says "Nothing to undo".
  Unticking a named list in the checklist offers no undo; the checklist
  stays open to tick it again. The order and the change mode are separate
  settings: sorting ranks the rows and never changes their figures. Each list
  has its own order and direction: `o` steps to the next order in its own
  direction, and `O` (or a Shift-click on the order word) reverses a sorted
  one; manual has none. The order word's arrow says which way the values
  run down the list. Changes sort by percent only: Stonks converts no
  currency, so an amount would rank yen against dollars, and an order saved
  as the amount (`"abs"`) reads as % change. The change mode sets the day's
  change only, so the hero's change is a click target only while it shows
  the day's.
- A key-hint row shows its view's most-used keys.
- One cursor, the keys' and the pointer's, as in the shell's panels. The
  featured row takes the selected fill; the cursor's row the shell's
  hover-cursor fill and a bar down the left edge, in the shell's 60 ms,
  and on the featured row only the bar. The list menu, a symbol's lists,
  and Manage lists move and mark their cursor the same way, the wheel
  included, except that a name being typed or a delete being asked keeps
  it. A fill already on its way as a surface closes finishes its 60 ms: Qt
  pauses no `Behavior`'s animation. Search keeps its split:
  the keys choose a result and the pointer only tints one, so passing over
  results never swaps the hero's preview.
- Stonks' own controls (the range tokens, the list name, the order word,
  the look icon, the `?`, the footer, and the list views' actions) take the
  shell's pressed fill from the moment the button goes down, while it is
  held, as the shell's `Button` does; hover and selection keep their own.
- Data settings live in `~/.config/omarchy/grvc.stonks.json`; `barStyle`
  and `barStyleRight` stay on the bar entry and are written through `updateEntryInline`. All (`symbols`
  and `order`, the version-1 keys, so an older build reads the same All, and
  All's direction in `reversed`, a key of its own), the named lists (`lists`,
  each with its order and direction), the current list (`list`), featured
  symbol, chart range (`range`), look, change mode, refresh interval, and
  whether the popup's first-run hint has shown (`hinted`)
  persist; scrub time never does, nor where a list is scrolled (`Watchlist.places`,
  each surface's own, for the session).
  A data file that is there but can't be read (empty, not JSON, not an
  object, or not readable for its permissions) is never written: the
  settings in memory stay, the starter list
  if it never read, changes apply to them unsaved, the footer says so, and
  the file is read again once it parses. A missing one is created by the
  next change.
  Each list's symbols array is its manual order; sorting is a view over it
  (`Settings.sortedSymbols`), and rows move by hand only while manual order is
  shown. For a bar widget, `listPlugins`
  `enabled: false` means "not on the bar"; the service still runs when
  `{ "id": "grvc.stonks" }` is in `plugins[]`.
- Presentation follows Apple's Stocks app where it has decided: no currency
  conversion, the currency code with the exchange beside the name, the
  regular close as the headline with the extended-hours print labelled.
  A pre- or post-market print is hidden when it shows as the close itself;
  an overnight print is a trade, and stays. A company's name is
  Yahoo's long name wherever it shows, rows and search alike; the short one
  arrives in capitals for some listings and cut at 31 characters.
- Nothing moves when the look, the range, the list, its order, or the
  featured symbol changes, but for one exception: a list of another length
  moves the popup's bottom edge and the footer riding it, easing there.
  The list's header is the caption line's height, never its order word's,
  so no word moves the rows.
  The header keeps the animal's height in both looks, and the look is one
  small icon in both, so only the icon changes. The animal is the day's in
  both looks, retro's in cells and smooth's drawn, a bull up and a bear
  down at the moment shown; a flat day has none. Its slot keeps its place
  drawn or not, so the status words start after it in both looks, on a flat
  day, and while a symbol's first quote is out. On a turn of the same chart
  (a scrub or a replay across the close, a live day crossing it)
  smooth's crossfades in 160 ms OutCubic, from where a
  turn under way left it; a symbol, range, list, or look change, a failed
  range's retry landing, or an open, changes it at once, and retro's cells
  always change at once.
  Loading holds still: a refetch with the range in hand, out or
  failed, keeps the chart at full ink and the header on the market; only a
  chart not yet in says "Loading", naming what is coming ("LOADING AAPL
  1M"), and while it is out the hero keeps the chart on show
  (`ChartMotion.chart`), the previous range or symbol, chart, figures, and
  info lines alike, open or shut, and takes no scrub or replay; when it
  lands, or its first fetch fails, the new chart draws in. A range needs its history and the symbol's
  quote, since the headline is never the last bar. A retry of a first fetch
  that failed keeps the day and "unavailable" on screen until an answer
  lands. Before any chart has been in, at a cold start, the hero is empty
  under "Loading", never the day or "No quote". There is never a third
  state. Both looks share one hero box, and one fitted ink height drives both
  digit renderers, so they share a top line, baseline, and left edge however
  narrow it gets. The price has one size per surface and shrinks only when it
  cannot fit beside the change. The change and its caption are pinned to the
  hero's right edge; the extended-hours print is one compact line in the
  strip under the price, which keeps its height when there is none. The info
  block under the range row is always two lines. The footer sits at the
  bottom, one gap under the list's rows, and the rows stop short of the
  scrollbar's gutter.
- Smooth signs changes with + and a true minus (−); retro with ▲ and ▼
  (`Format.lookSigns`). From 1,000% up a percentage has no decimals. A
  listing's prices all take one count of decimals, decided from its
  headline price (`Quote.priceDigits`, `Format.priceDigits`): Yahoo's
  `priceHint` at least, four significant digits under 1 (SHIB 0.000005410;
  its hint of 5 would read 0.00001), none from 10,000 up. The hero, rows,
  pill, preview, info lines, and a scrub read the same digits; a move in
  money keeps cents where the price has none (`Format.moveDigits`). A
  figure that rounds to nothing has no sign, neither colour, and no
  animal (`Format.changeTone`, `dayTone`). The warning mark is "!" in
  both looks, never a
  triangle that could read as ▲. Retro's thousands comma hangs a cell below
  the baseline, and the strip under the price clears it in both looks.
- Intraday parsing drops a run of up to three buckets only when the series
  carries on past them: their closes have all left the last accepted price,
  and the bar after them opens back at that price instead of continuing from
  the run's last close. How far a stray reaches is not the test — one saved
  case is 0.8% wide, inside ordinary trading. Never the newest bar, never
  across an uneven gap, never daily or coarser history. Inside one pre- or
  post-market session, whatever the gaps, a run of three or four is stray
  when no bar of it opens where the one before closed, its closes land both
  above and below the last accepted price, and the bar after opens back at
  it: BRK-B's 520.93 and 489.66 against 502.65 on 2 October. Thin listings
  trade that shape two bars at a time, so two is never enough.
- The 1D chart draws the whole day the response describes, pre-market
  included, so the line reaches the previous close it is measured against.
  For a US stock or ETF Robinhood trades all day it is one New York
  calendar day, midnight to midnight, the way Robinhood's screen draws it
  (seen 7 October; its help: "from 12 AM-12 AM ET (24 hours),
  Monday-Friday"), with the hours still to come empty: the day of its
  newest print (`Overnight.chartDate`), so a day begins with its first
  print after midnight and the chart never stands empty before it; on a
  weekend or a holiday, the last trading day, all day. Sunday night's
  prints, and the evening's after a holiday, are on no 1D chart until
  midnight (`closedDateChart`, provisional until Robinhood's screen is seen
  then).
  It holds Yahoo's day and Robinhood's prints before it (the night since
  midnight) and after it (the after-hours and the evening's night), and
  each print says the time of its own date's clock. It is measured from
  the close before its regular session (`Overnight.dayBaseline`): Yahoo's
  previous close once its bars are the day's, its regular close from
  midnight to the pre-market, while its bars are still the day before; the
  evening's night stays on the day's previous close (provisional until the
  7 October 20:10 and 23:00 captures). The chart's day is its own value
  (`chart.day`), apart from Yahoo's quote: the hero at rest, its change
  modes, the info line, the rows, and the pill read the quote; the chart, a
  scrub of it, its legend, and a replay read the day; the line under the
  price names the newest print of all (`chart.latest`) against the quote's
  close, by the day's clock. A US stock or ETF Robinhood does not trade
  all day draws Yahoo's own day, 04:00 to 20:00 (`Overnight.sessionDay`),
  as Robinhood's screen draws one without its 24 Hour Market badge, though
  Robinhood starts at 07:00: Yahoo's pre-market prints from 04:00 are real.
  A US listing's 1D is laid out by print, Robinhood's way
  (`Chart.printFraction`): the prints so far stand evenly from the left
  edge to where the clock puts the newest, so hours nobody traded take no
  room and a thin name's line starts at the left edge, never floating mid-chart
  (PSIX at 14:55 on 7 October started 40% along); the hours to come run by
  the clock. A scrub, the keys' steps, and a replay go print to print, and
  read each print's own moment in both looks: retro's five-minute steps are
  a clock-laid day's, and rounding NBIS's 14:55:42 print read the one before.
  Robinhood's own first point on such a day, the previous close placed at
  07:00, is no trade and is not drawn: the baseline is that close. Any
  other listing's day runs by the clock. Prints outside a regular session are
  dim; ticks on the baseline mark the night's end, the close, and the
  evening's night, those the line has reached drawing in with it and those
  ahead of it there with the baseline, and a
  quiet hour across a night starts the line again, and so does a break in
  the exchange's day from its calendar (Tokyo's lunch, which Yahoo's one
  09:00 to 15:30 session hides), as retro's columns already stop there, in
  the hero, rows, and pill alike; a print alone after one,
  or the day's first, is a dot three times the line's width in its
  session's tone, still where
  the live dot breathes, and a cell of its own in retro; a scrub, the
  pointer's or a replay's, keeps to the prints: its left edge reads the
  day's first print, its right edge the last. Once the regular session has
  closed, its last regular print reads the close the hero shows, at the
  bell, "AT 16:00 · CLOSING BELL" (`Quote.readingAt`): the S&P 500's last
  bar is 15:55's, and Tokyo's row, following a scrub, read its 15:20 bar.
  Not at the quote's own stamp: London's 16:30 close on 7 October was
  stamped 17:20. A print after the close reads itself. The rows follow a scrub
  only inside Yahoo's day: one before it, or the night after it, leaves
  them, and the breadth, on now. The vertical range holds every drawn print
  and the baseline, with headroom; no print is ever clamped to keep it
  inside.
- Every chart, the day and each range, in both looks, has one rule: a
  baseline at the price the change is measured from (the previous close, or
  the period's starting price), and the line or columns and the area to it
  in the up colour above and the down colour below. The rows' day lines
  follow it too; only the pill's 40 px line keeps its figure's one colour.
  The area (smooth's 16% wash, retro's 35% stems) weighs the same on both
  sides in any theme: the up colour sets its alpha, and the down side takes
  the alpha that adds the same OKLab lightness over the surface's ground
  (`Tones.washAlpha`), never a second fixed number, and never more than half
  the ink of the line or cap it sits under, so those stay the most
  important thing. The line itself, dim ink included, is one share of its
  own colour on both sides.
  Up is the theme's green (`green`, else `color2`), as Omarchy colours
  success in every app it themes, and down its red, the shell's urgent;
  never the accent, which in Omarchy means selected. Where the green is
  under 0.10 from the red in OKLab (Hackerman, Lumon, Vantablack, White),
  up is the foreground, as the shell shows a good state beside a bad one.
  The same pair everywhere: the hero, rows, charts and washes, the breadth
  rule, the header's animal, the mark, and every pill form. The theme's
  colours are never adjusted: the sign and the baseline carry direction
  too.
  5Y, 10Y, and All use a log scale; scrub works by bar position, so the
  scale never moves it. A replay is a scrub that drives itself along the
  chart as it is laid out, by print on a US listing's day, by time on any
  other's, and
  by bar on a range, with the chart drawing in behind it, in the plot's own
  terms and retro's whole columns, never ahead of its scrub; it
  ends when the symbol or the range changes. A scrub or replay also ends
  when a refresh brings data that no longer covers it: a range's new
  history, or the day's next session, or its next calendar day.
- One motion for every change of the chart, in both looks (`ChartMotion`):
  it draws in from the left in 320 ms OutCubic, sweeping to the newest drawn
  print (the painters' `inkRight`, `inkColumns`), whether the symbol (from
  any trigger), the range, or a surface opening brought it, and nothing
  slides or fades. A chart on its way holds the one on show whole and
  still under "Loading"; the new one draws in when it lands.

## Style

- QML: value-in components, `readonly property` for derived state, explicit
  `Process` objects for every side effect, `Behavior` animations at the
  shell's 160ms OutCubic.
- Secondary text is the foreground mixed toward the ground it sits on
  (`Tones.dim`, a third of the way, kept at 4.5:1; `Tones.dimmer`, half,
  kept at 3:1), never `Qt.darker`, which makes it louder on a light theme.
  The pill's ground is the bar's.
- Every character Stonks draws is one Omarchy's default font, JetBrainsMono
  Nerd Font, has (⏎ for Enter, ↕ for manual): Qt draws a missing one from
  another font, at another size.
- JavaScript in the rule files (`*.js`): top-level functions only (QML
  cannot import ES modules). A file reads another through
  `.import "X.js" as X` and calls `X.name`; imports run one way, with no
  cycles, and `test/load.js` follows them under `bun`.
- A piece that takes the keys (search, the list menu, the list views) owns
  its lifecycle through one input, `active` (open, on an open surface), and
  keeps what it shows as it closes, fields' text included. The body only
  opens and closes it.

## Branches and pull requests

- Work happens on `dev`. `main` is what users install (`omarchy plugin
  add` clones the default branch, and `omarchy plugin update`
  fast-forwards to it), so it moves only at a release (Releases).
- Start each change on a branch named for it, from `dev` or from the
  unmerged branch it builds on. A small change from a maintainer goes
  straight to `dev`; one that needs another set of eyes gets a branch and a
  pull request.
- A pull request targets `dev`; one opened against `main` is retargeted. One
  built on an unmerged branch targets that branch and says which pull
  request merges first. Merged branches are kept, so GitHub does not
  retarget it: once the base merges, run `gh pr edit N --base dev` before it
  is merged.
- Before the final `test/all.sh`, rebase onto the pull request's base; where tests conflict, keep the base's harness rules and repairs.
- Open the pull request once `test/all.sh` passes, titled for the change. Its body shows what you ran and what you saw, and says what you could not check. It names no one's lists, screens, or home paths: screenshots use the demo watchlist, one listing of each kind (AAPL, busy; PSIX, thin; SPY, an ETF; ^GSPC, an index; BTC-USD, a cryptocurrency; SHEL.L and 7203.T, non-US), as `test/tophat/demo.json` holds it. Fix the review findings that hold up on the same branch.
- Keep merged branches: stacked pull requests rely on them.
- Pull requests leave `manifest.json`'s version alone, so parallel branches never fight over it.

## Releases

A maintainer releases from `dev`. The update notice keys on the version, so
every release bumps it, and nothing reaches `main` without one.

1. Bump `manifest.json`'s version in a release commit on `dev`.
2. Fast-forward `main` to it: `git push origin dev:main`.
3. Tag it (`vX.Y.Z`) and publish release notes.
4. File the Omarchy plugin marketplace's verify form with `main`'s new
   commit; until then the listing says Unverified.

## Agents

`AGENTS.md`, `CLAUDE.md`, and the other agent files are ignored: the
marketplace's review treats them as a listing blocker. Keep your own local
`AGENTS.md` beside this file if your tools read one, and have it send them
here. To copy it into each new worktree as a real file, turn on the hook
once in your main checkout:

```sh
git config core.hooksPath test/hooks
```
