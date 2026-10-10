import { test, expect } from "bun:test"
import { readFileSync } from "node:fs"
import { join } from "node:path"
import { load } from "./load.js"

// The rules read against Yahoo's and Robinhood's saved answers, which are
// private (test/fixtures; test/fixtures-dir.sh finds them). test/all.sh
// skips this file where there are none. The pure rules are model.test.js.
const found = Bun.spawnSync([join(import.meta.dir, "fixtures-dir.sh")])
if (!found.success) throw new Error(found.stderr.toString().trim())
const fixtures = found.stdout.toString().trim()
// The reader is in New York: an exchange's time is named
// with its zone only where that clock differs from the reader's.
process.env.TZ = "America/New_York"
// Every rule file's names, under one name: each is defined once.
const M = Object.assign({}, ...["Format", "Fetch", "Quote", "Market", "Overnight", "History", "Fundamentals", "Figures",
  "Chart", "Tones", "Settings", "KeySheet", "Search", "Cells"].map(name => load(name + ".js")))

const fixture = name => JSON.parse(readFileSync(join(fixtures, name), "utf8"))
const calendars = JSON.parse(readFileSync(join(import.meta.dir, "..", "calendars.json"), "utf8"))
const US = calendars.calendars.US
const JPX = calendars.calendars.JPX
const quote = M.parseChart(fixture("aapl.json"))
const shop = M.parseChart(fixture("shop-to.json"))
const btc = M.parseChart(fixture("btc-usd-day.json"))
const search = fixture("search.json")
const reg = quote.session.regular
const DAY = 24 * 3600

// A quote with only the points inside the regular session, so it reads as
// "still trading" for tests that need a live market.
function duringSession(q) {
  return { ...q, points: M.regularPoints(q) }
}
test("parseChart keeps the fields the panel needs", () => {
  const fields = q => ({ symbol: q.symbol, currency: q.currency, exchange: q.exchange, timezoneName: q.timezoneName, instrumentType: q.instrumentType, crypto: q.crypto })
  expect(fields(quote)).toEqual({ symbol: "AAPL", currency: "USD", exchange: "NASDAQ", timezoneName: "America/New_York", instrumentType: "EQUITY", crypto: false })
  expect(fields(shop)).toEqual({ symbol: "SHOP.TO", currency: "CAD", exchange: "TSX", timezoneName: "America/Toronto", instrumentType: "EQUITY", crypto: false })
  expect(fields(btc)).toEqual({ symbol: "BTC-USD", currency: "USD", exchange: "CRYPTO", timezoneName: "UTC", instrumentType: "CRYPTOCURRENCY", crypto: true })
  expect(quote.prevClose).toBe(316.85)
  expect(quote.dayHigh).toBeGreaterThan(quote.dayLow)
  expect(reg.end - reg.start).toBe(6.5 * 3600)
  // Names as the company writes them, as search takes them: Yahoo's short
  // name is in capitals for SHOP.TO and cut at 31 characters for SPY.
  expect(shop.name).toBe("Shopify Inc.")
  expect(M.parseChart(fixture("spy-2026-09-11-day-prepost.json")).name).toBe("State Street SPDR S&P 500 ETF Trust")
  expect(M.parseChart(fixture("nbis-2026-09-11-day-prepost.json")).name).toBe("Nebius Group N.V.")
})

test("the listing line names a pair's currency once", () => {
  // Yahoo names the pair with its currency: "BITCOIN USD · CRYPTO", not "· USD" again.
  expect(btc.name).toBe("Bitcoin USD")
  expect(M.listingMeta(btc)).toBe("CRYPTO")
  expect(M.listingMeta(quote)).toBe("NASDAQ · USD")
  expect(M.listingMeta(shop)).toBe("TSX · CAD")
})

test("parseChart drops a null close, even on the newest bar the stray filter never judges", () => {
  const json = fixture("aapl.json")
  const result = json.chart.result[0]
  const gone = quote.points[quote.points.length - 1].t
  result.indicators.quote[0].close[result.timestamp.indexOf(gone)] = null
  expect(M.parseChart(json).points.map(p => p.t)).toEqual(quote.points.map(p => p.t).filter(t => t !== gone))
})

test("across every saved intraday response the filter drops only those nine bars", () => {
  const days = [
    ["aapl.json", []],
    ["aapl-2026-09-04-day-prepost.json", []],
    ["aapl-2026-09-04-day-regular.json", []],
    ["shop-to.json", []],
    // A continuous market gives the filter nothing to judge.
    ["btc-usd-day.json", []],
    ["nbis-2026-09-11-day-prepost.json", [1789158000]],
    ["spy-2026-09-11-day-prepost.json", [1789156800]],
    ["msft-2026-09-11-day-prepost.json", [1789157100, 1789162200, 1789162500]],
    // BRK-B's after hours on Friday 2 October: 520.93, 489.66, 500.31, and
    // 489.66 between 502.80 and 502.65, 30, 5, 10, and 10 minutes apart.
    ["overnight/sweep-2026-10-03-1200/brk-b.json", [1790973900, 1790974200, 1790974800, 1790975400]]
  ]
  for (const [name, expected] of days) {
    const json = fixture(name)
    const result = json.chart.result[0]
    const parsed = M.parseChart(json)
    const kept = parsed.points.map(point => point.t)
    const dropped = result.timestamp.filter((t, i) =>
      result.indicators.quote[0].close[i] !== null && kept.indexOf(t) < 0)
    expect([name, dropped]).toEqual([name, expected])
    expect([name, parsed.droppedTimes]).toEqual([name, expected])
  }
  // MSFT at 17:30 and 17:35 ET printed 515.03 then 510.62 between 495.40 and
  // 495.01. The second opens where the first closed, so no single bar breaks
  // continuity; 17:40 opening at 495.20 gives the pair away. At 16:05 the
  // same shape sits one bucket after the bell, only 0.62% wide. The
  // neighbours stay.
  const msft = M.parseChart(fixture("msft-2026-09-11-day-prepost.json"))
  expect(msft.points.filter(p => [1789157400, 1789161900, 1789162800].indexOf(p.t) >= 0).map(p => p.p))
    .toEqual([495.3218, 495.4, 495.0108])
})

test("the headline is Yahoo's regular-market quote with its own time; the chart only stands in", () => {
  expect(M.headlineQuote(quote)).toEqual({ price: quote.price, t: quote.marketTime, source: "quote" })
  expect(M.regularClose(quote)).toBe(quote.price)
  const regular = M.regularPoints(quote)
  const noMeta = { ...quote, price: null }
  expect(M.headlineQuote(noMeta)).toEqual({ price: regular[regular.length - 1].p, t: regular[regular.length - 1].t, source: "chart" })
  const noTime = { ...quote, marketTime: null }
  expect(M.headlineQuote(noTime).source).toBe("chart")
  const nothing = { ...quote, price: null, points: [] }
  expect(M.headlineQuote(nothing)).toBeNull()
  expect(M.regularClose(nothing)).toBeNull()
})

const sep4 = M.parseChart(fixture("aapl-2026-09-04-day-prepost.json"))
const sep4Regular = fixture("aapl-2026-09-04-day-regular.json").chart.result[0]
const sep4Reg = sep4.session.regular

test("a bucket stamped at the bell is post-market, and the quote a second later is the close", () => {
  const regular = M.regularPoints(sep4)
  expect(regular.length).toBe(78)
  expect(regular[regular.length - 1].t).toBe(sep4Reg.end - 300)
  // The regular-only response for the same day carries the same last bar
  // and no 16:00 bucket. Its metadata is from a later fetch and is not
  // compared here.
  expect(sep4Regular.timestamp[sep4Regular.timestamp.length - 1]).toBe(regular[regular.length - 1].t)
  expect(sep4Regular.timestamp.length).toBe(78)
  const atBell = sep4.points.find(p => p.t === sep4Reg.end)
  expect(atBell).toBeDefined()
  expect(M.chartGeometry(sep4).points.find(p => p.x === M.chartGeometry(sep4).ticks[0]).ext).toBe(true)
  // The closing quote one second after the bell is still the regular quote,
  // not the bell bucket's 319.92.
  expect(M.headlineQuote(sep4)).toEqual({ price: 319.97, t: sep4Reg.end + 1, source: "quote" })
})

test("the day is drawn whole, and its range holds the previous close", () => {
  const spy = M.parseChart(fixture("spy-2026-09-11-day-prepost.json"))
  const spyReg = spy.session.regular
  const geo = M.chartGeometry(spy)
  expect(geo.start).toBe(spy.points[0].t)
  expect(geo.start).toBeLessThan(spyReg.start)
  expect(geo.points[0].ext).toBe(true)
  expect(geo.points[0].x).toBe(0)
  expect(geo.points.filter(p => !p.ext).length).toBe(78)
  expect(geo.points.filter(p => p.ext).length).toBe(109)
  // The last regular print is the 15:55 bucket, one five-minute step before
  // the bell tick.
  expect(geo.ticks[0] - M.lastRegularPoint(geo).x).toBeCloseTo(300 / (geo.end - geo.start), 10)
  // SPY gapped up on 11 September: the session traded 763.97 to 766.31, more
  // than six points above the 757.83 previous close, and only the pre-market
  // climbs between them. Drawing the session alone left the line in the top
  // fifth over an empty chart.
  expect(geo.lo).toBeCloseTo(757.1516, 4)
  expect(geo.hi).toBeCloseTo(766.9884, 4)
  const lowest = Math.max(...geo.points.map(p => p.y))
  const highest = Math.min(...geo.points.map(p => p.y))
  expect(lowest - highest).toBeGreaterThan(0.5)
  expect(geo.baselineY).toBeGreaterThan(lowest)
  // While the session trades, the axis ends at the bell, and time and
  // position map onto each other; before the axis there is no cursor.
  const live = duringSession(quote)
  expect(M.chartGeometry(live)).toMatchObject({ ticks: [], end: reg.end })
  expect(M.timeAtFraction(live, 0)).toBe(reg.start)
  expect(M.timeAtFraction(live, 1)).toBe(reg.end)
  expect(M.fractionAtTime(live, reg.start + 3.25 * 3600)).toBeCloseTo(0.5, 5)
  expect(M.fractionAtTime(live, reg.start - 60)).toBe(-1)
  expect(M.lastRegularPoint(null)).toBeNull()
})

