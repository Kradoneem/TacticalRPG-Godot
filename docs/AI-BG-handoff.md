# Tactical RPG — AI Background Handoff

Dit document geeft blijvende ontwerpcontext voor AI-assistenten die aan dit project meewerken.  
Voor de actuele implementatiestatus, bestanden, tests en recente beslissingen zijn de repository en Git-history altijd leidend.

## Bronnen van waarheid

- **Godot 4-repository:** https://github.com/Kradoneem/TacticalRPG-Godot
- **Oude Python/Pygame-versie:** https://github.com/Kradoneem/TacticalRPG
- **Lokale projectmap:** `~/tactical-rpg`

Gebruik de actuele code en Git-history boven oude chatnotities of dit document. Een recente expliciete ontwerpbeslissing van de developer gaat altijd boven oudere context.

---

# 1. Projectvisie

Dit project is een tactische, verhaalgedreven pixel-art RPG.

De speler leidt squads over een grid-gebaseerde wereld. Exploratie, positioning en tactische confrontaties vinden op dezelfde map plaats. Wanneer een gevecht begint, wordt dit kort gepresenteerd in een doelgerichte 2D side-view battle scene. Die presentatie is geen tweede tactical layer en geen langdurige klassieke turn-based battle mode.

De game moet overwinningen laten voelen als iets dat de speler heeft verdiend. Onzekerheid komt voort uit:

- vijandelijke positionering;
- beperkte opties en resources;
- obstakels;
- voorbereiding;
- risicoanalyse;
- squad-samenstelling.

Vermijd arbitraire of ondoorzichtige uitkomsten die agency ondermijnen.

## Ontwerpbril

Gebruik waar relevant psychologische en narratieve ontwerpprincipes:

- **Meaningful preparation:** voorbereiding moet merkbaar bijdragen aan succes.
- **Agency:** keuzes moeten begrijpelijke gevolgen hebben.
- **Unit identity:** spelers moeten een band kunnen opbouwen met individuele units.
- **Sociale dynamiek:** relaties, loyaliteit en frictie binnen de groep mogen betekenis krijgen.
- **Karakterontwikkeling:** mechanische en narratieve groei moeten elkaar ondersteunen.
- **Morele ambiguïteit:** keuzes hoeven niet simpel goed of kwaad te zijn.
- **Heldere progression:** rewards, stats en nieuwe opties moeten leesbaar en betekenisvol zijn.

---

# 2. Wereld en verhaalcontext

De wereld bevat magie, maar geen technologie als normale maatschappelijke basis.

Chapter 1 is een compacte sewer-tutorial die in het verleden plaatsvindt. De protagonist en diens beste vriend hebben een beperkt resourcebudget en ontmoeten corrupte creatures. De tutorial mondt uit in een eindbaas die beschikt over onbekende technologie.

Keuzes in deze tutorial resoneren later in het verhaal. Gebruik dit als ontwerpcontext, maar breid geen toekomstige verhaalcontent uit wanneer dat niet nodig is voor de huidige technische milestone.

---

# 3. Visuele richting

## Tactical map

- Orthografisch top-down.
- Painterly pixel-art uitstraling.
- Gericht op duidelijke leesbaarheid van grid, terrain en squad-tokens.

## Close-ups en battle presentation

- Spaarzame PS1-geïnspireerde perspectiefbeelden.
- Inzetbaar voor boss-introducties, lorebeats of dramatische momenten.
- Locatiespecifieke side-view achtergronden voor battle scenes.

Beide richtingen moeten uiteindelijk aansluiten op dezelfde Blender/ComfyUI-stijlpipeline.

Gebruik placeholders totdat een gameplay-milestone echte visuals noodzakelijk maakt.

---

# 4. Architectuurprincipes

## Algemene codeprincipes

- Bouw modulair, leesbaar en gedocumenteerd.
- Kies schaalbaarheid, maar vermijd abstractie zonder concrete behoefte.
- Geef zelfstandige verantwoordelijkheden eigen scripts.
- Gebruik Autoloads uitsluitend voor werkelijk globale state, bijvoorbeeld:
  - `GameState`;
  - een scene-stack of `SceneManager`.

