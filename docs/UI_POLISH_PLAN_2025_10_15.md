# UI Polish Plan - October 15, 2025

## Issues to Fix

### 1. Too Much Vertical White Space at Top
**Current**: Sticky score ticker has generous padding
**Fix**: Reduce padding from `py-3` to `py-2`, reduce gap between elements
**Impact**: Save ~20px vertical space

### 2. Remove "Must start with X card" Text
**Current**: Shows "Must start with yellow card" for each empty path
**Fix**: Remove this line completely, cost is enough info
**Impact**: Cleaner, less cluttered

### 3. Move Path Cost to Color Title Line
**Current**:
```
🟡 Yellow (+1 to 3)
Cost: FREE
```
**Fix**:
```
🟡 Yellow (+1 to 3) - FREE
🟡 Yellow (+1 to 3) - 1 card
```
**Impact**: More compact, easier to scan

### 4. Shrink "No paths yet" Box to Single Line
**Current**: Multi-line box with emoji, title, subtitle
**Fix**: Single line: "No paths started yet - First path is FREE"
**Impact**: Save ~80px vertical space

### 5. Remove "-2💳" Badge from Cards
**Current**: Orange pulsing badge shows cost for starting new paths
**Fix**: Remove completely (cost shown in path headers)
**Impact**: Less visual noise, cleaner hand

### 6. Remove "Click to play" Text from Cards
**Current**: Each card shows "Click to play" at bottom
**Fix**: Remove text, cards are obviously clickable
**Impact**: Cleaner card design

### 7. Red End Turn Button When Cards Remain
**Current**: Always green with blue info message above
**Fix**:
- Green button when hand is empty
- Red button when cards remain
- Text: "End Turn (will discard 3 cards)"
**Impact**: Visual warning for unintentional discard

---

## Implementation Plan

### File 1: `/app/views/games/show.html.erb`

#### Change 1: Reduce Sticky Header Padding
**Lines 4-40**

```erb
<!-- OLD -->
<div class="sticky top-0 z-50 bg-white border-b-4 shadow-lg mb-6 -mx-4 md:-mx-8 px-4 md:px-8 py-3">

<!-- NEW -->
<div class="sticky top-0 z-50 bg-white border-b-4 shadow-lg mb-4 -mx-4 md:-mx-8 px-4 md:px-8 py-2">
```

**Changes**:
- `mb-6` → `mb-4` (reduce bottom margin)
- `py-3` → `py-2` (reduce vertical padding)

---

#### Change 2: Move Cost to Path Title, Remove "Must start" Text
**Lines 250-298**

```erb
<!-- OLD -->
<div class="flex items-center gap-2">
  <span class="text-xl"><%= color_emoji %></span>
  <span class="font-bold capitalize text-gray-800"><%= color %></span>
  <span class="text-xs text-gray-600">(<%= color_rule %>)</span>
</div>

<!-- In empty path section -->
<div class="text-gray-400 text-sm italic mb-2">Not started</div>
<div class="mt-2 pt-2 border-t border-gray-200 text-xs text-gray-700">
  <div class="mb-1">
    Cost: <span class="font-semibold text-orange-700"><%= cost_display %></span>
  </div>
  <div class="text-gray-600">Must start with <%= color %> card</div>
</div>

<!-- NEW -->
<%
  # Calculate cost for display
  path_cost = @game.starting_cost_for_path_number(@game.player_paths.count)
  cost_display = path_cost == 0 ? 'FREE' : "#{path_cost} card#{'s' if path_cost > 1}"
  cost_color = path_cost == 0 ? 'text-green-700' : 'text-orange-700'
%>

<div class="flex items-center gap-2">
  <span class="text-xl"><%= color_emoji %></span>
  <span class="font-bold capitalize text-gray-800"><%= color %></span>
  <span class="text-xs text-gray-600">(<%= color_rule %>)</span>
  <% unless player_path || ai_path %>
    <span class="text-xs font-semibold <%= cost_color %>">- <%= cost_display %></span>
  <% end %>
</div>

<!-- In empty path section - SIMPLIFIED -->
<div class="text-gray-400 text-sm italic">Not started</div>
<!-- Remove border, remove "Must start" text -->
```

---

