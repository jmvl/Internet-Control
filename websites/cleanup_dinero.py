#!/usr/bin/env python3
"""
Clean up and reorganize the Dinero Cash website scrape.
Creates a standard HTML/CSS folder structure with user-friendly asset names.
"""

import os
import re
import shutil
from pathlib import Path

# Configuration
SOURCE_DIR = Path("/Users/jm/Codebase/internet-control/websites/dinero.cash")
OUTPUT_DIR = Path("/Users/jm/Codebase/internet-control/websites/www.dinero.cash")

# Asset mapping: original file name -> friendly name
ASSET_MAPPINGS = {
    # Logo
    "5f64c3655d83132c7b0ce6e9_logo.svg": "logo.svg",
    "5f65c0b5fb358634729236f9_white-logo.svg": "logo-white.svg",
    "5fa3b02d308ce41c44b9a9aa_light-logo.svg": "logo-light.svg",
    "5fa3bbb68b467d40cc9ec358_Webclip 1.svg": "webclip.svg",
    "5f6893800e621b13aab5b3e7_fdc.png": "favicon.png",

    # Hero images
    "5fa292094f88bbb332f398d5_Hero Image 1-3.jpg": "hero-1.jpg",
    "5fa292094f88bbb332f398d5_Hero Image 1-3-p-500.jpeg": "hero-1-500.jpg",
    "5fa292094f88bbb332f398d5_Hero Image 1-3-p-800.jpeg": "hero-1-800.jpg",
    "5fa292094f88bbb332f398d5_Hero Image 1-3-p-1080.jpeg": "hero-1-1080.jpg",
    "5fa292094c79e119f10ab973_Hero Image 2-3.jpg": "hero-2.jpg",
    "5fa292094c79e119f10ab973_Hero Image 2-3-p-500.jpeg": "hero-2-500.jpg",
    "5fa292094c79e119f10ab973_Hero Image 2-3-p-800.jpeg": "hero-2-800.jpg",
    "5fa292094c79e119f10ab973_Hero Image 2-3-p-1080.jpeg": "hero-2-1080.jpg",
    "5fa29209453b434111cac572_Hero Image 3-3.jpg": "hero-3.jpg",
    "5fa29209453b434111cac572_Hero Image 3-3-p-500.jpeg": "hero-3-500.jpg",
    "5fa29209453b434111cac572_Hero Image 3-3-p-800.jpeg": "hero-3-800.jpg",
    "5fa29209453b434111cac572_Hero Image 3-3-p-1080.jpeg": "hero-3-1080.jpg",
    "5fa29209625e4789fcb1e7de_Hero Image 4-3.jpg": "hero-4.jpg",
    "5fa29209625e4789fcb1e7de_Hero Image 4-3-p-500.jpeg": "hero-4-500.jpg",
    "5fa29209625e4789fcb1e7de_Hero Image 4-3-p-800.jpeg": "hero-4-800.jpg",
    "5fa29209625e4789fcb1e7de_Hero Image 4-3-p-1080.jpeg": "hero-4-1080.jpg",

    # Screen/widget images
    "5fa29c1e9092a23b00cb51b0_Screen w Widgets-2.png": "screen-widgets.png",
    "5fa29c1e9092a23b00cb51b0_Screen w Widgets-2-p-500.png": "screen-widgets-500.png",
    "5fa29c1e9092a23b00cb51b0_Screen w Widgets-2-p-800.png": "screen-widgets-800.png",

    # Tab images
    "5f659eecd9d0382ecf9499ac_Tabs-i2-2.png": "tabs-users.png",
    "5f65af3daf8175b7c56a2a64_tabs-i1-2.png": "tabs-business.png",
    "5f6591747810ce9b9f3e8a52_Tabs-i3-2.png": "tabs-banks.png",

    # Cube/feature icons
    "5f66f369ae6db7460195959d_cube-wlines.svg": "cube-wlines.svg",
    "5f688f5962ef46960d05eb54_Cube with lines - vertical.svg": "cube-vertical.svg",
    "5f66f27057ebff6c672cbc9f_cube-green.svg": "cube-green.svg",
    "5f66f2722850f2cc17b34e2e_cube-blue.svg": "cube-blue.svg",
    "5f66f271fae75eb8738ecc2e_cube-purple.svg": "cube-purple.svg",
    "5f66f2703d165e7e7291fc14_cube-yellow.svg": "cube-yellow.svg",

    # Feature icons
    "5f65b1821c72cb1d526024ab_Combined Shape.svg": "icon-wallet.svg",
    "5f65b182dc4ac109bd103901_Combined Shape - white.svg": "icon-wallet-white.svg",
    "5f65b182283251e0acacf256_payments-.svg": "icon-payments.svg",
    "5f65b182a4aef8059ea41170_payments-white.svg": "icon-payments-white.svg",
    "5f65b182af469e0f8a2ad685_Path Copy 15.svg": "icon-merchant.svg",
    "5f65b1825219af2baef33c90_Path Copy white.svg": "icon-merchant-white.svg",
    "5f65b182a4aef88705a4116f_bolt.svg": "icon-onboarding.svg",
    "5f65b182dc4ac18a0a103902_bolt-white.svg": "icon-onboarding-white.svg",
    "5f65b181efb7731c1ab27441_chevron-dark.svg": "chevron-dark.svg",
    "5f65b1822832510744acf255_chevron-white.svg": "chevron-white.svg",

    # Navigation icons
    "5f64ce49818fee399e663c51_arrow-left.svg": "arrow-left.svg",
    "5f64ca1b47f9a534d4cdda9e_slider-arrow.svg": "arrow-right.svg",
    "5f66fc7c9c4691885aa7f0cb_close.svg": "close.svg",
    "5fa3b67a1125331ced04908d_close-cross.svg": "close-cross.svg",

    # Timeline icons
    "5f65b83e8783e8407a1d620f_branding.svg": "icon-branding.svg",
    "5f65b83ee0a1e128891d5d0a_process.svg": "icon-process.svg",
    "5f65b83fb90b483195889313_business.svg": "icon-business.svg",
    "5f65b83fec427832e5c39dd5_integration.svg": "icon-integration.svg",

    # Contact icons
    "5f65c1c32c6eef664f418592_telephone.svg": "icon-phone.svg",
    "5f65c1c3af8175bf516a44b5_mail.svg": "icon-mail.svg",

    # Lottie animation
    "5f688a45db403fb0a74476e8_lottieflow-menu-nav-06-635FFF-easey.json": "menu-nav.json",
    "5f659e6f2850f212b8b13055_li-2.svg": "list-bullet.svg",

    # Feature card images - Wallet
    "5f66f77afa641b35e6f83763_f-i1.png": "wallet-1.png",
    "5f66f77abc099c3a1c4af071_f-i2.png": "wallet-2.png",
    "5f66f779e22a354ee2d1031a_f-i3.png": "wallet-3.png",
    "5f66f7792984f02233b7568d_f-i4.png": "wallet-4.png",
    "5f66f7792a82084fe8b9516a_f-i5.png": "wallet-5.png",
    "5f66f77951003ef237bfe82c_f-i6.png": "wallet-6.png",

    # Feature card images - Payments
    "5f66fd606b132408af8b42b0_f2-i1.png": "payments-1.png",
    "5f66fd60ecea8f984a96461d_f2-i2.png": "payments-2.png",
    "5f66fd6003a8b2cb8589fb98_f2-i3.png": "payments-3.png",
    "5f66fd60c24a00550cf15b0c_f2-i4.png": "payments-4.png",
    "5f66fd60fae75e497f8ede34_f2-i5.png": "payments-5.png",
    "5f66fd60b6be4311d8add86e_f2-i6.png": "payments-6.png",

    # Feature card images - Merchant
    "5f66fe445c4f1e110c7d5300_f3-i1.png": "merchant-1.png",
    "5f66fe43fc6bc66f4aef5620_f3-i2.png": "merchant-2.png",
    "5f66fe44fb358622ea946687_f3-i3.png": "merchant-3.png",
    "5f66fe43ae6db77ac095a764_f3-i4.png": "merchant-4.png",
    "5f66fe433d165e6b9a92097c_f3-i5.png": "merchant-5.png",
    "5f66fe4494338ca0ba63afb3_f3-i6.png": "merchant-6.png",

    # Feature card images - Onboarding
    "5f670ebaf2ec29e070402ed0_f4-i1.png": "onboarding-1.png",
    "5f670eba3f0b542592b9e25c_f4-i2.png": "onboarding-2.png",
    "5f670ebbae6db7286a95bac9_f4-i3.png": "onboarding-3.png",
    "5f670ebb6b1324bfea8b55ca_f4-i4.png": "onboarding-4.png",
    "5f670ebad9d038aeb696f118_f4-i5.png": "onboarding-5.png",
    "5f670ebbc750e59dec1cab89_f4-i6.png": "onboarding-6.png",

    # Agents page images
    "5fa663b5191773c94738f856_1 Agents Hero-2.jpg": "agents-hero-1.jpg",
    "5fa663b5191773c94738f856_1 Agents Hero-2-p-500.jpeg": "agents-hero-1-500.jpg",
    "5fa663b5191773c94738f856_1 Agents Hero-2-p-800.jpeg": "agents-hero-1-800.jpg",
    "5fa663b5191773c94738f856_1 Agents Hero-2-p-1080.jpeg": "agents-hero-1-1080.jpg",
    "5fa663b650eeb852e1a05d52_2 Agents Hero-2.jpg": "agents-hero-2.jpg",
    "5fa663b650eeb852e1a05d52_2 Agents Hero-2-p-500.jpeg": "agents-hero-2-500.jpg",
    "5fa663b650eeb852e1a05d52_2 Agents Hero-2-p-800.jpeg": "agents-hero-2-800.jpg",
    "5fa663b650eeb852e1a05d52_2 Agents Hero-2-p-1080.jpeg": "agents-hero-2-1080.jpg",
    "5fa663b66639f6728b41ece5_3 Agents Hero-2.jpg": "agents-hero-3.jpg",
    "5fa663b66639f6728b41ece5_3 Agents Hero-2-p-500.jpeg": "agents-hero-3-500.jpg",
    "5fa663b66639f6728b41ece5_3 Agents Hero-2-p-800.jpeg": "agents-hero-3-800.jpg",
    "5fa663b66639f6728b41ece5_3 Agents Hero-2-p-1080.jpeg": "agents-hero-3-1080.jpg",
    "5fa66bf56251b044b4b54b12_agents-screen-center 1-2.png": "agents-screen-center.png",
    "5fa66e9cf9ced0c0b220a81d_cash-in.svg": "icon-cash-in.svg",
    "5fa66f1afc6e35137bb70344_cash-out.svg": "icon-cash-out.svg",
    "5fa66f1ac79d7bf66c6f8528_cash-token.svg": "icon-cash-token.svg",
    "5fa67284b73fbbac068a23eb_logo-section-bg.svg": "logo-section-bg.svg",
}

