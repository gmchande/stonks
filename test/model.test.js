import { test, expect } from "bun:test"
import { existsSync, readdirSync, readFileSync } from "node:fs"
import { join } from "node:path"
import { load } from "./load.js"

// The pure rules: tests that read no saved answer, so they run on any
// clone. Those that read Yahoo's and Robinhood's saved answers are in
// saved.test.js.
const root = join(import.meta.dir, "..")
// The reader is in New York: an exchange's time is named
// with its zone only where that clock differs from the reader's.
process.env.TZ = "America/New_York"
// Every rule file's names, under one name: each is defined once.
const M = Object.assign({}, ...["Format", "Fetch", "Quote", "Market", "Overnight", "History", "Fundamentals", "Figures",
  "Chart", "Tones", "Settings", "KeySheet", "Search", "Cells"].map(name => load(name + ".js")))

const calendars = JSON.parse(readFileSync(join(root, "calendars.json"), "utf8"))
const US = calendars.calendars.US
const JPX = calendars.calendars.JPX
const DAY = 24 * 3600
const keptBars = bars => M.filterStrayCloses(bars).bars
const at = (date, clock) => M.epochAt(US, date, clock)

test("a stray run is the one the series carries on past", () => {
  // The bar after opens back at the level, not from the stray close.
  const stray = [
    { t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 90 }, { t: 600, o: 100, c: 101 }
  ]
  expect(keptBars(stray).map(bar => bar.c)).toEqual([100, 101])
  // Two in a row, MSFT's shape: the second opens from the first, so no single
  // bar breaks continuity — only the bar after the pair does.
  const pair = [
    { t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 115 }, { t: 600, o: 114, c: 110 },
    { t: 900, o: 100, c: 100.1 }
  ]
  expect(keptBars(pair).map(bar => bar.c)).toEqual([100, 100.1])
  // A real move: the next bar opens from where this one closed.
  const real = [
    { t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 90 }, { t: 600, o: 90, c: 100 }
  ]
  expect(keptBars(real)).toEqual(real)
  // A real move that stays away is never a run at all.
  const stayed = [
    { t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 104 }, { t: 600, o: 104, c: 104.2 },
    { t: 900, o: 104.2, c: 103.9 }
  ]
  expect(keptBars(stayed)).toEqual(stayed)
  // Small enough that price shape alone could not tell it from trading.
  const small = [
    { t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 99.2 }, { t: 600, o: 99.2, c: 100 }
  ]
  expect(keptBars(small)).toEqual(small)
})

test("stray filtering never judges the newest bar or an uneven gap", () => {
  const newest = [{ t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 100 }, { t: 600, o: 100, c: 90 }]
  // The last hourly bar of a day: the next bar is tomorrow's open.
  const overnight = [{ t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 90 }, { t: 900, o: 100, c: 101 }]
  const noOpens = [{ t: 0, c: 100 }, { t: 300, c: 90 }, { t: 600, c: 100 }]
  // A run longer than Yahoo has ever sent is a real move, not corruption.
  const long = [
    { t: 0, o: 100, c: 100 }, { t: 300, o: 100, c: 90 }, { t: 600, o: 90, c: 91 },
    { t: 900, o: 91, c: 90 }, { t: 1200, o: 90, c: 91 }, { t: 1500, o: 100, c: 100 }
  ]
  expect(keptBars(newest)).toEqual(newest)
  expect(keptBars(overnight)).toEqual(overnight)
  expect(keptBars(noOpens)).toEqual(noOpens)
  expect(keptBars(long)).toEqual(long)
  expect(keptBars([])).toEqual([])
})

test("yAt interpolates a polyline and is null past the line", () => {
  const pts = [{ x: 0, y: 0 }, { x: 1, y: 1 }]
  expect(M.yAt(pts, 0.5)).toBe(0.5)
  expect(M.yAt(pts, 0)).toBe(0)
  expect(M.yAt(pts, 1)).toBe(1)
  expect(M.yAt(pts, -0.1)).toBeNull()
  expect(M.yAt(pts, 1.1)).toBeNull()
  expect(M.yAt([], 0.5)).toBeNull()
})