test("sessionPhase follows the bells the exchange announced", () => {
  // The periods are trusted: an empty series does not make a holiday.
  const q = { ...quote, points: [] }
  expect(M.sessionPhase(q, q.session.pre.start + 60)).toBe("pre")
  expect(M.sessionPhase(q, reg.start + 60)).toBe("opening")
  expect(M.sessionPhase(q, reg.start + 2 * 3600)).toBe("open")
  expect(M.sessionPhase(q, reg.start + 2.75 * 3600)).toBe("lunch")
  expect(M.sessionPhase(q, reg.end - 30 * 60)).toBe("power")
  expect(M.sessionPhase(q, reg.end - 60)).toBe("closing")
  expect(M.sessionPhase(q, q.session.post.start + 60)).toBe("post")
  expect(M.sessionPhase(q, q.session.post.end + 3600)).toBe("closed")
  expect(M.sessionPhase(q, reg.start + 5 * DAY)).toBe("weekend")
  // The lunch lull is a New York thing.
  expect(M.sessionPhase({ ...q, timezoneName: "Europe/London" }, reg.start + 2.75 * 3600)).toBe("open")
})

test("crypto is always open, never sees a weekend, and still reports quote age", () => {
  const t = btc.session.regular.start + 3600
  expect(M.sessionPhase(btc, t)).toBe("always")
  expect(M.sessionPhase(btc, t + 5 * DAY)).toBe("always")
  expect(M.marketStatus(btc, t, 0, calendars)).toBe("Open around the clock")
  const ok = { status: "ok", receivedAt: t - 5 }
  expect(M.freshness(ok, { ...btc, marketTime: t - 10 }, t, 0)).toMatchObject({ state: "fresh", live: true })
  expect(M.freshness(ok, { ...btc, marketTime: t - 500 }, t, 0)).toMatchObject({ state: "aged", live: false })
})

test("after the close the header names the day and the next open from the calendar", () => {
  // Saturday 5 September 2026 with Friday's response: the old code counted
  // down to Monday 7 September, which Nasdaq had closed for Labor Day.
  const saturday = 1788582233
  const short = JSON.parse(JSON.stringify(calendars))
  short.calendars.US.validThrough = "2026-09-06"
  const rows = [
    // Friday evening: the regular close is named so 16:00 is not read as the
    // end of trading, then the post-market ends.
    [sep4.session.post.start + 1800, calendars, "After hours · close 16:00"],
    [sep4.session.post.end + 60, calendars, "Closed · opens Tue 09:30"],
    [saturday, calendars, "Weekend · opens Tue 09:30"],
    [1788793200, calendars, "Labor Day · opens Tue 09:30"],
    // Standard time, and a closure that keeps its opens verb.
    [M.epochAt(US, "2026-11-26", "12:00"), calendars, "Thanksgiving Day · opens Fri 09:30"],
    [M.epochAt(US, "2027-06-18", "12:00"), calendars, "Juneteenth · opens Mon 09:30"],
    // Past validThrough the schedule is unknown, and the header says so.
    [saturday, short, "Weekend · schedule unavailable"]
  ]
  for (const [now, cals, expected] of rows) expect([now, M.marketStatus(sep4, now, 0, cals)]).toEqual([now, expected])
})

test("an exchange's time names its zone only where the reader's clock differs", () => {
  const tokyo = M.parseChart(fixture("7203-t-day.json"))
  const evening = tokyo.session.regular.end + 3 * 3600
  const aapl = M.parseChart(fixture("aapl.json"))
  // Saturday 31 October: New York's clocks go back that night.
  const saturday = M.epochAt(US, "2026-10-31", "12:00")
  const readAs = (zone, fn) => {
    process.env.TZ = zone
    try { return fn() } finally { process.env.TZ = "America/New_York" }
  }
  const tokyoNext = () => M.marketStatus(tokyo, evening, 0, calendars)
  expect(readAs("America/New_York", tokyoNext)).toMatch(/^Closed · opens \w{3} 09:00 JST$/)
  expect(readAs("Asia/Tokyo", tokyoNext)).toMatch(/^Closed · opens \w{3} 09:00$/)
  // Nasdaq's Monday open, after the clocks change: nothing to name in New
  // York or Toronto; London, already on GMT, is told it is EST.
  const usNext = () => M.marketStatus(aapl, saturday, 0, calendars)
  expect(readAs("America/New_York", usNext)).toBe("Weekend · opens Mon 09:30")
  expect(readAs("America/Toronto", usNext)).toBe("Weekend · opens Mon 09:30")
  expect(readAs("Europe/London", usNext)).toBe("Weekend · opens Mon 09:30 EST")
  // A listing with no calendar names its zone as Yahoo does; "AS OF" too.
  const btc = M.parseChart(fixture("btc-usd-day.json"))
  expect(M.freshnessText({ state: "aged", asOf: btc.marketTime }, btc)).toBe("AS OF 18:32 UTC")
})

test("an exchange's time across a change of clocks reads by its own date's offset", () => {
  // An answer fetched after New York's clocks went back (EST) holds bars and
  // a close from before it (EDT): found in review, 09:30 read 08:30 EST.
  const before = at("2026-10-30", "09:30")
  const history = { range: "1M", interval: "30m", gmtoffset: -18000, zoneName: "EST",
    bars: [{ t: before, o: 100, h: 100, l: 100, c: 100 }] }
  expect(M.historyScrubText(history, history.bars[0], 2, US)).toBe("30 OCT 09:30 · 100.00")
  const aapl = { ...M.parseChart(fixture("aapl.json")), gmtoffset: -18000, zoneName: "EST" }
  const close = at("2026-10-30", "16:00")
  expect(M.freshnessText({ state: "aged", asOf: close }, aapl, calendars)).toBe("AS OF 16:00")
  process.env.TZ = "Europe/London"
  try {
    expect(M.freshnessText({ state: "aged", asOf: close }, aapl, calendars)).toBe("AS OF 16:00 EDT")
  } finally { process.env.TZ = "America/New_York" }
})

test("a weeknight after post-market leads with closed and the next open", () => {
  const q = {
    ...duringSession(quote),
    session: {
      pre: { start: M.epochAt(US, "2026-09-17", "04:00"), end: M.epochAt(US, "2026-09-17", "09:30") },
      regular: { start: M.epochAt(US, "2026-09-17", "09:30"), end: M.epochAt(US, "2026-09-17", "16:00") },
      post: { start: M.epochAt(US, "2026-09-17", "16:00"), end: M.epochAt(US, "2026-09-17", "20:00") }
    },
    points: [
      { t: M.epochAt(US, "2026-09-17", "04:00"), p: quote.prevClose },
      { t: M.epochAt(US, "2026-09-17", "15:55"), p: quote.price },
      { t: M.epochAt(US, "2026-09-17", "19:55"), p: quote.price + 1 }
    ]
  }
  const nextPre = M.epochAt(US, "2026-09-18", "04:00")
  for (const clock of ["20:01", "23:59"]) {
    const now = M.epochAt(US, "2026-09-17", clock)
    expect(M.marketStatus(q, now, 0, calendars)).toBe("Closed · opens Fri 09:30")
  }
  for (const clock of ["00:01", "03:59"]) {
    const now = M.epochAt(US, "2026-09-18", clock)
    expect(M.marketStatus(q, now, 0, calendars)).toBe("Closed · opens Fri 09:30")
  }
  expect(M.marketStatus(q, nextPre, 0, calendars)).toBe("Closed · opens Fri 09:30")
  const geometry = M.chartGeometry(q)
  expect(geometry.end).toBe(q.points[q.points.length - 1].t)
})

test("a listing's prices take the decimals they need, decided once from its headline price", () => {
  // Yahoo's priceHint at least, four significant digits under 1, none from
  // 10,000 up; the hints are the real ones (SHIB-USD 5, DOGE-USD 5, EURUSD=X
  // 4, BRK-A 2).
  const shown = (price, hint) => M.money(price, M.priceDigits(price, hint))
  expect(shown(5.41e-6, 5)).toBe("0.000005410")
  // However small: found in review, a ten-decimal cap read 1.234e-11 as 0.
  expect(shown(1.234e-11, 8)).toBe("0.00000000001234")
  expect(shown(0.08711, 5)).toBe("0.08711")
  expect(shown(0.5, 2)).toBe("0.5000")
  expect(shown(1.122, 4)).toBe("1.1220")
  expect(shown(235.62, 2)).toBe("235.62")
  expect(shown(759748.25, 2)).toBe("759,748")
  expect(shown(2900.5, undefined)).toBe("2,900.50")
  // A coin's day and every scrub of it are in the headline's decimals.
  const shib = M.parseChart(fixture("overnight/sweep-2026-10-08-1054/shib-usd.json"))
  expect(shib.priceDigits).toBe(9)
  expect(M.rowModel(shib, 0, "pct").priceText).toBe("0.000005410")
  expect(M.rowModel(shib, shib.points[3].t, "pct").priceText).toMatch(/^0\.00000\d{4}$/)
  // A move in money keeps cents where the price has none, and a coin's
  // decimals where it has more; its colour agrees with what is drawn.
  expect(M.signedMoney(-2105.766, 0)).toBe("\u22122,105.77")
  expect(M.changeText({ abs: -2e-8, pct: -0.37 }, "abs", 9)).toBe("\u22120.000000020")
  expect(M.changeTone({ abs: -2e-8, pct: -0.37 }, "abs", 9)).toBe("down")
  expect(M.changeTone({ abs: -2e-8, pct: -0.37 }, "abs")).toBe("flat")
})