def create_output_structure():
    """Create the output directory structure."""
    dirs = [
        OUTPUT_DIR,
        OUTPUT_DIR / "assets" / "images" / "hero",
        OUTPUT_DIR / "assets" / "images" / "tabs",
        OUTPUT_DIR / "assets" / "images" / "features",
        OUTPUT_DIR / "assets" / "images" / "wallet",
        OUTPUT_DIR / "assets" / "images" / "payments",
        OUTPUT_DIR / "assets" / "images" / "merchant",
        OUTPUT_DIR / "assets" / "images" / "onboarding",
        OUTPUT_DIR / "assets" / "images" / "agents",
        OUTPUT_DIR / "assets" / "icons",
        OUTPUT_DIR / "assets" / "css",
        OUTPUT_DIR / "assets" / "js" / "libs",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)
    print(f"Created directory structure in {OUTPUT_DIR}")


def determine_destination(friendly_name, ext):
    """Determine the destination directory for an asset."""
    if 'hero' in friendly_name.lower() and friendly_name.startswith('hero'):
        return OUTPUT_DIR / "assets" / "images" / "hero"
    elif friendly_name.startswith('tabs-'):
        return OUTPUT_DIR / "assets" / "images" / "tabs"
    elif friendly_name.startswith('wallet-'):
        return OUTPUT_DIR / "assets" / "images" / "wallet"
    elif friendly_name.startswith('payments-'):
        return OUTPUT_DIR / "assets" / "images" / "payments"
    elif friendly_name.startswith('merchant-'):
        return OUTPUT_DIR / "assets" / "images" / "merchant"
    elif friendly_name.startswith('onboarding-'):
        return OUTPUT_DIR / "assets" / "images" / "onboarding"
    elif friendly_name.startswith('agents-'):
        return OUTPUT_DIR / "assets" / "images" / "agents"
    elif ext == '.svg':
        return OUTPUT_DIR / "assets" / "icons"
    elif ext in ['.png', '.jpg', '.jpeg', '.gif', '.webp']:
        return OUTPUT_DIR / "assets" / "images"
    elif ext == '.css':
        return OUTPUT_DIR / "assets" / "css"
    elif ext == '.js':
        return OUTPUT_DIR / "assets" / "js"
    else:
        return OUTPUT_DIR / "assets"