test("an extended-hours print extends the day range as far as it reaches", () => {
  const q = {
    prevClose: 100,
    session: { regular: { start: 0, end: 900 } },
    points: [{ t: 0, p: 100 }, { t: 300, p: 110 }, { t: 900, p: 50 }]
  }
  const geometry = M.chartGeometry(q)
  expect(geometry.lo).toBeCloseTo(45.2, 10)
  expect(geometry.hi).toBeCloseTo(114.8, 10)
  expect(geometry.points[2].ext).toBe(true)
  for (const p of geometry.points) {
    expect(p.y).toBeGreaterThan(0)
    expect(p.y).toBeLessThan(1)
  }
})

test("Tokyo's lunch break comes from the calendar; the morning session stays on Yahoo", () => {
  const morning = 1788832800
  const lunch = 1788836400
  const jpx = {
    symbol: "7203.T",
    exchange: "TSE",
    timezoneName: "Asia/Tokyo",
    gmtoffset: 32400,
    crypto: false,
    session: { pre: null, post: null, regular: { start: M.epochAt(JPX, "2026-09-08", "09:00"), end: M.epochAt(JPX, "2026-09-08", "15:30") } },
    points: []
  }
  expect(M.marketStatus(jpx, morning, 0, calendars)).toBe("Market closes in 4h 30m")
  // Tokyo's clock is named for a reader in New York.
  expect(M.marketStatus(jpx, lunch, 0, calendars)).toBe("Lunch break · reopens 12:30 JST · in 30m")
})

test("formatting", () => {
  expect(M.duration(4200)).toBe("1h 10m")
  expect(M.duration(300)).toBe("5m")
  expect(M.duration(39 * 3600 + 1200)).toBe("1d 15h")
  // A countdown rounds up: its last minute reads 1m, never 0m.
  expect(M.duration(59)).toBe("1m")
  expect(M.duration(1)).toBe("1m")
  expect(M.duration(3570)).toBe("1h")
  expect(M.duration(4141)).toBe("1h 10m")
  expect(M.money(1234.5)).toBe("1,234.50")
  expect(M.money(118204)).toBe("118,204")
  expect(M.money(undefined)).toBe("—")
  expect(M.pct(-1.137)).toBe("\u22121.14%")
  expect(M.pct(1267.16)).toBe("+1,267%")
  expect(M.pct(71789.6)).toBe("+71,790%")
  expect(M.pct(-999.99)).toBe("\u2212999.99%")
  expect(M.changeText({ abs: 0.91, pct: 0.52 }, "abs")).toBe("+0.91")
  expect(M.changeText({ abs: -1234.5, pct: -2 }, "abs")).toBe("\u22121,234.50")
  expect(M.nextChangeMode("pct")).toBe("abs")
  expect(M.nextChangeMode("open")).toBe("pct")
  expect(M.compactNumber(52432411)).toBe("52.4M")
  expect(M.compactNumber(1234)).toBe("1K")
  expect(M.compactNumber(2.5e9)).toBe("2.5B")
  // A figure that rounds up to 1,000 of its unit is one of the next, and
  // trillions take fewer decimals as they grow, so no count draws wider
  // than 999.9M.
  expect([999499, 999500, 999.9e6, 999.96e6, 999.9e9, 999.96e9, 4.9e12, 33.82e12, 99.996e12, 400.11e12, 999.96e12, 12345.6e12]
    .map(M.compactNumber))
    .toEqual(["999K", "1.0M", "999.9M", "1.0B", "999.9B", "1T", "4.9T", "33.82T", "100T", "400.1T", "1000T", "12346T"])
})

test("arrowAngle saturates at five percent", () => {
  expect(M.arrowAngle(0)).toBe(0)
  expect(M.arrowAngle(2.5)).toBe(22.5)
  expect(M.arrowAngle(9)).toBe(45)
  expect(M.arrowAngle(-9)).toBe(-45)
})

test("each look has one sign language", () => {
  expect(M.lookSigns("+2.55%", false)).toBe("+2.55%")
  expect(M.lookSigns("\u22120.59%", false)).toBe("\u22120.59%")
  expect(M.lookSigns("+2.55%", true)).toBe("▲2.55%")
  expect(M.lookSigns("\u22120.59%", true)).toBe("▼0.59%")
  expect(M.lookSigns("—", true)).toBe("—")
})