test("rowModel shows the regular close at rest and the print under the finger", () => {
  const view = (t, mode, q = quote) => {
    const v = M.rowModel(q, t, mode)
    return { price: v.price, priceText: v.priceText, changeText: v.changeText, tone: v.tone, dayUp: v.dayUp }
  }
  // aapl.json ends on an after-hours print (324.72); at rest the row shows
  // the close, and the change mode moves only the change.
  const close = { price: 325.13, priceText: "325.13", tone: "up", dayUp: true }
  expect(view(0, "pct")).toEqual({ ...close, changeText: "+2.61%" })
  expect(view(0, "abs")).toEqual({ ...close, changeText: "+8.28" })
  expect(view(0, "open")).toEqual({ ...close, changeText: "+3.10%" })
  // The rows carry the mode's word inline; the hero's SINCE OPEN caption is
  // pointer.qml's. Percent and amount carry none.
  expect(M.rowModel(quote, 0, "open")).toMatchObject({ changeLine: "+3.10% open", periodLabel: "SINCE OPEN" })
  expect(M.rowModel(quote, 0, "abs")).toMatchObject({ changeLine: "+8.28", periodLabel: "" })
  // Scrubbing reads the print at that moment and holds it until the next;
  // the direction is the moment's too, so the bull and bear follow a scrub.
  const mid = quote.points[40]
  const scrubbed = { price: 316.23, priceText: "316.23", changeText: "\u22120.20%", tone: "down", dayUp: false }
  expect(view(mid.t, "pct")).toEqual(scrubbed)
  expect(view(mid.t + 30, "pct")).toEqual(scrubbed)
  // Before the first print the row reads the previous close.
  expect(view(quote.points[0].t - 60, "pct")).toEqual({ price: 316.85, priceText: "316.85", changeText: "0.00%", tone: "flat", dayUp: true })
  // Open mode can turn the change down while the day is still up.
  const flip = {
    ...quote, prevClose: 100, price: 105, marketTime: reg.end - 30,
    points: [{ t: reg.start + 60, p: 110 }, { t: reg.end - 60, p: 105 }]
  }
  expect(view(0, "open", flip)).toMatchObject({ price: 105, tone: "down", dayUp: true })
  // With no data nothing is invented: no price, no change, no direction.
  const nothing = { ...quote, price: null, marketTime: null, points: [] }
  expect(view(0, "pct", nothing)).toMatchObject({ priceText: "—", changeText: "—", dayUp: null })
  expect(M.rowModel(nothing, 0, "open").changeLine).toBe("—")
  // The scrub has no last print to stop at, rather than failing.
  expect(M.lastPrintTime(nothing)).toBeNull()
  expect(M.rowModel(nothing, 0, "pct")).toMatchObject({ pct: null, asOf: null })
  const emptyHistory = { symbol: "AAPL", range: "1Y", interval: "1d", baseline: null, bars: [] }
  expect(M.historyRowModel(emptyHistory, nothing, 0).dayUp).toBeNull()
})

test("marketStatus says whether the market is open, and where the finger is while scrubbing", () => {
  const q = duringSession(quote)
  expect(M.marketStatus(q, reg.start + 2 * 3600, 0, calendars)).toBe("Market closes in 4h 30m")
  expect(M.marketStatus(q, reg.start - 600, 0, calendars)).toBe("Pre-market · opens in 10m")
  expect(M.marketStatus(q, q.session.pre.start - 600, 0, calendars)).toBe("Market opens in 5h 40m")
  expect(M.marketStatus(quote, quote.session.post.start + 60, 0, calendars)).toBe("After hours · close 16:00")
  expect(M.marketStatus(q, reg.start + 2 * 3600, reg.start + 3600)).toBe("At 10:30 · Market open")
  expect(M.marketStatus(q, reg.start + 2 * 3600, reg.start + 2.75 * 3600)).toBe("At 12:15 · Lunch lull")
  // At rest the day's named moments lead too, as they do while scrubbing.
  expect(M.marketStatus(q, reg.start + 600, 0, calendars)).toBe("Opening bell · closes in 6h 20m")
  expect(M.marketStatus(q, reg.start + 2.75 * 3600, 0, calendars)).toBe("Lunch lull · closes in 3h 45m")
  expect(M.marketStatus(q, reg.end - 40 * 60, 0, calendars)).toBe("Power hour · closes in 40m")
  expect(M.marketStatus(q, reg.end - 3 * 60, 0, calendars)).toBe("Closing bell · closes in 3m")
})

test("extendedStack labels the print after the bell against the close", () => {
  expect(M.extendedStack(quote)).toEqual({ price: "324.72", changeText: "\u22120.13%", tone: "down", label: "AFTER HOURS", time: "", stale: false })
  expect(M.extendedStack(duringSession(quote))).toBeNull()
})

test("extendedStack is hidden when the print shows as the close", () => {
  const close = M.regularClose(quote)
  const last = quote.points[quote.points.length - 1]
  const echo = { ...quote, points: [...quote.points.slice(0, -1), { t: last.t, p: close + 0.001 }] }
  expect(M.extendedStack(echo)).toBeNull()
})

test("a change that rounds to nothing has no sign and no direction", () => {
  expect(M.pct(0)).toBe("0.00%")
  expect(M.pct(0.004)).toBe("0.00%")
  expect(M.pct(-0.004)).toBe("0.00%")
  expect(M.pct(0.005)).toBe("+0.01%")
  expect(M.signedMoney(0)).toBe("0.00")
  expect(M.signedMoney(-0.001)).toBe("0.00")
  expect(M.money(-0.001)).toBe("0.00")
  expect(M.lookSigns(M.pct(0), true)).toBe("0.00%")
  expect(M.changeTone({ abs: 0, pct: 0 }, "pct")).toBe("flat")
  // Each mode judges its own figure as drawn: a big stock's +1.20 can be
  // 0.00%, flat in percent and up in amount.
  expect(M.changeTone({ abs: 0.004, pct: 0.00004 }, "abs")).toBe("flat")
  expect(M.changeTone({ abs: 1.2, pct: 0.004 }, "pct")).toBe("flat")
  expect(M.changeTone({ abs: 1.2, pct: 0.004 }, "abs")).toBe("up")
  expect(M.changeTone({ abs: -3, pct: -2 }, "open")).toBe("down")
  expect(M.changeTone({ abs: null, pct: null }, "pct")).toBe("flat")
  const still = { ...quote, prevClose: M.regularClose(quote) }
  const view = M.rowModel(still, 0, "pct")
  expect(view.changeText).toBe("0.00%")
  expect(view.tone).toBe("flat")
  // The chart's direction still has one: the day did not fall.
  expect(view.dayUp).toBe(true)
})

test("the day line names its session's date and gives its open, high, low, and volume", () => {
  // SHOP.TO's saved day is Wednesday 2 September in Toronto; NBIS's is
  // Friday 11 September, which is what a Saturday shows. The open is the
  // first regular bar's.
  expect(M.dayStatsText(shop)).toBe("WED 2 SEP · O 194.74 · H 196.46 · L 192.88 · VOL 353K")
  expect(M.dayStatsText(M.parseChart(fixture("nbis-2026-09-11-day-prepost.json")))).toBe("FRI 11 SEP · O 234.80 · H 234.80 · L 223.64 · VOL 11.2M")
  expect(M.dayStatsText(null)).toBe("")
  // Before the session's first bar there is no open to give, and the line
  // leaves it out.
  const early = fixture("aapl.json")
  const result = early.chart.result[0]
  const pre = result.timestamp.filter(t => t < result.meta.currentTradingPeriod.regular.start).length
  result.timestamp = result.timestamp.slice(0, pre)
  for (const key of Object.keys(result.indicators.quote[0])) result.indicators.quote[0][key] = result.indicators.quote[0][key].slice(0, pre)
  expect(M.dayStatsText(M.parseChart(early))).toBe("TUE 1 SEP · H 327.30 · L 314.74 · VOL 52.4M")
  // Yahoo's 52-week marks come with every quote; a day that reaches one
  // says so in place of the plain H or L, and an ordinary day does not.
  expect(M.dayStatsText(quote)).toBe("TUE 1 SEP · O 316.98 · H 327.30 · L 314.74 · VOL 52.4M")
  const reaching = (field, from) => {
    const json = fixture("aapl.json")
    const meta = json.chart.result[0].meta
    meta[field] = meta[from]
    return M.parseChart(json)
  }
  expect(M.dayStatsText(reaching("fiftyTwoWeekHigh", "regularMarketDayHigh")))
    .toBe("TUE 1 SEP · O 316.98 · 52W HIGH 327.30 · L 314.74 · VOL 52.4M")
  expect(M.dayStatsText(reaching("fiftyTwoWeekLow", "regularMarketDayLow")))
    .toBe("TUE 1 SEP · O 316.98 · H 327.30 · 52W LOW 314.74 · VOL 52.4M")
})

// Saved answers from 1 October 2026 (2 October in Tokyo and London): the
// snapshots, then the daily bars around their dates.
const fundamentals = name => M.parseFundamentals(fixture(`fundamentals/${name}.json`))
const figures = name => M.withSnapshotCloses(fundamentals(name), fixture(`fundamentals/${name}-closes.json`))

test("Yahoo's latest cap and P/E each come with their own date's close", () => {
  const cap = (value, date, currency, close) => ({ value, date, currency, close })
  // NBIS's last P/E, 74.6 on 11 August, is still in the answer, but its
  // latest trailing diluted EPS is a loss, so it has none.
  expect(fixture("fundamentals/nbis.json").timeseries.result.some(r => r.trailingPeRatio)).toBe(true)
  expect(figures("nbis")).toEqual({ cap: cap(61605110950, "2026-09-23", "USD", 226.61000061035156), pe: null })
  // AAPL's P/E is older than its cap, and each takes its own date's close.
  expect(figures("aapl")).toEqual({ cap: cap(4918530543600, "2026-09-23", "USD", 337.0199890136719),
    pe: { value: 38.646789, date: "2026-09-17", close: 337 } })
  // A Toronto and a Tokyo listing: caps in the listing's currency.
  expect(figures("shop-to")).toEqual({ cap: cap(257625581988, "2026-09-23", "CAD", 200.4600067138672),
    pe: { value: 96.513335, date: "2026-09-23", close: 200.4600067138672 } })
  expect(figures("7203-t")).toEqual({ cap: cap(35821546821500, "2026-09-18", "JPY", 3025),
    pe: { value: 8.608913, date: "2026-09-18", close: 3025 } })
  // London's cap is in pounds; its prices are in pence.
  expect(figures("shel-l")).toEqual({ cap: cap(204282006647, "2026-09-23", "GBP", 3580),
    pe: { value: 10.567418, date: "2026-09-23", close: 3580 } })
  // An ETF and a cryptocurrency: every series empty, so no closes to ask for.
  for (const name of ["spy", "btc-usd"]) {
    expect(fundamentals(name)).toEqual({ cap: null, pe: null })
    expect(M.snapshotClosesUrl(name.toUpperCase(), fundamentals(name))).toBeNull()
  }
  // An answer that is not a timeseries, closes that are not a chart, or a
  // chart without a snapshot's close is no answer: the feed keeps the
  // figures it had.
  expect(M.parseFundamentals({ finance: { error: "Too Many Requests" } })).toBeNull()
  expect(M.withSnapshotCloses(fundamentals("aapl"), null)).toBeNull()
  expect(M.withSnapshotCloses(fundamentals("aapl"), { chart: { result: [{ meta: { gmtoffset: -14400 } }] } })).toBeNull()
  // Only an equity is asked.
  expect([quote, shop, btc].map(M.hasFundamentals)).toEqual([true, true, false])
  expect(M.hasFundamentals(M.parseChart(fixture("spy-2026-09-11-day-prepost.json")))).toBe(false)
  expect(M.hasFundamentals({ ...quote, symbol: "^GSPC", instrumentType: "INDEX" })).toBe(false)
})

