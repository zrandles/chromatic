# Chromatic - Recent Work

## 2025-10-13 - Fixed Game Creation Bug (500 Error)

### Problem
When clicking "Start New Game" button, users got a 500 Internal Server Error:
```
NoMethodError (undefined method `[]' for nil):
app/models/game.rb:47:in `draw_card'
app/models/game.rb:41:in `block in draw_hand'
app/models/game.rb:40:in `draw_hand'
app/models/game.rb:21:in `setup_new_game'
```

### Root Cause
The bug was in `app/models/game.rb` in the `setup_new_game` method.

**Previous (broken) code:**
```ruby
def setup_new_game
  unless game_state
    deck = create_deck
    self.game_state = {
      'deck' => deck,
      'player_hand' => [],
      'ai_hand' => [],
      'turn' => 'player'
    }

    # This line was the problem
    game_state['player_hand'] = draw_hand  # calls draw_hand which calls draw_card
    game_state['ai_hand'] = draw_hand
  end
end
```

The issue: `draw_hand` calls `draw_card`, which tries to access `game_state['deck']`. But at that point in the code, `game_state` was still being built as a local hash variable. When `draw_card` called the `game_state` accessor method, it returned `nil` because `self.game_state` hadn't been assigned yet.

### The Fix
**New (working) code:**
```ruby
def setup_new_game
  unless game_state
    # Initialize game_state with deck FIRST so draw_hand can access it
    self.game_state = {
      'deck' => create_deck,
      'player_hand' => [],
      'ai_hand' => [],
      'turn' => 'player'
    }

    # Now draw hands - game_state['deck'] is accessible
    self.game_state['player_hand'] = draw_hand
    self.game_state['ai_hand'] = draw_hand
  end
end
```

Key changes:
1. Assign `self.game_state` FIRST before calling `draw_hand`
2. Call `create_deck` inline in the hash (no intermediate variable)
3. Access `self.game_state['player_hand']` explicitly when assigning drawn hands

This ensures that when `draw_hand` → `draw_card` → `game_state['deck']` is called, the accessor method returns the properly initialized hash.

### Testing
**Local test (passed):**
```bash
$ cd /Users/zac/zac_ecosystem/apps/chromatic
$ bin/rails runner /tmp/test_chromatic_game.rb
Game created: ID=3
Player hand size: 7
AI hand size: 7
Deck size: 86
SUCCESS - Game created with no errors!
```

**Production test (passed):**
```bash
$ ssh zac@24.199.71.69 'cd /home/zac/chromatic/current && RAILS_ENV=production bundle exec rails console -e production'
> game = Game.create!
> puts "Game ID: #{game.id}, Player: #{game.player_hand.length}, AI: #{game.ai_hand.length}, Deck: #{game.game_state['deck'].length}"
Game ID: 1, Player: 7, AI: 7, Deck: 86
```

### Deployment
- Commit: `ebcb5217aabe07e9fde3285dde411bedff54d382`
- Deployed: 2025-10-13 21:32 UTC
- Files changed: `app/models/game.rb`

### Verification
- ✅ Game creation works via Rails console in production
- ✅ Game page loads correctly (http://24.199.71.69/chromatic/games/1)
- ✅ No more "undefined method `[]' for nil" errors in logs
- ✅ Player hand shows 7 cards, AI hand shows 7 cards, deck has 86 cards (correct)

### Notes
The previous session supposedly fixed this same bug, but the fix was incomplete because it didn't properly assign `self.game_state` before calling `draw_hand`. This is a reminder to always trace the full call stack when fixing initialization issues.

---

## Project Info
- **Location**: `/Users/zac/zac_ecosystem/apps/chromatic`
- **Production URL**: http://24.199.71.69/chromatic
- **Git**: github.com:zrandles/chromatic.git