#### Change 3: Shrink "No paths yet" Box
**Lines 313-321**

```erb
<!-- OLD -->
<div class="text-center py-12 bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg">
  <div class="text-4xl mb-2">🎯</div>
  <div class="text-lg font-bold text-gray-700 mb-1">No paths yet</div>
  <div class="text-sm text-gray-600">Play a card from your hand to start!</div>
  <div class="text-xs text-green-600 font-semibold mt-2">First path is FREE</div>
</div>

<!-- NEW -->
<div class="text-center py-3 bg-gray-50 border border-dashed border-gray-300 rounded-lg">
  <div class="text-sm text-gray-700">
    🎯 No paths started yet - <span class="font-bold text-green-600">First path is FREE</span>
  </div>
</div>
```

**Changes**:
- `py-12` → `py-3` (much less padding)
- Remove emoji, title, subtitle
- Single line with inline FREE emphasis
- `border-2` → `border` (thinner border)

---

#### Change 4: Red End Turn Button When Cards Remain
**Lines 350-367**

```erb
<!-- OLD -->
<% if hand_size > 0 %>
  <div class="bg-blue-50 border border-blue-300 rounded-lg p-2 text-center mb-2 text-xs md:text-sm">
    <%= hand_size %> <%= 'card'.pluralize(hand_size) %> remaining · Unplayed cards will be discarded
  </div>
<% end %>

<%= button_to "End Turn → (AI plays next)",
              end_turn_game_path(@game),
              method: :post,
              data: { turbo: false },
              class: "w-full px-6 py-4 bg-green-600 text-white rounded-lg hover:bg-green-700 font-bold transition-all text-base md:text-lg shadow-xl hover:shadow-2xl animate-pulse" %>

<!-- NEW -->
<%
  button_color = hand_size > 0 ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'
  button_text = hand_size > 0 ? "End Turn (will discard #{hand_size} #{hand_size == 1 ? 'card' : 'cards'})" : "End Turn → (AI plays next)"
%>

<%= button_to button_text,
              end_turn_game_path(@game),
              method: :post,
              data: { turbo: false },
              class: "w-full px-6 py-4 #{button_color} text-white rounded-lg font-bold transition-all text-base md:text-lg shadow-xl hover:shadow-2xl" %>
```

**Changes**:
- Remove info message above button
- Button color changes: green (no cards) / red (has cards)
- Button text shows discard count when cards remain
- Remove `animate-pulse` (distracting)

---

### File 2: `/app/views/games/_card.html.erb`

#### Change 5: Remove "-2💳" Badge
**Lines 24-28**

```erb
<!-- REMOVE THIS ENTIRE BLOCK -->
<% if is_new_path %>
  <div class="absolute -top-3 -right-3 bg-orange-600 text-white text-sm font-black px-3 py-1.5 rounded-full shadow-xl border-3 border-white animate-pulse">
    -2💳
  </div>
<% end %>
```

---

#### Change 6: Remove "Click to play" Text
**Lines 22**

```erb
<!-- OLD -->
<button type="submit" class="...">
  <div class="text-6xl font-black mb-1"><%= card['number'] %></div>
  <div class="text-sm uppercase font-bold tracking-wider"><%= card['color'] %></div>
  <div class="text-xs mt-1 opacity-60">Click to play</div>  <!-- REMOVE THIS -->
</button>

<!-- NEW -->
<button type="submit" class="...">
  <div class="text-6xl font-black mb-1"><%= card['number'] %></div>
  <div class="text-sm uppercase font-bold tracking-wider"><%= card['color'] %></div>
</button>
```

---

## Summary of Changes

**Vertical Space Saved**:
- Sticky header: ~10px
- "No paths yet" box: ~80px
- Per empty path (5 paths): ~15px each = 75px
- **Total: ~165px saved**

**Visual Clutter Removed**:
- 10 pulsing "-2💳" badges (one per card)
- 10 "Click to play" texts
- 5 "Must start with X" texts
- Info message above End Turn button

**New Visual Signals**:
- Path cost inline with color title (easier to scan)
- Red button warns about discarding cards
- Button text shows exact discard count

**Impact**: Much cleaner, more compact UI that fits more game state on screen without scrolling.
