.import "Format.js" as Format
.import "Market.js" as Market
.import "Overnight.js" as Overnight
.import "Quote.js" as Quote

// What a quote shows: the rows' and the hero's figures, the list's breadth,
// the day's info line, the line under the price, freshness, and the pill's
// arrow. Knows nothing of how the quote was parsed or when markets open.
//
// Presentation follows Apple's Stocks app where it has already decided:
// prices stay in the listing's currency, the currency code and exchange sit
// on one line, the headline price is the regular close with the extended
// hours print labelled separately.

function arrowAngle(pctChange) {
  if (!Format.isFiniteNumber(pctChange)) return 0
  return Format.clamp(pctChange / 5, -1, 1) * 45
}

// The listing line's exchange and currency, the code said once: left out
// where the name already ends with it, as Yahoo names a pair ("Bitcoin USD").
function listingMeta(quote) {
  var tail = " " + quote.currency
  var name = String(quote.name || "")
  return quote.exchange + (name.slice(-tail.length) === tail ? "" : " · " + quote.currency)
}

// Freshness is three separate facts, kept separate: the time the headline
// quote stands for, whether a refresh was asked for and has had no answer,
// and whether the last one failed. The policy is presentation, not a claim
// about the provider: a symbol that trades is asked for at the refresh
// interval, so a live indicator is honest for a quote under two minutes old.

var LIVE_QUOTE_MAX_AGE = 120

// Room for a run of the whole list and three tries of a bad answer before
// a refresh asked for counts as overdue.
var OVERDUE_AFTER = 90

// entry: the feed's last answer, { status: "ok"|"failed"|"saved" }, "saved"
// for a quote kept from an earlier session, or null before any. askedAt:
// when a refresh was asked for and has had no answer yet, or 0. A symbol
// nobody asked for is never late, so no cadence enters the rule.
function freshness(entry, quote, now, askedAt) {
  var head = quote ? Quote.headlineQuote(quote) : null
  var phase = quote ? Market.sessionPhase(quote, now) : "closed"
  var asOf = head ? head.t : null
  var overdue = askedAt > 0 && now - askedAt >= OVERDUE_AFTER
  // The quote stands for another day than the clock's, in its exchange's
  // time: the words name the day.
  var earlier = !!asOf && Math.floor((asOf + quote.gmtoffset) / 86400) !== Math.floor((now + quote.gmtoffset) / 86400)
  var state = entry && entry.status === "failed" ? "failed"
    : overdue ? "overdue"
    : !quote || !head ? "unavailable"
    : entry && entry.status === "saved" ? "saved"
    : Market.isTrading(phase) && now - head.t > LIVE_QUOTE_MAX_AGE ? "aged"
    : "fresh"
  return { state: state, asOf: asOf, earlier: earlier, live: state === "fresh" && Market.isTrading(phase), phase: phase }
}

// The words for a freshness state, or "" when nothing needs saying. A quote
// kept from an earlier session says when it is from until its first answer.
// The time is the quote's exchange's (`Market.printClock`), its zone named
// where the reader's clock differs.
function freshnessText(fresh, quote, calendars) {
  if (!fresh) return ""
  if (!fresh.asOf) return fresh.state === "failed" ? "REFRESH FAILED" : fresh.state === "unavailable" || fresh.state === "overdue" ? "NO DATA" : ""
  var asOf = "AS OF " + (fresh.earlier ? Format.WEEKDAYS[Format.localClock(fresh.asOf, quote.gmtoffset).weekday].toUpperCase() + " " : "")
    + Market.printClock(quote, fresh.asOf, calendars)
  if (fresh.state === "failed") return "REFRESH FAILED · " + asOf
  if (fresh.state === "overdue") return "UPDATE OVERDUE · " + asOf
  if (fresh.state === "aged" || fresh.state === "saved") return asOf
  return ""
}

function freshnessWarns(fresh) {
  return !!fresh && (fresh.state === "failed" || fresh.state === "overdue")
}

// The extended-hours line under the price: the newest print outside the
// regular session (`latest`, the chart's newest print of all, or the
// quote's own last), with its move against the quote's regular close. Null
// during the regular session. An overnight print says its own time, by the
// calendar the chart's `day` carries when it has one, and is `stale` once
// OVERNIGHT_STALE old at `now`. A pre- or post-market print that shows as
// the close itself is left out: an exchange with no extended session echoes
// its close. An overnight print is a trade, and stays.
function extendedStack(quote, latest, now, day) {
  var ext = Quote.extendedPrint(quote, latest)
  var close = Quote.regularClose(quote)
  var overnight = !!ext && ext.phase === "overnight"
  var digits = quote.priceDigits
  if (!ext || !Format.isFiniteNumber(close) || (!overnight && Format.money(ext.p, digits) === Format.money(close, digits))) return null
  var chg = Quote.change({ prevClose: close }, ext.p)
  return {
    price: Format.money(ext.p, digits),
    changeText: Format.pct(chg.pct),
    tone: Format.changeTone(chg, "pct"),
    label: overnight ? "OVERNIGHT" : ext.phase === "post" ? "AFTER HOURS" : "PRE-MARKET",
    time: overnight ? Market.printClock(day || quote, ext.t) : "",
    stale: overnight && now - ext.t > Overnight.OVERNIGHT_STALE
  }
}