test("a run's output splits into its answers, each said by what came back", () => {
  const trailer = (i, status, exit, retry = "") => `\n@@stonks ${i} ${status} ${exit} ${retry}\n`
  const text = '{"chart":1}' + trailer(0, 200, 0)
    + '{"e":"Not Found"}' + trailer(1, 404, 0)
    + "Too Many Requests" + trailer(2, 429, 0, "30")
    + trailer(3, "000", 6)
    + '{"x":"aaa' + trailer(4, 200, 63)
    + "<html>" + trailer(5, 502, 0)
    + '{"chart":2}' + trailer(7, 200, 0)
  const got = M.answers(text).map(a => [a.index, a.kind, a.body, a.retryAfter])
  expect(got).toEqual([
    [0, "ok", '{"chart":1}', 0],
    [1, "missing", '{"e":"Not Found"}', 0],
    [2, "refused", "Too Many Requests", 30],
    [3, "none", "", 0],
    [4, "bad", '{"x":"aaa', 0],
    [5, "bad", "<html>", 0],
    // The run never reached 6: it has no answer.
    [7, "ok", '{"chart":2}', 0]
  ])
  expect(M.answerKind(503, 0)).toBe("refused")
  expect(M.soleBody('{"a":1}' + trailer(0, 200, 0))).toBe('{"a":1}')
  expect(M.soleBody("Too Many" + trailer(0, 429, 0))).toBe("")
  // A run stopped mid-answer: the cut answer has no trailer, so none.
  expect(M.answers('{"a":1}' + trailer(0, 200, 0) + '{"b":').length).toBe(1)
})

test("blockCells lays digits on a grid with a blank column between", () => {
  const grid = text => {
    const { columns, cells } = M.blockCells(text)
    const rows = Array.from({ length: 6 }, () => Array(columns).fill(" "))
    for (const cell of cells) rows[cell.y][cell.x] = cell.lit ? "#" : "."
    return rows.map(row => row.join(""))
  }
  expect(grid("10")).toEqual([".#. ###", "##. #.#", ".#. #.#", ".#. #.#", "### ###", "       "])
  expect(grid("1.5")).toEqual([".#.   ###", "##.   #..", ".#.   ###", ".#.   ..#", "### # ###", "         "])
  // The comma hangs a cell below the baseline, which the point never does.
  expect(grid("1,0")).toEqual([".#.   ###", "##.   #.#", ".#.   #.#", ".#.   #.#", "### # ###", "    #    "])
  expect(M.blockCells("1,015.80").columns).toBe(27)
  // The price on its way draws as three dots, not as nothing at all.
  expect(M.blockCells("…").cells.filter(cell => cell.lit).length).toBe(3)
  expect(M.blockCells("…").columns).toBe(5)
  // The retro hero draws the dash rather than nothing.
  expect(M.blockCells("—").cells.filter(cell => cell.lit)).toEqual([
    { x: 0, y: 2, lit: true }, { x: 1, y: 2, lit: true }, { x: 2, y: 2, lit: true }
  ])
})

test("sprites fill the 20 by 14 grid, and the bull is not the bear", () => {
  for (const sprite of [M.BULL_SPRITE, M.BEAR_SPRITE]) {
    expect(sprite.length).toBe(14)
    for (const row of sprite) expect(row.length).toBe(20)
  }
  expect(M.spriteFor(true)).not.toEqual(M.spriteFor(false))
})

function historyBody(overrides) {
  const meta = { symbol: "AAPL", currency: "USD", gmtoffset: -14400, chartPreviousClose: 200, firstTradeDate: 345459600, ...(overrides.meta || {}) }
  const quote = {
    open: [1, 2, 3],
    high: [1.1, 2.1, 3.1],
    low: [0.9, 1.9, 2.9],
    close: [1, 2, 3],
    volume: [10, 20, 30],
    ...(overrides.quote || {})
  }
  return {
    chart: {
      result: [{
        meta,
        timestamp: overrides.timestamp || [100, 200, 300],
        indicators: { quote: [quote] }
      }]
    }
  }
}

test("parseHistory filters intraday prints but leaves daily reversals untouched", () => {
  const common = {
    timestamp: [100, 200, 300],
    quote: { open: [100, 100, 100], close: [100, 96, 100], high: [101, 97, 101], low: [95, 95, 99], volume: [10, 10, 10] }
  }
  const intraday = M.parseHistory(historyBody({ ...common, meta: { dataGranularity: "15m" } }), "1W")
  const daily = M.parseHistory(historyBody({ ...common, meta: { dataGranularity: "1d" } }), "1M")
  expect(intraday.bars.map(bar => bar.c)).toEqual([100, 100])
  expect(daily.bars.map(bar => bar.c)).toEqual([100, 96, 100])
})