test("the key stats line moves Yahoo's cap and P/E with the price, and leaves out what is not known", () => {
  // A quote at `price`, stamped `days` after `date`'s 20:00 UTC.
  const at = (q, price, date, days = 0) => ({ ...q, price, marketTime: M.dateEpoch(date) + days * DAY + 20 * 3600 })
  const aapl = figures("aapl")
  // At the snapshot's own close the figures are Yahoo's; 10% up moves both 10%.
  expect(M.keyStatsText(at(quote, 337.02, "2026-09-23"), aapl)).toBe("MKT CAP 4.92T · P/E 38.6 · 52W 225.95–344.57")
  expect(M.keyStatsText(at(quote, 370.72, "2026-10-01"), aapl)).toBe("MKT CAP 5.41T · P/E 42.5 · 52W 225.95–344.57")
  const nbis = M.parseChart(fixture("nbis-2026-09-11-day-prepost.json"))
  expect(M.keyStatsText(at(nbis, 226.61, "2026-09-23"), figures("nbis"))).toBe("MKT CAP 61.6B · 52W 73.52–299.86")
  // A cap in the price's own currency names none.
  expect(M.keyStatsText(at(shop, 200.46, "2026-09-23"), figures("shop-to"))).toBe("MKT CAP 257.6B · P/E 96.5 · 52W 129.01–253.10")
  // Tokyo's day, a week and more after its snapshots.
  expect(M.keyStatsText(M.parseChart(fixture("7203-t-day.json")), figures("7203-t"))).toBe("MKT CAP 33.82T · P/E 8.1 · 52W 2,686.00–4,000.00")
  // London before its session: the cap names its pounds against the
  // price's pence, and the zeros Yahoo sends then for the day's high and
  // low and the 52-week low are prices not known yet, left out of both lines.
  const london = fixture("shel-l-day.json")
  const meta = london.chart.result[0].meta
  expect([meta.regularMarketDayHigh, meta.regularMarketDayLow, meta.fiftyTwoWeekLow]).toEqual([0, 0, 0])
  const shell = M.parseChart(london)
  expect(shell.currency).toBe("GBp")
  expect(M.dayStatsText(shell)).toBe("FRI 2 OCT · VOL 4K")
  expect(M.keyStatsText(shell, figures("shel-l"))).toBe("MKT CAP GBP 204.8B · P/E 10.6")
  // A cap 120 days old still moves with the price; at 121 it is left out.
  expect(M.keyStatsText(at(quote, 337.02, "2026-09-23", 120), aapl)).toBe("MKT CAP 4.92T · P/E 38.6 · 52W 225.95–344.57")
  expect(M.keyStatsText(at(quote, 337.02, "2026-09-23", 121), aapl)).toBe("P/E 38.6 · 52W 225.95–344.57")
  // From 100 a P/E has no decimals.
  expect(M.keyStatsText(at(quote, 337, "2026-09-17"), { cap: null, pe: { value: 891.6, date: "2026-09-17", close: 337 } }))
    .toBe("P/E 892 · 52W 225.95–344.57")
  // An ETF and a cryptocurrency have their 52-week range only; never a word
  // about what is missing.
  expect(M.keyStatsText(M.parseChart(fixture("spy-2026-09-11-day-prepost.json")), null)).toBe("52W 629.28–779.37")
  expect(M.keyStatsText(btc, null)).toBe("52W 57,748–126,198")
  expect(M.keyStatsText(null, aapl)).toBe("")
})

test("each symbol is asked for on its own market's clock", () => {
  const q = duringSession(quote)
  const s = q.session
  const cadence = (quote, now, hero = false, interval = 60) => M.quoteCadence(quote, now, interval, hero, calendars)
  // Its regular session: the refresh interval, whatever the setting says.
  expect(cadence(q, reg.start + 3600)).toBe(60)
  expect(cadence(q, reg.start + 3600, false, 45)).toBe(45)
  // Pre-market and after hours: the close can't move, only the dim tail, so
  // every 5 minutes unless it is an open surface's hero; never faster than
  // the interval.
  expect(cadence(q, s.pre.start + 60)).toBe(300)
  expect(cadence(q, s.post.start + 60)).toBe(300)
  expect(cadence(q, s.post.start + 60, true)).toBe(60)
  expect(cadence(q, s.post.start + 60, false, 600)).toBe(600)
  // Closed: the night and the weekend.
  expect(cadence(q, s.post.end + 3600)).toBe(900)
  expect(cadence(q, reg.start + 5 * DAY, true)).toBe(900)
  // A cryptocurrency trades through every night and weekend, and keeps only
  // itself on the minute.
  expect(cadence(btc, btc.session.regular.start + 5 * DAY)).toBe(60)
  // No quote yet, or a first fetch that failed: the slow clock.
  expect(cadence(null, reg.start + 3600)).toBe(900)
})

test("a published closure or a break between segments is closed, whatever Yahoo's periods say", () => {
  const labor = 1788793200
  const fakeOpen = {
    ...sep4,
    session: { pre: null, post: null, regular: { start: labor - 3600, end: labor + 3600 } }
  }
  expect(M.quoteCadence(fakeOpen, labor, 60, false, null)).toBe(60)
  expect(M.quoteCadence(fakeOpen, labor, 60, false, calendars)).toBe(900)
  expect(M.inRegularSession(fakeOpen, labor, calendars)).toBe(false)
  // The header agrees: the published closure outranks a response that still
  // describes a session.
  expect(M.marketStatus(fakeOpen, labor, 0, calendars)).toBe("Labor Day · opens Tue 09:30")
  expect(M.marketStatus(fakeOpen, labor, 0, null)).toBe("Power hour · closes in 1h")
  // Tokyo's lunch break, from its calendar; the morning trades.
  const jpx = {
    symbol: "7203.T", exchange: "TSE", timezoneName: "Asia/Tokyo", gmtoffset: 32400, crypto: false,
    session: { pre: null, post: null, regular: { start: M.epochAt(JPX, "2026-09-08", "09:00"), end: M.epochAt(JPX, "2026-09-08", "15:30") } },
    points: []
  }
  expect(M.quoteCadence(jpx, 1788832800, 60, true, calendars)).toBe(60)
  expect(M.quoteCadence(jpx, 1788836400, 60, true, calendars)).toBe(900)
  expect(M.inRegularSession(jpx, 1788836400, calendars)).toBe(false)
})

test("freshness keeps quote age, an unanswered ask, and the refresh outcome apart", () => {
  const q = duringSession(quote)
  const trading = reg.start + 3600
  const ok = { status: "ok", receivedAt: trading - 10 }
  const live = { ...q, price: 100, marketTime: trading - 30 }
  expect(M.freshness(ok, live, trading, 0)).toMatchObject({ state: "fresh", live: true, asOf: trading - 30 })
  // The same old quote fetched again is still an old quote.
  const aged = { ...q, price: 100, marketTime: trading - 121 }
  expect(M.freshness(ok, aged, trading, 0)).toMatchObject({ state: "aged", live: false, asOf: trading - 121 })
  expect(M.freshnessText(M.freshness(ok, aged, trading, 0), q)).toBe("AS OF 10:27")
  // A refresh asked for and unanswered for 90 s is overdue, however old the
  // last answer; one nobody asked for never is.
  expect(M.freshness(ok, live, trading, trading - 89).state).toBe("fresh")
  expect(M.freshness(ok, live, trading, trading - 90)).toMatchObject({ state: "overdue", live: false })
  expect(M.freshnessText(M.freshness(ok, live, trading, trading - 90), q)).toBe("UPDATE OVERDUE · AS OF 10:29")
  expect(M.freshnessWarns(M.freshness(ok, live, trading, trading - 90))).toBe(true)
  expect(M.freshness({ status: "ok", receivedAt: trading - 86400 }, live, trading, 0).state).toBe("fresh")
  // A failed refresh is a failure whatever the quote's age, and keeps its as-of.
  const failed = { status: "failed", receivedAt: trading - 10 }
  expect(M.freshness(failed, live, trading, 0)).toMatchObject({ state: "failed", live: false, asOf: trading - 30 })
  expect(M.freshnessText(M.freshness(failed, live, trading, 0), q)).toBe("REFRESH FAILED · AS OF 10:29")
  expect(M.freshnessWarns(M.freshness(failed, live, trading, 0))).toBe(true)
  // No quote at all: unavailable, failed when the first fetch failed, and a
  // warning once its ask has gone 90 s unanswered.
  expect(M.freshness(null, null, trading, 0)).toMatchObject({ state: "unavailable", live: false })
  expect(M.freshnessText(M.freshness({ status: "failed", receivedAt: 0 }, null, trading, 0), q)).toBe("REFRESH FAILED")
  const nothing = M.freshness(null, null, trading, trading - 90)
  expect([nothing.state, M.freshnessText(nothing, q), M.freshnessWarns(nothing)]).toEqual(["overdue", "NO DATA", true])
})

