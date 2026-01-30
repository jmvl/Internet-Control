# Dinero Cash Website - UX/UI Improvement Roadmap

**Project**: Dinero Cash Website (https://dinero.cash)
**Base Directory**: `/Users/jm/Codebase/internet-control/websites/www.dinero.cash`
**Live Server**: HestiaCP at 192.168.1.30
**Analysis Date**: 2026-01-16
**Target Completion**: 2026-02-15 (4 weeks)

---

## Table of Contents

- [Phase 1: Critical Accessibility Fixes](#phase-1-critical-accessibility-fixes)
- [Phase 2: Performance Optimization](#phase-2-performance-optimization)
- [Phase 3: UX & Interaction Improvements](#phase-3-ux--interaction-improvements)
- [Phase 4: Design System & Visual Polish](#phase-4-design-system--visual-polish)
- [Phase 5: SEO & Technical Improvements](#phase-5-seo--technical-improvements)
- [Phase 6: Testing & Deployment](#phase-6-testing--deployment)

---

## Phase 1: Critical Accessibility Fixes

**Duration**: Week 1 (2026-01-17 to 2026-01-23)
**Goal**: Achieve WCAG AA compliance baseline

### 1.1 Skip Navigation Link
- [ ] Create `.skip-link` CSS class with proper positioning
  - [ ] Add `position: absolute; top: -100px` hidden state
  - [ ] Add `:focus { top: 0 }` visible state
  - [ ] Ensure high contrast (black on white, or white on black)
  - [ ] Add z-index: 9999 to appear above all content
- [ ] Add skip link HTML immediately after `<body>` tag
  - [ ] `<a href="#main-content" class="skip-link">Skip to main content</a>`
- [ ] Add `id="main-content"` to main content wrapper
- [ ] Test skip link functionality with keyboard only (Tab + Enter)
- [ ] Verify skip link works across all pages (index, users, agents)

**Files**: `assets/css/accessibility-improvements.css`, `index.html`, `users.html`, `agents.html`
**Estimated Time**: 30 minutes
**Priority**: P0 (Critical)

---

### 1.2 Visible Focus Indicators
- [ ] Create comprehensive `:focus-visible` CSS rules
  - [ ] Add `outline: 3px solid #4d90fe` for all interactive elements
  - [ ] Add `outline-offset: 2px` for spacing
  - [ ] Create `:focus:not(:focus-visible) { outline: none }` for mouse-only
- [ ] Apply focus styles to:
  - [ ] All navigation links (`.nav-link`)
  - [ ] All buttons (`.button`, `button` elements)
  - [ ] All form inputs (`input`, `textarea`, `select`)
  - [ ] Feature boxes (`.feature-box`)
  - [ ] Hero slider arrows
  - [ ] Close buttons in modals
- [ ] Test focus indicators with keyboard navigation
- [ ] Ensure focus indicators meet 3:1 contrast ratio

**Files**: `assets/css/accessibility-improvements.css`
**Estimated Time**: 1 hour
**Priority**: P0 (Critical)

---

### 1.3 ARIA Labels & Landmarks
- [ ] Add semantic landmarks to page structure
  - [ ] `<header role="banner">` for hero/navigation section
  - [ ] `<nav role="navigation" aria-label="Main">` for main nav
  - [ ] `<main id="main-content" role="main">` for content
  - [ ] `<footer role="contentinfo">` for footer
  - [ ] `<section aria-labelledby="...">` for content sections
- [ ] Add ARIA labels to interactive elements
  - [ ] Menu button: `aria-label="Toggle navigation menu" aria-expanded="false"`
  - [ ] Feature boxes: `aria-label="View wallet models features"`
  - [ ] Slider arrows: `aria-label="Previous slide" / "Next slide"`
  - [ ] Close buttons: `aria-label="Close dialog"`
  - [ ] Form inputs: `aria-required="true"` for required fields
- [ ] Add `aria-hidden="true"` to decorative elements
  - [ ] Background images without meaning
  - [ ] Decorative icons
  - [ ] Lottie animation containers
- [ ] Add live regions for form feedback
  - [ ] `role="alert"` for error messages
  - [ ] `role="status"` for success messages
- [ ] Test with screen reader (VoiceOver on macOS, NVDA on Windows)

**Files**: `index.html`, `users.html`, `agents.html`, `contact-us.html`
**Estimated Time**: 3 hours
**Priority**: P0 (Critical)

---

### 1.4 Form Label Fixes
- [ ] Remove placeholder-only label pattern
- [ ] Add proper `<label>` elements for all form inputs
  - [ ] Demo form: Name, Email, Phone, Country, Professional Area
  - [ ] Contact form: Email, Question
- [ ] Create `.visually-hidden` class for screen-reader-only labels
  - [ ] Position: absolute, width: 1px, clip: rect(0,0,0,0)
- [ ] Add `aria-describedby` associations for hints
- [ ] Add `aria-invalid` and error message containers
- [ ] Implement inline validation JavaScript
  - [ ] Validate on blur event
  - [ ] Add/remove `.invalid` and `.valid` classes
  - [ ] Update `aria-invalid` attribute dynamically
  - [ ] Show/hide error messages
- [ ] Test form flow with keyboard and screen reader

**Files**: `index.html` (demo form), `contact-us.html`, `assets/css/accessibility-improvements.css`, `assets/js/form-validation.js`
**Estimated Time**: 2 hours
**Priority**: P0 (Critical)

---

### 1.5 Color Contrast Audit & Fixes
- [ ] Audit all color combinations with WebAIM contrast checker
  - [ ] Hero text on image backgrounds
  - [ ] Body text variations (`.p`, `._14`, etc.)
  - [ ] Button text on backgrounds
  - [ ] Link text in context
  - [ ] Form field borders
  - [ ] Feature card titles
- [ ] Document all failing combinations in spreadsheet
- [ ] Implement fixes for failing combinations
  - [ ] Add text shadows for overlays
  - [ ] Add semi-transparent backgrounds for text on images
  - [ ] Adjust hex values for better contrast
- [ ] Re-test all fixed combinations
- [ ] Document final color palette with contrast ratios
- [ ] Test with color blindness simulator (toptal.com/designers/colorfilter)

**Files**: `assets/css/dinerocash.webflow.shared.f0a36ca9c.css`, design documentation
**Estimated Time**: 3 hours
**Priority**: P0 (Critical)

---

### 1.6 Image Alt Text Completion
- [ ] Audit all `<img>` elements for missing or empty alt text
- [ ] Write descriptive alt text for informative images
  - [ ] Hero images: Describe key visual elements
  - [ ] Tab images: Describe what users see in interface
  - [ ] Feature card images: Describe the feature shown
- [ ] Add `alt=""` to decorative images
  - [ ] Background patterns
  - [ ] Decorative icons (when SVGs are decorative)
- [ ] Ensure alt text is contextually appropriate
- [ ] Test with screen reader to verify descriptions

**Files**: `index.html`, `users.html`, `agents.html`
**Estimated Time**: 1 hour
**Priority**: P0 (Critical)

---

### 1.7 Reduced Motion Support
- [ ] Add `prefers-reduced-motion` media query detection
  - [ ] Test `window.matchMedia('(prefers-reduced-motion: reduce)')`
- [ ] Disable auto-sliding when reduced motion preferred
  - [ ] Hero slider: Check before initializing autoplay
  - [ ] Features slider: Check before auto-advancing
- [ ] Disable/replace animations when reduced motion preferred
  - [ ] Fade transitions: Replace with instant show/hide
  - [ ] Slide animations: Replace with direct jumps
  - [ ] Lottie animations: Hide completely or show static frame
  - [ ] Hover effects: Keep, but remove transition animations
- [ ] Test with macOS reduced motion setting enabled
- [ ] Document animation behavior for both modes

**Files**: `assets/js/accessibility.js`, `assets/css/accessibility-improvements.css`
**Estimated Time**: 2 hours
**Priority**: P1 (High)

---

## Phase 2: Performance Optimization

**Duration**: Week 2 (2026-01-24 to 2026-01-30)
**Goal**: Achieve Lighthouse Performance Score 90+

### 2.1 WebP Image Conversion
- [ ] Convert all hero images to WebP format
  - [ ] `hero-1.jpg` → `hero-1.webp`
  - [ ] `hero-2.jpg` → `hero-2.webp`
  - [ ] `hero-3.jpg` → `hero-3.webp`
  - [ ] `hero-4.jpg` → `hero-4.webp`
- [ ] Convert tab interface images to WebP
  - [ ] `tabs-users.png` → `tabs-users.webp`
  - [ ] `tabs-business.png` → `tabs-business.webp`
  - [ ] `tabs-banks.png` → `tabs-banks.webp`
- [ ] Convert feature card images to WebP
  - [ ] All wallet images (wallet-1 through wallet-6)
  - [ ] All payments images (payments-1 through payments-6)
  - [ ] All merchant images (merchant-1 through merchant-6)
  - [ ] All onboarding images (onboarding-1 through onboarding-6)
- [ ] Implement `<picture>` elements with fallbacks
- [ ] Verify JPEG fallback works for unsupported browsers
- [ ] Measure file size reduction (target: 25-35%)

**Files**: All images in `assets/images/`, HTML files using images
**Tools**: ImageMagick, Squoosh, or similar converter
**Estimated Time**: 3 hours
**Priority**: P1 (High)

---

### 2.2 Lazy Loading Implementation
- [ ] Add `loading="lazy"` to below-fold images
  - [ ] Hero slides 2, 3, 4 (keep slide 1 eager)
  - [ ] Tab images (only active tab eager)
  - [ ] All feature card images
- [ ] Add `loading="eager"` and `fetchpriority="high"` to first hero image
- [ ] Add `decoding="async"` to non-critical images
- [ ] Test lazy loading behavior in Chrome DevTools Network tab
- [ ] Verify LCP (Largest Contentful Paint) improves
- [ ] Measure initial page load reduction

**Files**: `index.html`, `users.html`, `agents.html`
**Estimated Time**: 1 hour
**Priority**: P1 (High)

---

### 2.3 JavaScript Optimization
- [ ] Audit current JavaScript dependencies
  - [ ] Document what jQuery is used for
  - [ ] Identify if jQuery can be removed or replaced
  - [ ] Check for unused Webflow chunks
- [ ] Add `defer` attribute to non-critical scripts
  - [ ] jQuery: `<script src="..." defer></script>`
  - [ ] Webflow chunks: `<script src="..." defer></script>`
- [ ] Add `async` to independent scripts
- [ ] Implement critical JS inline for above-fold functionality
  - [ ] Navigation toggle
  - [ ] Skip link functionality
- [ ] Test that all functionality still works with deferred loading
- [ ] Measure JS parsing/execution time improvement

**Files**: All HTML files with `<script>` tags
**Estimated Time**: 2 hours
**Priority**: P1 (High)

---

### 2.4 CSS Optimization
- [ ] Run CSS purge to remove unused styles
  - [ ] Use PurgeCSS or similar tool
  - [ ] Scan all HTML files for used classes
  - [ ] Generate purged CSS file
- [ ] Minify CSS for production
  - [ ] Remove comments and whitespace
  - [ ] Combine media queries where possible
- [ ] Implement critical CSS inlining
  - [ ] Extract above-fold CSS
  - [ ] Inline in `<head>`
  - [ ] Load remaining CSS asynchronously
- [ ] Add cache-busting to CSS filename
  - [ ] Already has hash, verify it updates on changes
- [ ] Measure CSS file size reduction

**Files**: `assets/css/dinerocash.webflow.shared.f0a36ca9c.css`
**Tools**: PurgeCSS, cssnano, or similar
**Estimated Time**: 3 hours
**Priority**: P2 (Medium)

---

### 2.5 Font Loading Optimization
- [ ] Reduce font weights to minimum needed
  - [ ] Current: Montserrat 400,500,600,700
  - [ ] Remove: 100, 200, 800, 900 if unused
- [ ] Add `font-display: swap` to all `@font-face` rules
- [ ] Use Google Fonts API with `display=swap` parameter
- [ ] Add `<link rel="preconnect">` for fonts.googleapis.com
- [ ] Test for FOUT (Flash of Unstyled Text) vs FOIT
- [ ] Measure font loading time improvement

**Files**: CSS files, HTML `<head>` sections
**Estimated Time**: 1 hour
**Priority**: P2 (Medium)

---

### 2.6 Loading States Implementation
- [ ] Create `.loading` class for buttons
  - [ ] Add spinner animation CSS
  - [ ] Add `pointer-events: none` to prevent double-submit
  - [ ] Add opacity reduction
- [ ] Implement skeleton loading for content
  - [ ] Create `.skeleton` CSS class
  - [ ] Add shimmer animation
  - [ ] Apply to feature cards, form sections
- [ ] Add loading state to forms
  - [ ] Show spinner on submit button
  - [ ] Disable form during submission
  - [ ] Re-enable on error/success
- [ ] Test loading states across slow 3G connection

**Files**: `assets/css/loading-states.css`, `assets/js/loading-states.js`
**Estimated Time**: 2 hours
**Priority**: P2 (Medium)

---

## Phase 3: UX & Interaction Improvements

**Duration**: Week 3 (2026-02-01 to 2026-02-07)
**Goal**: Improve user experience and interaction quality

### 3.1 Hero Slider Improvements
- [ ] Add pause on hover functionality
  - [ ] Pause autoplay on `mouseenter`
  - [ ] Resume on `mouseleave`
- [ ] Improve navigation indicator visibility
  - [ ] Make active dot clearly larger or different color
  - [ ] Add aria-label to dots (e.g., "Go to slide 1")
- [ ] Add keyboard navigation support
  - [ ] Arrow keys to navigate slides
  - [ ] Escape to close/exit
- [ ] OR: Replace with single hero + scroll animations
  - [ ] Evaluate A/B test data if available
  - [ ] Consider pros/cons of each approach
- [ ] Test with `prefers-reduced-motion` (from Phase 1)

**Files**: `assets/js/hero-slider.js`, `index.html`
**Estimated Time**: 2 hours (or 4 hours if replacing entirely)
**Priority**: P1 (High)

---

### 3.2 Mobile Touch Gestures
- [ ] Implement swipe gestures for feature slider
  - [ ] Touch start position tracking
  - [ ] Touch end position calculation
  - [ ] Swipe threshold detection (50px)
  - [ ] Trigger next/prev slide based on direction
- [ ] Add swipe to hero slider
- [ ] Test on actual iOS and Android devices
  - [ ] Verify gesture doesn't conflict with browser navigation
  - [ ] Test with various swipe speeds
- [ ] Add visual feedback for swipe in progress
  - [ ] Show partial slide during drag

**Files**: `assets/js/touch-gestures.js`
**Estimated Time**: 3 hours
**Priority**: P1 (High)

---

### 3.3 Mobile Navigation Improvements
- [ ] Add clear open/close state indication
  - [ ] Update `aria-expanded` attribute
  - [ ] Change icon from hamburger to X
  - [ ] Add background color change when open
- [ ] Implement smooth slide/fade animation for menu
- [ ] Add focus trap when menu is open
  - [ ] Tab cycles within menu only
  - [ ] Escape closes menu
- [ ] Click outside closes menu
- [ ] Test menu flow with keyboard only
- [ ] Ensure menu works without JavaScript (progressive enhancement)

**Files**: `assets/css/mobile-nav.css`, `assets/js/mobile-nav.js`
**Estimated Time**: 2 hours
**Priority**: P1 (High)

---

### 3.4 Touch Target Sizing
- [ ] Audit all interactive elements for minimum 44×44px
  - [ ] Navigation links
  - [ ] Feature boxes
  - [ ] Slider arrows
  - [ ] Form submit buttons
  - [ ] Close buttons
- [ ] Expand small tap targets with CSS
  - [ ] Use pseudo-elements for invisible expansion
  - [ ] Add padding where appropriate
- [ ] Test with various finger sizes
- [ ] Document any elements that cannot be expanded

**Files**: `assets/css/touch-targets.css`
**Estimated Time**: 1 hour
**Priority**: P1 (High)

---

### 3.5 Form UX Enhancements
- [ ] Implement inline validation (from Phase 1)
- [ ] Add character counter to textarea
  - [ ] Show "X / 5000 characters"
  - [ ] Warn as approaching limit
- [ ] Add password strength indicator (if password field added)
- [ ] Implement clear error message design
  - [ ] Red border on invalid fields
  - [ ] Error icon + text below field
  - [ ] Group multiple errors at top
- [ ] Add success state design
  - [ ] Green checkmark on valid fields
  - [ ] Success message after submission
- [ ] Test form flow end-to-end
  - [ ] Submit with invalid data
  - [ ] Submit with valid data
  - [ ] Verify error recovery

**Files**: `assets/css/form-ux.css`, `assets/js/form-validation.js`
**Estimated Time**: 3 hours
**Priority**: P2 (Medium)

---

### 3.6 Feature Popup UX Redesign
- [ ] Evaluate if popup is the right pattern
  - [ ] Consider inline expansion instead
  - [ ] Consider separate page for features
- [ ] If keeping popup, improve UX:
  - [ ] Add backdrop blur for better focus
  - [ ] Add clear close button (X) in corner
  - [ ] Make close button larger on mobile
  - [ ] Add animation timing for smooth feel
- [ ] Implement swipe to close on mobile
- [ ] Add keyboard support (Escape to close)
- [ ] Ensure focus trap within popup

**Files**: `assets/css/feature-popup.css`, `assets/js/feature-popup.js`
**Estimated Time**: 3 hours
**Priority**: P2 (Medium)

---

### 3.7 Scroll Animations
- [ ] Implement scroll-triggered reveal animations
  - [ ] Use Intersection Observer API
  - [ ] Fade in elements as they enter viewport
  - [ ] Slide up from bottom
- [ ] Respect `prefers-reduced-motion` (disable if preferred)
- [ ] Add animations to:
  - [ ] Section headings
  - [ ] Feature boxes
  - [ ] Timeline steps
  - [ ] Module cubes
- [ ] Ensure animations don't cause layout shift
- [ ] Test with slow scroll speed

**Files**: `assets/css/scroll-animations.css`, `assets/js/scroll-animations.js`
**Estimated Time**: 3 hours
**Priority**: P2 (Medium)

---

## Phase 4: Design System & Visual Polish

**Duration**: Week 3 (2026-02-01 to 2026-02-07)
**Goal**: Establish consistent design system and refined visuals

### 4.1 Color System Documentation
- [ ] Define CSS custom properties for all colors
  - [ ] Primary colors (green variations)
  - [ ] Secondary colors (blue variations)
  - [ ] Accent colors (purple, yellow)
  - [ ] Semantic colors (success, warning, error, info)
  - [ ] Neutral palette (gray scale)
- [ ] Document contrast ratios for all combinations
- [ ] Create `design-system/tokens/colors.md` documentation
- [ ] Add color usage guidelines
  - [ ] When to use each color
  - [ ] Color combinations to avoid
  - [ ] Dark mode considerations (if applicable)

**Files**: `assets/css/design-tokens.css`, documentation files
**Estimated Time**: 2 hours
**Priority**: P2 (Medium)

---

### 4.2 Typography System
- [ ] Define CSS custom properties for typography
  - [ ] Font families (display, body, monospace)
  - [ ] Font weights with numeric values
  - [ ] Responsive type scale using `clamp()`
  - [ ] Line heights for each size
  - [ ] Letter spacing where needed
- [ ] Create typography scale documentation
  - [ ] H1: clamp(2.5rem, 5vw + 1rem, 4rem)
  - [ ] H2: clamp(2rem, 4vw + 1rem, 3rem)
  - [ ] H3: clamp(1.5rem, 3vw + 0.5rem, 2rem)
  - [ ] Body: clamp(1rem, 1vw + 0.8rem, 1.125rem)
  - [ ] Small: clamp(0.875rem, 0.8vw + 0.75rem, 1rem)
- [ ] Document heading hierarchy rules
- [ ] Create `design-system/tokens/typography.md`

**Files**: `assets/css/design-tokens.css`, documentation files
**Estimated Time**: 2 hours
**Priority**: P2 (Medium)

---

### 4.3 Spacing System
- [ ] Define CSS custom properties for spacing
  - [ ] Base unit: 4px or 8px
  - [ ] Scale: xs (4px), sm (8px), md (16px), lg (24px), xl (32px), 2xl (48px), 3xl (64px)
- [ ] Apply spacing system consistently
  - [ ] Section padding
  - [ ] Component margins
  - [ ] Grid gaps
- [ ] Document spacing usage guidelines
- [ ] Create `design-system/tokens/spacing.md`

**Files**: `assets/css/design-tokens.css`, documentation files
**Estimated Time**: 1 hour
**Priority**: P2 (Medium)

---

### 4.4 Component Documentation
- [ ] Document all reusable components
  - [ ] Buttons (variants, states, sizes)
  - [ ] Forms (inputs, labels, error states)
  - [ ] Cards (feature cards, pricing cards)
  - [ ] Navigation (desktop, mobile)
  - [ ] Modals/popups
  - [ ] Sliders/carousels
- [ ] Create component documentation with:
  - [ ] HTML structure
  - [ ] CSS classes used
  - [ ] Interaction states
  - [ ] Accessibility notes
  - [ ] Usage examples
- [ ] Create `design-system/components/` directory with individual docs

**Files**: New documentation files in `design-system/components/`
**Estimated Time**: 4 hours
**Priority**: P2 (Medium)

---

### 4.5 Micro-interactions
- [ ] Add hover states to all interactive elements
  - [ ] Buttons: Color shift, slight lift (transform: translateY(-2px))
  - [ ] Links: Underline animation
  - [ ] Cards: Subtle shadow increase
- [ ] Add active states
  - [ ] Buttons: Scale down (transform: scale(0.98))
  - [ ] Links: Color flash
- [ ] Add transition timing functions
  - [ ] Use easing curves (ease-out, ease-in-out)
  - [ ] Consistent durations (150ms, 300ms, 500ms)
- [ ] Test micro-interactions don't cause motion sickness
- [ ] Respect `prefers-reduced-motion`

**Files**: `assets/css/micro-interactions.css`
**Estimated Time**: 3 hours
**Priority**: P2 (Medium)

---

### 4.6 Visual Hierarchy Refinement
- [ ] Audit page for heading hierarchy
  - [ ] Ensure single H1 per page
  - [ ] Fix H1/H2 issues in hero slides
  - [ ] Ensure logical heading order
- [ ] Refine hero section
  - [ ] Make primary CTA visually dominant
  - [ ] De-emphasize secondary CTA
  - [ ] Ensure value proposition is clearest element
- [ ] Refine feature boxes
  - [ ] Make titles more prominent
  - [ ] Add subtle hover lift
  - [ ] Improve "More" CTA visibility
- [ ] Add strategic whitespace
  - [ ] Increase section spacing for breathing room
  - [ ] Add padding around focal points

**Files**: `assets/css/visual-hierarchy.css`, HTML files
**Estimated Time**: 3 hours
**Priority**: P2 (Medium)

---

## Phase 5: SEO & Technical Improvements

**Duration**: Week 4 (2026-02-08 to 2026-02-14)
**Goal**: Achieve SEO best practices and technical excellence

### 5.1 Meta Tags Enhancement
- [ ] Add canonical URL tag to all pages
  - [ ] `<link rel="canonical" href="https://www.dinero.cash/">`
  - [ ] Ensure consistent www vs non-www
- [ ] Enhance Open Graph tags
  - [ ] Add `og:url`
  - [ ] Add `og:image` with dimensions
  - [ ] Add `og:locale`
  - [ ] Add `og:site_name`
- [ ] Complete Twitter Card tags
  - [ ] Add `twitter:card` (summary_large_image)
  - [ ] Add `twitter:site` and `twitter:creator`
  - [ ] Add `twitter:image`
- [ ] Optimize meta descriptions
  - [ ] Fix grammatical errors ("the market" → "the market")
  - [ ] Write compelling descriptions (150-160 chars)
  - [ ] Include primary keywords naturally
- [ ] Add favicon to all pages (currently only index.html)

**Files**: `index.html`, `users.html`, `agents.html`, `contact-us.html`
**Estimated Time**: 1 hour
**Priority**: P1 (High)

---

### 5.2 Structured Data (Schema.org)
- [ ] Add Organization schema
  - [ ] Name, URL, logo
  - [ ] Address (Luxembourg)
  - [ ] Contact point (phone, email)
  - [ ] Parent organization (Accelior S.A.)
- [ ] Add SoftwareApplication schema
  - [ ] Name: Dinero Cash Platform
  - [ ] Application category: Finance
  - [ ] Description
  - [ ] Offers (pricing if applicable)
- [ ] Add WebSite schema
  - [ ] Name, URL
  - [ ] Potential action: Search
- [ ] Test with Google Rich Results Test
- [ ] Submit to Google Search Console

**Files**: All HTML pages (in `<head>` section)
**Estimated Time**: 2 hours
**Priority**: P1 (High)

---

### 5.3 Sitemap & Robots.txt
- [ ] Create comprehensive sitemap.xml
  - [ ] Include all pages (index, users, agents, contact, privacy)
  - [ ] Add lastmod dates
  - [ ] Set priority levels (index: 1.0, others: 0.8)
  - [ ] Set change frequencies
- [ ] Update/create robots.txt
  - [ ] Allow all bots
  - [ ] Disallow admin/private areas if any
  - [ ] Add sitemap reference
- [ ] Submit sitemap to Google Search Console
- [ ] Submit sitemap to Bing Webmaster Tools

**Files**: `sitemap.xml`, `robots.txt`
**Estimated Time**: 1 hour
**Priority**: P1 (High)

---

### 5.4 Heading Structure Fix
- [ ] Fix multiple H1 issue in hero slider
  - [ ] Change to single H1 for page
  - [ ] Use H2 for slide headings
  - [ ] Update slide navigation ARIA labels
- [ ] Audit all pages for proper heading hierarchy
  - [ ] No skipped levels (H1 → H3 is bad)
  - [ ] Logical sectioning with H2s
  - [ ] H3s for subsections
- [ ] Ensure headings are descriptive
  - [ ] Avoid generic "Features" as only text
  - [ ] Include context in headings
- [ ] Test with screen reader heading navigation

**Files**: `index.html`, `users.html`, `agents.html`
**Estimated Time**: 1.5 hours
**Priority**: P1 (High)

---

### 5.5 Security Headers
- [ ] Configure HestiaCP to add security headers
  - [ ] `X-Frame-Options: DENY` or `SAMEORIGIN`
  - [ ] `X-Content-Type-Options: nosniff`
  - [ ] `X-XSS-Protection: 1; mode=block`
  - [ ] `Strict-Transport-Security: max-age=31536000`
  - [ ] `Content-Security-Policy` (if feasible)
  - [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] Test headers with securityheaders.com
- [ ] Document headers in deployment guide

**Files**: HestiaCP configuration, server config
**Estimated Time**: 2 hours
**Priority**: P2 (Medium)

---

### 5.6 Form Security Hardening
- [ ] Verify form method is POST (not GET)
- [ ] Implement CSRF token protection
  - [ ] Generate token on page load
  - [ ] Validate on submission
  - [ ] Regenerate after successful submission
- [ ] Add rate limiting to form endpoints
- [ ] Implement server-side validation
  - [ ] Never trust client-side validation
  - [ ] Sanitize all input
  - [ ] Validate email format, required fields
- [ ] Add honeypot field for bot protection
- [ ] Log form submissions for monitoring

**Files**: Server-side form handler, HTML forms
**Estimated Time**: 3 hours
**Priority**: P1 (High)

---

### 5.7 404 Page Creation
- [ ] Design custom 404 page
  - [ ] Maintain site branding
  - [ ] Clear "Page not found" message
  - [ ] Link back to home
  - [ ] Link to key sections (Users, Agents)
  - [ ] Consider helpful search or sitemap links
- [ ] Implement 404.html in root
- [ ] Configure HestiaCP to use custom 404
- [ ] Test 404 by visiting non-existent page
- [ ] Ensure 404 returns proper 404 status code

**Files**: `404.html`, server configuration
**Estimated Time**: 2 hours
**Priority**: P2 (Medium)

---

## Phase 6: Testing & Deployment

**Duration**: Week 4 (2026-02-12 to 2026-02-15)
**Goal**: Ensure quality and successful deployment

### 6.1 Pre-deployment Testing
- [ ] **Cross-browser testing**
  - [ ] Chrome (latest)
  - [ ] Firefox (latest)
  - [ ] Safari (macOS + iOS)
  - [ ] Edge (latest)
  - [ ] Mobile Safari (iOS)
  - [ ] Chrome Mobile (Android)
- [ ] **Accessibility testing**
  - [ ] Keyboard-only navigation
  - [ ] Screen reader testing (VoiceOver, NVDA)
  - [ ] Color contrast verification
  - [ ] Zoom testing (200%)
- [ ] **Performance testing**
  - [ ] Lighthouse audit (target: 90+ all categories)
  - [ ] PageSpeed Insights test
  - [ ] WebPageTest test
  - [ ] 3G connection simulation
- [ ] **Functional testing**
  - [ ] All forms submit correctly
  - [ ] All links work
  - [ ] All sliders/carousels function
  - [ ] Mobile menu works
  - [ ] Modals open/close properly

**Files**: All pages, all features
**Estimated Time**: 4 hours
**Priority**: P0 (Critical)

---

### 6.2 Content Verification
- [ ] Proofread all text content
  - [ ] Check for typos and grammatical errors
  - [ ] Verify phone numbers are correct
  - [ ] Verify email addresses work
  - [ ] Check all external links still valid
- [ ] Verify brand consistency
  - [ ] Logo usage is correct
  - [ ] Company name spelled correctly
  - [ ] Taglines match brand guidelines
- [ ] Test all contact methods
  - [ ] Send test email to info@accelior.com
  - [ ] Call +352 691 699 011 to verify
  - [ ] Test contact form submission

**Files**: All HTML pages
**Estimated Time**: 2 hours
**Priority**: P0 (Critical)

---

### 6.3 Backup & Pre-deployment Prep
- [ ] Create full backup of live site
  ```bash
  ssh root@192.168.1.30 "cd /home/dinero/web/dinero.cash && \
    tar -czf public_html.backup.$(date +%Y%m%d_%H%M%S).tar.gz public_html/"
  ```
- [ ] Document current live site state
  - [ ] Capture screenshots of all pages
  - [ ] Run Lighthouse audit for baseline
  - [ ] Document any known issues
- [ ] Prepare rollback plan
  - [ ] Document exact steps to revert
  - [ ] Keep backup accessible
- [ ] Create deployment checklist

**Files**: Deployment documentation
**Estimated Time**: 1 hour
**Priority**: P0 (Critical)

---

### 6.4 Deployment to Live
- [ ] Sync local files to live server
  ```bash
  rsync -avz --delete --exclude='*.md' --exclude='.git' \
    /Users/jm/Codebase/internet-control/websites/www.dinero.cash/ \
    root@192.168.1.30:/home/dinero/web/dinero.cash/public_html/
  ```
- [ ] Verify file permissions
  ```bash
  ssh root@192.168.1.30 "chown -R dinero:dinero /home/dinero/web/dinero.cash/public_html/"
  ```
- [ ] Test live site immediately
  - [ ] Check homepage loads
  - [ ] Test all pages load
  - [ ] Verify CSS/JS load correctly
  - [ ] Test form submissions
  - [ ] Check SSL certificate valid
- [ ] Run post-deployment Lighthouse audit
- [ ] Monitor server logs for errors
- [ ] Set up monitoring/alerting if possible

**Estimated Time**: 2 hours
**Priority**: P0 (Critical)

---

### 6.5 Post-deployment Verification
- [ ] **SEO verification**
  - [ ] Check Google can crawl (Fetch as Google)
  - [ ] Verify sitemap accessible
  - [ ] Test robots.txt
  - [ ] Check structured data with Rich Results Test
- [ ] **Analytics setup**
  - [ ] Verify analytics tracking works
  - [ ] Check goal tracking (form submissions)
  - [ ] Set up custom events if needed
- [ ] **Performance monitoring**
  - [ ] Run Lighthouse audit on live site
  - [ ] Check Core Web Vitals in Search Console
  - [ ] Document baseline metrics
- [ ] **Accessibility verification**
  - [ ] Run WAVE on live site
  - [ ] Test with actual screen readers
  - [ ] Verify all fixes are working

**Estimated Time**: 2 hours
**Priority**: P0 (Critical)

---

### 6.6 Documentation & Handoff
- [ ] Update project documentation
  - [ ] Document all changes made
  - [ ] Update sitemap with new pages
  - [ ] Document deployment process
- [ ] Create maintenance guide
  - [ ] How to update content
  - [ ] How to add new pages
  - [ ] How to rollback if needed
- [ ] Create design system documentation
  - [ ] Color palette with hex codes
  - [ ] Typography scale
  - [ ] Component library
  - [ ] Usage guidelines
- [ ] Document known issues/future improvements
- [ ] Hand off to stakeholders with demo

**Files**: Documentation files, README
**Estimated Time**: 3 hours
**Priority**: P1 (High)

---

## Quick Wins Checklist

These can be done in parallel with other phases:

- [ ] Add skip link (15 min)
- [ ] Fix focus states (30 min)
- [ ] Add `prefers-reduced-motion` (1 hour)
- [ ] Convert to WebP (2 hours)
- [ ] Fix form labels (2 hours)
- [ ] Add ARIA labels (3 hours)
- [ ] Add canonical tag (10 min)
- [ ] Add favicon to all pages (15 min)
- [ ] Fix meta description grammar (15 min)
- [ ] Add loading="lazy" to images (30 min)

---

## Progress Tracking

| Phase | Status | Completion | Last Updated |
|-------|--------|------------|--------------|
| Phase 1: Accessibility | Not Started | 0% | - |
| Phase 2: Performance | Not Started | 0% | - |
| Phase 3: UX Improvements | Not Started | 0% | - |
| Phase 4: Design System | Not Started | 0% | - |
| Phase 5: SEO & Technical | Not Started | 0% | - |
| Phase 6: Testing & Deploy | Not Started | 0% | - |

---

## Notes

- This TODO assumes the local version (`/Users/jm/Codebase/internet-control/websites/www.dinero.cash`) will replace the live version
- Some tasks may require coordination with HestiaCP hosting configuration
- Test environment recommended before production deployment
- Consider creating a staging site at `staging.dinero.cash` if available

---

## Resources

- **WCAG 2.1 AA Guidelines**: https://www.w3.org/WAI/WCAG21/quickref/
- **WebAIM Contrast Checker**: https://webaim.org/resources/contrastchecker/
- **Lighthouse**: Chrome DevTools > Lighthouse tab
- **Rich Results Test**: https://search.google.com/test/rich-results
- **WebPageTest**: https://www.webpagetest.org/
- **WAVE Accessibility Tool**: https://wave.webaim.org/

