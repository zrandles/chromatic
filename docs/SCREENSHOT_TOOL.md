# Screenshot Tool Documentation

## Purpose

Visual feedback tool for UX analysis and debugging. Captures full-page screenshots of the Chromatic app at different viewport sizes.

## Installation

First run auto-installs Puppeteer (~50MB). Subsequent runs are instant.

## Usage

```bash
# Basic usage - screenshots localhost:3000/<path>
bin/screenshot <path>

# Desktop viewport (default: 1280x800)
bin/screenshot /
bin/screenshot /games/1

# Mobile viewport (iPhone SE size)
bin/screenshot / --width 375 --height 667

# Tablet viewport (iPad)
bin/screenshot / --width 768 --height 1024

# Custom port (if server running on different port)
bin/screenshot / --port 3005

# Custom output path
bin/screenshot / --output /tmp/my_screenshot.png

# Full URL (not localhost)
bin/screenshot --url https://example.com
```

## Common Viewports

```bash
# Desktop (default)
--width 1280 --height 800

# Mobile - iPhone SE
--width 375 --height 667

# Mobile - iPhone 12/13/14
--width 390 --height 844

# Tablet - iPad
--width 768 --height 1024

# Desktop Large
--width 1920 --height 1080
```

## Output

Screenshots saved to `/tmp/chromatic_<sanitized_path>_<viewport>.png`

Example outputs:
- `/tmp/chromatic__.png` (root path, desktop)
- `/tmp/chromatic__games_1.png` (game page, desktop)
- `/tmp/chromatic__375x667.png` (root path, mobile)

## Integration with Claude Code

Screenshots are readable by Claude Code's Read tool:

```
Read tool → /tmp/chromatic_home.png
```

Claude Code will display the image and can analyze:
- Visual hierarchy
- Layout issues
- Color contrast
- Text readability
- Responsive design
- Spacing problems

## Use Cases

1. **UX Analysis** - Capture before making changes, verify after
2. **Responsive Testing** - Check mobile, tablet, desktop layouts
3. **Visual Regression** - Compare screenshots over time
4. **Documentation** - Share visual state with stakeholders
5. **Debugging** - See exactly what users see

## How It Works

1. Ruby wrapper (`bin/screenshot`) parses arguments
2. Auto-installs Puppeteer if not present
3. Runs Node.js script (`lib/screenshot.js`) with Puppeteer
4. Puppeteer launches headless Chrome
5. Navigates to URL and waits for page load
6. Captures full-page screenshot
7. Saves to specified output path

## Files

- `bin/screenshot` - Ruby CLI wrapper
- `lib/screenshot.js` - Node.js Puppeteer script
- `node_modules/puppeteer` - Headless Chrome automation

## Requirements

- Node.js (available via nvm: v22.14.0)
- npm/npx
- ~100MB disk space for Puppeteer + Chrome

## Future Enhancements

Possible additions:
- Screenshot comparison (diff two images)
- Batch screenshots (multiple pages at once)
- Wait for specific elements before capturing
- JavaScript execution before screenshot
- PDF generation
- Video recording of user flows