def copy_mapped_assets():
    """Copy all mapped assets to output directory."""
    cdn_dir = SOURCE_DIR / "cdn.prod.website-files.com" / "5f64c17b5fb4b057b9e5486e"
    if not cdn_dir.exists():
        print("CDN directory not found!")
        return {}

    asset_mappings = {}
    copied_count = 0

    # Build a mapping of all files in the CDN directory (normalize names)
    all_files = {}
    for f in cdn_dir.iterdir():
        if f.is_file():
            # Store both original name and lowercased version for matching
            all_files[f.name] = f
            all_files[f.name.replace('%20', ' ')] = f

    print(f"Found {len(all_files)} files in CDN directory")

    for original_name, friendly_name in ASSET_MAPPINGS.items():
        source_file = None

        # Try exact match first
        if original_name in all_files:
            source_file = all_files[original_name]
        # Try with spaces instead of %20
        elif original_name.replace('%20', ' ') in all_files:
            source_file = all_files[original_name.replace('%20', ' ')]
        # Try with %20 instead of spaces
        elif original_name.replace(' ', '%20') in all_files:
            source_file = all_files[original_name.replace(' ', '%20')]

        if source_file and source_file.exists():
            ext = source_file.suffix
            dest_dir = determine_destination(friendly_name, ext)
            dest_file = dest_dir / friendly_name

            shutil.copy2(source_file, dest_file)
            rel_path = dest_file.relative_to(OUTPUT_DIR)
            asset_mappings[f"cdn.prod.website-files.com/5f64c17b5fb4b057b9e5486e/{original_name}"] = str(rel_path)
            copied_count += 1
            print(f"Copied: {original_name[:50]:50} -> {rel_path}")
        else:
            print(f"NOT FOUND: {original_name}")

    print(f"\nCopied {copied_count} mapped assets")
    return asset_mappings


