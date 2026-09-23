-- easycarousel: turn simple blocks of images (or any content) into an
-- Embla-powered carousel
--
-- Syntaxes:
--
-- 1. A fenced block of markdown images:
--
--    ```carousel
--    ![](one.png)
--    ![](two.png)
--    ```
--
--    Use `{.carousel key="value"}` to pass options.
--
-- 2. An executable cell whose plots should become a carousel:
--
--    ```{r}
--    #| classes: carousel
--    plot(mpg ~ disp)
--    plot(mpg ~ hp)
--    ```
--
-- 3. A div: ::: {.carousel}. Each top-level block becomes a slide, so
--    slides can hold tables, code, or mixed content; group multi-block
--    slides with nested divs.
--
-- Options (attributes on the fenced block or div; project-wide defaults can
-- be set under the `easycarousel` metadata key):
--   autoplay   ms between auto-advances; unset means no autoplay
--   dots       "false" to hide the dot indicators
--   arrows     "false" to hide the prev/next arrows
--   fade       "true" for crossfade instead of slide
--   loop       "false" to stop at the ends instead of cycling
--   slides     number of slides visible at once (default 1)
--   slides-sm/-md/-lg/-xl  slides per view from 576/768/992/1200px up
--   gap        space between slides, any CSS length (default "1rem")
--   align      snap alignment: "center" (default), "start", or "end"
--   thumbs     "true" for a synced thumbnail strip below the carousel
--   vertical   "true" for a vertical carousel
--   height     viewport height for vertical carousels (default "20rem");
--              for horizontal carousels, caps slide image height instead
--              (e.g. to keep reveal.js slides from growing too tall)
--   drag-free  "true" for momentum scrolling without snapping
--   lazy       "true" to add loading="lazy" to slide images
--   effect     "scale", "opacity", "parallax", or "coverflow" (a 3D stack
--              where neighbouring slides recede behind the active one)
--   lightbox   "true" to make slide images open in Quarto's lightbox
--   caption    figure caption; with an id like #fig-x enables crossrefs
--   compare    "true" + exactly 2 images = a before/after comparison slider
--   marquee    "true" for a continuously scrolling strip (a logo ticker):
--              no arrows, dots, or dragging, just a CSS animation that
--              never stops. Tuned with these options:
--   speed      seconds for one full loop of a marquee (default "40s")
--   direction  marquee scroll direction: "left" (default) or "right"
--   pause      "false" to keep a marquee scrolling on hover
--   edges      "false" to drop a marquee's faded left/right edges
--   fragment   reveal.js only: step through slides as fragments
--              (default true in reveal.js)

local counter = 0
local deps_added = false
local defaults = {}

local option_names = {
  "autoplay", "interval", "dots", "indicators", "arrows", "controls",
  "fade", "loop", "wrap", "slides", "slides-sm", "slides-md", "slides-lg",
  "slides-xl", "gap", "align", "thumbs", "vertical", "height", "drag-free",
  "lazy", "effect", "lightbox", "fragment", "compare", "marquee", "speed",
  "direction", "pause", "edges"
}

local function read_meta(meta)
  local ec = meta["easycarousel"]
  if type(ec) == "table" then
    for _, name in ipairs(option_names) do
      if ec[name] ~= nil then
        defaults[name] = pandoc.utils.stringify(ec[name])
      end
    end
  end
end

local function ensure_deps()
  if deps_added or not quarto.doc.is_format("html:js") then
    return
  end
  deps_added = true
  quarto.doc.add_html_dependency({
    name = "easycarousel",
    version = "0.1.0",
    scripts = {
      "embla-carousel.umd.js",
      "embla-carousel-autoplay.umd.js",
      "embla-carousel-fade.umd.js",
      "easycarousel.js"
    },
    stylesheets = { "easycarousel.css" }
  })
end

local function truthy(value, default)
  if value == nil then
    return default
  end
  return value ~= "false" and value ~= "no"
end

local function attrs_table(attributes)
  local t = {}
  for k, v in pairs(attributes) do
    t[k] = v
  end
  for k, v in pairs(defaults) do
    if t[k] == nil then
      t[k] = v
    end
  end
  return t
end

-- Flatten Quarto cell wrappers so each output display counts as a slide
-- candidate, and drop the echoed source code from executable cells.
local function flatten(blocks, out)
  out = out or {}
  for _, b in ipairs(blocks) do
    if b.t == "Div" and (b.classes:includes("cell") or
        b.classes:includes("cell-output-display") or
        b.classes:includes("cell-output")) then
      flatten(b.content, out)
    elseif b.classes ~= nil and b.classes:includes("cell-code") then
      -- skip echoed source
    else
      table.insert(out, b)
    end
  end
  return out
end

-- true when the block is images and whitespace only
local function images_only(b)
  if b.t ~= "Para" and b.t ~= "Plain" then
    return b.t == "Figure"
  end
  local stripped = b:walk({ Image = function() return {} end })
  return pandoc.utils.stringify(stripped):gsub("%s+", "") == ""
