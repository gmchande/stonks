#!/usr/bin/env bash
# Renders StonksBody offscreen from fixtures. Quickshell only loads QML from
# inside its config folder, so a temporary one is assembled from copies.
# Usage: test/qml/render.sh [state ...]
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
out="${STONKS_VISUAL_DIR:-$plugin/out/render}"
mkdir -p "$out"
plugin_tree render.qml
# The pill sheet's pills load no popup: the offscreen platform has no popup
# window to put one in, and no render shows one.
patch_copy plugin/BarWidget.qml '/id: panelLoader/,/source:/s/active: true/active: false/'

export QT_QPA_PLATFORM=offscreen
export STONKS_VISUAL_CALENDARS="$plugin/calendars.json"

states=${*:-window-help-smooth window-help-retro popup-help-smooth popup-help-retro popup-help-sorted-smooth popup-help-sorted-retro popup-holiday-retro popup-price4-solo-smooth popup-price4-solo-retro popup-price5-stack-smooth popup-price5-stack-retro popup-nbis-1d-smooth popup-nbis-1d-retro popup-history-failed popup-history-loading popup-history-1w-smooth popup-history-1w-retro popup-history-1m-smooth popup-history-1m-retro popup-history-1y-smooth popup-history-1y-retro popup-history-all-smooth popup-history-all-retro loading failed aged history-scrub history-empty-loading history-sparse sprite-candidates popup-search-smooth popup-search-retro popup-search-stale-smooth popup-search-none-smooth popup-search-failed-retro popup-search-preview-smooth popup-search-preview-retro popup-search-show-smooth popup-search-show-retro min-window-smooth min-window-retro min-window-search-smooth w22-popup-smooth-aapl-1d w22-popup-retro-aapl-1d w22-window-smooth-aapl-1d w22-window-retro-aapl-1d w22-popup-smooth-aapl-5y w22-popup-retro-aapl-5y w22-window-smooth-aapl-5y w22-window-retro-aapl-5y w22-popup-smooth-spy-1d w22-popup-retro-spy-1d w22-window-smooth-spy-1d w22-window-retro-spy-1d w22-popup-smooth-shop-1d w22-popup-retro-shop-1d w22-window-smooth-shop-1d w22-window-retro-shop-1d w22-popup-smooth-shop-1y w22-popup-retro-shop-1y w22-window-smooth-shop-1y w22-window-retro-shop-1y w22-popup-smooth-mu-1d w22-popup-retro-mu-1d w22-window-smooth-mu-1d w22-window-retro-mu-1d window-1416-smooth popup-waiting-smooth popup-rowstates-smooth popup-rowstates-retro popup-note-smooth popup-hint-smooth popup-hint-retro popup-notice-file-smooth popup-notice-file-retro popup-notice-update-smooth popup-notice-update-retro popup-lists-menu-retro popup-lists-named-smooth popup-lists-empty-smooth popup-lists-empty-retro popup-lists-long-retro popup-lists-manage-smooth popup-lists-manage-retro popup-lists-symbol-smooth popup-lists-symbol-retro popup-lists-rename-smooth popup-lists-confirm-retro window-lists-manage-smooth window-lists-symbol-retro popup-rowlines-smooth popup-rowlines-retro popup-52w-smooth popup-52w-retro popup-breadth-even-smooth popup-breadth-even-retro popup-order-falls-smooth popup-order-rises-smooth popup-order-falls-retro popup-order-rises-retro window-order-falls-smooth window-order-rises-smooth window-order-falls-retro window-order-rises-retro popup-overnight-night-nbis-smooth popup-overnight-night-nbis-retro popup-overnight-night-snow-smooth popup-overnight-night-snow-retro popup-overnight-night-rvii-retro popup-overnight-day-nbis-smooth popup-overnight-day-nbis-retro popup-overnight-sunday-nbis-smooth popup-overnight-sunday-nbis-retro popup-overnight-live-et-smooth popup-overnight-live-et-retro popup-overnight-live-tln-smooth popup-overnight-live-tln-retro popup-overnight-live-nbis-1m-smooth popup-overnight-live-nbis-1m-retro popup-overnight-live-nbis-1m-scrub-smooth popup-overnight-live-nbis-1m-scrub-retro popup-overnight-2026-10-07-1153-nbis-smooth popup-overnight-2026-10-07-1153-nbis-retro popup-overnight-2026-10-06-1800-nbis-smooth popup-overnight-2026-10-06-2300-nbis-retro popup-overnight-2026-10-07-0005-nbis-smooth popup-overnight-2026-10-07-0005-nbis-retro popup-overnight-2026-10-07-0100-nbis-smooth popup-overnight-2026-10-07-0100-nbis-scrub-smooth popup-overnight-2026-10-07-0100-nbis-scrub-retro popup-overnight-2026-10-07-0600-nbis-retro popup-overnight-2026-10-03-1200-nbis-smooth popup-overnight-2026-10-04-2230-nbis-retro popup-fill-up-smooth popup-fill-down-smooth popup-fill-cross-smooth popup-fill-up-retro popup-fill-down-retro popup-fill-cross-retro popup-fill-up-smooth-kanagawa popup-fill-down-smooth-kanagawa popup-fill-cross-smooth-kanagawa popup-fill-up-retro-kanagawa popup-fill-down-retro-kanagawa popup-fill-cross-retro-kanagawa pill-sheet fetch-saved-smooth fetch-saved-retro fetch-overdue-smooth fetch-overdue-retro}
# The listing sweep (CONTRIBUTING.md, Verify it): every kind of listing on 1D at
# each of its moments, in both looks.
if [ $# -eq 0 ]; then
  for moment in 2026-10-07-1455 2026-10-07-0100 2026-10-07-0600 2026-10-03-1200; do
    for symbol in nbis psix spy bldp gspc btc-usd shel.l 7203.t; do
      states="$states popup-sweep-$moment-$symbol-smooth popup-sweep-$moment-$symbol-retro"
    done
  done
  # The look sweep's new listings in session, 8 October 10:54: a coin under
  # a cent, Toronto, a six-figure price, and a long symbol. `render.sh
  # popup-sweep-<moment>-<symbol>-<look>` renders any saved moment.
  for symbol in shib-usd ry.to brk-a brk-b; do
    states="$states popup-sweep-2026-10-08-1054-$symbol-smooth popup-sweep-2026-10-08-1054-$symbol-retro"
  done
  # The header's animal: a cold start in smooth too, and the window on an up,
  # a down, and a flat day, and a cryptocurrency, in both looks.
  states="$states loading-smooth failed-smooth"
  for day in 2026-10-07-1455-psix 2026-10-07-1455-nbis 2026-10-07-0100-bldp 2026-10-07-1455-btc-usd; do
    states="$states window-sweep-$day-smooth window-sweep-$day-retro"
  done
  # The footer's notes in both looks and both surfaces: a refusal, and a
  # removal's offer from a long list name, under the first visit's hint too.
  for look in smooth retro; do
    states="$states popup-note-undo-$look window-note-undo-$look popup-hint-undo-$look"
  done
  states="$states popup-note-retro"
  # The theme gallery: Omarchy's default, a light theme whose green is under
  # 3:1, and two where up falls back to the foreground. `render.sh
  # theme-<look>-<theme>` renders any other installed theme.
  for theme in tokyo-night catppuccin-latte hackerman white; do
    states="$states theme-smooth-$theme theme-retro-$theme"
  done
  # The pill at a larger text size, as `omarchy display text size 16` sets it.
  states="$states pill-sheet-large"
fi
# Every render is in an installed Omarchy theme: the one the state's name
# ends with (popup-fill-up-smooth-kanagawa, theme-retro-white), else Tokyo
# Night, the theme a fresh Omarchy install sets. It goes where the shell
# reads the current theme, so the shell's Color and the plugin's
# TrendColors both read it as they do on the desktop. A state ending -large
# has the shell's text size at 16 rather than 12.
themes=$(ls /usr/share/omarchy/themes | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2-)
theme_dir="$HOME/.local/state/omarchy/current"
mkdir -p "$theme_dir"
for state in $states; do
  dest="$out/$state.png"
  shot="$work/$state.png"
  theme=tokyo-night
  for t in $themes; do [[ $state == *-"$t" ]] && { theme=$t; break; }; done
  ln -sfn "/usr/share/omarchy/themes/$theme" "$theme_dir/theme"
  if [[ $state == *-large ]]; then printf '[font]\nbase-size = 16\n' > "$HOME/.config/omarchy/shell.toml"
  else rm -f "$HOME/.config/omarchy/shell.toml"; fi
  echo "render $state ($theme) -> $dest"
  # render.qml ignores whether the save worked and exits 0 anyway, so only a
  # picture this run wrote counts. It is judged in this run's own folder,
  # where no other run's picture can stand in for it, then moved to $out.
  rm -f "$dest"
  STONKS_VISUAL_STATE="$state" STONKS_VISUAL_OUT="$shot" quickshell_run 15 "$work/$state.log" -p "$root"
  code=$qs_code
  # A state whose QML threw still writes a picture; the log is what tells,
  # and so is a Qt warning from the plugin's files (lib.sh).
  warnings=$(stonks_warnings "$work/$state.log")
  if [[ $code -ne 0 || ! -s $shot || -n $warnings ]] || rg -q 'TypeError|ReferenceError|\bError:' "$work/$state.log"; then
    echo "FAIL $state (exit $code)"
    rg 'ERROR|error:|TypeError|ReferenceError|\bError:' "$work/$state.log" | head -30 || true
    [[ -n $warnings ]] && echo "Qt warnings from the plugin's files:" && head -30 <<< "$warnings"
    tail -20 "$work/$state.log"
    exit 1
  fi
  echo "OK $state ($(wc -c < "$shot") bytes)"
  mv "$shot" "$dest"
done
