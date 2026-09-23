/* easycarousel: initialize Embla on every .easycarousel element */
(function () {
  "use strict";

  var reducedMotion =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* reveal.js PDF export (?print-pdf): show every slide in a static grid
     instead of initializing the carousel, so handouts have all content */
  var printMode = /print-pdf/gi.test(window.location.search);

  function makeButton(className, label, svgPath) {
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = className;
    btn.setAttribute("aria-label", label);
    btn.innerHTML =
      '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" d="' +
      svgPath + '"/></svg>';
    return btn;
  }

  function addArrows(root, embla, vertical) {
    var prev = makeButton(
      "easycarousel__arrow easycarousel__arrow--prev",
      "Previous slide",
      vertical ? "M6 14l6-6 6 6" : "M14 6l-6 6 6 6");
    var next = makeButton(
      "easycarousel__arrow easycarousel__arrow--next",
      "Next slide",
      vertical ? "M6 10l6 6 6-6" : "M10 6l6 6-6 6");
    prev.addEventListener("click", function () { embla.scrollPrev(); });
    next.addEventListener("click", function () { embla.scrollNext(); });
    root.appendChild(prev);
    root.appendChild(next);

    function update() {
      prev.disabled = !embla.canScrollPrev();
      next.disabled = !embla.canScrollNext();
    }
    embla.on("select", update).on("reInit", update);
    update();
  }

  function addDots(root, embla) {
    var wrap = document.createElement("div");
    wrap.className = "easycarousel__dots";
    root.appendChild(wrap);
    var dots = [];

    function build() {
      wrap.innerHTML = "";
      dots = embla.scrollSnapList().map(function (_, i) {
        var dot = document.createElement("button");
        dot.type = "button";
        dot.className = "easycarousel__dot";
        dot.setAttribute("aria-label", "Go to slide " + (i + 1));
        dot.addEventListener("click", function () { embla.scrollTo(i); });
        wrap.appendChild(dot);
        return dot;
      });
    }

    function update() {
      var selected = embla.selectedScrollSnap();
      dots.forEach(function (dot, i) {
        dot.classList.toggle("easycarousel__dot--selected", i === selected);
      });
    }

    build();
    update();
    embla.on("select", update).on("reInit", function () { build(); update(); });
  }

  function addThumbs(root, embla) {
    var images = root.querySelectorAll(".easycarousel__slide img");
    if (!images.length) return;

    var thumbsRoot = document.createElement("div");
    thumbsRoot.className = "easycarousel__thumbs";
    var container = document.createElement("div");
    container.className = "easycarousel__thumbs-container";
    thumbsRoot.appendChild(container);
    root.appendChild(thumbsRoot);

    var thumbs = Array.prototype.map.call(images, function (img, i) {
      var btn = document.createElement("button");
      btn.type = "button";
      btn.className = "easycarousel__thumb";
      btn.setAttribute("aria-label", "Go to slide " + (i + 1));
      var copy = img.cloneNode(false);
      copy.removeAttribute("id");
      copy.classList.remove("lightbox");
      btn.appendChild(copy);
      container.appendChild(btn);
      btn.addEventListener("click", function () { embla.scrollTo(i); });
      return btn;
    });

    var thumbsEmbla = EmblaCarousel(thumbsRoot, {
      containScroll: "keepSnaps",
      dragFree: true
    });

    function update() {
      var selected = embla.selectedScrollSnap();
      thumbs.forEach(function (thumb, i) {
        thumb.classList.toggle("easycarousel__thumb--selected", i === selected);
      });
      thumbsEmbla.scrollTo(selected);
    }
    embla.on("select", update).on("reInit", update);
    update();
  }

  function addKeyboard(viewport, embla, vertical) {
    var prevKey = vertical ? "ArrowUp" : "ArrowLeft";
    var nextKey = vertical ? "ArrowDown" : "ArrowRight";
    viewport.addEventListener("keydown", function (e) {
      if (e.key !== prevKey && e.key !== nextKey) return;
      e.preventDefault();
      e.stopPropagation();
      if (e.key === prevKey) embla.scrollPrev();
      else embla.scrollNext();
    });
  }

  /* how many slides to either side of the active one stay visible in the
     coverflow stack; past this the card is faded out */
  var COVERFLOW_VISIBILITY = 2;

  /* 3D coverflow: distance from the active slide, measured in slides, drives
     one transform (rotate + squash + push back + pull toward the middle) plus
     a blur ramp, so the stack recedes behind the active card. Lengths are
     derived from the slide width, keeping the look size-independent. */
  function coverflow(slide, distance, perspective, physical) {
    // `distance` is the wrapped (shortest-path) distance from the active slide,
    // used for every visual (rotation, fan, depth). `physical` is the slide's
    // real, un-wrapped offset from centre (in slide-widths): the tween overwrites
    // Embla's own per-slide loop transform, so a slide that should wrap to the
    // near side still sits at its far layout position — the shift must cancel
    // THAT (physical), not the wrapped distance, or wrapped cards land off-screen.
    if (physical === undefined) physical = distance;
    var abs = Math.min(Math.abs(distance), COVERFLOW_VISIBILITY);
    var dir = Math.sign(distance);
    var ramp = abs / 3;
    var width = slide.offsetWidth || 1;

    // pushing the card back also shrinks it by this factor once the viewport's
    // perspective is applied
    var depth = ramp * width * 1.3;
    var shrink = perspective / (perspective + depth);
    // slides sit a full width apart in the flex track, so translateX has to
    // undo that layout offset before placing the card where we want it: a
    // compressed fan, so further cards stack up rather than march off-screen
    var target = dir * width * 0.5 * Math.pow(abs, 0.4);
    var shift = target / shrink - physical * width;

    // Per-slide perspective(): each card renders its own 3D locally, without the
    // parent perspective + preserve-3d that Safari flattens through a flex container.
    slide.style.transform =
      "perspective(" + perspective.toFixed(2) + "px) " +
      "translateX(" + shift.toFixed(2) + "px) " +
      "rotateY(" + (-distance / 3 * 50).toFixed(3) + "deg) " +
      "scaleY(" + (1 - ramp * 0.15).toFixed(4) + ") " +
      "translateZ(" + (-depth).toFixed(2) + "px)";
    slide.style.filter =
      "blur(" + (ramp * width * 0.02).toFixed(2) + "px) " +
      "brightness(" + (1 - ramp * 0.35).toFixed(3) + ") " +
      "drop-shadow(0 " + (2 + ramp * 6).toFixed(1) + "px " +
      (6 + ramp * 12).toFixed(1) + "px rgba(0, 0, 0, 0.35))";
    slide.style.opacity = abs >= COVERFLOW_VISIBILITY ? "0" : "1";
    slide.style.zIndex = String(Math.round(100 - abs * 10));
    slide.style.pointerEvents = abs < 0.5 ? "auto" : "none";
    slide.style.setProperty("--ec-active", abs < 0.5 ? "1" : "0");
  }

  /* scroll-linked effects: scale, opacity, parallax, coverflow */
  function addTween(embla, kind, loop) {
    var factor = { scale: 3, opacity: 2, parallax: 1, coverflow: 1 }[kind];
    var perspective = 0;

    // keep the vanishing point proportional to the card, so the effect looks
    // the same at every carousel size
    function setPerspective() {
      var first = embla.slideNodes()[0];
      perspective = (first ? first.offsetWidth : 500) * 1.4;
      embla.rootNode().style.perspective = perspective.toFixed(2) + "px";
    }

    function apply() {
      var progress = embla.scrollProgress();
      var snaps = embla.scrollSnapList();
      var slides = embla.slideNodes();
      // snaps are evenly spaced, so a progress delta converts to a distance
      // measured in slides
      var step = snaps.length > 1 ? Math.abs(snaps[1] - snaps[0]) : 1;
      snaps.forEach(function (snap, i) {
        var rawDiff = snap - progress;   // un-wrapped: the slide's real position
        var diff = rawDiff;
        if (loop) {
          // shortest distance around the loop
          if (diff > 0.5) diff -= 1;
          if (diff < -0.5) diff += 1;
        }
        var t = Math.max(0, 1 - Math.abs(diff) * factor);
        var slide = slides[i];
        if (!slide) return;
        if (kind === "coverflow") {
          coverflow(slide, step ? diff / step : 0, perspective, step ? rawDiff / step : 0);
        } else if (kind === "scale") {
          slide.style.transform = "scale(" + (0.85 + 0.15 * t).toFixed(4) + ")";
        } else if (kind === "opacity") {
          slide.style.opacity = (0.25 + 0.75 * t).toFixed(4);
        } else if (kind === "parallax") {
          var img = slide.querySelector("img");
          if (img) {
            img.style.transform =
              "translateX(" + (diff * 30).toFixed(3) + "%) scale(1.3)";
          }
        }
      });
    }

    embla.on("scroll", apply).on("select", apply).on("reInit", function () {
      if (kind === "coverflow") setPerspective();
      apply();
    });
    if (kind === "coverflow") setPerspective();
    apply();
  }

  function addBreakpoints(root, embla, base, breakpoints) {
    var queries = Object.keys(breakpoints).map(function (width) {
      return {
        mq: window.matchMedia("(min-width: " + width + "px)"),
        width: parseInt(width, 10),
        slides: breakpoints[width]
      };
    }).sort(function (a, b) { return a.width - b.width; });

    function apply() {
      var slides = base;
      queries.forEach(function (q) {
        if (q.mq.matches) slides = q.slides;
      });
      root.style.setProperty("--ec-slides", slides);
      embla.reInit();
    }

    queries.forEach(function (q) {
      q.mq.addEventListener("change", apply);
    });
    apply();
  }

  function addRevealFragments(root, embla) {
    if (!window.Reveal || typeof Reveal.on !== "function") return;
    Reveal.on("fragmentshown", function (e) {
      if (root.contains(e.fragment)) embla.scrollNext();
    });
    Reveal.on("fragmenthidden", function (e) {
      if (root.contains(e.fragment)) embla.scrollPrev();
    });
  }

  function initCompare(root) {
    if (printMode) {
      root.classList.add("easycarousel-compare--print");
      return;
    }
    var handle = document.createElement("div");
    handle.className = "easycarousel-compare__handle";
    handle.innerHTML = '<div class="easycarousel-compare__grip" role="slider" tabindex="0" aria-label="Comparison position" aria-valuemin="0" aria-valuemax="100" aria-valuenow="50"></div>';
    root.appendChild(handle);
    var grip = handle.firstChild;

    function setPos(pct) {
      pct = Math.max(0, Math.min(100, pct));
      root.style.setProperty("--ec-pos", pct + "%");
      grip.setAttribute("aria-valuenow", Math.round(pct));
    }

    function pointerPct(e) {
      var rect = root.getBoundingClientRect();
      return ((e.clientX - rect.left) / rect.width) * 100;
    }

    var dragging = false;
    root.addEventListener("pointerdown", function (e) {
      dragging = true;
      root.setPointerCapture(e.pointerId);
      setPos(pointerPct(e));
    });
    root.addEventListener("pointermove", function (e) {
      if (dragging) setPos(pointerPct(e));
    });
    root.addEventListener("pointerup", function () { dragging = false; });
    grip.addEventListener("keydown", function (e) {
      var now = parseFloat(grip.getAttribute("aria-valuenow"));
      if (e.key === "ArrowLeft") { setPos(now - 5); e.preventDefault(); }
      if (e.key === "ArrowRight") { setPos(now + 5); e.preventDefault(); }
    });
    setPos(50);
  }

  /* Marquees are pure CSS, but the animation only looks seamless while one
     group is at least as wide as the strip: otherwise the first copy leaves
     the right edge before the second one gets there, showing a gap. So repeat
     the items until a group covers the strip. */
  function initMarquee(root) {
    if (printMode) {
      root.classList.add("easycarousel-marquee--print");
      return;
    }
    var groups = root.querySelectorAll(".easycarousel-marquee__group");
    if (groups.length < 2) return;
    var items = Array.prototype.slice.call(
      groups[0].querySelectorAll(".easycarousel-marquee__item"));
    if (!items.length) return;

    function size() {
      groups.forEach(function (group) {
        group.querySelectorAll("[data-ec-repeat]").forEach(function (el) {
          el.remove();
        });
      });
      var width = groups[0].scrollWidth;
      if (!width) return;
      // a little wider than the strip, so rounding never leaves a sliver
      var copies = Math.ceil((root.clientWidth * 1.05) / width);
      for (var c = 1; c < copies; c++) {
        groups.forEach(function (group) {
          items.forEach(function (item) {
            var copy = item.cloneNode(true);
            // the extras are decorative repeats: no duplicate ids, and no
            // second entry for the same image in the lightbox gallery
            copy.querySelectorAll("[id]").forEach(function (el) {
              el.removeAttribute("id");
            });
            copy.querySelectorAll(".lightbox").forEach(function (el) {
              el.classList.remove("lightbox");
            });
            copy.setAttribute("aria-hidden", "true");
            copy.setAttribute("data-ec-repeat", "");
            group.appendChild(copy);
          });
        });
      }
    }

    size();
    // images without dimensions have no width yet at DOMContentLoaded, and
    // the strip is resized by the window and by reveal.js's own layout, so
    // measure again whenever either changes
    window.addEventListener("load", size);
    var timer;
    function resize() {
      clearTimeout(timer);
      timer = setTimeout(size, 150);
    }
    if (window.ResizeObserver) new ResizeObserver(resize).observe(root);
    else window.addEventListener("resize", resize);
  }

  function init(root) {
    var viewport = root.querySelector(".easycarousel__viewport");
    if (!viewport) return;
    if (printMode) {
      root.classList.add("easycarousel--print");
      root.classList.remove("easycarousel--coverflow");
      return;
    }
    var opts = JSON.parse(root.dataset.options || "{}");
    // the coverflow stack is all transform; without it the plain carousel is
    // the right fallback
    if (reducedMotion) root.classList.remove("easycarousel--coverflow");

    var plugins = [];
    if (opts.autoplay && !reducedMotion) {
      plugins.push(EmblaCarouselAutoplay({
        delay: opts.autoplay,
        stopOnInteraction: false,
        stopOnMouseEnter: true
      }));
    }
    if (opts.fade) plugins.push(EmblaCarouselFade());

    var embla = EmblaCarousel(viewport, {
      loop: opts.loop,
      align: opts.align,
      axis: opts.vertical ? "y" : "x",
      dragFree: opts.dragFree
    }, plugins);

    if (opts.arrows) addArrows(root, embla, opts.vertical);
    if (opts.dots) addDots(root, embla);
    if (opts.thumbs) addThumbs(root, embla);
    if (opts.effect && !reducedMotion) addTween(embla, opts.effect, opts.loop);
    if (opts.breakpoints) {
      addBreakpoints(root, embla, opts.slides || 1, opts.breakpoints);
    }
    if (opts.fragment) addRevealFragments(root, embla);
    addKeyboard(viewport, embla, opts.vertical);
    root.easycarousel = embla;
  }

  function initAll() {
    document.querySelectorAll(".easycarousel").forEach(init);
    document.querySelectorAll(".easycarousel-compare").forEach(initCompare);
    document.querySelectorAll(".easycarousel-marquee").forEach(initMarquee);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
