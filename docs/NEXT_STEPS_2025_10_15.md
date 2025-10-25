# Chromatic - Current State & Next Steps

## Current Session Summary

### What We've Accomplished Today

**Major Features Implemented:**
1. ✅ AI auto-play full turn after player action
2. ✅ Auto-discard remaining cards on End Turn
3. ✅ Rules toggle persistence (localStorage)
4. ✅ All 5 color paths always visible
5. ✅ Starter hints for empty paths
6. ✅ Sticky End Turn button (always visible)
7. ✅ Empty deck handling (no getting stuck)

**UI Polish Completed:**
1. ✅ Reduced vertical white space (~165px saved)
2. ✅ Removed visual clutter (25+ elements)
3. ✅ Path cost inline with color title
4. ✅ Red End Turn button when cards remain
5. ✅ Removed pulsing badges and unnecessary text

**Code Quality:**
- ✅ Rails Expert code review & refactoring
- ✅ Model logic properly separated from controllers
- ✅ Thin controllers following Rails best practices
- ✅ UX Expert testing & visual analysis

---

## Current Issue Discovered

### Problem: Game Gets Stuck with Unplayable Cards

**User Report**: "I have 2 unplayable cards and i've started 4 paths, so i can't keep going"

**Root Cause Analysis:**

1. **Current Card Draw Mechanics:**
   - Draw 1 card when playing a card to existing path (line 164-169 in game.rb)
   - Draw N cards when starting a new path (based on how many discarded, line 131-139)
   - Draw 1 card per card discarded on discard_and_draw

2. **Current End Turn Behavior:**
   - Auto-discard all remaining cards
   - Draw up to deck size (could be 0-10 cards depending on deck state)
   - No minimum hand refill guarantee

3. **Problem Scenario:**
   ```
   Player state:
   - 2 unplayable cards in hand
   - 4 paths started (5th path costs 4 cards to start)
   - Can't play either card (wrong colors or invalid values)
   - Can't start new path (need 4 cards, only have 2)
   - Stuck!

   Current "solution": End Turn
   - Discards 2 cards
   - Draws 2 cards (might still be unplayable)
   - No guarantee of progress
   ```

4. **Why This Happens:**
   - Hand size is 10 at start
   - Playing cards draws only 1 replacement
   - Hand naturally shrinks when starting paths (discard multiple, draw fewer)
   - No hand refill mechanism to maintain playable hand size

---

## Proposed Solution

### Guarantee Minimum Hand Size on End Turn

**Goal**: Ensure player always has at least 5 cards after End Turn

**Implementation Plan:**

```ruby
# In Game model (app/models/game.rb)

def handle_end_turn
  # Auto-discard all remaining cards if deck has cards
  if game_state['deck'].any?
    discard_all_and_draw('player')
  else
    # Deck empty, just clear hand
    player_hand.clear
  end

  # REFILL HAND TO MINIMUM SIZE (NEW LOGIC)
  min_hand_size = 5
  cards_needed = min_hand_size - player_hand.length

  if cards_needed > 0
    cards_needed.times do
      drawn = draw_card(save_after: false)
      break unless drawn  # Deck empty
      player_hand << drawn
    end
  end

  # AI plays full turn
  ai_play_full_turn

  save
end
```

**Rationale:**
- Guarantees minimum 5 cards per turn (enough to make progress)
- Still allows deck depletion (draws until empty if needed)
- Prevents "stuck with unplayable cards" scenario
- Maintains strategic tension (deck is still limited)

**Alternative: Higher Minimum**
- Could use 7 cards (70% of starting hand)
- Could use 10 cards (full hand refill)
- Trade-off: Higher = easier, but less deck scarcity tension

---

## Questions to Resolve

### 1. What Should the Minimum Hand Size Be?

**Options:**
- **5 cards**: Ensures basic playability, maintains scarcity
- **7 cards**: More comfortable, closer to starting hand
- **10 cards**: Full refill, removes hand management entirely

**Recommendation**: Start with 5, adjust based on playtesting

---

### 2. Should We Refill After Playing Cards Too?

**Current**: Play card → draw 1 → hand shrinks over time

**Alternative**: Always maintain minimum hand size after any action

**Considerations:**
- Pro: Never get stuck
- Con: Removes hand management as strategic element
- Con: Deck depletes faster

**Recommendation**: Only refill on End Turn (keeps hand management interesting)

---

### 3. Should AI Get Same Treatment?

**Current**: AI has same draw mechanics as player

**Options:**
- **Same rules**: Fair, but AI might get stuck too
- **Smarter AI**: AI checks if move leads to stuck state
- **Different rules**: AI always has minimum hand (unfair to player)

**Recommendation**: Same rules for fairness, improve AI decision-making separately

---

## Implementation Tasks

### Task 1: Update End Turn Hand Refill
**File**: `app/models/game.rb`
**Method**: `handle_end_turn` (lines 365-379)
**Change**: Add minimum hand size refill logic

### Task 2: Test Locally
- Start game, play until 4 paths started
- Get stuck with 2 unplayable cards
- Click End Turn
- Verify hand refills to at least 5 cards

### Task 3: Update Constants
**File**: `app/models/game.rb`
**Add constant**: `MIN_HAND_SIZE = 5` (near line 8)
**Use constant**: In `handle_end_turn` logic

### Task 4: Consider UI Feedback
**Show in UI**: "Drew 3 cards to refill hand" (flash message)
**OR**: Silent refill (just happens automatically)

**Recommendation**: Silent (less noise), maybe add to deck status indicator

---

## Potential Future Improvements

### Improvement 1: Smarter Discard on End Turn
**Current**: Discards all cards (might discard useful ones)
**Future**: Keep cards that can extend existing paths, discard truly dead cards

### Improvement 2: Hand Size Indicator
**Current**: Shows count in hand section title
**Future**: Show "Hand: 7/10" or similar (current/max)

### Improvement 3: "Pass" Action
**Current**: Must End Turn to progress when stuck
**Future**: Allow "Pass" (don't discard, just end turn and draw)

---

## Testing Notes

**Current Game State to Reproduce Issue:**
- Play to Round 2-3
- Start 4 paths (use up most of hand starting costs)
- Try to continue with remaining 2 cards
- If both are unplayable → stuck

**Expected After Fix:**
- Same scenario, but End Turn draws up to 5 cards
- Should have more options to continue

---

## Decision Needed

**Before implementing, need to decide:**
1. Minimum hand size: 5, 7, or 10 cards?
2. Refill on every action or only on End Turn?
3. Should AI get same treatment?
4. Should we show UI feedback for refills?

**Recommendation**:
- 5 cards minimum
- Only on End Turn
- Same for AI
- Silent refill

Ready to implement once confirmed!