def copy_css_js_files():
    """Copy all CSS and JS files."""
    cdn_dir = SOURCE_DIR / "cdn.prod.website-files.com"
    if not cdn_dir.exists():
        return {}

    asset_mappings = {}

    # Copy CSS files
    for css_file in cdn_dir.rglob("*.css"):
        rel_path = css_file.relative_to(SOURCE_DIR)
        dest_file = OUTPUT_DIR / "assets" / "css" / css_file.name
        dest_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(css_file, dest_file)
        final_rel_path = dest_file.relative_to(OUTPUT_DIR)
        asset_mappings[str(rel_path).replace("\\", "/")] = str(final_rel_path)
        print(f"Copied CSS: {css_file.name}")

    # Copy JS files (from CDN directory only)
    cdn_js_dir = SOURCE_DIR / "cdn.prod.website-files.com" / "5f64c17b5fb4b057b9e5486e" / "js"
    if cdn_js_dir.exists():
        for js_file in cdn_js_dir.glob("*.js"):
            dest_file = OUTPUT_DIR / "assets" / "js" / js_file.name
            shutil.copy2(js_file, dest_file)
            rel_path = f"cdn.prod.website-files.com/5f64c17b5fb4b057b9e5486e/js/{js_file.name}"
            final_rel_path = dest_file.relative_to(OUTPUT_DIR)
            asset_mappings[rel_path] = str(final_rel_path)
            print(f"Copied JS: {js_file.name}")

    # Copy external libraries
    externals = [
        ("ajax.googleapis.com/ajax/libs/webfont/1.6.26/webfont.js", "assets/js/libs/webfont.js"),
        ("d3e54v103j8qbb.cloudfront.net/js/jquery-3.5.1.min.dc5e7f18c8%EF%B9%96site=5f64c17b5fb4b057b9e5486e.js", "assets/js/libs/jquery-3.5.1.min.js"),
    ]

    for original, dest in externals:
        # Build the full path from SOURCE_DIR
        source_file = SOURCE_DIR
        for part in original.split('/'):
            source_file = source_file / part
            # Only stop if we've found a FILE, not a directory
            if source_file.exists() and source_file.is_file():
                break
            # Continue building path if it's a directory or doesn't exist yet
        if source_file.exists() and source_file.is_file():
            dest_file = OUTPUT_DIR / dest
            dest_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_file, dest_file)
            asset_mappings[original] = dest
            print(f"Copied external: {original[:40]}...")

    return asset_mappings