test("parseHistory drops null closes, and without a previous close the first close is the baseline", () => {
  const hist = M.parseHistory(historyBody({
    meta: { chartPreviousClose: "nope" },
    quote: { close: [1, null, 3] }
  }), "1Y")
  expect(hist.bars.map(b => b.t)).toEqual([100, 300])
  expect(hist.bars.map(b => b.c)).toEqual([1, 3])
  expect(hist.baseline).toBe(1)
})

test("parseHistory drops a duplicate of the last bar", () => {
  const hist = M.parseHistory(historyBody({
    timestamp: [100, 200, 200],
    quote: {
      open: [1, 2, 2],
      high: [1.1, 2.1, 2.2],
      low: [0.9, 1.9, 1.8],
      close: [1, 2, 2.05],
      volume: [10, 20, 21]
    }
  }), "1Y")
  expect(hist.bars).toEqual([
    { t: 100, o: 1, h: 1.1, l: 0.9, c: 1 },
    { t: 200, o: 2, h: 2.2, l: 1.8, c: 2.05 }
  ])
})

test("coverage is short only when the response begins within one interval of listing", () => {
  const base = { interval: "1d", baseline: 10, firstTradeDate: 100, bars: [{ t: 100, h: 11, l: 9, c: 10 }] }
  expect(M.periodStats(base).coverage.short).toBe(true)
  expect(M.periodStats({ ...base, bars: [{ ...base.bars[0], t: 100 + DAY }] }).coverage.short).toBe(true)
  expect(M.periodStats({ ...base, bars: [{ ...base.bars[0], t: 101 + DAY }] }).coverage.short).toBe(false)
  expect(M.periodStats({ ...base, interval: "1wk", bars: [{ ...base.bars[0], t: 100 - 3 * DAY }] }).coverage.short).toBe(true)
  expect(M.periodStats({ ...base, interval: "1wk", bars: [{ ...base.bars[0], t: 100 - 8 * DAY }] }).coverage.short).toBe(false)
  expect(M.periodStats({ ...base, firstTradeDate: null }).coverage.short).toBe(false)
})

test("a response with no bars draws nothing and claims nothing", () => {
  const empty = M.parseHistory({ chart: { result: [{ meta: { symbol: "NEW", chartPreviousClose: 10 }, indicators: { quote: [{}] } }] } }, "1Y")
  expect(M.periodStats(empty)).toEqual({
    last: null,
    change: { abs: null, pct: null, up: true },
    high: null,
    low: null,
    belowHigh: null,
    coverage: { from: null, to: null, bars: 0, short: false }
  })
  expect(M.historyGeometry(empty)).toEqual({
    points: [], baselineY: null, ticks: [], lo: null, hi: null, start: null, end: null, day: false
  })
  expect(M.historyBarAt(empty, 0.5)).toBeNull()
  expect(M.historyFraction(empty, 1)).toBe(-1)
  expect(M.historyBarAt({ bars: [{ t: 1, c: 2 }] }, NaN)).toBeNull()
  expect(M.historyFraction({ bars: [{ t: 1, c: 2 }] }, 1)).toBe(0)
})

test("the view's chart can be drawn once its data is in, or its first fetch has failed", () => {
  const quote = { symbol: "A" }
  const history = { bars: [] }
  const ok = { A: { status: "ok" } }
  // The day: its quote, or its first fetch failed; nothing while it is out.
  expect(M.viewChart("A", "1D", { A: quote }, {}, {})).toEqual({ symbol: "A", range: "1D", quote, day: quote, latest: null, history: null, failed: false })
  expect(M.viewChart("A", "1D", {}, { A: { status: "loading" } }, {})).toBeNull()
  expect(M.viewChart("A", "1D", {}, { A: { status: "failed" } }, {})).toMatchObject({ quote: null, failed: false })
  // A failed first quote is the answer on a range too: no headline from the
  // history's last bar.
  expect(M.viewChart("A", "1M", {}, { A: { status: "failed" } }, { "A|1M": { status: "ok", history } }))
    .toMatchObject({ quote: null, history: null, failed: false })
  // A range needs its history and the symbol's quote: the headline is never
  // the last bar. Nothing while the history's first answer is out.
  expect(M.viewChart("A", "1M", {}, ok, { "A|1M": { status: "ok", history } })).toBeNull()
  expect(M.viewChart("A", "1M", { A: quote }, ok, {})).toBeNull()
  expect(M.viewChart("A", "1M", { A: quote }, ok, { "A|1M": { status: "ok", history } })).toMatchObject({ history, failed: false })
  // History in hand stays drawn after a refetch fails.
  expect(M.viewChart("A", "1M", { A: quote }, ok, { "A|1M": { status: "failed", history } })).toMatchObject({ history, failed: false })
  // A first fetch that failed has the day stand in (through its retry: the
  // answer stays until another lands).
  expect(M.viewChart("A", "1M", { A: quote }, ok, { "A|1M": { status: "failed", history: null } })).toMatchObject({ history: null, failed: true })
})