end

-- A slide is either {image = Image, caption = string} or {block = Block}
local function build_slides(blocks)
  local slides = {}
  for _, b in ipairs(flatten(blocks)) do
    local images = {}
    b:walk({ Image = function(img) table.insert(images, img) end })
    if #images > 0 and images_only(b) then
      for _, img in ipairs(images) do
        table.insert(slides, {
          image = img,
          caption = pandoc.utils.stringify(img.caption)
        })
      end
    else
      table.insert(slides, { block = b })
    end
  end
  return slides
end

local function build_options(attrs)
  local autoplay = attrs["autoplay"] or attrs["interval"]
  local breakpoints = {}
  local has_breakpoints = false
  for suffix, width in pairs({ sm = 576, md = 768, lg = 992, xl = 1200 }) do
    local n = tonumber(attrs["slides-" .. suffix])
    if n then
      breakpoints[tostring(width)] = n
      has_breakpoints = true
    end
  end
  return {
    autoplay = autoplay and tonumber(autoplay) or false,
    dots = truthy(attrs["dots"] or attrs["indicators"], true),
    arrows = truthy(attrs["arrows"] or attrs["controls"], true),
    fade = truthy(attrs["fade"], false),
    loop = truthy(attrs["loop"] or attrs["wrap"], true),
    align = attrs["align"] or "center",
    thumbs = truthy(attrs["thumbs"], false),
    vertical = truthy(attrs["vertical"], false),
    dragFree = truthy(attrs["drag-free"], false),
    effect = attrs["effect"] or false,
    slides = tonumber(attrs["slides"]) or 1,
    breakpoints = has_breakpoints and breakpoints or false,
    fragment = truthy(attrs["fragment"], quarto.doc.is_format("revealjs"))
  }
end

local function build_compare(images, id)
  local blocks = pandoc.Blocks({})
  blocks:insert(pandoc.RawBlock("html", string.format(
    '<div id="%s" class="easycarousel-compare" role="group" ' ..
    'aria-roledescription="comparison slider">\n' ..
    '<div class="easycarousel-compare__before">', id)))
  blocks:insert(pandoc.Plain({ images[1] }))
  blocks:insert(pandoc.RawBlock("html",
    '</div>\n<div class="easycarousel-compare__after">'))
  blocks:insert(pandoc.Plain({ images[2] }))
  blocks:insert(pandoc.RawBlock("html", '</div>\n</div>'))
  return blocks
end

-- A marquee is a plain CSS animation rather than an Embla carousel: the
-- slides are emitted twice side by side and the track is translated by half
-- its width, so the second copy lands exactly where the first started and the
-- loop is seamless. The duplicate is aria-hidden, since it is the same content.
local function build_marquee(slides, attrs, id)
  local gap = attrs["gap"] or "1rem"
  local height = attrs["height"] or "4rem"
  local speed = attrs["speed"] or "40s"
  if tonumber(speed) then
    speed = speed .. "s"
  end
  local lazy = truthy(attrs["lazy"], false)
  local lightbox = truthy(attrs["lightbox"], false)

  local variant = ""
  if attrs["direction"] == "right" then
    variant = variant .. " easycarousel-marquee--reverse"
  end
  if truthy(attrs["pause"], true) then
    variant = variant .. " easycarousel-marquee--pause"
  end
  if not truthy(attrs["edges"], true) then
    variant = variant .. " easycarousel-marquee--no-fade"
  end

  local blocks = pandoc.Blocks({})
  blocks:insert(pandoc.RawBlock("html", string.format(
    '<div id="%s" class="easycarousel-marquee%s" role="group" ' ..
    'aria-roledescription="scrolling strip" ' ..
    'style="--ec-gap: %s; --ec-marquee-height: %s; --ec-marquee-speed: %s;">\n' ..
    '<div class="easycarousel-marquee__track">',
    id, variant, gap, height, speed)))

  for copy = 1, 2 do
    blocks:insert(pandoc.RawBlock("html", string.format(
      '<div class="easycarousel-marquee__group"%s>',
      copy == 2 and ' aria-hidden="true"' or "")))
    for _, slide in ipairs(slides) do
      blocks:insert(pandoc.RawBlock("html",
        '<div class="easycarousel-marquee__item">'))
      if slide.image then
        local img = slide.image:clone()
        if lazy then
          img.attributes["loading"] = "lazy"
        end
        -- the copy is decorative, so it gets neither an id nor a lightbox
        -- link that would show up twice in the gallery
        if copy == 2 then
          img.identifier = ""
        elseif lightbox then
          img.classes:insert("lightbox")
        end
        blocks:insert(pandoc.Plain({ img }))
      else
        blocks:insert(slide.block:clone())
      end
      blocks:insert(pandoc.RawBlock("html", '</div>'))
    end
    blocks:insert(pandoc.RawBlock("html", '</div>'))
  end

  blocks:insert(pandoc.RawBlock("html", '</div>\n</div>'))
  return blocks
