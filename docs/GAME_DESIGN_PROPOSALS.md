# Chromatic Game Design Proposals
**Date**: 2025-10-15
**Designer**: Game Design Expert
**Purpose**: Add strategic depth and meaningful decisions to Chromatic

---

## Executive Summary

**Problem**: Chromatic has a polished interface (7/10 UX) but shallow gameplay (3/10 strategic depth). Players correctly perceive the game as luck-driven with boring optimal strategies.

**Root Cause**: The combo multiplier system (2.0x for 5 paths) creates a dominant "start many paths" strategy that's more rewarding than the intended "extend paths for exponential scoring" strategy.

**Solution**: 5 concrete mechanical changes that:
- Balance the risk/reward of starting vs. extending paths
- Add meaningful decision points (not just "play whatever fits")
- Make Blue and Yellow viable strategies
- Give players control over randomness
- Create strategic persistence across rounds

**Expected Outcome**: Game where skilled players consistently beat AI by making better decisions about path focus, card management, and timing.

---

## Current State Analysis

### The Dominant Strategy Problem

**Math Breakdown**:
```
Strategy A: Start 5 Paths (1 card each)
- Base score: 5 × (1²) = 5 pts
- Rainbow multiplier: 2.0x
- Total: 10 pts
- Cards used: 5 × 2 = 10 cards (starting cost)

Strategy B: Extend Paths (4 cards in 2 paths)
- Base score: 2 × (4²) = 32 pts
- Path multiplier: 1.2x (only 2 colors)
- Total: 38.4 pts
- Cards used: 2 × 2 (start) + 6 (extensions) = 10 cards

Wait... Strategy B should win!
```

**But it doesn't work because**:
- Extending requires SPECIFIC cards (Red needs 5→7→10→15)
- 10-card hand rarely contains 3+ extension cards for same color
- Players forced to start multiple paths because they can't extend
- Result: Best achievable strategy is 5×1-card paths (15 pts)

**The Real Problem**: The game WANTS you to extend paths (exponential scoring) but FORCES you to start many paths (restrictive rules + small hand).

### User Complaints Mapped to Design Flaws

| User Complaint | Game Design Issue | Fix Priority |
|---|---|---|
| "Almost no interesting decisions" | Random hand + restrictive rules = play whatever fits | HIGH |
| "Pairs/multiples impossible" | Blue/Yellow require lucky draws (2-3% chance) | HIGH |
| "What's the point of deck?" | Deck resets, paths clear, no persistence | MEDIUM |
| "Too easy" (implied) | AI doesn't punish bad strategy | LOW |

---

## Proposed Mechanical Changes

### Proposal 1: Dynamic Starting Cost (HIGH PRIORITY)

**Problem**: 2-card starting cost is fixed, making starting paths always costly regardless of strategy.

**Solution**: Starting cost scales with how many paths you already have.
```
1st path: FREE (0 cards)
2nd path: 1 card
3rd path: 2 cards
4th path: 3 cards
5th path: 4 cards
Total cost for 5 paths: 0+1+2+3+4 = 10 cards
```

**Why This Works**:
- **Early game**: Easy to start diverse paths (learn colors, explore options)
- **Mid game**: Meaningful choice: "Start 5th path for 4 cards OR extend existing path?"
- **Balances strategies**: 5-path rainbow strategy now costs 10 cards (vs. current 10 cards for 5 paths)
- **Psychological**: First path feels like a gift (positive feedback)

**Mathematical Impact**:
```
Current: 5 paths × 1 card = 5 pts × 2.0x = 10 pts (cost: 10 cards)
Proposed: 5 paths × 1 card = 5 pts × 2.0x = 10 pts (cost: 10 cards)

BUT extending becomes more attractive:
- Start 3 paths (cost: 0+1+2 = 3 cards)
- Extend 1 path to 4 cards (cost: 3 cards)
- Total: 3×(1²) + 1×(4²) = 3 + 16 = 19 pts × 1.4x = 26.6 pts (cost: 6 cards)
```

**Game Design Principle**: Progressive cost increases tension (like bidding in auction games). Forces interesting tradeoffs at 3-4 paths.

**Implementation Complexity**: SIMPLE (change one constant to a method)

---

### Proposal 2: "Hold 3 Cards" Between Rounds (HIGH PRIORITY)

**Problem**: Deck resets, paths clear, no strategic continuity. "What's the point of planning?"