// Named lists (Phase 4). All is the library, stored as the version-1
// `symbols`; named lists are subsets with their own order.
const library = (extra = {}) => M.fileSettings({
  symbols: ["NBIS", "BE", "IREN", "SPY"], featured: "NBIS", order: "pct",
  lists: [
    { name: "My Portfolio", symbols: ["NBIS", "BE"], order: "manual" },
    { name: "Energy", symbols: ["BE", "IREN"], order: "name" }
  ],
  ...extra
})

test("the data file reads as written and repairs hand edits", () => {
  const v1 = { version: 1, symbols: ["NBIS", "SNOW"], featured: "SNOW", order: "pct", changeMode: "pct", style: "retro", refreshIntervalSec: 60 }
  const read = M.fileSettings(v1)
  expect(read).toEqual({ ...v1, reversed: false, lists: [], list: "", range: "1D", hinted: false })
  expect(M.listSymbols(read)).toEqual(["NBIS", "SNOW"])
  expect(M.listOrder(read)).toBe("pct")
  // The version-1 keys keep their meaning, so an older build reads the same All.
  const withLists = library({ list: "Energy" })
  expect(withLists.symbols).toEqual(["NBIS", "BE", "IREN", "SPY"])
  expect(withLists.order).toBe("pct")
  // No file: the default library and cadence.
  expect(M.fileSettings(null).symbols).toEqual(["NVDA", "AAPL", "MSFT", "SPY", "TSLA"])
  expect(M.fileSettings(null).refreshIntervalSec).toBe(60)
  // Symbols are upper-cased, trimmed, and kept once, from a string or a list.
  expect(M.fileSettings({ symbols: "nvda, aapl AAPL" }).symbols).toEqual(["NVDA", "AAPL"])
  expect(M.fileSettings({ symbols: ["spy", " tsla ", "SPY"] }).symbols).toEqual(["SPY", "TSLA"])
  // The cadence stays between 30 seconds and 15 minutes.
  for (const [given, kept] of [[15, 30], [1000, 900], [120, 120], ["nope", 60]])
    expect([given, M.fileSettings({ refreshIntervalSec: given }).refreshIntervalSec]).toEqual([given, kept])
  // A symbol only a named list holds joins All; an unknown current list is
  // All, and a change of case is not unknown.
  const orphan = M.fileSettings({ symbols: ["NBIS"], lists: [{ name: "Energy", symbols: ["BE"] }], list: "Gone" })
  expect(orphan.symbols).toEqual(["NBIS", "BE"])
  expect(orphan.list).toBe("")
  expect(M.fileSettings({ symbols: ["NBIS"], lists: [{ name: "Energy" }], list: "energy" }).list).toBe("Energy")
  // A hand edit's unknown order is manual, manual is never reversed, and
  // list names are trimmed, kept once ignoring case, and never All or empty.
  const edited = M.fileSettings({ symbols: ["BE"], order: "bogus", reversed: true, lists: [
    { name: "  Energy  ", symbols: ["be", "BE"], reversed: true }, { name: "energy", symbols: ["X"] },
    { name: "All", symbols: [] }, { name: "", symbols: [] }, { name: "Wins", order: "bogus" },
    { name: "Losers", order: "pct", reversed: true }
  ] })
  expect([edited.order, edited.reversed]).toEqual(["manual", false])
  expect(edited.lists).toEqual([
    { name: "Energy", symbols: ["BE"], order: "manual", reversed: false },
    { name: "Wins", symbols: [], order: "manual", reversed: false },
    { name: "Losers", symbols: [], order: "pct", reversed: true }
  ])
})

