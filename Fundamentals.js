.import "Format.js" as Format
.import "Quote.js" as Quote

// Cap and P/E: Yahoo's dated snapshots, their closes, and the key stats
// line. Knows nothing of sessions or charts.

var FUNDAMENTALS_URL = "https://query1.finance.yahoo.com/ws/fundamentals-timeseries/v1/finance/timeseries/"

// Yahoo keeps a listing's cap and P/E as dated snapshots, weeks or months
// apart (once ten months); 400 days reaches the latest.
var FUNDAMENTALS_DAYS = 400

// A cap snapshot older than this, against the price, is too stale to move.
var CAP_MAX_AGE_DAYS = 120

// Only an equity has a cap or a P/E: Yahoo sends an ETF, an index, or a
// cryptocurrency none.
function hasFundamentals(quote) {
  return !!quote && quote.instrumentType === "EQUITY"
}

function fundamentalsUrl(symbol, now) {
  return FUNDAMENTALS_URL + encodeURIComponent(symbol) + "?type=trailingMarketCap,trailingPeRatio,trailingDilutedEPS"
    + "&period1=" + (now - FUNDAMENTALS_DAYS * 24 * 60 * 60) + "&period2=" + now
}

// The latest dated value of one series: { value, date, currency }, or null.
function latestSnapshot(results, type) {
  var latest = null
  for (var i = 0; i < results.length; i++) {
    var meta = results[i] && results[i].meta
    if (!meta || !meta.type || meta.type[0] !== type) continue
    var series = results[i][type] || []
    for (var j = 0; j < series.length; j++) {
      var point = series[j]
      var value = point && point.reportedValue ? point.reportedValue.raw : null
      if (!Format.isFiniteNumber(value) || typeof point.asOfDate !== "string") continue
      if (!latest || point.asOfDate > latest.date)
        latest = { value: value, date: point.asOfDate, currency: point.currencyCode || "" }
    }
  }
  return latest
}

// Yahoo's latest cap and P/E, each with its own date; null when the answer
// is not a timeseries. The P/E stands only while the latest trailing diluted
// EPS is above zero: after a loss Yahoo publishes no new P/E, and its last
// one describes earnings that are gone.
function parseFundamentals(json) {
  var results = json && json.timeseries && json.timeseries.result
  if (!Array.isArray(results)) return null
  var cap = latestSnapshot(results, "trailingMarketCap")
  var pe = latestSnapshot(results, "trailingPeRatio")
  var eps = latestSnapshot(results, "trailingDilutedEPS")
  return {
    cap: cap && cap.value > 0 ? cap : null,
    pe: pe && pe.value > 0 && eps && eps.value > 0 ? { value: pe.value, date: pe.date } : null
  }
}

// "2026-09-23" as the epoch of its midnight, UTC.
function dateEpoch(date) {
  var parts = String(date || "").split("-")
  return Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])) / 1000
}

function snapshotDates(figures) {
  return [figures.cap, figures.pe].filter(function(s) { return !!s }).map(function(s) { return s.date }).sort()
}

// Each snapshot was taken at its date's close, so that close is what moves
// it with the price since. The daily bars around the snapshots' dates, with
// a week before for holidays; null when there is no snapshot.
function snapshotClosesUrl(symbol, figures) {
  var dates = snapshotDates(figures)
  if (!dates.length) return null
  return Quote.CHART_URL + encodeURIComponent(symbol) + "?interval=1d&period1=" + (dateEpoch(dates[0]) - 7 * 24 * 60 * 60)
    + "&period2=" + (dateEpoch(dates[dates.length - 1]) + 2 * 24 * 60 * 60)
}

// The figures with each snapshot's close: the last session's on or before
// its date, in the exchange's calendar. Null when the answer is not a chart
// or lacks a snapshot's close: no answer, so the feed keeps what it had.
function withSnapshotCloses(figures, json) {
  var result = json && json.chart && json.chart.result && json.chart.result[0]
  if (!result || !result.meta) return null
  var times = result.timestamp || []
  var bars = result.indicators && result.indicators.quote && result.indicators.quote[0]
  var closes = bars && bars.close ? bars.close : []
  var offset = result.meta.gmtoffset || 0
  var withClose = function(snapshot) {
    if (!snapshot) return null
    var close = null
    for (var i = 0; i < times.length; i++) {
      var day = new Date((times[i] + offset) * 1000).toISOString().slice(0, 10)
      if (day <= snapshot.date && Quote.knownPrice(closes[i]) !== null) close = closes[i]
    }
    return close === null ? null : Object.assign({}, snapshot, { close: close })
  }
  var cap = withClose(figures.cap)
  var pe = withClose(figures.pe)
  if ((figures.cap && !cap) || (figures.pe && !pe)) return null
  return { cap: cap, pe: pe }
}

function peText(value) {
  return value < 100 ? value.toFixed(1) : Format.grouped(String(Math.round(value)))
}

// The info block's second line, on every range: the cap, the P/E, and the
// 52-week range, each only when known. The cap and the P/E move with the
// headline price from their own date's close; a cap more than
// CAP_MAX_AGE_DAYS whole days older than the price is left out. The cap's
// currency is named only when it is not the price's (London prices in GBp,
// its caps in GBP).
function keyStatsText(quote, figures) {
  var q = quote || {}
  var head = quote ? Quote.headlineQuote(quote) : null
  var cap = figures ? figures.cap : null
  var pe = figures ? figures.pe : null
  var parts = []
  if (head && cap && Math.floor((head.t - dateEpoch(cap.date)) / (24 * 60 * 60)) <= CAP_MAX_AGE_DAYS)
    parts.push("MKT CAP " + (cap.currency && cap.currency !== q.currency ? cap.currency + " " : "")
      + Format.compactNumber(cap.value * head.price / cap.close))
  if (head && pe) parts.push("P/E " + peText(pe.value * head.price / pe.close))
  if (Format.isFiniteNumber(q.fiftyTwoWeekLow) && Format.isFiniteNumber(q.fiftyTwoWeekHigh))
    parts.push("52W " + Format.money(q.fiftyTwoWeekLow, q.priceDigits) + "–" + Format.money(q.fiftyTwoWeekHigh, q.priceDigits))
  return parts.join(" · ")
}
