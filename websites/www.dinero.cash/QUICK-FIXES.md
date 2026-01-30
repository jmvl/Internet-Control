# Dinero Cash - Quick Implementation Fixes

## Copy-Paste Ready Code Snippets

---

## 1. Head Section Improvements (index.html)

### Add to `<head>` after existing meta tags:

```html
<!-- Canonical URL -->
<link rel="canonical" href="https://www.dinero.cash/" />

<!-- Enhanced Open Graph -->
<meta property="og:url" content="https://www.dinero.cash/" />
<meta property="og:image" content="https://www.dinero.cash/assets/images/og-image.jpg" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:locale" content="en_US" />
<meta property="og:site_name" content="Dinero Cash" />

<!-- Enhanced Twitter Card -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:site" content="@dinerocash" />
<meta name="twitter:image" content="https://www.dinero.cash/assets/images/twitter-card.jpg" />

<!-- Structured Data (Organization) -->
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Dinero Cash",
  "url": "https://www.dinero.cash",
  "description": "Mobile money platform for financial institutions",
  "contactPoint": {
    "@type": "ContactPoint",
    "telephone": "+352691699011",
    "contactType": "sales",
    "email": "info@accelior.com"
  },
  "parentOrganization": {
    "@type": "Organization",
    "name": "Accelior S.A."
  }
}
</script>
```

### Replace description meta tag:

```html
<!-- Current -->
<meta content="The most innovative financial platform on market for users, financial providers and merchants" name="description"/>

<!-- Replace with -->
<meta content="Deploy next-gen mobile money services in 3-6 months. Dinero Cash empowers banks and financial institutions with customizable payment platforms, cross-border transfers, and comprehensive digital ecosystem." name="description"/>
```

---

## 2. Body Improvements

### Add skip link after `<body>`:

```html
<a href="#main-content" class="skip-link">Skip to main content</a>
```

### Add main wrapper:

```html
<!-- Wrap page content div -->
<main id="main-content" class="page" role="main">
  <!-- existing content -->
</main>
```

---

## 3. Form Security Fixes

### Demo Form - Replace:

```html
<!-- FROM -->
<form id="wf-form-Demo-Form" name="wf-form-Demo-Form" data-name="Demo Form" method="get" ...>

<!-- TO -->
<form id="wf-form-Demo-Form" name="wf-form-Demo-Form" data-name="Demo Form" method="POST"
      action="/api/demo-request" autocomplete="name" novalidate>
```

### Contact Form - Replace:

```html
<!-- FROM -->
<form id="wf-form-Contact-Form" name="wf-form-Contact-Form" data-name="Contact Form" method="get" ...>

<!-- TO -->
<form id="wf-form-Contact-Form" name="wf-form-Contact-Form" data-name="Contact Form" method="POST"
      action="/api/contact" autocomplete="email" novalidate>
```

---

## 4. ARIA Improvements

### Navigation - Add aria-label:

```html
<nav role="navigation" class="nav-menu w-nav-menu" aria-label="Main navigation">
```

### Menu button - Add attributes:

```html
<div class="menu-button w-nav-button"
     role="button"
     aria-label="Toggle navigation menu"
     aria-expanded="false"
     tabindex="0">
```

### Feature boxes - Add aria:

```html
<div id="walletmodels" class="feature-box" role="button" tabindex="0" aria-label="View wallet models features">
```

---

## 5. Image Alt Text Fixes

### Replace empty alt text:

```html
<!-- FROM -->
<img src="assets/images/tabs/tabs-users.png" loading="lazy" alt="" />

<!-- TO -->
<img src="assets/images/tabs/tabs-users.png" loading="lazy" alt="Dinero Cash mobile app interface showing user payment features" />
```

```html
<!-- FROM -->
<img src="assets/images/tabs/tabs-business.png" loading="lazy" ... alt="" />

<!-- TO -->
<img src="assets/images/tabs/tabs-business.png" loading="lazy" alt="Dinero Cash merchant dashboard with agent network and payment tools" />
```

```html
<!-- FROM -->
<img src="assets/images/tabs/tabs-banks.png" loading="lazy" ... alt="" />

<!-- TO -->
<img src="assets/images/tabs/tabs-banks.png" loading="lazy" alt="Dinero Cash banking platform interface for cross-border operations" />
```

---

## 6. CSS Additions (Add to style block or CSS file)