// lists.qml drives adding, removing, stepping, naming, and ordering through
// the real Service and keys, on a library where no symbol is in two named
// lists and every add is already in All. These are the cases it cannot reach.
test("membership across several lists", () => {
  // A new symbol added on a named list joins All; one added on All joins no list.
  const onEnergy = M.withSymbolAdded(library({ list: "Energy" }), "fslr")
  expect(onEnergy.symbols).toEqual(["NBIS", "BE", "IREN", "SPY", "FSLR"])
  expect(M.listSymbols(onEnergy)).toEqual(["BE", "IREN", "FSLR"])
  expect(onEnergy.featured).toBe("NBIS")
  const onAll = M.withSymbolAdded(library(), "FSLR")
  expect(onAll.symbols).toContain("FSLR")
  expect(onAll.lists.every(list => list.symbols.indexOf("FSLR") < 0)).toBe(true)
  // BE is in both named lists: leaving Energy keeps it in My Portfolio and All;
  // leaving All takes it out of both.
  const offEnergy = M.withMembership(library({ list: "Energy" }), "BE", "Energy", false, ["BE", "IREN"])
  expect([offEnergy.symbols, offEnergy.lists.map(list => list.symbols)])
    .toEqual([["NBIS", "BE", "IREN", "SPY"], [["NBIS", "BE"], ["IREN"]]])
  const offAll = M.withMembership(library(), "BE", "", false, ["BE", "NBIS", "IREN", "SPY"])
  expect([offAll.symbols, offAll.lists.map(list => list.symbols)])
    .toEqual([["NBIS", "IREN", "SPY"], [["NBIS"], ["IREN"]]])
  // The featured symbol leaving All from the last row shown hands the hero
  // to the row above it; All keeps its last symbol.
  expect(M.withMembership(library(), "NBIS", "", false, ["BE", "IREN", "SPY", "NBIS"]).featured).toBe("SPY")
  const one = M.fileSettings({ symbols: ["NBIS"] })
  expect(M.withMembership(one, "NBIS", "", false, ["NBIS"]).symbols).toEqual(["NBIS"])
  // Each list keeps its own order and manual arrangement, apart from All's.
  const energy = M.withListOrder(library({ list: "Energy" }), "symbol")
  expect([M.listOrder(energy), energy.order, energy.lists[0].order]).toEqual(["symbol", "pct", "manual"])
  const all = M.withListOrder(library(), "symbol")
  expect([all.order, all.lists[1].order]).toEqual(["symbol", "name"])
  const moved = M.withManualOrder(library({ list: "Energy" }), ["IREN", "BE"])
  expect([M.listSymbols(moved), M.listOrder(moved), moved.symbols])
    .toEqual([["IREN", "BE"], "manual", ["NBIS", "BE", "IREN", "SPY"]])
  // A reorder that does not hold the list's symbols is refused.
  expect(M.listSymbols(M.withManualOrder(library({ list: "Energy" }), ["IREN"]))).toEqual(["BE", "IREN"])
  // A list's direction is its own, survives a change of its members, and
  // goes with a new order or a hand arrangement.
  const losers = M.withListReversed(library({ list: "Energy" }))
  expect([M.listReversed(losers), losers.reversed, losers.lists[0].reversed]).toEqual([true, false, false])
  expect(M.listReversed(M.withSymbolAdded(losers, "FSLR"))).toBe(true)
  expect(M.listReversed(M.withMembership(losers, "BE", "Energy", false, ["IREN", "BE"]))).toBe(true)
  expect(M.listReversed(M.withListOrder(losers, "pct"))).toBe(false)
  expect(M.listReversed(M.withManualOrder(losers, ["IREN", "BE"]))).toBe(false)
  expect(M.listReversed(M.withListReversed(library({ list: "My Portfolio" })))).toBe(false)
})

