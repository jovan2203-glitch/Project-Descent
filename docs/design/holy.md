# Holy book

Both healers, the archer and the tank are built; the melee and caster are drafts. Values in Frost Bolts (FB) are conversation shorthand; real numbers go in balance.gd. Heal sizes are in "heals": 1.0 = one old Heal spell (Balance.REFERENCE_HEAL).
Six playstyles, each built on its own idea: Healer (Hymns), Healer 2 (the Prisms, white), Archer (Lightstring, gold prisms), Tank (the Censer), Melee (Daylight), Caster (the Herald).

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
- Refrain - instant, 1.2 over 12 s (ticks every second, faster with Haste), 1 mana, 1 Mercy.
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

### Runes (Epic)
- Resounding: booms also deal 0.6 FB Holy damage within 8 m (Benediction around the ally, the others around you), split past the AoE cap.
- Overture: after a boom, your next spell with a cast time within 3 s is instant (and can be cast on the move). It is used up when that cast lands.

## Healer 2 (the Prisms) - spec "Line of Light" - BUILT 2026-10-16
Code: player.gd, "Holy healer: the Prisms". Numbers: balance.gd (PRISM_*, HEALS). Pictures: scripts/prism.gd, scripts/light_beam.gd. Nothing to do with the Hymns: no Verses, its heals count for nothing in that kit.
- Prisms: up to 3 floating crystals (a 4th replaces the oldest), 1 min each. The healer's are WHITE and work only with heals (see the archer for the gold ones; the limit counts both). Own-only: only your beams charge yours; the party sees them faint.
- Beam: every direct heal (and Piercing Light) is a literal beam from you to the target. Each prism within 1 m of the line (seen from above, between you and the target) stores 25% of it as light (max 3 old Heals) and makes the heal 10% stronger.
- Shattering: a prism's light is split evenly between allies within 8 m; enemies there take up to 1.0 FB Holy (at full light). Meter line "Prism Shatter".
- Heals never target prisms. Only Shatter Prism and Infuse do: the prism under the mouse (mouseover casting), else the one you clicked (green ring), else your closest.
- Moving: prisms flicker out and flicker in.

### Kit (heals in old Heals; mana in points)
- Set Prism - ground target, off GCD, 30 m, 8 s cd. 0.5 mana.
- Move Prism - off GCD, 5 s cd: the prism closest to your mouse jumps to the spot under it (keeps light and time). 1 mana.
- Mending Ray - 3 s channel, 1.5 over 6 ticks; every tick's beam charges. 3 mana.
- Bright Lance - 2.5 s cast, 1.8. 3.5 mana.
- Gleam - instant, 0.5. 1 mana.
- Prism Ward - instant, 15 s cd, shield 1.2 for 8 s (its beam charges). 2 mana.
- Piercing Light - 1.5 s cast, 1.0 FB Holy beam; prisms store 25% of the damage as light. 1.5 mana.
- Realign - ground target, 20 s cd: all prisms move around the spot in the same shape; their time starts over.
- Shatter Prism - no cd: shatters one prism. Shatter All - off GCD, 20 s cd: all at once.
- Infuse - 45 s cd: fills one prism to full. 1 mana.
- Kaleidoscope - 2 min cd, 10 s: your beams pass through every prism, wherever it stands.

## Archer (Lightstring, bow, Energy) - spec "Lightstring" - BUILT 2026-10-16
Code: player.gd, "Holy archer: Lightstring". Numbers: balance.gd (REFRACT_*, GOLD_*, SUNLIT_*, BREAKER_*, VOLLEY_*).
- **Prism colours (the hybrid rule):** the healer's Set Prism makes WHITE prisms, used only by heals; Prism Arrow makes GOLD prisms, used only by arrows. Light never moves between the colours. The 3-prism limit counts both, so a healer/archer hybrid has to split them. Realign, Move Prism and Step of Light work with either colour (moving converts nothing).
- **Refraction:** every shot is a line from you to the enemy. Each gold prism on it fires a refracted arrow at another enemy within 8 m of it for 40% of the shot (own meter line "Refraction"); with no other enemy there, the shot is +10% instead. The prism stores 25% of the shot's damage as light (same cap as white). Auto-shots do it too: 10% charge, 20% refraction.