end

local function build_carousel(slides, attrs, id)
  local opts = build_options(attrs)
  local gap = attrs["gap"] or "1rem"
  local height = attrs["height"] or "20rem"
  local lazy = truthy(attrs["lazy"], false)
  local lightbox = truthy(attrs["lightbox"], false)

  local style = string.format("--ec-slides: %d; --ec-gap: %s;", opts.slides, gap)
  if opts.vertical then
    style = style .. string.format(" --ec-height: %s;", height)
  elseif attrs["height"] then
    style = style .. string.format(" --ec-img-max-height: %s;", height)
  end

  local variant = ""
  if opts.vertical then
    variant = variant .. " easycarousel--vertical"
  end
  if opts.effect == "coverflow" then
    variant = variant .. " easycarousel--coverflow"
  end

  local blocks = pandoc.Blocks({})
  blocks:insert(pandoc.RawBlock("html", string.format(
    '<div id="%s" class="easycarousel%s" role="region" ' ..
    'aria-roledescription="carousel" data-options="%s" style="%s">\n' ..
    '<div class="easycarousel__viewport" tabindex="0">\n' ..
    '<div class="easycarousel__container">',
    id,
    variant,
    quarto.json.encode(opts):gsub('"', "&quot;"),
    style)))

  for i, slide in ipairs(slides) do
    blocks:insert(pandoc.RawBlock("html", string.format(
      '<div class="easycarousel__slide%s" role="group" ' ..
      'aria-roledescription="slide" aria-label="%d of %d">',
      slide.image and "" or " easycarousel__slide--content",
      i, #slides)))
    if slide.image then
      if lazy then
        slide.image.attributes["loading"] = "lazy"
      end
      if lightbox then
        slide.image.classes:insert("lightbox")
      end
      blocks:insert(pandoc.Plain({ slide.image }))
      if slide.caption ~= "" then
        blocks:insert(pandoc.RawBlock("html",
          '<div class="easycarousel__caption">' .. slide.caption .. '</div>'))
      end
    else
      blocks:insert(slide.block)
    end
    blocks:insert(pandoc.RawBlock("html", '</div>'))
  end

  blocks:insert(pandoc.RawBlock("html", '</div>\n</div>'))

  -- reveal.js fragments: one hidden step per advance; the JS wires
  -- fragmentshown/fragmenthidden to the carousel
  if opts.fragment and quarto.doc.is_format("revealjs") and #slides > 1 then
    local steps = {}
    for _ = 2, #slides do
      table.insert(steps, '<span class="fragment easycarousel__step"></span>')
    end
    blocks:insert(pandoc.RawBlock("html", table.concat(steps, "\n")))
  end

  blocks:insert(pandoc.RawBlock("html", '</div>'))
  return blocks
end

local function fallback(slides)
  -- non-HTML formats: stack the slides vertically
  local blocks = pandoc.Blocks({})
  for _, slide in ipairs(slides) do
    if slide.image then
      blocks:insert(pandoc.Para({ slide.image }))
    else
      blocks:insert(slide.block)
    end
  end
  return blocks
end

local function render(blocks, attrs, identifier)
  local slides = build_slides(blocks)
  if #slides == 0 then
    return nil
  end

  local result
  if not quarto.doc.is_format("html:js") then
    result = fallback(slides)
  else
    ensure_deps()
    counter = counter + 1
    local id = "easycarousel-" .. counter
    local images = {}
    for _, slide in ipairs(slides) do
      if slide.image then
        table.insert(images, slide.image)
      end
    end
    if truthy(attrs["marquee"], false) then
      result = build_marquee(slides, attrs, id)
    elseif truthy(attrs["compare"], false) and #images == 2 then
      result = build_compare(images, id)
    else
      result = build_carousel(slides, attrs, id)
    end
  end

  -- crossref support: an id like #fig-x (plus a caption) wraps the
  -- carousel in a Figure so @fig-x references work
  local caption_text = attrs["caption"] or attrs["fig-cap"]
  if identifier and identifier:match("^fig%-") and caption_text then
    return quarto.FloatRefTarget({
      identifier = identifier,
      type = "Figure",
      content = result,
      caption_long = pandoc.read(caption_text, "markdown").blocks
    })
  end
  return result
end

function CodeBlock(el)
  if not el.classes:includes("carousel") then
    return nil
  end
  local parsed = pandoc.read(el.text, "markdown").blocks
  return render(parsed, attrs_table(el.attributes), el.identifier)
end

function Div(el)
  if not el.classes:includes("carousel") then
    return nil
  end
  return render(el.content, attrs_table(el.attributes), el.identifier)
end

return {
  { Meta = read_meta },
  { CodeBlock = CodeBlock, Div = Div }
}