test("which day the 1D chart shows: the newest print's, or on a closed date the last trading day", () => {
  const date = newest => M.chartDate(US, newest)
  // A weekday's first print after midnight begins its day.
  expect(date(at("2026-10-07", "00:00"))).toBe("2026-10-07")
  // Until then the chart stays on the day before, so it never stands
  // empty: Wednesday 00:05, its newest print Tuesday 23:55.
  expect(date(at("2026-10-06", "23:55"))).toBe("2026-10-06")
  // A weekend or a holiday shows the last trading day, all day, Sunday
  // night's session included (provisional): Saturday on Friday's last
  // print, Sunday 22:25, Thanksgiving's evening, and the night before the
  // half day after it.
  expect(date(at("2026-10-09", "19:55"))).toBe("2026-10-09")
  expect(date(at("2026-10-11", "22:25"))).toBe("2026-10-09")
  expect(date(at("2026-11-26", "20:30"))).toBe("2026-11-25")
  expect(date(at("2026-11-26", "23:55"))).toBe("2026-11-25")
  // Monday's first print after midnight begins Monday.
  expect(date(at("2026-10-12", "00:05"))).toBe("2026-10-12")
})

test("an open surface asks Robinhood again every five minutes of a night, and once after it", () => {
  const due = (asked, now) => M.overnightDue(asked, now, calendars)
  expect(due(0, at("2026-10-02", "13:00"))).toBe(true)
  expect(due(at("2026-10-01", "22:56"), at("2026-10-01", "23:00"))).toBe(false)
  expect(due(at("2026-10-01", "22:55"), at("2026-10-01", "23:00"))).toBe(true)
  // The night's last bars are in ten minutes after 04:00.
  expect(due(at("2026-10-02", "03:58"), at("2026-10-02", "04:05"))).toBe(false)
  expect(due(at("2026-10-02", "03:58"), at("2026-10-02", "04:11"))).toBe(true)
  // Nothing new comes between then and the next night, nor at the weekend.
  expect(due(at("2026-10-02", "04:11"), at("2026-10-02", "19:59"))).toBe(false)
  expect(due(at("2026-10-02", "13:00"), at("2026-10-03", "12:00"))).toBe(false)
  expect(due(at("2026-10-03", "12:00"), at("2026-10-04", "20:05"))).toBe(true)
})

test("each print says its own time across a change of clocks, and the day marks an early close", () => {
  // Summer time ends Sunday 1 November 2026. On Sunday night Yahoo's response
  // is still Friday's, in summer time; the night's print is not.
  const quote = {
    symbol: "X", instrumentType: "EQUITY", exchange: "NASDAQ", gmtoffset: -14400, prevClose: 100, price: 100,
    marketTime: at("2026-10-30", "16:00"),
    session: {
      pre: { start: at("2026-10-30", "04:00"), end: at("2026-10-30", "09:30") },
      regular: { start: at("2026-10-30", "09:30"), end: at("2026-10-30", "16:00") },
      post: { start: at("2026-10-30", "16:00"), end: at("2026-10-30", "20:00") }
    },
    points: [{ t: at("2026-10-30", "19:55"), p: 100 }]
  }
  const sunday = M.dayChart(quote, [{ t: at("2026-11-01", "21:00"), p: 100.5, s: "overnight" }], calendars)
  expect(M.extendedStack(quote, sunday.latest, at("2026-11-01", "21:05"), sunday.day)).toMatchObject({ label: "OVERNIGHT", time: "21:00" })
  // The day after Thanksgiving closes at 13:00, and its tick says so: laid
  // out by print, it stands between the 12:55 print and the 15:00 one, and
  // none stands at 16:00, past the newest print, where the clock runs.
  const early = {
    ...quote, gmtoffset: -18000, marketTime: at("2026-11-27", "13:00"),
    session: {
      pre: { start: at("2026-11-27", "04:00"), end: at("2026-11-27", "09:30") },
      regular: { start: at("2026-11-27", "09:30"), end: at("2026-11-27", "13:00") },
      post: { start: at("2026-11-27", "13:00"), end: at("2026-11-27", "17:00") }
    },
    points: [{ t: at("2026-11-27", "12:55"), p: 101 }, { t: at("2026-11-27", "15:00"), p: 101.5 }]
  }
  const friday = M.dayChart(early, [{ t: at("2026-11-26", "22:00"), p: 100.2, s: "overnight" }], calendars).day
  const geometry = M.chartGeometry(friday)
  const [noon, afternoon] = geometry.points.map(p => p.x)
  expect(geometry.ticks.filter(x => x > noon && x < afternoon)).toHaveLength(1)
  expect(geometry.ticks.filter(x => x > afternoon).map(x => M.timeAtFraction(friday, x))).not.toContain(at("2026-11-27", "16:00"))
})

