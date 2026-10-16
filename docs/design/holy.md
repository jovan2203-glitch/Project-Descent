# Holy book

Healer built; the other specs are drafts. Values in Frost Bolts (FB) are conversation shorthand; real numbers go in balance.gd. Heal sizes are in "heals": 1.0 = one old Heal spell (Balance.REFERENCE_HEAL).
Four playstyles, each built on its own idea: Healer (Hymns), Block tank (Standards), Melee (Daylight), Caster (the Herald).

## The wipe (2026-10-16)
- Every old Holy ability was removed: Heal (the starter heal), Dawnlight, Sunlance, Oath Strike, Radiant Arrow, Shield of Dawn, Sacred Bulwark. The book is rebuilt from this file, healer first.
- Psalm (Healer) is the new starter heal every character gets.

## Healer (Hymns) - spec "Choir of One" - BUILT 2026-10-16
Code: player.gd, "Holy healer: the Hymns". Numbers: balance.gd (VERSE_*, MERCY_*, CHORUS_*, VIGIL_*, ...). Ring: scripts/hymn_ring.gd.
- Theme: a ring of floating golden glyphs turns around you, coloured by your Hymn (Mercy gold, Chorus white, Vigil blue). A boom is a column of light in the Hymn's colour.

### Hymns (stances)
- Three Hymns: Mercy, Chorus, Vigil. No Hymn until you first sing one; that first Sing never costs Verses.
- Sing Mercy / Sing Chorus / Sing Vigil - instant, on the GCD (so a macro can't fold a free swap into another ability), not usable mid-cast, can't sing the Hymn you are in.
- Mercy: your single-target heals (Psalm, Outpour, Lift, Refrain, Antiphon) heal 20% more.
- Chorus: those heals (not Refrain's ticks) also heal up to 2 other allies within 8 m of the target for 30% (meter line "Chorus").
- Vigil: allies within 15 m take 5% less damage (renewed every second), and your heals leave a 3 s shield worth 10% of the heal.

### Verses
- Up to 6, shown as pips under the resource bars (VS row) and as a number on the Sing, Reprise and Last Verse buttons. Extra Verses are wasted. Out of combat one fades every 2 s.
- Each Verse suits a Hymn: single-target heals give Mercy Verses, heals on many give Chorus Verses, shields and less damage taken give Vigil Verses.
- Singing with 6: the Hymn you ENTER booms and every Verse is spent (always; nothing keeps Verses through a boom).
- Singing with fewer: all are lost (Key Change keeps 1/2/3, Rest keeps all).

### Booms
- Benediction (Mercy): 3 old Heals on your friendly target (you with none).
- Chorale (Chorus): every ally within 30 m healed for 1 old Heal.
- Bulwark of Song (Vigil): allies within 15 m take 30% less damage for 5 s.
- +10% for each spent Verse of the entered Hymn (up to +60%); Bulwark of Song instead lasts 0.5 s longer per match.
- Full Choir: when your last three booms were Mercy, Chorus and Vigil in any order, the third is 50% stronger (Bulwark of Song: 50% longer) and 2 Verses of its Hymn come back. Then the count starts over.

### Kit (heals in old Heals; Verses given)
- Psalm - 2 s cast, 1.0, 2 mana, 1 Mercy. The starter heal every character has (default bar slot 4).
- Outpour - 3 s cast, 2.2, 4 mana, 2 Mercy.
- Lift - instant, 8 s cooldown, 0.5, 1 mana, 1 Mercy.
- Refrain - instant, 1.2 over 12 s (ticks every second, faster with Haste), 2 mana, 1 Mercy.
- Canticle - 2.5 s cast, 12 s cooldown, up to 5 injured allies within 30 m (lowest first) for 0.6, 3 mana, 2 Chorus.
- Exultation - 2 s cast, no cooldown, every ally within 20 m for 0.45, 4 mana (the most of any cast), 1 Chorus. The spammable group heal.
- Antiphon - instant, 15 s cooldown, target 0.8 then you 50% of that, 2 mana, 1 Chorus.
- Shelter - instant, 12 s cooldown, 1.2 shield for 8 s, 2 mana, 1 Vigil.
- Steady Voice - instant, 30 s cooldown, allies within 15 m take 10% less damage for 6 s, 2 mana, 2 Vigil.
- High Note - 1.5 s cast Holy bolt, 1.0 FB; your lowest-health ally within 30 m is healed for 50% of the damage. 2 mana, 1 Verse of the Hymn you sing (Mercy with none).
- Reprise - instant, within 6 s of a boom, costs 3 Verses: repeats it at 40% (Bulwark of Song: 40% of its reduction). Not a boom for Full Choir.
- Swell - instant, off GCD, 60 s cooldown, 10 s: everything that gives Verses gives 1 more.
- Rest - 60 s cooldown: 40% less damage for 6 s; singing without a boom during it keeps your Verses.
- Last Verse - 3 min cooldown, needs 6 Verses and spends them: lifts the nearest downed ally within 30 m at 30% health.

### Talents (Holy tree)
- Row 1: Mercy's Ear (2): healing an ally below 35% gives a Mercy Verse, once per 6/3 s. Many Voices (2): a heal landing on 3+ allies (Chorus's splash counts) gives a Chorus Verse, once per 6/3 s. Watchful (2): an ally in your Vigil taking a hit of 10%+ of max health gives a Vigil Verse, once per 6/3 s.
- Row 2: Key Change (3): singing without a boom keeps 1/2/3 Verses. Open Doors (4, requires Shelter): Shelter absorbs 10/20/30/40% more; capstone: its cooldown is 4 s.

### Runes (Epic)
- Resounding: booms also deal 0.6 FB Holy damage within 8 m (Benediction around the ally, the others around you), split past the AoE cap.
- Overture: after a boom, your next spell with a cast time within 3 s is instant.

## Block tank (Standards, requires a shield) - spec "Standard Bearer"
- Theme: you plant tall white-and-gold standards. Two within 20 m of each other are joined by a beam of light at waist height.
- Standards: up to 3, 30 s each. Within 8 m of one: +10% Block chance and +10% Block cap. Enemies within 8 m take 0.08 FB Holy damage per second, high threat (own meter line).
- Beams: an enemy crossing a beam takes 0.3 FB (once per 3 s per enemy), high threat.
- Every 5 blocks while inside a Standard's area, that Standard pulses for 0.4 FB within 6 m.
- Raise Standard - instant, 3 charges, 10 s recharge: plants one at your feet (a 4th replaces the oldest).
- Shield bash that heals you; twice as much inside a Standard's area.
- A big defensive.
- Clarion Blow - 6 s cooldown, 1.0 weapon damage as Holy, high threat; pulses the nearest Standard.
- Toll - 15 s cooldown: every Standard pulses at once for 0.5 FB within 8 m, high threat. Grabs packs at several spots.
- Hallow Step - 12 s cooldown: leap to one of your Standards, 0.4 FB on landing.
- Rally - 30 s cooldown: all Standards fly to you.
- Hold Fast - 20 s cooldown, off GCD: your next 3 attacks taken from the front are blocked.
- Unfallen - 120 s cooldown, 8 s: while inside a Standard's area you can't drop below 1 health; when it ends you heal for 30% of the damage it stopped.

## Melee (Daylight, two-handed mace or hammer) - spec "High Noon"
- Theme: a small sun icon over the resource bar rises as Daylight builds; the hammer glows hotter. Ties into the Dusk till Dawn rune.
- Daylight: 0-100 bar like Rage. Built by strikes, spent by finishers. At 75+ it is Noon: strikes deal 15% more. Out of combat it fades.
- Dawnstrike - 6 s cooldown, 1.2 weapon damage, +25 Daylight.
- Rising Blow - no cooldown, 0.6 weapon damage, +10 Daylight. Filler.
- Morning Star - 8 s cooldown, hammer thrown up to 20 m, 0.7 FB, +15 Daylight.
- Glare - 12 s cooldown, 0.6 FB within 8 m, +10 Daylight per enemy hit (up to 30).
- Zenith - finisher, spends all Daylight: 0.03 FB per point (3.0 FB at 100), +25% at Noon.
- Sunfall - AoE finisher, spends all Daylight: 2.4 FB at 100 within 8 m, split evenly past the cap.
- Last Light - after a finisher spends 75+, your next builder builds twice as much.
- Long Day - 60 s cooldown, 10 s: finishers don't spend Daylight.
- Heat Shimmer - 45 s cooldown, 20% less damage for 6 s; spends Daylight for an absorb (0.02 FB per point).
- Solstice - 90 s cooldown, 8 s: Daylight held at 100.

## Caster (the Herald) - spec "Herald's Voice"
- Theme: a tall winged figure of light. Unlike Shadow's demon, it doesn't stay with you: it flies to whatever you last damaged and hovers above it.
- The Herald: 30 s; if it isn't up, your rotation calls it. It repeats each Holy spell you cast at 40% from above its enemy (own meter line).
- Call the Herald - 1.5 s cast, 30 s cooldown.
- Ray - 2 s cast, 1.0 FB. Filler.
- Glory - 2.5 s cast, 10 s cooldown, 2.2 FB; +25% on the Herald's enemy.
- Proclaim - instant, 12 s cooldown: the Herald dives for 1.5 FB.
- Litany - 3 s channel, 0.5 FB per second; the Herald repeats each tick at double strength.
- Falling Star - 30 s cooldown: 2.0 FB within 6 m after 1 s.
- Herald's Ring - 20 s cooldown: a ring of light around the Herald, 0.8 FB within 8 m.
- Redirect - instant, 8 s cooldown: sends the Herald to another enemy; its next repeat is doubled.
- Wingbeat - blink: the Herald lifts you 8 m forward.
- Ascend - 90 s cooldown, 12 s: you and the Herald merge; spells +30%, Ray is instant.
- A bow spell; the Herald repeats it like any Holy spell.

## Talents for the other specs (outline, ranks to be set when built)
- Tank: Wide Ground (area +1/2 m), Bright Beams (beams +20/40%), Hard Shield (+1/2/3% Block with a shield), Ringing Ears (Toll -3/6 s), Standing Order (Standards +5/10 s), Bastion (5, bottom: Standard damage +3-15%).
- Melee: High Noon (Noon from 70/65), Hot Iron (Noon bonus +5/10%), Long Shadow (Zenith +10/20%), Early Riser (Dawnstrike +5 Daylight per rank), Sunburnt (Sunfall cap +1/2 targets), Daybreak (5, bottom: finishers +3-15%).
- Caster: Loud Herald (repeats 43/46/50%), Long Litany (Litany +1 s), Bright Wings (Herald +3/6 s), Star Shower (Falling Star +1/2 m), Chosen Target (Glory bonus +10/20%), Exalted (5, bottom: Holy spells +3-15%).
- Open: Grace (3: heals on others +2/4/6%), Steadfast (3: Block +1/2/3%), Burnished (3: Holy damage +2/4/6%), Overflowing (3: overhealing becomes a small absorb, 10/20/30%), Zeal (2: after a finisher or big heal, +5/10% move speed 3 s), Penitent (3: after taking a big hit, next heal on yourself +10/20/30%), Kindred Light (3: self-buffs from Holy 5/10/15% longer).
- The current Holy talent layout (26 slots) is too small for four specs; it grows to Shadow's size.

## Other runes
- Legendary (already exists): Dusk till Dawn. Dawn could also start you at 50 Daylight.
- Epic Pilgrim Standard: one Standard follows you at half strength.
- Epic Second Herald: a smaller second Herald on your second-to-last target, repeating at 15%.
- Rare: Zenith at 100 Daylight refunds 20.

## Open questions
- Does the Holy book get a bow spell, or does archery stay with Martial?
- Tank: should Standards be attackable by enemies?
