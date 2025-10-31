# Chromatic - Card Game Context

## Overview

Chromatic is a multiplayer card game where players build color paths following unique rules for each color. The game emphasizes strategic card play with exponential scoring for longer paths.

**Live URL**: http://24.199.71.69/chromatic

## Game Mechanics

### Core Rules
- Players start with a hand of 7 cards
- Deck contains 5 colors (Red, Blue, Green, Yellow, Purple) with numbers 1-20 each
- Starting a new color path costs 3 cards (you discard 2 extras)
- Scoring: (number of cards in path)² - Exponential growth!
- 10 rounds total, highest score wins

### Color-Specific Rules

1. **Red**: Must ascend with jumps (no consecutive numbers)
   - Example: 2, 5, 9, 14 ✓
   - Example: 2, 3, 5 ✗ (3 is consecutive to 2)

2. **Blue**: Waves (alternating up/down)
   - Example: 5, 10, 7, 12 ✓
   - Example: 5, 10, 15 ✗ (all ascending)

3. **Green**: Consecutive numbers only
   - Example: 5, 6, 7, 8 ✓
   - Example: 5, 7, 9 ✗ (not consecutive)

4. **Yellow**: Solo cards (max 1 card per path)
   - Useful for high-value single cards
   - Can't build long paths

5. **Purple**: Descends exponentially
   - Each card must be significantly lower (≤70% of previous)
   - Example: 20, 13, 8, 5 ✓
   - Example: 20, 18, 16 ✗ (not decreasing enough)

### Strategic Tension

- Starting a path is expensive (3 cards) but longer paths score exponentially
- 1 card = 1 point, 2 cards = 4 points, 3 cards = 9 points, 4 cards = 16 points!
- Players must balance starting multiple paths vs building longer paths
- Yellow provides a low-cost scoring option (only 1 card needed)

## Technical Architecture

### Models

**Game** (`app/models/game.rb`)
- Manages game state, turn order, scoring
- `game_state` JSON field stores: player hand, AI hand, deck, current turn
- Methods: `play_card`, `validate_card_play`, `end_turn`, `ai_play`

**ColorPath** (`app/models/color_path.rb`)
- Represents a color sequence for a player
- `cards_data` JSON field stores array of cards in path
- `score` calculated as (card count)²
- `player_type`: 'player' or 'ai'

### Controllers

**GamesController** (`app/controllers/games_controller.rb`)
- `index`: Show recent games and rules
- `show`: Display active game with player hand and paths
- `create`: Start new game
- `play_card`: Player plays a card to a color path
- `end_turn`: End player turn, trigger AI turn

### Views

- `index.html.erb`: Homepage with game rules and recent games list
- `show.html.erb`: Active game display
- `_card.html.erb`: Card partial with color selector
- `_color_path.html.erb`: Color path display partial

### AI Logic

Simple AI opponent in `Game#ai_play`:
1. Try to add cards to existing paths (valid moves)
2. If no valid moves, start a new path (if 3+ cards in hand)
3. Otherwise pass

Future improvements:
- Smarter path selection (prioritize longer paths)
- Look ahead to maximize score potential
- Card counting/tracking

## Deployment

### Stack
- Rails 8.0, Ruby 3.3.4
- SQLite database (4 separate DBs: primary, cache, queue, cable)
- Solid Queue for background jobs (Rails 8 default)
- Tailwind CSS for styling
- Systemd service: `chromatic.service`
- Nginx reverse proxy at `/chromatic`

### Database Configuration

Production SQLite databases at:
- `/home/zac/chromatic/shared/storage/production.sqlite3` (primary)
- `/home/zac/chromatic/shared/storage/production_cache.sqlite3` (cache)
- `/home/zac/chromatic/shared/storage/production_queue.sqlite3` (queue)
- `/home/zac/chromatic/shared/storage/production_cable.sqlite3` (cable)

### Deployment Process

```bash
cd /Users/zac/zac_ecosystem/apps/chromatic
git add -A && git commit -m "message"
git push
cap production deploy
```

### Server Commands

```bash
# Check service status
ssh zac@24.199.71.69 'sudo systemctl status chromatic.service'

# Restart service
ssh zac@24.199.71.69 'sudo systemctl restart chromatic.service'

# View logs
ssh zac@24.199.71.69 'tail -f /home/zac/chromatic/current/log/production.log'

# Rails console
ssh zac@24.199.71.69 'cd /home/zac/chromatic/current && RBENV_ROOT=$HOME/.rbenv RBENV_VERSION=3.3.4 $HOME/.rbenv/bin/rbenv exec bundle exec rails console -e production'
```

## Future Enhancements

### MVP+ Features
- [ ] Real multiplayer (ActionCable for real-time play)
- [ ] User accounts and authentication
- [ ] Game history and statistics
- [ ] Leaderboards
- [ ] Tournament mode

### Gameplay Improvements
- [ ] Smarter AI with difficulty levels
- [ ] Tutorial/onboarding flow
- [ ] Card animations (CSS transitions)
- [ ] Sound effects
- [ ] Mobile responsive optimizations

