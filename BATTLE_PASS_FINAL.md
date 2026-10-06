# Robruzz — Final Battle Balance Pass

## Core goals
- Ease new players into the class/spectrum triangle.
- Keep fights tense without making early encounters feel punitive.
- Make enemy AI readable rather than purely random.
- Make the boss feel like the culmination of the adaptation mechanic.
- Give every named skill a simple visual identity without adding a VFX framework.

## Final player tuning
| Fighter | Class | HP | LP |
|---|---|---:|---:|
| protagonist | Visible | 54 | 28 |
| companion 1 | High Energy | 48 | 26 |
| companion 2 | Low Energy | 50 | 26 |

Player LP regeneration: +4 at the start of each living player turn.

Revive remains intentionally limited to Companion 1. The protagonist and Companion 2 do not automatically receive Revive; this keeps death/recovery decisions meaningful.

## Final traversal encounters
| Fight | Enemies | HP each | Guard |
|---|---|---:|---:|
| Room 1 / Enemy 1 | 2 × Type 1 | 26 | 2% |
| Room 1 / Enemy 2 | 2 × Type 2 | 29 | 4% |
| Room 2 / Enemy 3 | 2 × Type 3 | 32 | 7% |
| Room 2 / Enemy 4 | 2 × Type 4 | 34 | 12% |

The first turn of regular enemy AI is deliberately predictable. Stronger patterns arrive after the player has had time to learn the fight.

## Boss
- HP: 96
- Class: High Energy
- Speed: 12 (stored, not used for turn order)
- Guard chance: 9% base, with extra defensive behavior when low HP

Boss priorities:
1. Open with Energy Surge once when its offense buff is absent.
2. Use Gamma Ray when multiple party members are alive, increasingly often as HP falls.
3. Use X-Ray to pressure the weakest living ally.
4. Use Crush as the reliable fallback.
5. Guard becomes a little more likely in the final stretch.

The boss's most important mechanic remains unchanged: it completely rejects the player's most-used damaging skill from Room 2.

## Adaptation tuning
- Room 1 usage tracking now focuses on damaging skills, so support/debuff spam cannot accidentally become the Room 2 resistance.
- Room 2 still resists the most-used Room 1 damaging skill at 0.5 effectiveness.
- The boss still completely rejects the most-used Room 2 damaging skill.
- Class advantage is now 1.5× rather than 2×, so weaknesses are valuable without turning fights into instant wins.

## Player feedback
Skill menu entries now expose matchup information while selected or hovered:
- `WEAK` — skill's spectrum has the 1.5× class advantage.
- `RESIST` — the current adaptation is halving that skill.
- `REJECTED` — the boss will fully block that skill.

Target selection also labels individual enemies as `WEAK`, `RESIST`, or `REJECTED` when relevant.

Actual impacts already display the corresponding combat feedback as well.

## Skill visual identity
Every named skill now receives a distinct simple color in the existing BattleStage effect system. No new attack types or heavyweight VFX framework were added.

The existing BattleStage also differentiates several attacks through projectile/dot counts, so the combination should make repeated attacks recognizable during play.

## Critical gameplay rule fixed
The protagonist is the run anchor. Their death immediately ends the battle as a loss, even if companions are still alive. The defeat check is performed both at battle startup and immediately after damage resolves.

## Recommended playtest order
1. Room 1 Enemy 1: verify it feels like the onboarding fight.
2. Room 1 Enemy 2: verify burst pressure increases without a difficulty spike.
3. Room 2 Enemy 3: verify the resisted skill is readable and alternatives are attractive.
4. Room 2 Enemy 4: verify control pressure and resource wear are meaningful.
5. Boss: verify the rejected skill is obvious, the boss AI feels intentional, and the player can win through adaptation rather than grinding.
6. Kill the protagonist intentionally and confirm the battle immediately enters the defeat result.
7. Kill a companion and confirm they remain defeated visually and Revive only works from the character(s) that actually have it.