test("a quote kept from an earlier session says when it is from, and warns only once asked for and unanswered", () => {
  const q = duringSession(quote)
  const close = { ...q, price: 100, marketTime: reg.end - 1 }
  const saved = { status: "saved", receivedAt: reg.end }
  // The same day: its time. Another day: the day too, so yesterday's close
  // is never read as now; in its exchange's time, with no live mark.
  const sameDay = M.freshness(saved, close, q.session.post.start + 60, 0)
  expect([sameDay.state, sameDay.live, M.freshnessText(sameDay, q)]).toEqual(["saved", false, "AS OF 15:59"])
  const nextDay = M.freshness(saved, close, reg.start + DAY + 60, 0)
  expect([nextDay.state, nextDay.live, M.freshnessWarns(nextDay), M.freshnessText(nextDay, q)])
    .toEqual(["saved", false, false, "AS OF TUE 15:59"])
  const late = M.freshness(saved, close, reg.start + DAY + 90, reg.start + DAY)
  expect([late.state, M.freshnessText(late, q)]).toEqual(["overdue", "UPDATE OVERDUE · AS OF TUE 15:59"])
})

test("outside trading an old close is normal, but a failed refresh still shows", () => {
  const q = duringSession(quote)
  const night = q.session.post.end + 3600
  const closeQuote = { ...q, price: 100, marketTime: reg.end + 1 }
  const ok = { status: "ok", receivedAt: night - 60 }
  expect(M.freshness(ok, closeQuote, night, 0)).toMatchObject({ state: "fresh", live: false })
  expect(M.freshnessText(M.freshness(ok, closeQuote, night, 0), q)).toBe("")
  const failed = { status: "failed", receivedAt: night - 60 }
  expect(M.freshness(failed, closeQuote, night, 0).state).toBe("failed")
})

test("sorting ranks the rows as a view over the manual list", () => {
  const q = (symbol, name, prevClose, price) => ({ symbol, name, prevClose, price, marketTime: 1, points: [], session: { regular: null } })
  // Names that sort unlike the symbols, so each order is its own.
  const quotes = { UP: q("UP", "Alpha Inc", 100, 110), DN: q("DN", "Mid Co", 100, 95), FL: q("FL", "Zeta Corp", 100, 100) }
  const manual = ["FL", "DN", "UP", "NEW"]
  expect(M.sortedSymbols(manual, quotes, "manual")).toEqual(manual)
  expect(M.sortedSymbols(manual, quotes, "symbol")).toEqual(["DN", "FL", "UP", "NEW"])
  expect(M.sortedSymbols(manual, quotes, "name")).toEqual(["UP", "DN", "FL", "NEW"])
  expect(M.sortedSymbols(manual, quotes, "pct")).toEqual(["UP", "FL", "DN", "NEW"])
  // Reversed, each sorted order runs the other way; a symbol with no quote
  // stays at the bottom, and manual has no direction.
  expect(M.sortedSymbols(manual, quotes, "symbol", true)).toEqual(["UP", "FL", "DN", "NEW"])
  expect(M.sortedSymbols(manual, quotes, "pct", true)).toEqual(["DN", "FL", "UP", "NEW"])
  expect(M.sortedSymbols(manual, quotes, "manual", true)).toEqual(manual)
  // A tie keeps the manual order, whichever way the sort runs.
  const tie = { FL2: { ...quotes.FL, symbol: "FL2" }, FL: quotes.FL }
  expect(M.sortedSymbols(["FL2", "FL"], tie, "pct")).toEqual(["FL2", "FL"])
  expect(M.sortedSymbols(["FL2", "FL"], tie, "pct", true)).toEqual(["FL2", "FL"])
  // Lucid is up 10%, NVIDIA 2%: by percent Lucid leads, by amount NVIDIA.
  const pair = { LCID: q("LCID", "Lucid", 10, 11), NVDA: q("NVDA", "NVIDIA", 180, 183.6) }
  expect(M.sortedSymbols(["LCID", "NVDA"], pair, "pct")).toEqual(["LCID", "NVDA"])
  expect(M.sortedSymbols(["LCID", "NVDA"], pair, "abs")).toEqual(["NVDA", "LCID"])
})

test("parseSearch keeps tradable results with names and readable exchanges", () => {
  const rows = M.parseSearch(search)
  expect(rows[0].symbol).toBe("SHOP")
  expect(rows[0].exchange).toBe("NASDAQ")
  expect(rows.find(r => r.symbol === "SHOP.TO").exchange).toBe("TSX")
  for (const r of rows) expect(r.name.length).toBeGreaterThan(0)
})

test("search names are whole, so the row's own ellipsis is the only cut", () => {
  const rows = M.parseSearch({ quotes: [
    // Yahoo's short name stops at 31 characters; the long name is whole.
    { symbol: "TSLT", shortname: "T-REX 2X Long Tesla Daily Targe", longname: "T-REX 2X Long Tesla Daily Target ETF", exchange: "BTS", quoteType: "ETF" },
    // A German listing pads its share class onto the short name.
    { symbol: "VUAA.DE", shortname: "Vanguard S&P 500 UCITS ETF    R", longname: null, exchange: "GER", quoteType: "ETF" },
    { symbol: "MTX.F", shortname: "MTU Aero Engines AG           N", exchange: "FRA", quoteType: "EQUITY" },
    // Neither an option nor a row without a symbol is something to add.
    { symbol: "TSLA260918C00400000", shortname: "TSLA Sep 2026 400 call", exchange: "OPR", quoteType: "OPTION" },
    { shortname: "No symbol", exchange: "NMS", quoteType: "EQUITY" },
    { symbol: "BARE", exchange: "NMS", quoteType: "EQUITY" }
  ] })
  expect(rows.map(r => r.name)).toEqual([
    "T-REX 2X Long Tesla Daily Target ETF", "Vanguard S&P 500 UCITS ETF", "MTU Aero Engines AG", "BARE"
  ])
})

