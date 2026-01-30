# Design System: Cyber-Minimalist Tech Landing Page

## Design Philosophy
**"Dark Mode Futurism"** - A premium, tech-forward aesthetic that combines the depth of near-black backgrounds with vibrant green accents to convey innovation, sophistication, and confidence. The design embraces bold typography, high contrast, and generous negative space to create immediate visual impact and memorability.

**Core Principles**:
- **Bold Simplicity**: One dominant accent color, not a rainbow
- **Typographic Scale**: Massive headlines that command attention
- **Depth & Atmosphere**: Layered backgrounds create visual intrigue
- **Strategic Restraint**: Every element earns its place through purpose

---

## Color Palette

### Primary Colors
| Color Name | Hex | Usage |
|------------|-----|-------|
| Background Primary | `#0a1a12` | Deep dark green-black - the canvas |
| Background Card | `#0f2418` | Slightly lifted dark green for depth |
| Accent Green | `#00cc66` | Vibrant green - the brand signature |

### Secondary Colors
| Color Name | Hex | Usage |
|------------|-----|-------|
| Background Elevated | `#142a1e` | For hover states and raised elements |
| Accent Green Dark | `#00a352` | For button hover states |

### Text Colors
| Color Name | Hex | Usage |
|------------|-----|-------|
| Text Primary | `#ffffff` | Pure white for headlines and emphasis |
| Text Secondary | `#cccccc` | Light gray for body text |
| Text Tertiary | `#888888` | Muted gray for captions and metadata |

### Functional Colors
| Color Name | Hex | Usage |
|------------|-----|-------|
| Success | `#00cc66` | Reuses accent green for consistency |
| Warning | `#ffb347` | Warm orange for alerts |
| Error | `#ff4d4d` | Clear red for destructive actions |
| Border Subtle | `#1a3326` | Nearly invisible borders for separation |

### CSS Variables
```css
:root {
  --bg-primary: #0a1a12;
  --bg-card: #0f2418;
  --bg-elevated: #142a1e;
  --accent-green: #00cc66;
  --accent-green-dark: #00a352;
  --text-primary: #ffffff;
  --text-secondary: #cccccc;
  --text-tertiary: #888888;
  --border-subtle: #1a3326;
  --color-success: #00cc66;
  --color-warning: #ffb347;
  --color-error: #ff4d4d;
}
```

---

## Typography

### Font Family
- **Display/Headline Font**: **Montserrat** (Bold 700+, Extrabold 800)
- **Body/Navigation Font**: **Inter** or **Roboto** (Regular 400, Medium 500)
- **Alternative**: **Manrope** for a tech-forward geometric alternative

### Rationale
- **Montserrat** provides geometric precision and commanding presence at large sizes
- **Inter/Roboto** ensures readability for smaller UI text and navigation
- The pairing creates hierarchy: commanding headlines, supportive body text

### Font Weights
- **Regular:** 400 (Body text, descriptions)
- **Medium:** 500 (Navigation, buttons, emphasis)
- **Semibold:** 600 (Subheadings, card titles)
- **Bold:** 700 (Primary headlines)
- **Extrabold:** 800 (Hero headlines only)

---

## Text Styles

### Headings
| Style | Size/Line-height | Weight | Letter Spacing | Usage |
|-------|-----------------|--------|----------------|-------|
| Hero H1 | 72px/80px | Extrabold 800 | -1px | Main hero headline - "CYBERNETICS REIMAGINED" |
| Section H1 | 48px/56px | Bold 700 | -0.5px | Major section headers |
| H2 | 32px/40px | Semibold 600 | -0.3px | Card titles and feature headers |
| H3 | 24px/32px | Semibold 600 | -0.2px | Subsection headers |

### Body Text
| Style | Size/Line-height | Weight | Letter Spacing | Usage |
|-------|-----------------|--------|----------------|-------|
| Body Large | 18px/28px | Regular 400 | 0 | Primary reading text, descriptions |
| Body | 16px/24px | Regular 400 | 0 | Standard body text |
| Body Small | 14px/20px | Regular 400 | 0 | Secondary information, metadata |