### Kit (weapon multipliers on the bow; Energy)
- Prism Arrow - off GCD, 30 m ground target, 2 charges (12 s recharge): plants a gold prism. 15.
- Glimmer Shot - instant filler, 1.8x weapon. 20.
- Refracting Shot - 2 s cast, 8 s cd, 2.0x weapon; its refracted arrows hit for 60%. 30.
- Sunlit Arrow - 12 s cd, 1.2x weapon plus the light it drains from the gold prisms on its line (0.03 per point of light; three full prisms about +0.6, so ~1000 on a crit at level 50). 30.
- Prism Breaker - 15 s cd: shoots a gold prism (mouseover, clicked, closest); it shatters for 0.6 FB + 0.06 per point of light within 8 m (split past the AoE cap). Heals nothing. 25.
- Step of Light - off GCD, 20 s cd, 40 m: you appear next to one of your prisms (either colour).
- Spectrum Volley - 2 min cd, 8 s: every second each gold prism shoots the nearest enemy within 8 m for 0.4 FB + 0.02 per point of its light (own meter line).

## Tank (the Censer) - spec "Censer Bearer" - BUILT 2026-10-16
Code: player.gd, "Holy tank: the Censer". Numbers: balance.gd (INCENSE_*, MOTE_*, ...). Pictures: scripts/censer.gd, scripts/light_mote.gd.
- Gear: heavy armor, a melee weapon and an off hand item (tome, wand, lantern; not a shield). Every ability requires both (`requires_off_hand`). It keeps the small Dodge and Parry its stats give; nothing in the spec builds on them.
- The censer is not an item: the first censer ability makes it appear at your side on a chain of light; it fades 3 s after combat. Pure Holy: light and sacred incense (white-gold), never fire or embers.
- Mana: every ability costs a little (fractions of a mana point allowed). Nonstop tanking runs dry in ~5-7 minutes.

### Incense (the censer's fullness)
- A buff, 0-100 stacks, 30 s; any gain refreshes it, spending doesn't. It also drains 1 stack every 2 s (2026-10-30: it was too easy to keep up), except while the censer is raised. The censer glows brighter with more.
- Each stack: +0.15% Block (+15% at 100), shown as a faint barrier of light that flashes on a block. Enemies within 5 m take up to 0.06 FB Holy per second (at 100), 4x threat, own meter line "Incense".
- Small direct gains: +1 per hit taken, +2 per hit blocked, a few from builders.

### Motes of light (the main source)
- Builders knock motes loose from enemies; spending Incense drops motes worth 60% of what was spent (up to 5 per spend).
- A mote holds 10 Incense and heals you for 0.1 old Heals when you walk within 1.2 m (own meter line "Light Mote"). Lands 2-5 m from the enemy, lasts 10 s, max 12 on the ground (oldest fades).
- Own-only: only the owner picks them up; bright for the owner, faint for the party.

### Kit (FB; mana in points)
- Censer Swing - filler, 0.5 FB (was 0.7; tank rule pass), 3x threat (was 4x), +3 Incense, knocks 1 mote loose. 0.4 mana.
- Hallowed Arc - 8 s cd, 0.5 FB within 8 m, 4x threat, +1 Incense per enemy, 1 mote per enemy (max 3). 1 mana.
- Guiding Ray - 10 s cd, 25 m, 0.4 FB, 6x threat, +3 Incense, a mote at the enemy. The ranged pull. 1 mana.
- Pour Out - 12 s cd, needs 30 Incense, spends all: 0.03 FB per stack within 8 m (3.0 FB at 100), 4x threat (was 6x). 2 mana.
- Absolve - 10 s cd, spends up to 40 Incense, heals 0.05 old Heals per stack (2.0 at 40). 1.5 mana.
- Aureole - off GCD, 20 s cd, spends 30 Incense: +25% Block for 5 s.
- Gather the Light - off GCD, 30 s cd: picks up every mote at once.
- Raise the Censer - 90 s cd, 30 m: the censer hangs 4 m over the enemy for 8 s. Enemies within 10 m of it must attack you for 4 s; it sheds a mote every second. Meanwhile your Incense gives no Block and no aura (it is kept and comes back). Utility, not damage. 2 mana.
- Unfallen - off GCD, 120 s cd, 8 s: nothing can kill you, hits give double Incense; when it ends you heal for 30% of the damage taken during it.

### Rune (Epic)
- Bright Burst: picking up a mote deals 0.15 FB Holy within 5 m, 4x threat, own meter line.

