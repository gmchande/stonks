# Stonks

Your watchlist in the Omarchy shell. A pill with one featured symbol and its
day, a popup with a chart you can scrub, and a tiled window that stays open
while you work.

## Install

```sh
omarchy plugin add https://github.com/gmchande/stonks.git --enable
```

Or by hand:

```sh
git clone https://github.com/gmchande/stonks.git ~/.config/omarchy/plugins/grvc.stonks
omarchy-shell shell rescanPlugins
omarchy plugin enable grvc.stonks center
```

`omarchy plugin add` only clones the plugin, so the app launcher has no
Stonks until you copy its entry and icon:

```sh
cp ~/.config/omarchy/plugins/grvc.stonks/share/stonks.desktop ~/.local/share/applications/
mkdir -p ~/.local/share/icons/hicolor/scalable/apps
cp ~/.config/omarchy/plugins/grvc.stonks/share/grvc.stonks.svg ~/.local/share/icons/hicolor/scalable/apps/
```

Quotes come from Yahoo Finance's chart endpoint, which is unofficial: Yahoo
doesn't offer it for this use, and its terms restrict automated access.
Overnight prints for US stocks and ETFs, and which of them Robinhood trades
around the clock, come from Robinhood's public historicals and instruments;
Robinhood's data is for personal use. Neither asks for an account or a key,
and either may change or stop without notice.
Each listing is asked for only as often as its own market can move, all
that are due together over one compressed connection, and a host that
refuses is left alone for a while. Saved quotes show, marked as old, until
the network answers. Needs curl 8.4 or later; Omarchy ships it.
Prices show in each listing's own currency, the way Apple's Stocks does; the
currency code sits next to the exchange beside the name. A price shows the
decimals it needs: a coin under a cent to four significant digits
(0.000005410), a price of 10,000 or more in whole units.

## Use

**The pill.** It starts in the bar's centre. Drag it to another section of
the bar to move it, as you move any bar widget; the popup opens under it
wherever it sits, and in the right section the bar's Super+Ctrl number key
for its place opens the popup, as it does for the icons beside it. It shows
the symbol you last looked at in the popup or the window, and its day as it
stands now: the day's line and change, whatever range the popup or the
window is on, and whatever moment a scrub reads.
Left click opens the popup.
Scroll walks the current list, and the symbol you land on stays featured
until you scroll again. Middle click changes its form, in turn: a
sparkline, an arrow tilted by the size of the move, text with the price
("NBIS 235.62 −5.70%"), and
Stonks' mark alone: a little chart in cells that climbs on an up day and
falls on a down one, and names the symbol and its change when you hover it.
The sparkline and the arrow name the company and the market's phase on
hover; the text says it all already, so its hover is quiet. The pill draws
in the bar's own colour, like Omarchy's icons beside it; the arrow, the
mark, and the sign say which way the day went. It turns the bar's alert
colour only when a refresh has failed or is overdue, with a "!" before the
change (beside the mark on the icon), and hovering any form says which. A
vertical bar has room for the symbol over its change ("−5.7%") in place of
the first three, so there middle click switches between that and the mark.
In the bar's right section, among Omarchy's own icons, the pill is that
icon until you middle-click it there,
and it keeps the form you pick there for the right; the centre and left keep
theirs, and moving the pill brings back each section's own. Right click
opens the window, closing the popup if it is open, or brings it forward
from another workspace; with the window on your workspace, it closes it.
The first time the popup opens, its footer says how to move and change the
pill, and what right click does; it never says it again.

**The window.** `omarchy-shell grvc.stonks openWindow '{}'` opens a tiled
window titled Stonks (class `org.quickshell`). Escape closes it. Choose from
1D through All below the chart; `[` and `]` step between ranges. Historical
scrubs snap to the period Yahoo returned. Past about 720 pixels the window's content
keeps that width and centres. The popup, pill, and window share one
watchlist and their fetch queues. The launcher entry (Install) opens it too.
Want a key for the window? Add this line to `~/.config/hypr/bindings.lua`; a
press opens the window, or brings it forward from another workspace, and a
press while it is on the workspace you are on closes it:

```
o.bind("SUPER + SHIFT + T", "Stonks", "omarchy-shell grvc.stonks toggleWindow")
```

The window tiles by default. A window rule can match class `org.quickshell`
and title `Stonks` if you prefer it floating.

**The popup.** The top line counts down to the open or close while Yahoo
has announced today's bell, and names the moment of the day while it lasts:
the opening bell, New York's lunch lull, the power hour, the closing bell. During after hours it says so with the time of
the close; once trading is over it says the market is closed and names the
next open; weekends and holidays use a schedule the plugin carries. Times
are the exchange's own, with its zone named when it is not yours: in New
York, Nasdaq opens at 09:30 and Tokyo at 09:00 JST. The small
chart icon at the top right shows the look a click switches to: Stonks'
cells in smooth, a curve in retro; click it, or press `s`. The hero is the
featured symbol: Yahoo's regular-market quote and its change, with the
pre-market, after-hours, or overnight print on a compact line under it when
there is one. A US stock or ETF that Robinhood trades around the clock, its
24 Hour Market, trades overnight, 8 pm to 4 am New York time from Sunday to
Thursday night, except before a market holiday. Its line reads
"OVERNIGHT 22:50 234.27 +0.86%": the time of its last trade, and its move
from the regular close. It dims once it is 20 minutes old. A symbol that
hasn't traded tonight keeps its after-hours line, and any other symbol, an
index, a cryptocurrency, or a non-US listing has none. The overnight price
is never the headline, and never in the day's high, low, or change. Such a
symbol's 1D chart is one New York day, midnight to midnight, the way
Robinhood draws it: the night since midnight, the pre-market, the day's
session, its after-hours, and the evening's night, each extended session
dimmer, with the hours still to come left empty and ticks at the night's
end, the close, and the evening's night. A new day begins with its first
trade after midnight; until then the chart stays on the day before. From
midnight to the pre-market the chart is measured from the last close,
while the price above it is still that close and its day. A weekend or a
holiday shows the last trading day. Another US stock or ETF draws its own
day, 4 am to 8 pm. A US listing's 1D lays its trades out evenly, the way
Robinhood does, from the left edge to where the clock has reached, so the
quiet hours of a thinly traded name take no room; the hours still to come
run by the clock. On a range
the change is measured over the range, which is named under it. Under the
range row, two lines always say where the price sits: the day (its date,
so a weekend says the day is Friday's) or the range, over the 52 weeks,
each as its low, a thin rule with a tick at the price, and its high. A day
that reaches a 52-week high or low shows that end in the move's colour on
both lines. Beside them, the day's open once the session has traded and
its volume, or the dates of the range's low and high, and on every range
the market cap and the P/E, each only when known. The cap
and P/E are Yahoo's latest dated figures moved with the price since, so
the cap is an estimate; an ETF, an index, or a cryptocurrency has neither,
and a company losing money has no P/E. A quote older than two minutes
during trading says "as of" with its time. A failed or overdue refresh says
so on the row, on the hero's listing line, and on the pill, and keeps the
last price. A figure that has not moved reads 0.00% with no sign, in neither
colour. Hover the chart to
scrub back through the day; the hero and the header follow, and so does
every row while the scrub is on today,
and the strip under the price names the dashed line the scrub reads
against ("┄ PREV CLOSE 316.85", or "┄ 1Y START 230.03" on a range).
`p` replays the chart: a scrub that plays itself, with the line drawing in
behind it, through the day's trades or times or, on a range, its dates.
Choose from 1D through All under the chart, or wheel over the range row. One
range applies to every symbol and list; the popup and the window share it,
and it is kept across restarts. Every change of chart, another symbol, a new
range, or opening the popup or window, draws it in from the left. Long-range
scrubs leave the watchlist rows on today,
and the rows always show the day's change.
Click a row to feature it; right-click (or middle-click) removes it, and
the footer says what went: `u`, or a click on that note, puts it back where
it was, in every list that held it, until you next change a list. The
featured row is filled. One cursor, as in Omarchy's own panels, is a bar
down the left edge on a lightly filled row: the pointer puts it on the row
under it, the arrow keys move it on from wherever it is, and it stays when
the pointer leaves the list. Before you point or press a key, it rests on
the featured row (or the first row, when the featured symbol is not in this
list).

**Lists.** All holds every symbol you follow; named lists, such as My
Portfolio or Energy, hold some of them, and a symbol can be in several.
The list's name sits at the left of the line above the rows: click it, or
press `w`, for the menu of lists with their counts and "New list…". `,` and
`.` step through them. A dim TODAY follows the name, since the rows and the
rest of that line are the day's on every range; a scrub of the day moves
them through it. The rest of the line is the list's breadth: the up colour
runs in from the left for the rows that are up and the down colour from the
right for those down, so each list shows its mood before you read a row;
hover it for the counts. A new list starts empty and search opens to fill
it.
Adding on a named list puts the symbol in that list and in All; removing on a
named list takes it out of that list only, and removing on All takes it out
of every list. All always keeps one symbol; a named list may be empty. Each
list keeps its own order and direction: click the order word above the rows,
or press `o`, to cycle manual, symbol, name, and % change, and
Shift-click it, or press `Shift+O`, to run a sorted order the other way, so
% change can put the biggest losers first. The arrow before the word says
which way the values run down the list: `↓` from the largest, `↑` from the
smallest; manual order shows `↕`. Each list also comes back where you left it,
scrolled as it was, until the shell restarts; a list you have not opened yet
starts at the top. Switching lists leaves the featured symbol, the
hero, and the pill where they were. Every symbol is fetched once, however
many lists hold it.
"Manage lists…" at the end of the menu (or `Shift+W`) renames, reorders, and
deletes named lists; All stays first and cannot be changed, and a delete asks
first, in the row. `m` on the cursor row, or Ctrl-click on any row, shows that
symbol's lists as tick boxes: ticking adds it to a list, unticking takes it
out, and unticking All removes it everywhere.
Rows can be moved by hand only while manual order is shown. Click the change
to cycle percent, currency amount, and percent since the open; that is the
day's change, so on a range it changes the rows and the hero keeps the
range's. Sorting by % change ranks the rows and leaves what they show
alone. In search, the top result is chosen to start with, and the arrows
choose another; the hero shows the chosen result before you add it: its
price, chart, and figures, on the range you are on. Enter adds it, or click
a result and then its Add; Escape goes back to the featured symbol. A result
already in the list you are on says Show instead: Enter or Show features its
row. A result's quote is fetched once the choice rests on it, and not
refreshed until you add it. `?` opens the shortcut sheet: the everyday keys
and what the mouse does. Every key is in this table:

| Key | Does |
| --- | --- |
| `↑` `↓` | Move the row cursor |
| `j` `k` | Move the row cursor (popup) |
| `⏎` | Feature the cursor row |
| Space | Feature the cursor row (popup) |
| `←` `→` | Scrub one chart step |
| `h` `l` | Scrub one chart step (popup) |
| `[` `]` | Change the chart range |
| `p` | Replay the shown chart |
| `Shift+P` | Replay it in slow motion |
| `a` or `+` | Search and add a symbol |
| `x` | Remove the cursor row |
| `u` | Undo a removal, while the footer offers it |
| Delete or Backspace | Remove the cursor row (window) |
| `Shift+J` `Shift+K` | Reorder the cursor row (manual order only) |
| `o` | Cycle the list order |
| `Shift+O` | Reverse a sorted order (or Shift-click the order) |
| `w` | Open the list menu |
| `Shift+W` | Manage lists: rename, reorder, delete |
| `m` | The cursor row's lists |
| `,` `.` | Previous or next list, scrolled where you left it |
| `c` | Cycle the day's change: percent, amount, and since-open |
| `s` | Switch between the smooth and retro looks |
| `r` | Refresh |
| `1` to `9` | Feature that row |
| Tab or `Shift+Tab` | Next panel on the bar (popup) |
| `?` | Open the shortcut sheet |
| `Esc` | Close the sheet, then the scrub, then the popup or window |

**Two looks.** Smooth is the default: a big price and a line chart. Retro
draws the way Omarchy draws its own logo: block digits on a lit grid, pixel
columns, and pixel sparklines. Both put a bull in the header when the
featured chart is up and a bear when it is down, at the moment shown, drawn
as a line in smooth and in pixels in retro, and none on a flat day: a
scrub or a replay across the close turns one into the other. Click the
animal to replay the shown chart. Both looks draw every range the same
way: the line or columns and the area to the baseline (the previous close,
or the price the range started at) in the up colour above it and the down
colour below, and the rows' lines do the same. Up is the theme's green and
down its red; a theme whose green and red are too close to tell apart
(Hackerman, Lumon, Vantablack, White) shows up in its plain text colour.
Both looks leave a gap where the market paused: Tokyo's lunch break, and a
quiet night. 5Y, 10Y, and All use a log
scale. Smooth signs changes with +
and −, retro with ▲ and ▼. Switching looks moves nothing but the digits.
Shift-click the chart, or `Shift+P`, for the slow-motion replay.

All, the named lists, each list's order and direction, the current list, the
featured symbol, the chart range, look, change mode, refresh interval, and
whether the popup has shown its first-time hint persist in
`~/.config/omarchy/grvc.stonks.json`. All keeps the file's
original `symbols` and `order` keys, with its direction in a key of its own,
`reversed`, so an older version of the plugin still reads it (and drops the
named lists and the directions on its next save). Where each list is scrolled
is kept only until the shell restarts. The pill's
forms, `barStyle` for the centre and left and `barStyleRight` for the right
section, stay on its bar entry, which middle click writes.

The window also works with nothing on the bar, though Omarchy has no switch
for it: enabling a bar widget always puts it on the bar. Take the pill out of
the bar and add a presence entry by hand so the plugin stays loaded:

```sh
omarchy plugin disable grvc.stonks
```

Then add `{ "id": "grvc.stonks" }` to `plugins` in
`~/.config/omarchy/shell.json`. To put the pill back, remove that presence
entry by hand first, then:

```sh
omarchy plugin enable grvc.stonks center
```

The order matters both ways. The shell looks for the plugin in the bar
before it looks in `plugins`, so `disable` removes the pill and leaves the
presence entry alone, and `enable` (or `omarchy bar put`) does nothing
while a presence entry exists.

## Develop

The plugin uses QML and plain JavaScript rule files, with no build step. Runtime
files stay at the repository root for the manifest's entry points; tests live
in `test/`, and the optional launcher lives in `share/`.
See [CONTRIBUTING.md](CONTRIBUTING.md) for architecture, domain rules,
verification, and how to send a change.

- `test/all.sh` runs every check (it needs a Wayland session; one to two
  minutes). The saved answers some checks read are private, so on a fresh
  clone those checks skip and say why. `bun test test/model.test.js` alone
  runs the pure data rules in the rule files (`*.js`).
- An edit takes effect after `omarchy restart shell`: `Plugin.qml` stays loaded, and a hot reload can leave the old window answering.
- `omarchy-shell shell toggle grvc.stonks` opens the popup from a terminal,
  on the focused screen's pill, as the bar's Super+Ctrl number keys do.
- `omarchy-shell grvc.stonks openWindow '{}'` opens the window;
  `'{"symbol":"AAPL","range":"1Y"}'` opens it on that symbol and range.