**Solution**: At end of round, choose 3 cards from your hand to keep for next round.

**Why This Works**:
- **Meaningful end-of-round decision**: "Which cards give me best start next round?"
- **Long-term strategy**: Build toward Yellow sequence over multiple rounds
- **Skill expression**: Good players identify valuable cards (pairs, sequences)
- **Reduces frustration**: Got Blue pair but no path? Save them for Round 2!

**Example Gameplay**:
```
Round 1 End: You have Blue 7, Blue 7, Green 5, Yellow 3, Purple 12
Decision: Keep Blue 7, Blue 7, Yellow 3
Strategy: Start Round 2 with Blue pair (instant 2-card path!) + Yellow sequence starter

Round 2 Start: Draw 7 new cards + your 3 held cards = 10-card hand
Now you can: Play Blue 7+7 immediately (4 pts from 2-card path), continue Yellow sequence
```

**Game Design Principle**: "Card drafting lite" - gives players agency over randomness without complex drafting mechanics.

**Implementation Complexity**: MEDIUM (add hold selection UI + carry forward logic)

---

### Proposal 3: Relaxed Blue & Yellow Rules (HIGH PRIORITY)

**Problem**: Blue pairs (2% chance) and Yellow sequences (1% chance) are statistically unplayable.

**Current Rules**:
- **Blue**: Must complete pairs (7,7 then 12,12)
- **Yellow**: Must ascend by exactly 1 (1→2→3→4→5)

**Proposed Rules**:
- **Blue**: Start with any card. Every 2nd card must be within ±3 of previous card (loose pairing).
  - Example: 7→9 (pair-ish), 9→11 (pair-ish), 11→8 (pair-ish)
  - Still feels "blue" (grouping numbers) but achievable
  - Max 10 cards (same as current)

- **Yellow**: Must ascend, but by 1-3 (flexible sequence).
  - Example: 2→3 (+1), 3→6 (+3), 6→8 (+2), 8→10 (+2)
  - Still feels "yellow" (building upward) but achievable
  - Max 8 cards (same as current)

**Why This Works**:
- **Blue becomes viable**: With ±3 range, ~30% of Blues in hand can extend (vs. 2% for exact pairs)
- **Yellow becomes viable**: With 1-3 range, ~40% of Yellows can extend (vs. 1% for strict sequence)
- **Strategic differentiation**: Blue still harder than Purple (descending), but not impossible

**Mathematical Justification**:
```
P(Blue pair in 10-card hand) = 2-3% (current)
P(Blue within ±3) = ~30% (proposed) - 10x more achievable!

P(Yellow strict sequence) = 1-2% (current)
P(Yellow +1 to +3) = ~40% (proposed) - 20x more achievable!
```

**Game Design Principle**: Rules should feel restrictive but achievable. Current Blue/Yellow feel like trap options.

**Implementation Complexity**: SIMPLE (change validation logic in `validate_card_play`)

---

### Proposal 4: Reduced Combo Multiplier + Bonus for Long Paths (MEDIUM PRIORITY)

**Problem**: Rainbow bonus (2.0x for 5 colors) dominates exponential scoring. Balancing issue.

**Current Multipliers**:
```
1 path:  1.0x
2 paths: 1.2x
3 paths: 1.4x
4 paths: 1.7x
5 paths: 2.0x (RAINBOW!)
```

**Proposed Multipliers**:
```
1 path:  1.0x
2 paths: 1.1x (reduced from 1.2x)
3 paths: 1.25x (reduced from 1.4x)
4 paths: 1.4x (reduced from 1.7x)
5 paths: 1.6x (reduced from 2.0x) - still special, but not dominant
```

**PLUS: Long Path Bonus**:
```
Path length 5+: +5 bonus points
Path length 7+: +10 bonus points
Path length 10+: +20 bonus points
```

**Why This Works**:
- **Rebalances tradeoff**: 5 short paths still good (1.6x) but not overwhelming
- **Rewards mastery**: Building long paths gets tangible bonus (not just exponential)
- **Creates new strategy**: "Focus on one perfect Purple path (15 cards = 225 pts + 20 bonus = 245 pts!)"

**Mathematical Impact**:
```
Strategy A: 5 paths × 1 card = 5 pts × 1.6x = 8 pts
Strategy B: 1 path × 7 cards = 49 pts + 10 bonus = 59 pts × 1.0x = 59 pts

Now extending is clearly better if you can pull it off!
```