### Special Text
| Style | Size/Line-height | Weight | Letter Spacing | Usage |
|-------|-----------------|--------|----------------|-------|
| Navigation | 14px/20px | Medium 500 | 0.5px | Navigation links (ALL CAPS) |
| Button Text | 16px/24px | Medium 500 | 0.3px | Call-to-action buttons |
| Metric Display | 48px/56px | Bold 700 | 0 | Large numbers/stats (e.g., "500,000+") |

---

## Component Styling

### Buttons

#### Primary CTA Button
- **Background:** Accent Green (`#00cc66`)
- **Text:** White (`#ffffff`)
- **Height:** 52px
- **Padding:** 24px horizontal, 14px vertical
- **Corner Radius:** 4px (subtle - almost square)
- **Border:** None
- **Shadow:** Subtle glow `0 4px 20px rgba(0, 204, 102, 0.3)`
- **Hover State:** Background `#00a352`, Shadow `0 6px 24px rgba(0, 204, 102, 0.4)`, Scale `1.02`
- **Transition:** 250ms cubic-bezier(0.4, 0, 0.2, 1)

#### Secondary (Outline) Button
- **Background:** Transparent
- **Border:** 1px solid Accent Green (`#00cc66`)
- **Text:** Accent Green (`#00cc66`)
- **Height:** 48px
- **Padding:** 20px horizontal, 12px vertical
- **Corner Radius:** 4px
- **Hover State:** Background `rgba(0, 204, 102, 0.1)`, Border color `#00a352`

#### Ghost Button
- **Background:** Transparent
- **Text:** Text Secondary (`#cccccc`)
- **Hover State:** Text `#ffffff`

### Cards
- **Background:** Card Background (`#0f2418`)
- **Border:** 1px solid Border Subtle (`#1a3326`)
- **Corner Radius:** 12px
- **Padding:** 32px
- **Shadow:** `0 8px 32px rgba(0, 0, 0, 0.4)` (deep shadow for depth)
- **Hover State:** Background `#142a1e`, Border `#00cc66`, Transform `translateY(-4px)`
- **Transition:** 300ms cubic-bezier(0.4, 0, 0.2, 1)

### Navigation
- **Logo:** Text Primary, Bold, with accent chevron icon
- **Nav Links:** Text Secondary, Medium 500, ALL CAPS, 8px letter spacing
  - *Hover State:* Text Primary, underline animation (2px bottom border expands from center)
- **Contact Button:** Same as Primary CTA but smaller (40px height)

### Icons
- **Primary Icons:** 24px × 24px
- **Small Icons:** 16px × 16px
- **Hero/Feature Icons:** 48px × 48px and larger
- **Default Color:** Accent Green (`#00cc66`)
- **Inactive Color:** Text Tertiary (`#888888`)

---

## Spacing System

**8px Base Unit** - All spacing derives from multiples of 8

| Token | Value | Usage |
|-------|-------|-------|
| `--space-xs` | 8px | Icon padding, tight gaps |
| `--space-sm` | 16px | Card padding, internal spacing |
| `--space-md` | 24px | Default margins, component gaps |
| `--space-lg` | 32px | Section spacing |
| `--space-xl` | 48px | Major section separation |
| `--space-2xl` | 64px | Screen edges, hero padding |
| `--space-3xl` | 96px | Dramatic separation |

---

## Layout & Grid

### Container
- **Max Width:** 1280px (for large screens)
- **Padding:** 32px on sides (mobile), 64px (desktop)

### Header Layout
- **Structure:** Flexbox, space-between
- **Height:** 80px
- **Logo:** Left-aligned
- **Nav:** Centered
- **CTA:** Right-aligned

### Hero Section
- **Layout:** Flex column, centered
- **Min Height:** 80vh
- **Text Alignment:** Center
- **Max Width:** 900px for text content

### Feature Cards Grid
- **Desktop:** 3-column grid, `repeat(3, 1fr)`
- **Tablet:** 2-column grid
- **Mobile:** 1-column stack
- **Gap:** 24px

---

## Motion & Animation

### Transitions
- **Standard:** 250ms cubic-bezier(0.4, 0, 0.2, 1)
- **Emphasis:** 350ms cubic-bezier(0.34, 1.56, 0.64, 1) (spring)
- **Entry:** 400ms ease-out with stagger delay

### Animations