## Gameplay-state

Een tactical token vertegenwoordigt altijd precies één `Squad`.

- Squads mergen nooit.
- `Unit`- en `Squad`-objecten zijn de gedeelde gameplay-state.
- Tactical gameplay en battle presentation maken geen kopieën van units.
- Battle sprites hebben nooit een eigen gridpositie.

## Drie expliciet gescheiden lagen

### Tactical gameplay state

Verantwoordelijk voor:

- grid;
- vrije beweging;
- zicht en detectie;
- squad-tokens;
- alert turns;
- targetkeuze;
- de toestand van vijandelijke squads op de map.

### Battle presentation

Verantwoordelijk voor:

- tijdelijke 2D side-view scene;
- formaties;
- HUD;
- combat feedback;
- actieanimaties;
- korte cinematics of close-ups.

Deze laag bezit of dupliceert geen duurzame gameplay-state.

### Data en resolution logic

Verantwoordelijk voor:

- `Unit`;
- `Squad`;
- abilities;
- combatregels;
- HP, MP en statuses;
- `EncounterContext`;
- resolutie van acties en gevolgen.

Deze laag mag niet afhankelijk worden van specifieke presentation nodes.

---

# 5. Tactical exploration en alert state

## Vrije exploratie

Exploratie gebeurt op dezelfde tactical grid als confrontaties.

- Tijdens vrije exploratie bestaat geen movement budget.
- De speler kan vrij bewegen totdat een alert state wordt getriggerd.

## Alert state

Wanneer een enemy squad binnen **10 tiles** van de Main Squad komt:

1. start de alert tactical state;
2. alle relevante squad-tokens krijgen turns;
3. turns gebruiken een movement budget.

De exacte formule voor dit movement budget moet nog worden vastgelegd wanneer de actuele implementatie dat vereist.

## Enemy AI

Begin bewust klein:

- `STATIC`
- `PATROL`

Mogelijke latere uitbreidingen:

- `CHASE`
- `GUARD`

Niet-geaggroede patrols houden hun eigen turns en kunnen zelfstandig alert worden.

---

# 6. Tactical encounter-flow

Wanneer de Main Squad adjacent is aan een enemy token, toont de tactical interface:

- `Attack`
- `Defend`
- `Items`
- `Wait`

Bouw en valideer eerst alleen `Attack` volledig.

Wanneer meerdere enemy tokens adjacent zijn:

1. kiest de speler één enemy squad als target;
2. alleen de Main Squad en die gekozen enemy squad gaan de encounter in;
3. alle andere enemy tokens blijven afzonderlijk bestaan op de tactical map.

Er is geen multi-squad battle en geen reinforcement-merging in de side-view battle presentation.

---

# 7. Battle scene en vaste lifecycle

`battle_scene` is een korte, zelfstandige 2D side-view resolution/presentation.

Het is nadrukkelijk niet:

- een tweede exploratielaag;
- een tweede tactical grid;
- een klassieke fight-until-death mode;
- een plek waar meerdere nearby squads samensmelten.

## EncounterContext

De battle scene ontvangt een `EncounterContext` met uitsluitend de betrokken Main Squad en gekozen enemy squad.

Na afloop keert de game terug naar exact dezelfde tactical context, met bijgewerkte gedeelde state.

## Formaties

- Maximaal vier formation-slots per zijde.
- De protagonist krijgt command input.
- Overige allies handelen automatisch.
- Enemies handelen automatisch.
- Een Companion Boss mag een apart groot party-slot gebruiken.
- Bosses mogen meerdere formation-slots beslaan.

## Vaste battle-lifecycle

1. Start ability.
2. Ronde 1:
   - protagonist command;
   - automatische allies;
   - automatische enemies.
3. Ronde 2:
   - protagonist command;
   - automatische allies;
   - automatische enemies.
4. Finishing ability.
5. Terugkeer naar dezelfde tactical context.

De battle eindigt eerder wanneer een betrokken squad volledig is verslagen.

Als de battle na twee rondes niet eindigt:

- blijven HP behouden;
- blijven MP behouden;
- blijven statuses behouden;
- wordt de tactical context hervat.

Start- en finishing-hooks mogen veilig overslaan zolang equipment en loadouts nog niet bestaan.

---

# 8. Victory, defeat en dungeon completion

Wanneer een enemy squad verslagen is:

- markeer of verwijder die squad individueel op de tactical map;
- verander geen andere enemy squads door die overwinning;
- behoud de reguliere tactical context.

Een dungeon is pas cleared wanneer **alle** enemy-squad-tokens defeated zijn.

Pas daarna verschijnt één gezamenlijk resultaatscherm met:

- totale XP;
- totale loot.

Verzin geen XP-, loot- of rewarddata wanneer die nog niet in projectdata bestaat.

---

# 9. Ability-data en ownership

`SkillData` is de catalogus voor alle abilities.

`Unit` bewaart alleen bekende ability-ID’s:

- `learned_skills`;
- `learned_spells`.

Nieuwe gamecode kent abilities toe via:

```gdscript
unit.learn_ability(ability_id)

10. Prioriteitsrichting
De algemene technische richting is:

bestaande Python/Pygame-functionaliteit migreren waar nodig;
noodzakelijke gameplay-architectuur bouwen;
pas daarna nieuwe combatregels of presentation-polish toevoegen.
Een beoogde volgorde is:

BattleSession refactor naar de vaste battle-lifecycle;
tactical alert-turncontroller;
grote exploration-testmap.
Deze volgorde is geen onveranderlijk plan: toets haar steeds aan de actuele repository en de nieuwste ontwerpkeuze.

Sewer art-baseline
De eerdere depth + prompt-aanpak liet materiaalinterpretatie te vrij. Color + depth gaf betere herkenbaarheid van waterkanalen en betere samenhang. De stijl varieert nog, mede door verschillen in bronrenders en framing; gelijke prompt is geen garantie op gelijke stijl.
De geleverde ComfyUI-workflow gebruikt daadwerkelijk DreamShaper XL, met checkpointbestandsnaam DreamShaperXL1.0Alpha2_fixedVae_half_00001_.safetensors. De oude labels waren misleidend; de NoobAI-nodes deden alleen een VAE-rondgang en zijn verwijderd. Niet zonder overleg wisselen van checkpoint om stijlvariatie te repareren.
Workflowbaseline, niet noodzakelijk de laatste lokale instellingen:
Color → VAE Encode → KSampler → VAE Decode → SaveImage.
Bijbehorende depth → ImageInvert → SDXL Depth ControlNet.
Denoise 0,55; depth strength 0,60; start 0,00 / end 0,55.
35 steps; CFG 7,5; Euler / Karras.
Seed 789571244948615, vast houden bij vergelijking.
Negative prompt leeg.
Bij color/depth-input dezelfde camera, uitsnede en afmetingen gebruiken.
Img2img-resolutie volgt de color-input als er geen resize-node tussen zit. Full-resolution 4K-verwerking is zwaarder; exacte gebruikte verwerking en GPU-capaciteit nog niet vastgelegd.
Vaste prompt:
Layouts en ontwerpcontext
Entrance: droge startkamer, linker entree met korte afdaling, afgesloten poort naar een korte donkere doorgang, kanaal aan de voorzijde.
Corridor: 12 × 3 vloermodules, parallel waterkanaal, linker entree en uitgang rechtsachter.
Maintenance: compacte 5 × 4 onderhoudsnis, L-kanaal, rooster, tonnen, planken en puin; cache als visueel prototype.
Grote map: asymmetrische west- en oosthal met zijruimte; vier uitgangen; twee stenen bruggen en een ondiepe waadplek. Noordoostelijke uitgang mag later verborgen zijn maar wordt nu gewoon zichtbaar getoond.
Waadplek is alleen visuele geometrie. Het materiaal is niet geschikt om daaruit automatisch walkability of waterdiepte af te leiden; terrain-state moet later expliciet in Godot worden vastgelegd.
Waterwiel besproken maar geparkeerd om deze tests niet met een dominante prop te belasten.
