#!/usr/bin/env bash
#
# Quarto post-render hook: bake per-page SEO metadata into every rendered HTML
# page, and keep the sitemap's home entry in lockstep.
#
#   - <link rel="canonical"> (absolute URL)  -> fixes the Search Console error
#     "Duplicate without user-selected canonical": Google was torn between
#     https://host/ and https://host/index.html for the home page.
#   - <meta property="og:url"> (same URL)    -> Quarto 1.10 doesn't emit it, and
#     social-network scrapers read the STATIC HTML, so it must be baked in here.
#   - sitemap.xml home entry index.html -> / -> keeps canonical = og:url =
#     sitemap in lockstep on the home's clean root URL.
#
# URLs are ABSOLUTE (https://host/path) as Google requires for canonical. The
# home page (root index.html) canonicalises to the clean root "https://host/";
# every other page to its own ".html" URL.
#
# Defensive by design: never fails the build (always exits 0). perl -i is used
# (not sed -i) because its in-place syntax is identical on macOS and the Linux
# CI runner.
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

  # Page path relative to the output dir, then its absolute canonical URL. The
  # home (root index.html) and any directory index map to the clean dir URL.
  rel="${f##*/$OUT_BASE/}"
  case "$rel" in "$OUT_BASE"/*) rel="${rel#"$OUT_BASE"/}" ;; esac
  case "$rel" in
    index.html)   url="$BASE/" ;;
    */index.html) url="$BASE/${rel%index.html}" ;;
    *)            url="$BASE/$rel" ;;
  esac

  # Inject canonical + og:url after og:site_name (fallback: after og:image),
  # each only if absent. No-op if the page has no Open Graph block at all.
  JM_URL="$url" perl -0777 -i -pe '
    my $u = $ENV{JM_URL};
    my $ins = "";
    $ins .= qq{<link rel="canonical" href="$u">\n}       unless /rel="canonical"/;
    $ins .= qq{<meta property="og:url" content="$u">\n}   unless /property="og:url"/;
    if (length $ins) {
      s{(<meta property="og:site_name"[^>]*>\s*\n)}{$1$ins}
        or s{(<meta property="og:image"[^>]*>\s*\n)}{$1$ins};
    }
  ' "$f" 2>/dev/null || true
done

# Sitemap: drop every page that carries a robots noindex (buyer-only pages: welcome, download,
# open-in-jackmate). Keeping them in the sitemap would tell Google "index this" and "don't" at once.
# The list is derived from the rendered HTML, so a future noindex page needs only its meta tag.
# (Never block them in robots.txt: Google must be able to fetch the page to see the noindex.)
SM="$OUT_DIR/sitemap.xml"
if [ -f "$SM" ]; then
  printf '%s\n' "${QUARTO_PROJECT_OUTPUT_FILES:-}" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in *.html) ;; *) continue ;; esac
    grep -qiE '<meta[^>]+name="robots"[^>]+noindex' "$f" 2>/dev/null || continue
    rel="${f##*/$OUT_BASE/}"
    case "$rel" in "$OUT_BASE"/*) rel="${rel#"$OUT_BASE"/}" ;; esac
    JM_LOC="$BASE/$rel" perl -0777 -i -pe '
      my $l = quotemeta($ENV{JM_LOC});
      s{[ \t]*<url>\s*<loc>$l</loc>.*?</url>[ \t]*\n?}{}gs;
    ' "$SM" 2>/dev/null || true
  done
fi

# Sitemap: rewrite the home entry's <loc> from .../index.html to the clean root,
# so it matches the home canonical/og:url exactly.
if [ -f "$SM" ]; then
  JM_BASE="$BASE" perl -0777 -i -pe '
    my $b = quotemeta($ENV{JM_BASE});
    s{<loc>$b/index\.html</loc>}{<loc>$ENV{JM_BASE}/</loc>}g;
  ' "$SM" 2>/dev/null || true
fi

exit 0