test("a failed answer is asked again five minutes on, whatever the hour", () => {
  const asked = at("2026-10-02", "04:11")
  expect(M.overnightDue(asked, at("2026-10-02", "04:15"), calendars, true)).toBe(false)
  expect(M.overnightDue(asked, at("2026-10-02", "04:16"), calendars, true)).toBe(true)
  expect(M.overnightDue(asked, at("2026-10-02", "08:00"), calendars, false)).toBe(false)
})

test("each side's wash adds the lightness the up colour's does, worked out from the theme", () => {
  const hex = h => ({ r: parseInt(h.slice(1, 3), 16) / 255, g: parseInt(h.slice(3, 5), 16) / 255, b: parseInt(h.slice(5, 7), 16) / 255 })
  // The renders' colours, Kanagawa's (a pale accent, a dark red), and
  // Catppuccin Latte's, a light theme whose wash takes light away.
  const themes = {
    render: { ground: "#101315", up: "#7aa2f7", down: "#a55555", downWash: 0.257 },
    kanagawa: { ground: "#1f1f28", up: "#dcd7ba", down: "#c34043", downWash: 0.377 },
    latte: { ground: "#eff1f5", up: "#1e66f5", down: "#d20f39", downWash: 0.134 }
  }
  for (const [name, t] of Object.entries(themes)) {
    const [ground, up, down] = [hex(t.ground), hex(t.up), hex(t.down)]
    // Up keeps the alpha it is given.
    expect(M.washAlpha(up, up, ground, 0.16, 1)).toBeCloseTo(0.16, 6)
    // Down takes the alpha that adds the same lightness: more for a darker
    // red on a dark ground, less on a light one.
    const a = M.washAlpha(down, up, ground, 0.16, 1)
    expect([name, Math.round(a * 1000) / 1000]).toEqual([name, t.downWash])
    expect(M.addedLightness(down, ground, a)).toBeCloseTo(M.addedLightness(up, ground, 0.16), 6)
  }
  // Never more than half the ink it sits under, so the line and the caps
  // stay the most important thing: Kanagawa's red stems would match the
  // pale accent's at 77% of a cap's full ink, and the extended hours' at 37%
  // of their 45%. Both stop at half.
  const [ground, up, down] = [hex("#1f1f28"), hex("#dcd7ba"), hex("#c34043")]
  expect(M.washAlpha(down, up, ground, 0.35, 1)).toBe(0.5)
  expect(M.washAlpha(down, up, ground, 0.35 * 0.45, 0.45)).toBe(0.225)
  // Below the cap the rule holds: Gruvbox's red stems match at 40%.
  const [gGround, gUp, gDown] = [hex("#282828"), hex("#7daea3"), hex("#ea6962")]
  const stem = M.washAlpha(gDown, gUp, gGround, 0.35, 1)
  expect(Math.round(stem * 1000) / 1000).toBe(0.4)
  expect(M.addedLightness(gDown, gGround, stem)).toBeCloseTo(M.addedLightness(gUp, gGround, 0.35), 6)
  // A colour too close to the ground to add as much is at the cap.
  expect(M.washAlpha(hex("#16181a"), hex("#7aa2f7"), hex("#101315"), 0.16, 1)).toBe(0.5)
})

test("up never reads as down in any installed theme", () => {
  // Up is the theme's green, or the foreground where the green is too close
  // to the red (Hackerman, Lumon, Vantablack, White); either way the pair
  // stays apart. Read from the themes Omarchy installs, as the shell reads
  // them: `red` (else `color1`) is its urgent.
  const dir = "/usr/share/omarchy/themes"
  const themes = readdirSync(dir).filter(name => existsSync(join(dir, name, "colors.toml")))
  expect(themes.length).toBeGreaterThanOrEqual(22)
  const fellBack = []
  for (const name of themes) {
    const toml = readFileSync(join(dir, name, "colors.toml"), "utf8")
    const key = keys => M.hexColor(M.themeColor(toml, keys))
    const [foreground, down] = [key(["foreground", "color7"]), key(["red", "color1"])]
    const green = M.themeColor(toml, ["green", "color2"])
    const up = M.upColor(green, down, foreground)
    if (up === foreground) fellBack.push(name)
    expect([name, M.oklabDistance(typeof up === "string" ? M.hexColor(up) : up, down) >= M.UP_DOWN_APART]).toEqual([name, true])
  }
  expect(fellBack.sort()).toEqual(["hackerman", "lumon", "vantablack", "white"])
})