test("request URLs are the exact strings Yahoo is sent, and history never takes the 1D path", () => {
  expect(M.chartUrl("SHOP.TO")).toBe("https://query1.finance.yahoo.com/v8/finance/chart/SHOP.TO?range=1d&interval=5m&includePrePost=true")
  expect(M.searchUrl("a b")).toContain("q=a%20b")
  expect(M.historyUrl("AAPL", "1D")).toBeNull()
  expect(M.HISTORY_RANGES["1D"]).toBeUndefined()
  expect(M.historyUrl("NBIS", "1W")).toBe("https://query1.finance.yahoo.com/v8/finance/chart/NBIS?range=5d&interval=15m&events=div%2Csplits&includeAdjustedClose=true")
  // The saved fundamentals answers are the feed's own requests.
  const saved = name => readFileSync(join(fixtures, "fundamentals", name + ".url"), "utf8").replace(/^# /, "").trim()
  const asked = Number(saved("aapl").match(/period2=(\d+)/)[1])
  expect(M.fundamentalsUrl("AAPL", asked)).toBe(saved("aapl"))
  expect(asked - Number(saved("aapl").match(/period1=(\d+)/)[1])).toBe(400 * DAY)
  for (const [name, symbol] of [["nbis", "NBIS"], ["aapl", "AAPL"], ["shop-to", "SHOP.TO"], ["7203-t", "7203.T"], ["shel-l", "SHEL.L"]])
    expect(M.snapshotClosesUrl(symbol, fundamentals(name))).toBe(saved(name + "-closes"))
  expect(M.historyUrl("NBIS", "1M")).toBe("https://query1.finance.yahoo.com/v8/finance/chart/NBIS?range=1mo&interval=1h&events=div%2Csplits&includeAdjustedClose=true")
  expect(M.historyUrl("AAPL", "1Y")).toBe("https://query1.finance.yahoo.com/v8/finance/chart/AAPL?range=1y&interval=1d&events=div%2Csplits&includeAdjustedClose=true")
  expect(M.historyUrl("NVDA", "2Y")).toBe("https://query1.finance.yahoo.com/v8/finance/chart/NVDA?range=2y&interval=1d&events=div%2Csplits&includeAdjustedClose=true")
  expect(M.historyUrl("FIG", "All")).toBe("https://query1.finance.yahoo.com/v8/finance/chart/FIG?range=max&interval=1mo&events=div%2Csplits&includeAdjustedClose=true")
  expect(Object.keys(M.HISTORY_RANGES)).toEqual(["1W", "1M", "3M", "6M", "YTD", "1Y", "2Y", "5Y", "10Y", "All"])
  expect(M.historyRanges()).toEqual(["1D", "1W", "1M", "3M", "6M", "YTD", "1Y", "2Y", "5Y", "10Y", "All"])
})

const historyExpectations = [
  {
    fixture: "aapl-1y.json", range: "1Y", interval: "1d", bars: 251,
    baseline: 230.03, last: 332.2699890136719, abs: 102.23998901367187, pct: 44.44637178353775,
    high: { p: 344.57000732421875, t: 1785331800 },
    low: { p: 229.02000427246094, t: 1757683800 },
    belowHigh: 3.5696717790568844, from: 1757683800, to: 1789133400, short: false
  },
  {
    fixture: "nvda-2y.json", range: "2Y", interval: "1d", bars: 501,
    baseline: 116.91, last: 218.2899932861328, abs: 101.37999328613282, pct: 86.71627173563667,
    high: { p: 236.5399932861328, t: 1778765400 },
    low: { p: 86.62000274658203, t: 1744032600 },
    belowHigh: 7.715397192018907, from: 1726147800, to: 1789133400, short: false
  },
  {
    // Asked for monthly bars, Yahoo sent daily ones; the response's own
    // granularity is the one used.
    fixture: "fig-max.json", range: "All", interval: "1d", bars: 281,
    baseline: 85, last: 23.200000762939453, abs: -61.79999923706055, pct: -72.70588145536536,
    high: { p: 142.9199981689453, t: 1754055000 },
    low: { p: 16.600000381469727, t: 1777555800 },
    belowHigh: 83.7671417155248, from: 1753968600, to: 1789133400, short: true
  },
  {
    fixture: "shop-to-1y.json", range: "1Y", interval: "1d", bars: 252,
    baseline: 200.65, last: 178.41000366210938, abs: -22.23999633789063, pct: -11.083975249384814,
    high: { p: 253.10000610351562, t: 1761744600 },
    low: { p: 129.00999450683594, t: 1778765400 },
    belowHigh: 29.510075322107543, from: 1757597400, to: 1789133400, short: false
  },
  {
    fixture: "nbis-5d.json", range: "1W", interval: "15m", bars: 131,
    baseline: 210.63, last: 224.5500030517578, abs: 13.920003051757817, pct: 6.608746641863846,
    high: { p: 254.74000549316406, t: 1788885900 },
    low: { p: 209.40499877929688, t: 1788528600 },
    belowHigh: 11.851300066889728, from: 1788528600, to: 1789156800, short: false
  },
  {
    fixture: "nbis-1mo.json", range: "1M", interval: "1h", bars: 155,
    baseline: 193.23, last: 224.5500030517578, abs: 31.320003051757823, pct: 16.20866483038753,
    high: { p: 280.8299865722656, t: 1786984200 },
    low: { p: 194.8000030517578, t: 1788269400 },
    belowHigh: 20.04058904372926, from: 1786541400, to: 1789156800, short: false
  },
  {
    fixture: "aapl-5y.json", range: "5Y", interval: "1wk", bars: 262,
    baseline: 148.97, last: 332.2699890136719, abs: 183.29998901367188, pct: 123.04490099595347,
    high: { p: 344.57000732421875, t: 1785124800 },
    low: { p: 124.16999816894531, t: 1672635600 },
    belowHigh: 3.5696717790568844, from: 1631505600, to: 1789156801, short: false
  }
]

test("periodStats matches the saved history fixtures", () => {
  for (const expected of historyExpectations) {
    const history = M.parseHistory(fixture("history/" + expected.fixture), expected.range)
    const stats = M.periodStats(history)
    expect(history.interval, expected.fixture).toBe(expected.interval)
    expect(history.baseline, expected.fixture).toBe(expected.baseline)
    expect(stats.last, expected.fixture).toBe(expected.last)
    expect(stats.change.abs, expected.fixture).toBeCloseTo(expected.abs, 10)
    expect(stats.change.pct, expected.fixture).toBeCloseTo(expected.pct, 10)
    expect(stats.change.up, expected.fixture).toBe(expected.abs >= 0)
    expect(stats.high, expected.fixture).toEqual(expected.high)
    expect(stats.low, expected.fixture).toEqual(expected.low)
    expect(stats.belowHigh, expected.fixture).toBeCloseTo(expected.belowHigh, 10)
    expect(stats.coverage, expected.fixture).toEqual({
      from: expected.from, to: expected.to, bars: expected.bars, short: expected.short
    })
  }
})

test("the saved NVDA split response uses split-adjusted close columns on both sides", () => {
  const json = fixture("history/nvda-split.json")
  const split = json.chart.result[0].events.splits["1718026200"]
  const history = M.parseHistory(json, "2Y")
  expect(split.splitRatio).toBe("10:1")
  expect(history.bars[4]).toMatchObject({ t: 1717767000, c: 120.88800048828125 })
  expect(history.bars[5]).toMatchObject({ t: 1718026200, c: 121.79000091552734 })
  expect(history.bars[5].c / history.bars[4].c).toBeCloseTo(1.0074614554265338, 10)
  expect(history.bars[0].c).toBe(115)
  expect(json.chart.result[0].indicators.adjclose[0].adjclose[0]).toBe(114.67301177978516)
})

test("historyGeometry uses uniform bar spacing and retains bar facts", () => {
  const history = M.parseHistory(fixture("history/aapl-1y.json"), "1Y")
  const geometry = M.historyGeometry(history)
  const step = 1 / (history.bars.length - 1)
  expect(geometry.points.length).toBe(history.bars.length)
  expect(geometry.points[0]).toMatchObject({ x: 0, t: 1757683800, p: 234.07000732421875, ext: false })
  expect(geometry.points[geometry.points.length - 1]).toMatchObject({ x: 1, t: 1789133400, p: 332.2699890136719, ext: false })
  for (let i = 1; i < geometry.points.length; i++)
    expect(geometry.points[i].x - geometry.points[i - 1].x).toBeCloseTo(step, 12)
  const closes = history.bars.map(bar => bar.c).concat([history.baseline])
  expect(geometry.day).toBe(false)
  // Headroom: every close and the baseline sit strictly inside the range.
  expect(geometry.lo).toBeLessThan(Math.min(...closes))
  expect(geometry.hi).toBeGreaterThan(Math.max(...closes))
  expect(geometry.baselineY).toBeGreaterThan(0)
  expect(geometry.baselineY).toBeLessThan(1)
  expect(geometry.start).toBe(1757683800)
  expect(geometry.end).toBe(1789133400)
  expect(geometry.ticks).toEqual([])
})

test("5Y and longer draw on a log scale; shorter ranges stay linear", () => {
  const weekly = M.parseHistory(fixture("history/aapl-5y.json"), "5Y")
  const geometry = M.historyGeometry(weekly)
  const logY = p => 1 - (Math.log(p) - Math.log(geometry.lo)) / (Math.log(geometry.hi) - Math.log(geometry.lo))
  for (const point of geometry.points) expect(point.y).toBeCloseTo(logY(point.p), 12)
  expect(geometry.baselineY).toBeCloseTo(logY(weekly.baseline), 12)
  const highest = geometry.points.reduce((a, b) => (b.p > a.p ? b : a))
  const lowest = geometry.points.reduce((a, b) => (b.p < a.p ? b : a))
  expect(Math.min(...geometry.points.map(point => point.y))).toBe(highest.y)
  expect(Math.max(...geometry.points.map(point => point.y))).toBe(lowest.y)
  // The scrub walks bars by position, so the scale cannot move it.
  const bar = weekly.bars[100]
  expect(M.historyBarAt(weekly, geometry.points[100].x)).toBe(bar)
  expect(M.historyFraction(weekly, bar.t)).toBe(geometry.points[100].x)
  for (const range of ["10Y", "All"]) {
    const long = M.historyGeometry({ ...weekly, range })
    const longY = p => 1 - (Math.log(p) - Math.log(long.lo)) / (Math.log(long.hi) - Math.log(long.lo))
    for (const point of long.points) expect(point.y).toBeCloseTo(longY(point.p), 12)
  }
  const linear = M.historyGeometry({ ...weekly, range: "2Y" })
  const linearY = p => 1 - (p - linear.lo) / (linear.hi - linear.lo)
  for (const point of linear.points) expect(point.y).toBeCloseTo(linearY(point.p), 12)
  // A log has no place for zero: a long range with a zero baseline or a
  // zero close draws linear, every point finite.
  for (const odd of [{ ...weekly, baseline: 0 }, { ...weekly, bars: weekly.bars.map((bar, i) => (i === 3 ? { ...bar, c: 0 } : bar)) }]) {
    const flat = M.historyGeometry(odd)
    for (const point of flat.points) expect(Number.isFinite(point.y)).toBe(true)
    expect(Number.isFinite(flat.baselineY)).toBe(true)
    const oddY = p => 1 - (p - flat.lo) / (flat.hi - flat.lo)
    for (const point of flat.points) expect(point.y).toBeCloseTo(oddY(point.p), 12)
  }
})

test("history scrub lookup snaps to a bar and maps its timestamp back", () => {
  const history = M.parseHistory(fixture("history/aapl-1y.json"), "1Y")
  const middle = history.bars[125]
  expect(M.historyBarAt(history, 0.5)).toBe(middle)
  expect(M.historyFraction(history, middle.t)).toBe(0.5)
  expect(M.historyBarAt(history, -1)).toBe(history.bars[0])
  expect(M.historyBarAt(history, 2)).toBe(history.bars[history.bars.length - 1])
  expect(M.historyFraction(history, history.bars[0].t - 1)).toBe(-1)
  expect(M.historyFraction(history, history.bars[history.bars.length - 1].t + 1)).toBe(-1)
})

// The range is said by its token and the change's caption above the line,
// so the line never says it again (design pass 3).
test("history labels state coverage and the bar granularity, never the range", () => {
  const aapl = M.parseHistory(fixture("history/aapl-1y.json"), "1Y")
  const week = M.parseHistory(fixture("history/nbis-5d.json"), "1W")
  const month = M.parseHistory(fixture("history/nbis-1mo.json"), "1M")
  const fig = M.parseHistory(fixture("history/fig-max.json"), "All")
  const weekly = M.parseHistory(fixture("history/aapl-5y.json"), "5Y")
  expect(M.historyStatsText(aapl)).toBe("H 344.57 29 JUL 26 · L 229.02 12 SEP 25 · 3.6% BELOW HIGH")
  expect(M.historyStatsText(week)).toBe("H 254.74 8 SEP · L 209.40 4 SEP · 11.9% BELOW HIGH")
  expect(M.historyStatsText(month)).toBe("H 280.83 17 AUG · L 194.80 1 SEP · 20.0% BELOW HIGH")
  expect(M.historyStatsText(fig)).toBe("SINCE 31 JUL 25 · H 142.92 1 AUG 25 · L 16.60 30 APR 26 · 83.8% BELOW HIGH")
  expect(M.historyStatsText(weekly)).toBe("H 344.57 JUL 26 · L 124.17 JAN 23 · 3.6% BELOW HIGH")
  expect(M.historyStatsText({ ...week, bars: [] })).toBe("0 BARS")
  // A weekly bar names no day, so it carries its year even when the whole
  // period sits inside one.
  const oneYear = {
    ...weekly, interval: "1wk",
    bars: weekly.bars.filter(bar => bar.t >= 1767225600 && bar.t < 1798761600)
  }
  expect(M.historySpansYears(oneYear)).toBe(false)
  expect(M.historyStatsText(oneYear)).toMatch(/H [\d.,]+ [A-Z]{3} 26 · L [\d.,]+ [A-Z]{3} 26/)
  expect(M.historyScrubText(aapl, aapl.bars[0])).toBe("12 SEP 2025 · 234.07")
  expect(M.historyScrubText(week, week.bars[0])).toBe("4 SEP 09:30 · 213.58")
  expect(M.historyScrubText({ ...week, interval: "30m" }, week.bars[0])).toBe("4 SEP 09:30 · 213.58")
  expect(M.historyScrubText(month, month.bars[0])).toBe("12 AUG 09:30 · 233.17")
  expect(M.historyScrubText({ ...week, interval: "1wk" }, week.bars[0])).toBe("WEEK OF 4 SEP · 213.58")
  expect(M.historyScrubText({ ...aapl, interval: "1mo" }, aapl.bars[0])).toBe("SEP 2025 · 234.07")
  expect(M.historyScrubText({ ...aapl, interval: "3mo" }, aapl.bars[0])).toBe("SEP 2025 · 234.07")
  // A short sparse response says how many bars actually exist.
  const sparse = {
    symbol: "NEW", range: "All", interval: "1d", gmtoffset: 0, baseline: 10, firstTradeDate: 100,
    bars: [{ t: 100, h: 11, l: 9, c: 10 }, { t: 100 + DAY, h: 12, l: 10, c: 11 }]
  }
  expect(M.historyStatsText(sparse)).toContain("SINCE 1 JAN 70 · 2 BARS")
})

test("historyRowModel uses the quote until a historical bar is scrubbed", () => {
  const history = M.parseHistory(fixture("history/aapl-1y.json"), "1Y")
  const resting = M.historyRowModel(history, quote, 0)
  expect(resting.price).toBe(M.regularClose(quote))
  expect(resting.asOf).toBe(M.headlineQuote(quote).t)
  expect(resting.changeText).toBe(M.pct((M.regularClose(quote) - history.baseline) / history.baseline * 100))
  expect(resting.periodLabel).toBe("1Y")
  expect(resting.dayUp).toBe(true)
  const bar = history.bars[20]
  const scrubbed = M.historyRowModel(history, quote, bar.t)
  expect(scrubbed.price).toBe(bar.c)
  expect(scrubbed.asOf).toBe(bar.t)
  expect(scrubbed.changeText).toBe(M.pct((bar.c - history.baseline) / history.baseline * 100))
  const fallback = M.historyRowModel(history, null, 0)
  expect(fallback).toMatchObject({
    symbol: "AAPL", name: "AAPL", price: 332.2699890136719,
    asOf: history.bars[history.bars.length - 1].t
  })
  expect(M.historyRowModel(null, quote, 0)).toBeNull()
})

test("historyRowModel direction follows the change being shown", () => {
  const history = {
    symbol: "TEST", range: "1Y", interval: "1d", baseline: 300,
    bars: [{ t: 1, h: 251, l: 249, c: 250 }, { t: 2, h: 281, l: 279, c: 280 }]
  }
  expect(M.historyRowModel(history, { ...quote, price: 325 }, 0).dayUp).toBe(true)
  expect(M.historyRowModel(history, quote, 1)).toMatchObject({ price: 250, tone: "down", dayUp: false })
})

test("settingsFromBar is null when the bar entry has no symbols", () => {
  expect(M.settingsFromBar(fixture("shell-bar-no-symbols.json"))).toBeNull()
  expect(M.settingsFromBar({ plugins: [] })).toBeNull()
})

// ---------------------------------------------------------------- overnight

// Robinhood's saved span=day answer for a moment, by symbol: the bars that traded.
const traded = (set, symbols) => M.parseOvernight(fixture(`overnight/${set}/robinhood-day.json`), symbols)
const savedDay = (set, name) => M.parseChart(fixture(`overnight/${set}/${name}.json`))
const at = (date, clock) => M.epochAt(US, date, clock)

test("Robinhood's answer keeps only the bars that traded, by the symbols asked for", () => {
  // Saved Friday 2 October at 13:40 New York. bounds=24_5 still fills SNOW's
  // quiet five-minute slots with flat interpolated bars; GMIN.TO, a Toronto
  // listing Robinhood does not trade, comes back empty in its place.
  const raw = fixture("overnight/day/robinhood-day.json").results
  const bars = traded("day", ["NBIS", "SNOW", "RVII", "GMIN.TO"])
  expect(raw[1].historicals.length).toBe(288)
  expect(bars.SNOW.length).toBe(288 - raw[1].historicals.filter(b => b.interpolated).length)
  expect(bars.NBIS.filter(b => b.s === "overnight").length).toBe(96)
  expect(bars.RVII.filter(b => b.s === "overnight")).toEqual([])
  expect(bars["GMIN.TO"]).toEqual([])
  // Asked out of the order it answers in, an answer names another symbol
  // and is no answer for the one asked.
  expect(M.parseOvernight(fixture("overnight/day/robinhood-day.json"), ["SNOW", "NBIS"]))
    .toEqual({ SNOW: [], NBIS: [] })
  expect(M.parseOvernight({ chart: {} }, ["NBIS"])).toBeNull()
})

test("Robinhood's instruments say which listings it trades all day, by the symbols asked for", () => {
  // Saved Wednesday 7 October: NBIS and SPY trade on its 24 Hour Market,
  // PSIX and BLDP do not. Results come in Robinhood's own order; one it does
  // not list is not all-day, and a share class is asked with a dot.
  const answer = fixture("overnight/sweep-2026-10-07-1455/robinhood-instruments.json")
  expect(M.parseAllDay(answer, ["PSIX", "NBIS", "BLDP", "SPY", "ZZZZQ"]))
    .toEqual({ PSIX: false, NBIS: true, BLDP: false, SPY: true, ZZZZQ: false })
  expect(M.parseAllDay({ results: [{ symbol: "BRK.B", all_day_tradability: "tradable" }] }, ["BRK-B"])).toEqual({ "BRK-B": true })
  expect(M.allDayUrl(["BRK-B", "NBIS"])).toContain("?symbols=BRK.B,NBIS")
  expect(M.parseAllDay({ chart: {} }, ["NBIS"])).toBeNull()
})

test("which listings have an overnight market comes from Yahoo, never from Robinhood's answer", () => {
  // Asked for SPX, ^GSPC, BTC, and BTC-USD, Robinhood answers the index and
  // the cryptocurrency with nothing, and BTC with the bars of a bitcoin ETF.
  const answer = M.parseOvernight(fixture("overnight/robinhood-index-crypto.json"), ["SPX", "^GSPC", "BTC", "BTC-USD"])
  expect([answer.SPX.length, answer["^GSPC"].length, answer["BTC-USD"].length]).toEqual([0, 0, 0])
  expect(answer.BTC.length).toBeGreaterThan(0)
  // So the quote decides: a stock or an ETF on a US exchange.
  expect(M.hasOvernight(savedDay("day", "nbis"), calendars)).toBe(true)
  expect(M.hasOvernight(M.parseChart(fixture("spy-2026-09-11-day-prepost.json")), calendars)).toBe(true)
  expect(M.hasOvernight(savedDay("day", "gspc"), calendars)).toBe(false)
  expect(M.hasOvernight(btc, calendars)).toBe(false)
  expect(M.hasOvernight(shop, calendars)).toBe(false)
  expect(M.hasOvernight(M.parseChart(fixture("7203-t-day.json")), calendars)).toBe(false)
  expect(M.hasOvernight(M.parseChart(fixture("shel-l-day.json")), calendars)).toBe(false)
  // One request for the list, a share class in Robinhood's spelling.
  expect(M.overnightUrl(["NBIS", "BRK-B"]))
    .toBe("https://api.robinhood.com/marketdata/historicals/?symbols=NBIS,BRK.B&interval=5minute&span=day&bounds=24_5")
})

// The 1D chart of a saved moment, with the quote it was built from.
// Robinhood's answer is read for the symbols it holds, in its order.
const dayAt = (set, name) => {
  const asked = fixture(`overnight/${set}/robinhood-day.json`).results.map(r => r.symbol)
  const quote = savedDay(set, name)
  return { ...M.dayChart(quote, traded(set, asked)[name.toUpperCase()], calendars), quote }
}
// The line under the price at `now`, as the hero reads it.
const stripAt = (built, now) => M.extendedStack(built.quote, built.latest, now, built.day)

test("the 1D chart is the New York calendar day, midnight to midnight, the hours to come empty", () => {
  // Wednesday 7 October, 11:53: Robinhood's screen draws the day from
  // midnight, the night and the pre-market before the open, and nothing past now.
  const quote = savedDay("2026-10-07-1153", "nbis")
  const { day } = dayAt("2026-10-07-1153", "nbis")
  expect(M.chartSpan(day)).toMatchObject({ start: at("2026-10-07", "00:00"), end: at("2026-10-08", "00:00") })
  expect(day.points[0].t).toBeGreaterThanOrEqual(at("2026-10-07", "00:00"))
  const sessions = day.points.map(p => p.s).filter((s, i, all) => s !== all[i - 1])
  expect(sessions).toEqual(["overnight", "pre", "reg"])
  expect(M.chartGeometry(day).points.at(-1).x).toBeCloseTo((11 * 60 + 50) / 1440, 2)
  // Ticks at the night's end, the close, and tonight's start.
  expect(M.chartGeometry(day).ticks.map(x => M.timeAtFraction(day, x)))
    .toEqual([at("2026-10-07", "04:00"), at("2026-10-07", "16:00"), at("2026-10-07", "20:00")])
  // Measured from Tuesday's close, the quote's previous close.
  expect(day.prevClose).toBe(quote.prevClose)
})

test("before the day's first print the chart stays on yesterday, and the line under the price names the night", () => {
  // Wednesday 00:05: Robinhood's newest bar is Tuesday 23:55.
  const { day, latest } = dayAt("2026-10-07-0005", "nbis")
  expect(M.chartSpan(day).start).toBe(at("2026-10-06", "00:00"))
  expect(M.lastPrintTime(day)).toBe(at("2026-10-06", "23:55"))
  expect(stripAt(dayAt("2026-10-07-0005", "nbis"), at("2026-10-07", "00:05"))).toMatchObject({ label: "OVERNIGHT", time: "23:55" })
})

test("from midnight to the pre-market the chart is the new day, measured from yesterday's close", () => {
  // Wednesday 01:00: Yahoo's bars are still Tuesday's, so its previous close
  // is Monday's; the night after Tuesday's close is measured from Tuesday's.
  const quote = savedDay("2026-10-07-0100", "nbis")
  const { day, latest } = dayAt("2026-10-07-0100", "nbis")
  expect(M.chartSpan(day).start).toBe(at("2026-10-07", "00:00"))
  expect(day.points.every(p => p.s === "overnight")).toBe(true)
  expect(M.money(day.prevClose)).toBe("249.87")
  expect(M.money(quote.prevClose)).not.toBe("249.87")
  // A scrub of the night reads its move from that close, as the line under
  // the price does; the headline stays Tuesday's close and day.
  const scrubbed = M.rowModel(day, latest.t, "pct")
  expect(scrubbed.changeText).toBe(M.extendedStack(quote, latest, at("2026-10-07", "01:00"), day).changeText)
  expect(scrubbed.dayUp).toBe(false)
  expect(M.rowModel(quote, 0, "pct").changeText).toBe("+7.44%")
  // At 06:00 Yahoo's day is Wednesday's, and its previous close is the same close.
  expect(M.money(dayAt("2026-10-07-0600", "nbis").day.prevClose)).toBe("249.87")
})

test("the evening's night is on the day's chart, measured from the day's previous close (provisional)", () => {
  // Tuesday 23:00: the night since 20:00 at the right end of Tuesday.
  const quote = savedDay("2026-10-06-2300", "nbis")
  const { day } = dayAt("2026-10-06-2300", "nbis")
  expect(M.chartSpan(day).start).toBe(at("2026-10-06", "00:00"))
  expect(day.points.at(-1)).toMatchObject({ s: "overnight" })
  expect(day.points.at(-1).t).toBeGreaterThanOrEqual(at("2026-10-06", "20:00"))
  expect(day.prevClose).toBe(quote.prevClose)
})

test("a weekend shows Friday all day, and Sunday night is named under the price, on no chart yet (provisional)", () => {
  const saturday = dayAt("2026-10-03-1200", "nbis").day
  expect(M.chartSpan(saturday)).toMatchObject({ start: at("2026-10-02", "00:00"), end: at("2026-10-03", "00:00") })
  expect(M.lastPrintTime(saturday)).toBe(at("2026-10-02", "19:55"))
  // No session Friday night: no tick at 20:00.
  expect(M.chartGeometry(saturday).ticks.map(x => M.timeAtFraction(saturday, x)))
    .toEqual([at("2026-10-02", "04:00"), at("2026-10-02", "16:00")])
  const sunday = dayAt("2026-10-04-2230", "nbis")
  expect(M.chartSpan(sunday.day).start).toBe(at("2026-10-02", "00:00"))
  expect(sunday.latest.t).toBeGreaterThanOrEqual(at("2026-10-04", "20:00"))
  expect(stripAt(sunday, at("2026-10-04", "22:30"))).toMatchObject({ label: "OVERNIGHT" })
})

test("an overnight print is its own line under the price, measured from the close, with its time", () => {
  const now = at("2026-10-01", "23:00")
  const strip = name => stripAt(dayAt("night", name), now)
  const nbis = savedDay("night", "nbis")
  const nbisDay = dayAt("night", "nbis").day
  // NBIS traded to 22:50, ten minutes ago: Robinhood's newest bar.
  expect(strip("nbis")).toEqual({ price: "234.27", changeText: "+0.86%", tone: "up", label: "OVERNIGHT", time: "22:50", stale: false })
  expect(M.money(M.regularClose(nbis))).toBe("232.28")
  // Never the headline, nor in the day's high: the day holds a night print
  // above Thursday's high, and the hero and the day's line are Thursday's.
  expect(Math.max(...nbisDay.points.map(p => p.p))).toBeGreaterThan(nbis.dayHigh)
  expect(M.rowModel(nbis, 0, "pct").priceText).toBe("232.28")
  // SNOW last traded at 22:20: forty minutes old, it dims.
  expect(strip("snow")).toMatchObject({ label: "OVERNIGHT", time: "22:20", stale: true })
  // RVII has not traded tonight: no overnight line, its after-hours stays.
  expect(strip("rvii")).toMatchObject({ label: "AFTER HOURS", time: "" })
  // While a scrub reads the night, the header names it.
  expect(M.marketStatus(nbisDay, now, at("2026-10-01", "21:30"), calendars)).toBe("At 21:30 · Overnight")
  expect(M.marketStatus(nbisDay, now, at("2026-10-01", "00:20"), calendars)).toBe("At 00:20 · Overnight")
})

test("no session on Friday or Saturday night, or the night before a holiday", () => {
  const weekend = dayAt("weekend", "nbis")
  // Saturday noon: Friday's after-hours is the newest print.
  expect(stripAt(weekend, at("2026-09-26", "12:00"))).toMatchObject({ label: "AFTER HOURS" })
  expect(M.lastPrintTime(weekend.day)).toBe(at("2026-09-25", "19:55"))
  const night = t => M.nightAt(US, t)
  expect(night(at("2026-09-27", "22:00")).open).toBe(true)
  expect(night(at("2026-09-29", "02:00")).open).toBe(true)
  expect(night(at("2026-09-25", "22:00")).open).toBe(false)
  expect(night(at("2026-09-26", "22:00")).open).toBe(false)
  // Thanksgiving is Thursday 26 November: no session Wednesday night, and
  // Thursday night trades into Friday.
  expect(night(at("2026-11-25", "22:00")).open).toBe(false)
  expect(night(at("2026-11-26", "22:00")).open).toBe(true)
  expect(night(at("2026-10-02", "12:00"))).toBeNull()
})

test("after midnight the answer is still Friday's: its date, its open, its prints, and its rows' day lines", () => {
  // Saved Monday 5 October at 00:36 New York. Yahoo's current period is
  // already Monday's; the bars, the high, low, and volume, and the trading
  // periods are Friday's.
  const now = at("2026-10-05", "00:36")
  const live = name => M.parseChart(fixture(`overnight/live-2026-10-05/${name}.json`))
  const nbis = live("nbis")
  expect(M.dayStatsText(nbis)).toBe("FRI 2 OCT · O 235.81 · H 248.34 · L 235.34 · VOL 12.3M")
  for (const name of ["nbis", "et", "tln"]) {
    const quote = live(name)
    // Friday's 19:59 print is after hours, never Monday's pre-market.
    expect(M.extendedStack(quote, null, now).label).toBe("AFTER HOURS")
    // A row's day line runs the full width: Friday's pre-market to its last print.
    const points = M.chartGeometry(quote).points
    expect([points[0].x, points[points.length - 1].x]).toEqual([0, 1])
    // The next open comes from the calendar.
    expect(M.marketStatus(quote, now, 0, calendars)).toBe("Closed · opens Mon 09:30")
  }
  // A daytime answer reads as it did: Friday 2 October at 13:40.
  const day = savedDay("day", "nbis")
  expect(M.dayStatsText(day)).toBe("FRI 2 OCT · O 235.81 · H 248.34 · L 235.34 · VOL 9.5M")
  expect(M.marketStatus(day, at("2026-10-02", "13:40"), 0, calendars)).toBe("Market closes in 2h 20m")
})

test("a quote held past its bars' session takes the phase and the bell from Yahoo's current period", () => {
  // The saved Monday 00:36 NBIS answer, still held at 04:30: its current
  // period's pre-market has begun, so the header turns, and so does the
  // cadence, at the boundary itself, not at the next fetch.
  const nbis = M.parseChart(fixture("overnight/live-2026-10-05/nbis.json"))
  const dawn = at("2026-10-05", "04:30")
  expect(M.marketStatus(nbis, dawn, 0, calendars)).toBe("Pre-market · opens in 5h")
  expect([M.quoteCadence(nbis, dawn, 60, true, calendars), M.quoteCadence(nbis, dawn, 60, false, calendars)]).toEqual([60, 300])
  // The chart, the open, and the info line stay the bars' Friday.
  expect(M.dayStatsText(nbis)).toBe("FRI 2 OCT · O 235.81 · H 248.34 · L 235.34 · VOL 12.3M")
  expect(M.extendedStack(nbis, null, dawn).label).toBe("AFTER HOURS")
  // London's answer, saved before Friday's session with Thursday's bars,
  // still held at 08:30 London: Friday's session is open.
  const london = M.parseChart(fixture("shel-l-day.json"))
  const morning = M.epochAt(calendars.calendars.LSE, "2026-10-02", "08:30")
  expect(M.marketStatus(london, morning, 0, calendars)).toBe("Market closes in 8h")
  expect([M.inRegularSession(london, morning, calendars), M.quoteCadence(london, morning, 60, false, calendars)]).toEqual([true, 60])
})

test("a quote held from an earlier day stays warm by its calendar; one with no calendar, on the slow clock once its periods are past", () => {
  // NBIS's answer of Wednesday 7 October at 14:55, held into Thursday.
  const nbis = M.parseChart(fixture("overnight/sweep-2026-10-07-1455/nbis.json"))
  const thursday = at("2026-10-08", "11:00")
  expect(M.sessionPhase(nbis, thursday)).toBe("closed")
  expect([M.inRegularSession(nbis, thursday, calendars), M.staysWarm(nbis, thursday, calendars), M.quoteCadence(nbis, thursday, 60, false, calendars)])
    .toEqual([true, true, 60])
  // Before Thursday's open, and on Saturday: closed.
  expect(M.staysWarm(nbis, at("2026-10-08", "08:00"), calendars)).toBe(false)
  expect(M.staysWarm(nbis, at("2026-10-10", "12:00"), calendars)).toBe(false)
  // The S&P 500 is on the US calendar (S&P is one of its exchanges): kept
  // fresh through Thursday's session like any US listing, at the refresh
  // interval, and not before Wednesday's open.
  const gspc = M.parseChart(fixture("overnight/sweep-2026-10-07-1455/gspc.json"))
  expect([M.staysWarm(gspc, at("2026-10-07", "11:00"), calendars), M.staysWarm(gspc, at("2026-10-07", "06:00"), calendars)]).toEqual([true, false])
  expect([M.staysWarm(gspc, thursday, calendars), M.quoteCadence(gspc, thursday, 60, false, calendars)]).toEqual([true, 60])
  expect(M.staysWarm(gspc, at("2026-10-10", "12:00"), calendars)).toBe(false)
  // An index whose exchange has no calendar (Russell's, Yahoo's WCB): in its
  // periods it is warm; once they are past, it is asked on the slow clock to
  // learn of the next.
  const russell = { ...gspc, exchange: "WCB" }
  expect([M.staysWarm(russell, at("2026-10-07", "11:00"), calendars), M.staysWarm(russell, at("2026-10-07", "06:00"), calendars)]).toEqual([true, false])
  expect([M.staysWarm(russell, thursday, calendars), M.quoteCadence(russell, thursday, 60, false, calendars)]).toEqual([true, 900])
  // A cryptocurrency never stays warm with nothing open.
  expect(M.staysWarm(btc, btc.session.regular.start + 3600, calendars)).toBe(false)
})
