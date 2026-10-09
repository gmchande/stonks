#!/usr/bin/env bash
# The real Service through migration, persist, and external edits, with the
# fake curl and a scratch HOME holding the bar entry; which symbols ask for a
# cap and P/E, once a day, keeping the last good on a failure; a data file
# that can't be read, never written over; and the version watch on the
# tree's copy of the manifest.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
feed_tree service.qml Service.qml Gate.qml Updates.qml QuoteFeed.qml HistoryFeed.qml FundamentalsFeed.qml AllDayFeed.qml OvernightFeed.qml Fetch.js Quote.js Format.js Market.js Overnight.js History.js Fundamentals.js Chart.js Settings.js calendars.json manifest.json
# The harness ages a fundamentals entry by a day.
patch_copy Service.qml '/readonly property var fundamentals:/a\  readonly property alias testFundamentalsFeed: fundamentalsFeed'
scratch_home shell-bar-only.json shell.json
run_qs 70
finish "ALL PASS"