**Game Design Principle**: Multipliers should enhance gameplay, not dictate it. Current rainbow bonus is TOO strong.

**Implementation Complexity**: SIMPLE (change multiplier constants + add bonus calculation)

---

### Proposal 5: Deck Persistence Across Rounds (OPTIONAL)

**Problem**: "What's the point of having a deck if we clear paths after every round?"

**Solution**: Keep same deck across all 10 rounds (don't reset). Paths still clear, but deck memory persists.

**Why This Works**:
- **Card counting strategy**: "I've seen 10 Purple cards, only 10 left - save Purple path for later rounds"
- **Resource management**: Early rounds deplete high numbers, late rounds favor low-number strategies
- **Creates progression**: Rounds feel different (early = abundance, late = scarcity)

**Game Design Principle**: Resource depletion creates natural difficulty curve (like Dominion, Slay the Spire).

**Why It's Optional**:
- **Complexity cost**: Adds tracking burden for casual players
- **May slow gameplay**: Players calculating probabilities
- **Not essential**: Other proposals address core issues

**Implementation Complexity**: SIMPLE (remove deck reset in `continue_to_next_round`)

---

## Priority Ranking

### Tier 1: Critical Fixes (Implement ASAP)
1. **Proposal 3: Relaxed Blue/Yellow Rules** - Makes 2 colors playable (unlocks strategic space)
2. **Proposal 1: Dynamic Starting Cost** - Balances starting vs. extending (core decision)
3. **Proposal 4: Reduced Combo Multiplier** - Fixes dominant strategy (balance fix)

**Rationale**: These 3 changes address the core issues (luck dependence, boring optimal strategy) with minimal implementation cost.

### Tier 2: Major Improvement (Implement Next)
4. **Proposal 2: Hold 3 Cards** - Adds strategic persistence (biggest depth increase)

**Rationale**: Requires UI changes (card selection screen) but adds most strategic depth. Do after Tier 1 proves balance is better.

### Tier 3: Optional Enhancement
5. **Proposal 5: Deck Persistence** - Adds resource management (nice-to-have)

**Rationale**: Only implement if game still feels too luck-based after Tier 1+2. May overcomplicate for casual game.

---

## Implementation Plan

### Phase 1: Quick Wins (Proposals 1, 3, 4)
**Time Estimate**: 1-2 hours
**Files Changed**:
- `app/models/game.rb` - Update `play_card`, `calculate_combo_multiplier`, scoring logic
- `app/models/color_path.rb` - Update `next_play_hint` for new rules
- `app/controllers/games_controller.rb` - No changes needed (logic in model)
- `app/views/games/show.html.erb` - Update multiplier display, add bonus display

**Testing Checklist**:
- [ ] Blue paths achievable (play 3-4 card path in test game)
- [ ] Yellow paths achievable (play 3-4 card path in test game)
- [ ] Starting costs increase correctly (0, 1, 2, 3, 4 cards)
- [ ] New multipliers applied (1.0x, 1.1x, 1.25x, 1.4x, 1.6x)
- [ ] Long path bonuses trigger (+5, +10, +20)
- [ ] AI still plays reasonably (doesn't break)

### Phase 2: Deep Strategy (Proposal 2)
**Time Estimate**: 2-3 hours
**Files Changed**:
- `app/models/game.rb` - Add `held_cards` to game_state, update `continue_to_next_round`
- `app/controllers/games_controller.rb` - Add `select_hold_cards` action
- `app/views/games/_round_end.html.erb` - NEW: Card selection UI
- `app/views/games/show.html.erb` - Display held cards in next round

**New UI Flow**:
1. Round ends (existing round summary screen)
2. "Choose 3 cards to keep for next round" screen (NEW)
3. Player clicks 3 cards, submits
4. Round 2 starts with 3 held + 7 new = 10 cards

### Phase 3: Optional (Proposal 5)
**Time Estimate**: 30 minutes
**Files Changed**:
- `app/models/game.rb` - Comment out `game_state['deck'] = create_deck` in `continue_to_next_round`

**Testing**: Play 10-round game, verify deck doesn't reset between rounds.

---

## Expected Gameplay Outcomes

### Before Changes
**Turn 1**: Draw 10 random cards
**Decision**: "Which 1-2 cards can I even play?" (low agency)
**Strategy**: Start as many 1-card paths as possible
**Result**: 5 paths × 1 card = 10 pts (boring, luck-based)

### After Tier 1 Changes
**Turn 1**: Draw 10 random cards
**Decision**: "Do I start with Blue (±3 range, achievable!) or Purple (easy but lower multiplier)?"
**Mid-game**: "I have 3 paths (cost 3 cards total). Start 4th path (3 cards) or extend Purple to 5 cards (3 cards for +21 pts)?"
**Strategy**: Balance starting diverse paths (multiplier) vs. extending one path (exponential + bonus)
**Result**: Multiple viable strategies, decisions matter

### After Tier 2 Changes (Hold Cards)
**Round 1 End**: "I got Blue 7, Blue 9 (±3 pairing!). Save these for Round 2!"
**Round 2 Start**: "I kept Blue pair - instant 2-card path! Now I can focus on extending it."
**Strategy**: Plan across rounds, build toward long-term goals
**Result**: Skill expression through planning, less frustrating randomness

---

## Game Design Principles Applied

### 1. Meaningful Choices (Sid Meier)
**Before**: "Play whatever fits" (no choice)
**After**: "Start 4th path or extend Purple?" (interesting tradeoff)

### 2. Flow State (Csikszentmihalyi)
**Before**: Too luck-dependent (frustrating, not flow)
**After**: Challenge matches skill (relaxed rules = achievable mastery)

### 3. Risk/Reward Balance
**Before**: Low risk (start paths) = high reward (rainbow bonus)
**After**: High risk (extend paths) = high reward (exponential + bonus)

### 4. Player Agency
**Before**: Random hand dictates play (passive)
**After**: Hold cards, choose focus (active decisions)

### 5. Progressive Difficulty
**Before**: Flat (every round same)
**After**: Dynamic starting costs + deck depletion = natural curve

---

## Success Metrics

**How to know if changes worked**:

1. **Strategic Diversity**: In 10 test games, do players use 3+ different strategies?
   - ✅ Good: 5-path rainbow, 3-path + extensions, 1-path max focus all viable
   - ❌ Bad: Everyone still does 5×1-card paths

2. **Blue/Yellow Playability**: Can players build 3+ card Blue/Yellow paths?
   - ✅ Good: 50%+ of games have 3+ card Blue or Yellow
   - ❌ Bad: Still stuck at 1-2 cards

3. **Interesting Decisions**: Do players hesitate before playing (thinking)?
   - ✅ Good: "Hmm, start 4th path or extend..." (visible decision)
   - ❌ Bad: "Just play whatever" (autopilot)

4. **Skill Expression**: Does better strategy beat worse strategy?
   - ✅ Good: Player who extends smartly beats player who starts many paths
   - ❌ Bad: Winner determined by draw luck

5. **Replayability**: Do players want to try new strategies in Game 2?
   - ✅ Good: "Last game I did rainbow, this time I'll focus on one long Purple path"
   - ❌ Bad: "Same strategy every game"

---

## Risks & Mitigations

### Risk 1: Changes make game TOO easy
**Mitigation**: Relaxed rules + hold cards may make perfect paths too common
**Solution**: Monitor test games. If everyone gets 10+ card paths, add caps or increase costs

### Risk 2: AI breaks with new rules
**Mitigation**: AI logic assumes old Blue/Yellow rules
**Solution**: Update AI's `validate_card_play` calls (should work automatically, but test)

### Risk 3: Hold cards UI confuses players
**Mitigation**: New screen mid-flow disrupts pacing
**Solution**: Clear instructions ("Choose 3 cards to keep"), skip feature for Round 1→2 (tutorial)

### Risk 4: Balance swings too far toward extending
**Mitigation**: If starting paths becomes bad, rainbow diversity disappears
**Solution**: Keep rainbow bonus at 1.6x (still meaningful), tune long-path bonuses down if needed

---

## Next Steps

1. **Review Proposal**: Zac approves priority ranking
2. **Implement Tier 1**: Changes 1, 3, 4 (quick balance fixes)
3. **Playtest 5 Games**: Record strategies used, decisions made, fun factor
4. **Tune Numbers**: Adjust multipliers/bonuses based on playtest results
5. **Implement Tier 2**: Hold cards feature (if Tier 1 successful)
6. **Production Deploy**: Ship improved game to http://24.199.71.69/chromatic

---

**End of Proposal**
Ready for implementation - see code below.