// The info block's first line on the day: the session it describes, its
// regular low and high once known, the price's place between them, then
// its open and volume. An end the day pushes to its 52-week mark takes
// that direction's tone, as the 52-week line's does (`Fundamentals.yearLine`).
// The open keeps its slot before the session's first bar, so the line keeps
// its shape; VOL's is as wide as 999.9M. With no quote there is no line.
function dayLine(quote) {
  if (!quote) return null
  var q = quote
  var head = Quote.headlineQuote(q)
  var range = Format.infoRange(q.dayLow, q.dayHigh, head ? head.price : null, q.priceDigits)
  if (range.high !== null && Format.isFiniteNumber(q.fiftyTwoWeekHigh) && range.high >= q.fiftyTwoWeekHigh) range.highTone = "up"
  if (range.low !== null && Format.isFiniteNumber(q.fiftyTwoWeekLow) && range.low <= q.fiftyTwoWeekLow) range.lowTone = "down"
  return {
    title: sessionDayText(q),
    range: range,
    facts: [
      { label: "OPEN", value: Format.isFiniteNumber(q.dayOpen) ? Format.money(q.dayOpen, q.priceDigits) : "", widest: range.widest },
      { label: "VOL", value: Format.isFiniteNumber(q.volume) ? Format.compactNumber(q.volume) : "", widest: Format.widest("999.9M") }
    ]
  }
}

// The date of the session the day's figures are, in the exchange's own
// calendar: "FRI 11 SEP". On a weekend, a holiday, or before the new day's
// session that is not today, and the line says so; "1D" when there is none.
function sessionDayText(quote) {
  if (!quote || !Format.isFiniteNumber(quote.figuresDay)) return "1D"
  var d = new Date((quote.figuresDay + (quote.gmtoffset || 0)) * 1000)
  return Format.WEEKDAYS[d.getUTCDay()].toUpperCase() + " " + d.getUTCDate() + " " + Format.MONTHS[d.getUTCMonth()]
}

// How the list reads on the figures its rows show: up, flat, and down, and
// the rows with no figure yet. The rows' own price and tone rules, so the
// rule under the list name never disagrees with them.
function listBreadth(symbols, quotes, scrubT, mode) {
  var out = { up: 0, flat: 0, down: 0, none: 0 }
  for (var i = 0; i < symbols.length; i++) {
    var quote = quotes[symbols[i]]
    var read = quote ? (scrubT ? Quote.readingAt(quote, scrubT) : Quote.headlineQuote(quote)) : null
    var price = read ? read.price : null
    var chg = quote ? Quote.change(quote, price) : null
    if (!chg || chg.pct === null) out.none++
    else out[Format.changeTone(chg, mode, quote.priceDigits)]++
  }
  return out
}

// The one projection every price on screen comes from. The headline is
// the regular-market quote; a non-zero scrubT reads that moment of the day
// (`Quote.readingAt`). Every change is measured from the previous close, so
// dayUp is the direction at the moment shown, whatever the change mode, as
// a range's is. dayTone is that change's
// tone, flat when it rounds to nothing, so the bull and bear follow a scrub
// and a replay, and a flat day has neither.
// It carries no drawing: a line is drawn from its quote, so it redraws when
// the quote does, not with the clock or the change mode. Nor does it read
// the clock, so a row is not derived again every second. Pass the
// already-snapped scrub time.
function rowModel(quote, scrubT, changeMode) {
  var read = scrubT ? Quote.readingAt(quote, scrubT) : Quote.headlineQuote(quote)
  var price = read ? read.price : null
  var chg = Quote.change(quote, price)
  return {
    symbol: quote.symbol,
    name: quote.name,
    price: price,
    priceText: Format.money(price, quote.priceDigits),
    asOf: read ? read.t : null,
    // Null stays null: an unavailable change must not read as unchanged.
    pct: chg.pct,
    tone: Format.changeTone(chg, changeMode, quote.priceDigits),
    dayUp: chg.pct === null ? null : chg.up,
    dayTone: Format.changeTone(chg, "pct", quote.priceDigits),
    changeText: Format.changeText(chg, changeMode, quote.priceDigits)
  }
}