#### Hero Load Sequence (Staggered Entry)
```css
.hero-line { animation: fadeInUp 600ms ease-out forwards; }
.hero-headline { animation: fadeInUp 700ms ease-out 100ms forwards; opacity: 0; }
.hero-subtext { animation: fadeInUp 700ms ease-out 200ms forwards; opacity: 0; }
.hero-cta { animation: fadeInUp 700ms ease-out 300ms forwards; opacity: 0; }

@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(30px); }
  to { opacity: 1; transform: translateY(0); }
}
```

#### Hover Microinteractions
- **Buttons:** Scale 1.02, shadow intensifies
- **Cards:** Lift 4px, border glows with accent color
- **Nav Links:** Underline expands from center (width 0 → 100%)

#### Background Effects
- **Subtle Drift:** Background graphics slowly move (parallax-style)
- **Pulse:** Accent elements gently pulse (scale 1 → 1.05 → 1)

---

## Visual Effects

### Background
- **Base:** Solid `#0a1a12`
- **Overlay:** Subtle radial gradient `radial-gradient(circle at 30% 40%, rgba(0, 204, 102, 0.08) 0%, transparent 50%)`
- **Texture:** Optional noise overlay for depth (1-2% opacity)

### Glow Effects
- **Accent Glow:** `box-shadow: 0 0 40px rgba(0, 204, 102, 0.2)`
- **Card Glow (Hover):** `box-shadow: 0 0 30px rgba(0, 204, 102, 0.15), 0 8px 32px rgba(0, 0, 0, 0.4)`

### Borders
- **Subtle:** 1px solid `rgba(255, 255, 255, 0.05)`
- **Accent:** 1px solid `#00cc66` (for focused/active states)

---

## Responsive Breakpoints

| Breakpoint | Width | Adjustments |
|------------|-------|-------------|
| **Mobile** | < 640px | Single column, reduced font sizes (H1: 42px), compact spacing |
| **Tablet** | 640px - 1024px | 2-column grids, medium font scaling |
| **Desktop** | 1024px - 1440px | Full layout, 3-column grids |
| **Wide** | > 1440px | Max container 1280px, increased spacing |

---

## Accessibility

### Color Contrast
- All text meets **WCAG AA** (4.5:1 minimum)
- Accent green on dark background passes AAA
- White text on dark backgrounds passes AAA

### Focus States
- **Outline:** 2px solid Accent Green, offset 2px
- **Skip Link:** Visible on focus, top-left position

### Motion Preferences
- Respect `prefers-reduced-motion` - disable animations for users who prefer reduced motion

### Semantic HTML
- Use proper heading hierarchy (h1 → h2 → h3)
- Buttons for actions, links for navigation
- ARIA labels for icon-only buttons

---

## Component Code Examples

### Primary Button CSS
```css
.btn-primary {
  background: var(--accent-green);
  color: var(--text-primary);
  height: 52px;
  padding: 14px 24px;
  border-radius: 4px;
  border: none;
  box-shadow: 0 4px 20px rgba(0, 204, 102, 0.3);
  transition: all 250ms cubic-bezier(0.4, 0, 0.2, 1);
}

.btn-primary:hover {
  background: var(--accent-green-dark);
  box-shadow: 0 6px 24px rgba(0, 204, 102, 0.4);
  transform: scale(1.02);
}
```

### Card CSS
```css
.card {
  background: var(--bg-card);
  border: 1px solid var(--border-subtle);
  border-radius: 12px;
  padding: 32px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
  transition: all 300ms cubic-bezier(0.4, 0, 0.2, 1);
}

.card:hover {
  background: var(--bg-elevated);
  border-color: var(--accent-green);
  transform: translateY(-4px);
}
```

---

## Summary

This design system captures the essence of the cyber-minimalist aesthetic: **bold, restrained, and memorable**. The single accent color strategy, massive typography, and dark theme depth create a premium tech-forward experience that stands apart from generic designs.

### Key Differentiators
1. **Single Accent Color Commitment** - The green becomes synonymous with the brand
2. **Massive Typographic Scale** - Headlines that dominate and command attention
3. **Deep Dark Mode First** - Not an afterthought, but the foundation
4. **Strategic Restraint** - Every element serves a purpose; nothing is decorative filler
