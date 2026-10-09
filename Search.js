.import "Quote.js" as Quote

// Yahoo's symbol lookup: its URL and its answer. Knows nothing else.

var SEARCH_URL = "https://query2.finance.yahoo.com/v1/finance/search"

function searchUrl(query) {
  return SEARCH_URL + "?q=" + encodeURIComponent(query) + "&quotesCount=8&newsCount=0"
}

function parseSearch(json) {
  var quotes = (json && json.quotes) || []
  var out = []
  for (var i = 0; i < quotes.length; i++) {
    var q = quotes[i]
    if (!q.symbol) continue
    if (q.quoteType && q.quoteType !== "EQUITY" && q.quoteType !== "ETF" && q.quoteType !== "INDEX" && q.quoteType !== "CRYPTOCURRENCY") continue
    out.push({ symbol: q.symbol, name: searchName(q), exchange: Quote.EXCHANGE_NAMES[q.exchange] || String(q.exchange || "").toUpperCase() })
  }
  return out
}

// Yahoo's short name is cut at 31 characters ("…Tesla Daily Targe"), and a
// German listing's pads a share-class letter onto the end ("…UCITS ETF    R",
// R for registered shares). The long name is the whole name, so the row's
// own ellipsis is the only cut; the short name, without that letter, is the
// fallback.
function searchName(q) {
  if (q.longname) return q.longname
  if (q.shortname) return String(q.shortname).replace(/\s{2,}[A-Z]$/, "").trim()
  return q.symbol
}