def update_html_files(asset_mappings):
    """Update HTML files with new asset paths."""
    html_dir = SOURCE_DIR / "dinerocash.webflow.io"
    if not html_dir.exists():
        print("HTML directory not found!")
        return

    for html_file in html_dir.glob("*.html"):
        if html_file.name == '_downloads.html':
            continue
        print(f"Processing: {html_file.name}")
        content = html_file.read_text(encoding='utf-8')

        # Replace asset paths
        for original_path, new_path in asset_mappings.items():
            # Handle various URL encodings
            original_patterns = [
                original_path,
                original_path.replace("%20", " "),
                original_path.replace("%20", "%20"),
                original_path.replace(" ", "%20"),
                original_path.replace(" ", " "),
                original_path.replace("%EF%B9%96", "?"),
            ]

            rel_path = f"../{new_path}"
            for pattern in original_patterns:
                content = content.replace(f"../{pattern}", rel_path)
                content = content.replace(pattern, new_path)

        # Also update srcset attributes
        for original_path, new_path in asset_mappings.items():
            original_clean = original_path.replace("%20", " ").replace("%EF%B9%96", "?")
            new_path_clean = new_path.replace("%20", " ")
            rel_path = f"../{new_path_clean}"
            content = re.sub(
                re.escape(original_clean) + r"(\s+\d+w)",
                lambda m: rel_path + m.group(1),
                content
            )

        # Write updated HTML
        output_file = OUTPUT_DIR / html_file.name
        output_file.write_text(content, encoding='utf-8')
        print(f"  -> Updated: {output_file}")


def main():
    """Main cleanup function."""
    print("Starting Dinero Cash website cleanup...")
    print(f"Source: {SOURCE_DIR}")
    print(f"Output: {OUTPUT_DIR}")
    print()

    # Clean output directory first
    if OUTPUT_DIR.exists():
        shutil.rmtree(OUTPUT_DIR)

    # Create output structure
    create_output_structure()

    # Copy mapped assets (images, icons)
    print("\nCopying mapped assets (images, icons)...")
    mapped_assets = copy_mapped_assets()

    # Copy CSS and JS files
    print("\nCopying CSS and JS files...")
    css_js_assets = copy_css_js_files()

    # Merge mappings
    all_mappings = {**mapped_assets, **css_js_assets}

    # Update HTML files
    print("\nUpdating HTML files...")
    update_html_files(all_mappings)

    print("\n" + "="*60)
    print("✅ Cleanup complete!")
    print("="*60)
    print(f"\nOutput structure:")
    print(f"  {OUTPUT_DIR}/")
    print(f"    index.html")
    print(f"    users.html")
    print(f"    agents.html")
    print(f"    assets/")
    print(f"      css/")
    print(f"      js/")
    print(f"      js/libs/")
    print(f"      images/")
    print(f"      images/hero/")
    print(f"      images/tabs/")
    print(f"      images/wallet/")
    print(f"      images/payments/")
    print(f"      images/merchant/")
    print(f"      images/onboarding/")
    print(f"      images/agents/")
    print(f"      icons/")


if __name__ == "__main__":
    main()