```css
/* Skip Navigation Link */
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  background: #000;
  color: #fff;
  padding: 8px 16px;
  text-decoration: none;
  z-index: 100;
  font-family: 'Roboto', sans-serif;
  font-size: 14px;
}

.skip-link:focus {
  top: 0;
}

/* Focus Indicators */
.button:focus,
a:focus,
input:focus,
textarea:focus,
button:focus {
  outline: 3px solid #4d90fe;
  outline-offset: 2px;
}

/* Reduced Motion Support */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }

  .hero-slider {
    animation: none !important;
  }
}

/* Button Loading State */
.button.loading {
  position: relative;
  pointer-events: none;
  opacity: 0.7;
}

.button.loading::after {
  content: "";
  position: absolute;
  width: 16px;
  height: 16px;
  top: 50%;
  left: 50%;
  margin-left: -8px;
  margin-top: -8px;
  border: 2px solid #fff;
  border-radius: 50%;
  border-top-color: transparent;
  animation: spin 0.6s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
```

---

## 7. JavaScript Improvements

### Add to script section:

```javascript
// Respect reduced motion preference
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

if (!prefersReducedMotion) {
  // Only enable auto-play if user prefers motion
  $('.hero-slider').each(function() {
    // Slider initialization
  });
}

// Pause slider on hover
$(document).ready(function() {
  $('.hero-slider').on('mouseenter', function() {
    $(this)[0].pauseAutoPlay();
  }).on('mouseleave', function() {
    $(this)[0].playAutoPlay();
  });

  // Add loading states to forms
  $('form').on('submit', function() {
    const submitBtn = $(this).find('input[type="submit"]');
    submitBtn.addClass('loading').val('Sending...');
  });
});

// ARIA improvements for mobile menu
$('.menu-button').on('click', function() {
  const isExpanded = $(this).attr('aria-expanded') === 'true';
  $(this).attr('aria-expanded', !isExpanded);
});
```

---

## 8. Fix Broken Image Paths

### Find and replace in index.html:

```bash
# Run in the website directory
sed -i '' 's|\.\.\/assets\/images|assets/images|g' index.html
sed -i '' 's|\.\.\/assets\/5f65af|assets/images|g' index.html
```

Or manually find these patterns and remove the `../`:
- `../assets/images/hero/` → `assets/images/hero/`
- `../assets/images/tabs/` → `assets/images/tabs/`

---

## 9. robots.txt (Create new file)

Create `/Users/jm/Codebase/internet-control/websites/www.dinero.cash/robots.txt`:

```txt
User-agent: *
Allow: /

Sitemap: https://www.dinero.cash/sitemap.xml
```

---

## 10. sitemap.xml (Create new file)

Create `/Users/jm/Codebase/internet-control/websites/www.dinero.cash/sitemap.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://www.dinero.cash/</loc>
    <lastmod>2026-01-16</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://www.dinero.cash/users.html</loc>
    <lastmod>2026-01-16</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>https://www.dinero.cash/agents.html</loc>
    <lastmod>2026-01-16</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>
```

---

## 11. Google Fonts Optimization

### Replace the WebFont loader:

**Remove**:
```html
<script src="assets/js/libs/webfont.js" type="text/javascript"></script>
<script type="text/javascript">WebFont.load({  google: {    families: ["Montserrat:100,100italic,200,200italic,300,300italic,400,400italic,500,500italic,600,600italic,700,700italic,800,800italic,900,900italic","Roboto:regular,500,700"]  }});</script>
```

**Add**:
```html
<link rel="preconnect" href="https://fonts.googleapis.com" crossorigin />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&family=Roboto:wght@400;500;700&display=swap" rel="stylesheet" />
```

---

## 12. Script Loading Optimization

### Add defer/async to script tags:

```html
<!-- Add defer to dependent scripts -->
<script src="assets/js/libs/jquery-3.5.1.min.js" defer></script>
<script src="assets/js/webflow.schunk.e0c428ff9737f919.js" defer></script>
<script src="assets/js/webflow.schunk.6449263ae916e6fb.js" defer></script>
<script src="assets/js/webflow.schunk.61b534daaaeddbc7.js" defer></script>
<script src="assets/js/webflow.3a4a17aa.087a1f0f61470ed1.js" defer></script>

<!-- Wrap inline scripts in DOMContentLoaded -->
<script>
document.addEventListener('DOMContentLoaded', function() {
  // Your existing inline scripts here
});
</script>
```

---

## Testing Checklist

After implementing fixes, test:

- [ ] Lighthouse score (target: 90+ all categories)
- [ ] All images load correctly (check broken paths)
- [ ] Forms submit via POST (check network tab)
- [ ] Keyboard navigation works (Tab through entire page)
- [ ] Mobile menu functions with aria-expanded toggle
- [ ] Alt text displays for all images
- [ ] Reduced motion respected (toggle in OS settings)
- [ ] All links go to valid destinations
- [ ] Google PageSpeed Insights shows improvement
- [ ] Structured data validates (https://validator.schema.org/)