### UI Enhancements
- [ ] Better card hover/preview
- [ ] Drag-and-drop card play
- [ ] Path validation preview (show if card is valid before playing)
- [ ] Score prediction (show potential score before playing)
- [ ] Color blindness mode (add patterns/symbols to colors)

## Bug Fix Process

<critical>
**MANDATORY TESTING WORKFLOW** - Never skip these steps:

1. **Start Local Server**
   ```bash
   cd /Users/zac/zac_ecosystem/apps/chromatic
   bin/rails server -p 3002
   ```

2. **Reproduce Bug Locally**
   - Visit http://localhost:3002/chromatic
   - Perform the exact action that's broken
   - Document what you see vs what should happen

3. **Fix the Code**
   - Make minimal, focused changes
   - One bug per commit

4. **Verify Fix Locally** ⚠️ CRITICAL STEP
   - Refresh page in browser
   - Test the EXACT action that was broken
   - Test related functionality (don't break other things)
   - **DO NOT COMMIT unless local test passes**

5. **Commit Only After Local Verification**
   ```bash
   git add -A && git commit -m "Fix: [specific issue verified locally]"
   git push
   ```

6. **Deploy to Production**
   ```bash
   cap production deploy
   ```

7. **Verify on Production**
   - Visit http://24.199.71.69/chromatic
   - Test the same action again
   - If it doesn't work, rollback or fix immediately

8. **Update Documentation**
   - Add to "Recent Bug Fixes" section below
   - Remove from "Known Issues" section
   - Update "Last Updated" timestamp
</critical>

## Known Issues

- **End Turn button doesn't work** - Button exists in UI but action may not be triggering (reported 2025-10-14)

## Recent Bug Fixes

### 2025-10-13: Missing Tailwind CSS in Production
**Problem**: Game displayed as completely unstyled HTML (black text on white background).

**Root Cause**:
1. Tailwind CSS gem was installed but never initialized (no config file)
2. Capistrano deployment wasn't compiling Tailwind CSS during `deploy:assets:precompile`
3. Task clearing order issue: `Rake::Task['deploy:assets:precompile'].clear_actions` was called AFTER defining custom task, resulting in empty task

**Solution**:
1. Modified `config/deploy.rb` to run `rails tailwindcss:build` before `rails assets:precompile`
2. Moved `clear_actions` calls to BEFORE custom task definitions
3. Manually compiled assets on production server to fix immediate issue

**Files Changed**:
- `/Users/zac/zac_ecosystem/apps/chromatic/config/deploy.rb` (lines 53-55, 88-100)

**Verification**: http://24.199.71.69/chromatic now displays with full Tailwind CSS styling

### 2025-10-13: Asset Path Issue for Subdirectory Deployment
**Problem**: Assets referenced as `/assets/...` instead of `/chromatic/assets/...`, causing CSS not to load.

**Root Cause**:
- Rails didn't know the app was mounted under `/chromatic` subdirectory
- HTML output showed: `<link rel="stylesheet" href="/assets/tailwind-95092246.css" />`
- Should be: `<link rel="stylesheet" href="/chromatic/assets/tailwind-95092246.css" />`
- Assets were accessible at `/chromatic/assets/` via nginx but Rails wasn't generating correct paths

**Solution**:
Added `config.relative_url_root = "/chromatic"` to `config/environments/production.rb`

**Files Changed**:
- `/Users/zac/zac_ecosystem/apps/chromatic/config/environments/production.rb` (line 47)

**Verification**: Asset paths now correctly include `/chromatic` prefix. Confirmed with:
- `curl http://24.199.71.69/chromatic` shows `href="/chromatic/assets/tailwind-95092246.css"`
- `curl -I http://24.199.71.69/chromatic/assets/tailwind-95092246.css` returns 200 OK

## Development Notes

### Testing Locally

The game can be played locally:
```bash
cd /Users/zac/zac_ecosystem/apps/chromatic
bin/rails server -p 3002
# Visit http://localhost:3002/chromatic
```

### Color Validation Logic

All color rules are in `Game#validate_card_play`. Each color has specific validation:
- Red/Blue: Check direction patterns
- Green: Check if consecutive
- Yellow: Check path length limit
- Purple: Check exponential decrease

### Game Flow

1. Player selects card from hand
2. Chooses color path to play to (dropdown)
3. Game validates move
4. If valid: card added to path, score updated, card drawn
5. If starting new path: 2 extra cards discarded
6. Player ends turn
7. AI takes turn (automatic)
8. Repeat until round ends (hands empty or deck empty)
9. After 10 rounds, winner determined

---

## Recent Updates

### 2025-10-31: Gem Updates (Task #157)
**Major Updates**:
- Rails 8.0.3 → 8.1.1
- Puma 6.6.1 → 7.1.0
- RSpec 7.1.1 → 8.0.2
- Capistrano 3.18.1 → 3.19.2
- capistrano3-puma 6.0.0 → 7.1.0
- shoulda-matchers 6.5.0 → 7.0.1

**Security Patches**:
- json 2.13.2 → 2.15.2
- rubyzip 3.1.1 → 3.2.1
- selenium-webdriver 4.36.0 → 4.38.0
- Various Rails dependency updates

**Status**: Successfully deployed to production, all services running with updated versions.

---

**Last Updated**: 2025-10-31