## Melee (Daylight, two-handed mace or hammer) - spec "High Noon" - DRAFT, not planned soon
- Theme: a small sun icon over the resource bar rises as Daylight builds; the hammer glows hotter. Ties into the Dusk till Dawn rune.
- Daylight: 0-100 bar like Fury. Built by strikes, spent by finishers. At 75+ it is Noon: strikes deal 15% more. Out of combat it fades.
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

## Caster (the Herald) - spec "Herald's Voice" - DRAFT, not planned soon
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

## Talents (ribbon layout, 2026-10-27; TREE_VERSION 12)
- Specs side by side as ribbons: Choir of One (columns 1-3), Censer Bearer (4-6), the open talents on the spine (7), Line of Light (8-10), Lightstring (11-13). 19 talents per spec, at most 5 needing one ability; capstones need 15 points in the spec. Code: each spec's component (holy_hymns.gd, holy_censer.gd, holy_prisms.gd, holy_lightstring.gd); hit and heal bonuses and the open talents: holy_talents.gd. The tree is no longer full: the melee and caster drafts would get ribbons of their own.
- Shapes: Choir of One "bell", Censer Bearer "censer", Line of Light "cut gem", Lightstring "sun arrow". Links: Many Voices -> Choir Loft, Watchful -> Night Watch; Wide Arc -> Deep Pour, Heavy Motes -> Shaken Loose; Wide Burst -> Prismatic Burst, Thirsty Glass -> Full Glass; Deep Burn -> Long Volley, Gilded -> Full Gold.
- Choir of One (54 ranks): Many Voices (2), Watchful (2), Mercy's Ear (2), Choir Loft (2, Chorus reaches 1/2 more allies), Night Watch (3, Vigil 6/7/8% instead of 5%), Key Change (3), Open Doors (4, Shelter), Swelling Chorus (3, Sing Chorus), Warded Song (3, Vigil's shield 33/67/100% larger), Rising Voice (3, booms 5/10/15% stronger), Long Note (3), Long Echo (3, Reprise repeats at 45/50/55% instead of 40%), Sheltering Light (3, moved from the shared talents), Tender Mercy (3, Mercy's heals +4/8/12% on top), Full Voice (2, a Full Choir gives 1/2 more Verses back), Held Note (2, out of combat Verses fade every 4/6 s), Mercy Seat (3, Benediction +10/20/30% below 35% health), Breath Between (3, each boom gives 1/2/3% max mana). Capstone Radiance (5, Holy heals +2-10%; at max a boom whose 6 Verses all suit it is 20% stronger, Bulwark of Song 20% longer).
- Censer Bearer (55 ranks): Heavy Chain (2, Censer Swing), Absolution (3, Absolve), Mote Magnet (2), Wide Arc (3, Hallowed Arc), Bright Barrier (3), Lingering Light (2), Bright Motes (3, no longer needs Censer Swing), Offering (3, Pour Out and Absolve +5/10/15%), Full Censer (3, 2/4/6% less damage taken at 75+ Incense), Heavy Smoke (3, the Incense aura +10/20/30%), Unbroken (3, Unfallen), Heavy Motes (3, motes give 1/2/3 more Incense), Deep Pour (3, Pour Out), Turned Aside (3, a block heals 0.3/0.6/1% max health; own meter line), Cloying Smoke (3, censer abilities and Incense +5/10/15% threat), Shaken Loose (3, a 10/20/30% chance a builder knocks one more mote loose), Ringing Censer (2, blocks give 1/2 more Incense), Hold the Line (3, below 35% health Incense gives 33/67/100% more Block, as a buff). Capstone Censer's Weight (5; at max, with 100 Incense, 10% more on top).
- Line of Light (55 ranks): Wide Burst (3, Shatter All), Quick Lance (3, Bright Lance), Steady Ray (3, Mending Ray), Clear Glass (2), Prismatic Burst (3, Shatter All), Deep Crystal (3), Quick Realign (3, Realign), Thirsty Glass (3, beams charge 10/20/30% more), Sharp Facets (2), Clear Mind (3) and Long Glass (2) moved from the shared talents, Bright Shards (3, each shattering prism gives 0.3/0.6/1% max mana; gold ones too), Polish (3, a prism you move gains 10/20/30% of its cap), Aftershine (3, for 6 s after a shatter heals an ally, your heals on them +3/6/9%), Lifeline (3, beam heals +7/13/20% below 35% health), Focused Light (3, a shatter with one ally near heals them 10/20/30% more), Last Glint (2, white prisms that run out shatter with 50/100% of their light), Full Glass (3, a heal whose beam passes a full prism +5/10/15%). Capstone Brilliance (5, shatter heals +4-20%; at max a heal through 3 prisms is 20% stronger).
- Lightstring (57 ranks): Full Quiver (3, Prism Arrow), Glimmering (3, instant bow shots +5/10/15%; no longer needs Glimmer Shot), Steady Aim (3, Refracting Shot), Deep Burn (3, Sunlit Arrow), Wide Fan (2), Split Light (3), Long Volley (3, Spectrum Volley), Wide Break (3, Prism Breaker), Gilded (3, shots charge gold prisms 10/20/30% more), Pinpoint (3, a focused shot 13/16/19% instead of 10%), Burnished (3, moved from the open talents: it names Holy), Lined Up (3, a shot through 2+ gold prisms +4/8/12%), Bright Quiver (2), Light Draw (3, Holy abilities cost 3/6/9% less Energy), Full Gold (3, a full gold prism's refracted arrows +10/20/30%), Gilt Tips (3, auto-shots +4/8/12%), Dazzle (3, refracted arrows +3/6/9% crit chance), Sundown (3, bow shots +5/10/15% below 35% health). Capstone Sunsteel (5; at max new gold prisms start with 33% of their light).
- Open (9): Grace (3), Steadfast (3), Overflowing (3), Watchful Eye (2), Second Breath (2), Penitent (3), Candlelight (3, after healing another ally, your next damaging spell or ability within 6 s +4/8/12%), First Light (3, the first 6 s of a fight: spells and abilities deal and heal 4/8/12% more), Zeal (2).
- Folded earlier: Last Rites (Last Verse 2 min), High Censer (Raise the Censer 1 min), Swift Light (Step of Light 10 s).

## Talents for the other specs (outline, ranks to be set when built)
- Melee: High Noon (Noon from 70/65), Hot Iron (Noon bonus +5/10%), Long Shadow (Zenith +10/20%), Early Riser (Dawnstrike +5 Daylight per rank), Sunburnt (Sunfall cap +1/2 targets), Daybreak (5, bottom: finishers +3-15%).
- Caster: Loud Herald (repeats 43/46/50%), Long Litany (Litany +1 s), Bright Wings (Herald +3/6 s), Star Shower (Falling Star +1/2 m), Chosen Target (Glory bonus +10/20%), Exalted (5, bottom: Holy spells +3-15%).

## Other runes
- Legendary (already exists): Dusk till Dawn. Dawn could also start you at 50 Daylight.
- Epic Fourth Facet (BUILT): you can have 4 prisms instead of 3 (either colour).
- Epic Second Herald: a smaller second Herald on your second-to-last target, repeating at 15%.
- Rare: Zenith at 100 Daylight refunds 20.

## Open questions
- None right now.

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Binding Ring (Holy's root) - instant, 30 s cooldown, 2 mana, 40 m, your friendly target (you with none). A ring of light around them for 8 s; the first 3 enemies to come within 3 m are rooted 3 s. Code: scripts/player/utility.gd.
- Circle of Silence (Holy's interrupt) - instant, off the GCD, 25 s cooldown (shared interrupt cooldown), 2 mana, 30 m, card level 18. A circle within 5 m of the target for 4 s: every enemy casting inside is interrupted, and any enemy that starts a cast inside it is interrupted too (3 s lockout each). Checked every 0.1 s; a client only sends interrupts for enemies whose cast bar shows. Code: scripts/player/utility.gd.
- Holy Ground (2026-10-28) - placed, 45 s cooldown, 2 mana, 30 m. A 5 m circle on the ground for 6 s that no enemy can step into: any that get in (or stand there when it lands) are pushed just past its edge (checked every 0.15 s; bosses are too strong). Area denial, unlike Binding Ring (which roots the first enemies near an ally). Card level 26. Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Steady Voice, Rest, Unfallen.

## Healers: out-of-combat rez
- Hymn of Waking (Choir of One) and Relight (Line of Light) - 8 s cast, 4 mana, 30 m, out of combat only. A dead or downed ally gets up where they fell with 50% health and mana. Code: scripts/player/rez.gd. Last Verse stays the Hymns' combat revive.
