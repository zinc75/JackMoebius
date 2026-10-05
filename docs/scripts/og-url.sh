#!/usr/bin/env bash
#
# Quarto post-render hook: inject a per-page <meta property="og:url"> into every
# rendered HTML page.
#
# Why: Quarto (1.10) emits og:title/description/image/site_name but NOT og:url.
# Social-network link scrapers read the *static* HTML (they don't run JS), so the
# tag must be baked in at render time — which is exactly what a post-render script
# does, both locally and in CI.
#
# Defensive by design: this must never fail the build. Every step is guarded and
# the script always exits 0. perl -i is used (not sed -i) because its in-place
# syntax is identical on macOS and Linux (the CI runner).
#
# Env provided by Quarto: QUARTO_PROJECT_OUTPUT_DIR, QUARTO_PROJECT_OUTPUT_FILES.

set -u

OUT_DIR="${QUARTO_PROJECT_OUTPUT_DIR:-_site}"
OUT_BASE="$(basename "$OUT_DIR")"

# Base URL from _quarto.yml site-url (single source of truth), trailing slash
# stripped. Falls back to the known domain if parsing ever fails.
BASE="$(sed -nE 's/^[[:space:]]*site-url:[[:space:]]*([^[:space:]#]+).*/\1/p' _quarto.yml 2>/dev/null | head -1)"
BASE="${BASE:-https://jackmoebius.io}"
BASE="${BASE%/}"

printf '%s\n' "${QUARTO_PROJECT_OUTPUT_FILES:-}" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *.html) ;; *) continue ;; esac
  [ -f "$f" ] || continue

  # Path of this page relative to the output dir (handles both absolute paths and
  # paths relative to the project dir), then build the page URL. Keep the ".html"
  # so og:url matches what the sitemap advertises.
  rel="${f##*/$OUT_BASE/}"
  case "$rel" in "$OUT_BASE"/*) rel="${rel#"$OUT_BASE"/}" ;; esac
  url="$BASE/$rel"

  # Insert og:url right after og:site_name (fallback: after og:image). No-op if a
  # og:url is already present, or if the page has no Open Graph block at all.
  OG_URL="$url" perl -0777 -i -pe '
    my $u = $ENV{OG_URL};
    unless (/property="og:url"/) {
      my $tag = qq{<meta property="og:url" content="$u">\n};
      s{(<meta property="og:site_name"[^>]*>\s*\n)}{$1$tag}
        or s{(<meta property="og:image"[^>]*>\s*\n)}{$1$tag};
    }
  ' "$f" 2>/dev/null || true
done

exit 0
