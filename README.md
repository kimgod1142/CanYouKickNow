# CanYouKickNow?

**Real-time interrupt cooldown tracker for Mythic+ — works even without the addon on party members.**

> M+ 파티 차단기 쿨타임 실시간 추적 애드온

---

## Features

- **No addon required on others** — uses `UnitClass()` and `UNIT_SPELLCAST_SUCCEEDED` to detect casts without any communication between players.
- **Spec-aware via Inspect** — automatically inspects party members at dungeon start to confirm whether they have their interrupt talented. No guessing.
- **Talent detection** — some interrupts require a talent point (e.g. Paladin Rebuke, Shaman Wind Shear). Shows `?` until confirmed, then locks in the correct state.
- **Auto show/hide** — panel appears automatically when you enter a Mythic+ dungeon and hides when you leave.
- **Live cooldown bars** — smooth, class-colored bars count down each interrupt every frame.
- **Spec correction on cast** — if a Hunter uses Muzzle instead of Counter Shot, the tracker auto-corrects the spec assumption immediately.
- **Full settings panel** — `/ckn config` opens an options UI with bar texture, row height, font size, and more.
- **Solo test mode** — `/ckn test` loads all 5 UI states (ready / cooldown / unknown / no kick / API limit) so you can preview without a group.
- **English / Korean UI** — automatically switches based on your client locale.

---

## Panel States

| Display | Meaning |
|---|---|
| `▶ READY` | Interrupt confirmed + off cooldown |
| `15s` | On cooldown, counting down |
| `? 특성 미확인` | Talented interrupt — not yet confirmed via Inspect or cast |
| `— 차단 없음` | No interrupt for this spec (Holy Paladin, Holy Priest, etc.) |
| `— 추적 불가` | Warlock — pet-based interrupt, not trackable via WoW API |

---

## Tracked Interrupts

| Class / Spec | Spell | CD | Talent? |
|---|---|---|---|
| Warrior (all) | Pummel / 들이치기 | 15s | No |
| Paladin (Prot / Ret) | Rebuke / 비난 | 15s | **Yes** |
| Paladin (Holy) | — | — | No interrupt |
| Hunter (BM / MM) | Counter Shot / 반격의 사격 | 24s | **Yes** |
| Hunter (SV) | Muzzle / 재갈 | 15s | **Yes** |
| Rogue (all) | Kick / 발차기 | 15s | No |
| Priest (Shadow) | Silence / 침묵 | 30s | No |
| Priest (Disc / Holy) | — | — | No interrupt |
| Death Knight (all) | Mind Freeze / 정신 얼리기 | 15s | **Yes** |
| Shaman (all) | Wind Shear / 날카로운 바람 | 12s | **Yes** |
| Mage (all) | Counterspell / 마법 차단 | 25s | No |
| Warlock (all) | — | — | Pet-based, API limit |
| Monk (Brew / WW) | Spear Hand Strike / 손날 찌르기 | 15s | **Yes** |
| Monk (MW) | — | — | No interrupt |
| Druid (Balance) | Solar Beam / 태양 광선 | 60s | **Yes** |
| Druid (Feral / Guardian) | Skull Bash / 두개골 강타 | 15s | **Yes** |
| Druid (Resto) | — | — | No interrupt |
| Demon Hunter (all) | Disrupt / 분열 | 15s | No |
| Evoker (Dev / Aug) | Quell / 진압 | 20s | **Yes** |
| Evoker (Preservation) | — | — | No interrupt |

### Cooldown-Reducing Talents

| Class | Talent | Effect |
|---|---|---|
| Mage | Quick Witted (382297) | Counterspell 25s → 20s |
| Warrior | Honed Reflexes (391271) | Pummel 15s → 14s |
| Death Knight | Coldthirst (378848) | −3s per successful interrupt *(not trackable)* |

---

## How It Works

```
Mythic+ dungeon entered
  → BuildRoster(): UnitClass() per party member → assign default interrupt
  → InspectAllParty(): NotifyInspect() queue → INSPECT_READY
      → GetInspectSpecialization() → CKYN_SPEC_INTERRUPT lookup
      → confirmed = true, talent-reduced CD applied if applicable

During dungeon
  → UNIT_SPELLCAST_SUCCEEDED: interrupt cast detected
      → record endTime = castTime + cd
      → auto-correct spec if wrong (e.g. Hunter BM → SV)

Dungeon completed / left
  → panel auto-hides, roster cleared
```

Direct cooldown queries on other players are not available in the WoW API. This addon works around that using `UnitClass()` for roster building and `UNIT_SPELLCAST_SUCCEEDED` for live tracking.

---

## Commands

| Command | Description |
|---|---|
| `/ckn` | Toggle the tracker panel |
| `/ckn config` | Open settings panel |
| `/ckn test` | Load dummy data for solo UI testing |
| `/ckn reset` | Clear all cooldown data |
| `/ckn reload` | Re-scan roster + re-inspect party |

---

## Installation

1. Download `CanYouKickNow-vX.X.X.zip` from the [Releases](../../releases) page.
2. Extract and place the `CanYouKickNow` folder into: `World of Warcraft/_retail_/Interface/AddOns/`
3. Reload WoW or log in.

---

## Known Limitations

- **Warlock interrupts** are pet-based (`Spell Lock`, `Axe Toss`). The pet's casts are not exposed via `UNIT_SPELLCAST_SUCCEEDED` on the player's unit token — tracking is not possible with the current WoW API.
- **Death Knight Coldthirst** (−3s per successful interrupt) is event-driven and cannot be tracked. Base 15s cooldown is always shown.
- **Talented interrupts** (e.g. Paladin Rebuke) show `?` until Inspect completes or the player actually uses the interrupt. Inspect requires ~30 yard range.

---

## License

MIT — free to use, modify, and distribute.

**Author:** kimgod1142 · kimgod1142@gmail.com
