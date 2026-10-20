# Gedeelde ability-uitvoering en protagonistcommandmenu

- AbilityResolver is gedeeld door handmatige en automatische acties.
- Hij valideert ownership, squad-targetgrenzen, ondersteuning en HP/MP-kosten.
- Kosten en effect worden eenmaal synchroon uitgevoerd.
- AutomaticActionResolver kiest nog steeds alleen het bestaande supportgedrag.
- Supportdrempel en bestaande healingformules blijven intact.
- BattleAbilityMenu toont Attack, Skills en Spells op basis van bekende IDs.
- BattleSession begrenst protagonistcommands voorlopig tot single-enemy damage.
- Gedeelde resolver ondersteunt ook bestaande single-ally healing.
- Python additive damage-scaling en defense-afhandeling zijn gemigreerd.
- Focused Strike behoudt zijn prototype-multiplier.
- Ingredientkosten, drain, buffs, groepsacties en elemental resistances ontbreken.
- Twee-ronden-lifecycle, results en questmeldingen blijven behouden.
- Geen permanente nieuwe startabilities of MP-budgetten toegevoegd.
- Teststatus: werkt

# Quest-objectives, meldingen en Party Quest Log

- QuestDefinition en QuestObjective zijn Resources met vaste definities.
- QuestData bevat drie prototype-testquests, geen definitieve Chapter 1 lore.
- LocationData definieert sewer_test_slice expliciet als corridor + junction.
- Deze test-slice is niet het volledige toekomstige sewer-dungeon.
- GameState bewaart queststatus en behaalde objective-IDs afzonderlijk.
- Objective achievement is blijvend; quest completion is een expliciete stap.
- Bestaande squad-/map-/locatie-clearqueries bepalen objective achievement.
- Refresh gebeurt bij map-entry en na encounterterugkeer, niet per frame.
- Alleen nieuwe objectivevoortgang emit een update.
- Main bezit één blijvende niet-modale QuestUpdateBanner buiten GameLayer.
- Meldingen wachten tijdens battle/results, Party en modal mapinteracties.
- De wachtrij blijft behouden bij kamerwisselingen.
- Party bevat een zelfstandig read-only Quest Log met bestaande inputisolatie.
- Party blijft tijdens tactical alert en battle geblokkeerd.
- Geen NPC-inlevering, questrewards, dialogue of save/load geïmplementeerd.
- Encounter-rewards blijven afzonderlijk en worden niet door quests herhaald.
- Teststatus: werkt

# Encounter-results — nieuw ontwerpcontract

Dit vervangt oudere dungeon-clear-only-resultregels.

- Na volledige enemy squad defeat: eenmaal encounter-rewards en één
  resultaatscherm na afloop van de korte battle transition.
- Geen normaal resultaatscherm wanneer enemies na twee rondes nog leven.
- Bijzondere encountermeldingen kunnen onafhankelijk results tonen,
  zonder automatisch defeat-rewards te geven.
- EncounterResult bevat daadwerkelijke opbrengsten en schermbeslissing.
- GameState.settle_encounter() kent rewards eenmaal toe.
- Python-XP-formule is gemigreerd; iedere levende deelnemer krijgt het
  volledige squadbedrag. Defeated deelnemers krijgen geen XP.
- Huidige sewercontent heeft geen geverifieerde gold/lootdata:
  defaults blijven nul/leeg.
- Squad defeat, map clear en expliciete locatie-mapclear zijn aparte
  toekomstige questvoorwaarden, geen extra encounter-rewardtriggers.
- Er is nog geen volledig questsysteem of location manifest geïmplementeerd.
- Resultpanel blijft binnen de bestaande tijdelijke BattleScene-presentatie.
- Automatische terugkeer/results gebeurt na de laatste actiefeedback.
- Teststatus: “automatische en handmatige tests geslaagd”

# Actuele aanvulling — equipment afgerond, 20 oktober 2026

Dit blok heeft voorrang op conflicterende statusclaims hieronder.
De eerdere Items-, Party-, junction- en battle-lifecycle-milestones
blijven afgerond.

## Getest en gepusht gameplay-ijkpunt

- Commit: `9c0546b — feat: migrate party equipment and derived unit stats`.
- Volledige SHA: `9c0546b5c0f4d1fb292c98aea99186184c815d50`.
- De gebruiker bevestigt dat de implementatie en tests werken.
- Equipment is geen Party-placeholder meer. Formation blijft placeholder.

## Architectuur en gedrag

- EquipmentData bevat de centrale equipmentdefinities.
- GameState.equipment_inventory bewaart equipment-ID → beschikbaar aantal.
- Unit bewaart slot → uitgeruste ID; publieke equipment levert een snapshot.
- Effectieve stats zijn basisstats plus huidige equipmentbonussen.
- Bestaande combat- en UI-callers blijven dezelfde Unit-properties lezen.
- GameState.change_equipment() beheert voorraad en uitrustingswissels.
- Uitgeruste gear is niet tegelijkertijd beschikbaar in voorraad.
- Vervangen of afgelegde gear keert terug naar voorraad.
- Party ondersteunt squad → lid → slot → uitrusten/afleggen.
- Level-ups wijzigen basisstats; equipmentbonussen blijven afzonderlijk.
- HP-percentage blijft bij equipmentwissels behouden, afgerond naar beneden.
- Levende units behouden minimaal één HP; defeated units blijven op nul HP.
- Items blijft functioneren met de effectieve stat-properties.

## Grenzen

- Slots: weapon, armor, accessory; Wooden Shield blijft voorlopig armor.
- Gear en startvoorraad zijn Python-prototypes, geen definitieve balans.
- Geen equipment-granted abilities, start-/finishing-loadouts,
  classrestricties, durability of unieke enchantments geïmplementeerd.
- Volgende gameplay-milestone nog niet gekozen.

---


# Actuele aanvulling — 20 oktober 2026

Dit blok heeft voorrang op conflicterende statusclaims hieronder.
De eerdere junction-, battle-lifecycle- en centrale Party-milestones
blijven afgerond.

## Nieuw getest en gepusht gameplay-ijkpunt

- Commit: `21fb38f — feat: add item catalog and quantity-based party consumables`.
- Volledige SHA: `21fb38f10d2b7b7ce933ea76963a6334e2e3f4b4`.
- Automatische datatest en handmatige gameplaytests zijn door de gebruiker
  geslaagd verklaard.
- Items is geen Party-placeholder meer. Equipment en Formation blijven
  placeholders.

## Itemarchitectuur

- `scripts/domain/item_data.gd`: centrale catalogus met itemdefinities.
- `GameItem` en `ItemEffect`: Resources met beschrijving en effecten,
  zonder voorraadgegevens.
- `GameState.item_inventory`: dictionary met item-ID → hoeveelheid.
- `GameState.add_item()` en `use_item()`: voorraad, ownership en verbruik.
- `ItemUseResolver`: valideert alle effecten vóór uitvoering.
- PartyMenu: item → squad → één levend lid → gebruik en feedback.
- Bestaande Unit-referenties worden aangepast; geen gameplaykopieën.

## Gevalideerd gedrag en grenzen

- HP-/MP-herstel, samengestelde Elixir-effecten en éénmalig verbruik.
- Annuleren zonder verbruik; nulvoorraad wordt verwijderd.
- Menu-inputisolatie, alertblokkering en behouden toestand bij kamerterugkeer.
- Gebruik op een vol target verbruikt voorlopig één item, conform Python.
- Prototypecontent: Potion 20 HP, Hi-Potion 50 HP, Ether 10 MP,
  Elixir 30 HP en 30 MP. Startvoorraad: één van elk.
- Deze voorraad is geen definitief Chapter-1-resourcebudget.
- Battle-itemgebruik, automatische itemstrategieën, classbonussen,
  revival en groepsheals zijn niet geïmplementeerd.
- Een encounter-party-heal is een latere ontwerpwens.
- Volgende gameplay-milestone nog niet gekozen; herijken tegen actuele
  code en bestaande Python-functionaliteit. Geen art- of battle-polish.

---

# Actuele projectstatus — 19 oktober 2026

Dit blok heeft voorrang op alle historische statusclaims en roadmaps hieronder. Historische passages blijven als context behouden, maar zijn geen actuele bouwopdracht. Controleer bij iedere nieuwe sessie eerst de huidige Git HEAD via de GitHub API en lees vervolgens SHA-gepinde bestanden. Recente expliciete gebruikersbesluiten hebben voorrang.

## Vastgelegd ijkpunt

- Repository: https://github.com/Kradoneem/TacticalRPG-Godot
- Lokale projectmap: `~/tactical-rpg`
- Branch: `main`
- Geteste en gepushte gameplaycommit: `3309293 — feat: centralize party menu and fix status formatting`.
- Volledige SHA: `33092936ceb20c67e5778c15bca1a7f8a9529167`.
- Eerdere ijkpunten: `0394d53` — zelfstandige STATIC/PATROL-squads op junction; `87b4245` — battlepresentation isoleren van tactical camera en UI.
- Dit is een gameplay-ijkpunt, niet noodzakelijk de nieuwste HEAD na een documentatiecommit.

## Afgeronde exploration/junction-milestone

De gebruiker heeft de junction-loop getest en bevestigd:

- Entrance, corridor, maintenance en junction gebruiken de gedeelde exploration-architectuur.
- De grote junction-placeholder is geïntegreerd als gameplaytestmap met camera/scrolling, gekalibreerde grid, walkable zones en mapverbinding.
- STATIC en PATROL functioneren als zelfstandige enemy-squad-tokens. Iedere token vertegenwoordigt precies één Squad; squads mergen nooit.
- Patrols bewegen na een geldige Main Squad-beweging tijdens vrije exploration; geblokkeerde bewegingen tellen niet mee.
- Tijdens alert bewegen patrols op hun eigen tactical beurt; STATIC blijft staan.
- Attack bevat uitsluitend de Main Squad en de gekozen adjacent enemy squad. Andere tokens blijven zelfstandig op de tactical map.
- Battle keert terug naar dezelfde tactical context. HP/MP en individuele defeated-state blijven behouden, ook bij maintenance → junction-terugkeer.
- De bestaande battle-lifecycle en tactical alert-foundation zijn al geïmplementeerd; stel die niet opnieuw voor als ontbrekende refactor.
- BattleSession gebruikt een configureerbare `maximum_rounds` via EncounterContext, voorlopig standaard twee volledige rondes. Start- en finishing-hooks skippen veilig zolang loadouts ontbreken.

## Afgeronde battlepresentation-fix

- SceneManager gebruikt een afzonderlijke screen-space CanvasLayer voor tijdelijke battlepresentation.
- Battle volgt niet de tactical Camera2D.
- De tactical source-instance blijft behouden; geen kopieën van Squad- of Unit-objecten.
- Bronzichtbaarheid, bron-CanvasLayers en process-mode worden tijdelijk aangepast en daarna hersteld.
- Exploration-UI is tijdens battle verborgen; terugkeer is getest.

## Afgeronde centrale Party-milestone

### Verantwoordelijkheden

- `scripts/ui/party_menu.gd`: bestaande interface, schermnavigatie, squad-/unitinspectie en bekende abilities.
- `scripts/ui/party_menu_controller.gd`: centrale eigenaar en toegangspoort; geen menunavigatie en geen eigen partydata.
- `scripts/core/main.gd`: maakt één PartyMenuController buiten GameLayer aan, zodat die kamerwisselingen overleeft.
- SceneManager en actieve scenes leveren toestemming voor openen.
- PartyMenu leest dezelfde bestaande Squad- en Unit-referenties als gameplay.

### Werkend en getest

- Openen met Escape via Main.
- Status toont squadselectie, unit level, actuele HP/MP, Attack, Defense, Speed, Wisdom en bekende skills/spells.
- Het aantal squads en unitstats worden correct geformatteerd. De eerdere zichtbare `%d`-placeholders zijn opgelost door eerst de volledige template samen te stellen en daarna te formatteren.
- Menunavigatie blijft in PartyMenu via de publieke `handle_menu_input(event)`-functie.
- PartyMenu verwerkt keyboard-input vóór GUI-afhandeling; de controller roept geen private menufuncties aan.
- WASD/pijltjes navigeren; Enter/Spatie bevestigt; Escape gaat terug en sluit op het hoofdmenu.
- De controller zet GameLayer tijdelijk op `PROCESS_MODE_DISABLED` en herstelt de eerder opgeslagen process-mode bij sluiten. Dit is geen globale SceneTree-pauze.
- Main Squad, patrols en mapinteracties handelen niet op menunavigatie.
- Het menu werkt op sewer-maps en de stad-placeholder; exit-/terugreisinput lekt niet door.

### Expliciete beschikbaarheidsbeslissing

Party is een algemene gamefunctie, niet een exploration-specifiek menu.

- Normaal beschikbaar op sewer-, stads- en toekomstige locaties.
- Niet beschikbaar tijdens tactical alert: **alert betekent dat tactical combat is gestart**.
- Niet beschikbaar tijdens tactical acties, strategy selection en side-view battlepresentation.
- Niet beschikbaar tijdens actieve dialogue.
- Tijdelijk geblokkeerd tijdens modal exitinteractie, pending terugreis/transitions en geregistreerde SceneManager-overlays.
- Na hervatte vrije exploration is Party weer beschikbaar.

Beschikbaarheid van het menu en toestemming voor individuele opties zijn afzonderlijke zaken. Save/load, units toevoegen of tussen squads wisselen kunnen later contextafhankelijke opties worden. Er zijn nog geen nieuwe voorwaarden of systemen voor geïmplementeerd.

### Grenzen

- Equipment, Items en Formation zijn expliciete placeholders; geen itemgebruik, equipment/loadout of squadwisselbeheer geïmplementeerd.
- `set_blocked(reason, blocked)` is een aansluitpunt voor toekomstige modal systemen zoals dialogue. Er is nog geen dialogue-systeem aangesloten; daadwerkelijke dialogueblokkering is dus nog niet end-to-end gevalideerd.
- De legacy-testscene `tacticaltest.gd` bevat nog eigen PartyMenu-aansturing. De centrale milestone is getest via Main met de sewer-route. Ruim die legacy-koppeling later gericht op; maak geen tweede centrale controller.
- Geen `ExplorationPartyMenu` en geen extra Party-Autoload toevoegen.

## Behouden grenzen en backlog

- Mapcache is gamesessie-state, geen disk-save/load.
- Meerdere verbindingen tussen dezelfde maps zijn niet gevalideerd.
- Bewaarde maps accepteren volgens het bestaande entry-contract hun opgeslagen vertrekcel.
- Een begrensd cache-ontlaadbeleid ontbreekt nog.
- Spelvenster blijft 1920 × 1080; achtergrondresolutie staat los van viewportresolutie.
- Uniforme pixels-per-tegel-schaal tussen alle achtergronden is nog niet bewezen. Junction-integratie lost automatische framingverschillen van entrance/corridor niet vanzelf op.
- De maps blijven gameplay-placeholders. Geen nieuwe art-polish of dynamisch fakkellicht zonder concrete gameplaybehoefte.
- Items/equipment/loadouts, dialogue/quests/shops, progression, map-clear rewards en save/load zijn nog niet als nieuwe milestones afgerond.
- Perception, lockpicks en interactieve caches zijn contentwensen, geen geïmplementeerde regels. Ontdekken, openen en loot toekennen blijven afzonderlijke stappen.
- Geen verzonnen rewarddata, checkformules, verbruik of movement-/initiativeformules voorstellen. Lees bestaande implementaties voordat ontbrekende regels worden aangenomen.

## Volgende sessie

1. Controleer lokale `git status`, laatste commit en relevante diffs. Lees GitHub main-HEAD via API; gebruik daarna SHA-gepinde bronnen.
2. Gebruik dit blok als actueel ijkpunt. Stel BattleSession-lifecycle, alert-foundation, junction-integratie of een nieuw minimaal PartyMenu niet opnieuw als ontbrekend werk voor.
3. De volgende gameplay-milestone is nog niet gekozen. Herijk bestaande Python-migratie en noodzakelijke gameplayarchitectuur tegen actuele code en de nieuwste gebruikerskeuze.
4. Controleer vóór nieuwe code relevante Godot-bestanden en, bij migratie, de overeenkomstige Python-functionaliteit.
5. Beperk iedere milestone tot één concrete gameplayuitbreiding. Nieuwe ideeën die de milestone doorkruisen gaan op de backlog.
6. Lever volledige functies of bij grote refactors volledige vervangende bestanden, zonder de overige bestaande inhoud blind te overschrijven.
7. Na testen: relevante bestanden committen en pushen. Bij `remote: Internal Server Error`: opnieuw `git push origin main`, niet force-pushen.
8. Na 30 minuten vastlopen hulp vragen met de eerste foutmelding en het betrokken scriptpad.

## Lokale repositoryhygiëne bij dit ijkpunt

De laatste lokale status bevatte alleen untracked bestanden naast de gepushte gameplaycommit: `art/`, losse kalibratie-exports en een verdacht bestand `tatus --short`. Dit zijn geen automatisch te committen gameplaywijzigingen. Inspecteer het verdachte bestand vóór verwijderen; gebruik geen `git add .` of brede cleanup-opdracht. De huidige lokale status moet bij hervatten opnieuw worden gecontroleerd.

---


## Historische context — oude statusclaims hieronder eerst verifiëren

# Persona Patch — Godot Tactical RPG: Handoff oktober 2026

> **Gebruik:** voeg dit document toe aan of vervang conflicterende passages in de bestaande Game Developer Persona.  
> **Prioriteit:** recente expliciete ontwerpbeslissingen hieronder hebben voorrang op oudere notities, inclusief oudere passages over vrije exploration zonder move budget en over reinforcement-squads die in dezelfde side-view battle zouden verschijnen.

---

## 1. Projectbronnen en verificatie

### Actieve Godot-repository

- Repository: `https://github.com/Kradoneem/TacticalRPG-Godot`
- Lokale projectmap: `~/tactical-rpg`
- Primair branch: `main`
- Bevestigde huidige commit op `main`:

```text
39dca3c — refactor: unify learned skill and spell ownership
```

### Oude Python/Pygame-repository

- Repository: `https://github.com/Kradoneem/TacticalRPG`
- Relevante migratiebronnen:
  - `skill.py`
  - `skill_data.py`
  - `unit.py`
  - `game_state.py`
  - `party_menu.py`
  - `battle.py`
  - `battle_scene.py`
  - `battle_results_scene.py`

### Git als bron van waarheid lezen

Gebruik Git en GitHub om feitelijke projectstatus te controleren vóórdat je code voorstelt. Vertrouw niet op verouderde aannames, losse chatnotities of een mogelijk gecachete branch-URL.

#### Lokaal: eerst doen wanneer de gebruiker terminaloutput kan geven

```bash
git status
git branch --show-current
git log -1 --oneline
git show --stat --oneline HEAD
git diff HEAD~1..HEAD
```

Voor een specifiek bestand in de laatste commit:

```bash
git show HEAD:scripts/domain/unit.gd
git diff HEAD~1..HEAD -- scripts/domain/unit.gd
```

Voor zoeken in het lokale project:

```bash
grep -R "learn_skill\|learn_spell\|learn_ability" -n scripts
```

#### Via GitHub API: voorkeur boven `raw/.../main` bij recente pushes

1. Lees eerst de actuele branch-head:

```text
https://api.github.com/repos/Kradoneem/TacticalRPG-Godot/commits/main
```

2. Noteer de SHA uit het antwoord.

3. Lees daarna bestanden vastgepind op die SHA:

```text
https://raw.githubusercontent.com/Kradoneem/TacticalRPG-Godot/<COMMIT_SHA>/scripts/domain/unit.gd
```

4. Inspecteer wijzigingsdetails via:

```text
https://api.github.com/repos/Kradoneem/TacticalRPG-Godot/commits/<COMMIT_SHA>
```

Dit endpoint geeft commit message, gewijzigde bestanden en patches terug.

5. Voor een volledige bestandsinventaris:

```text
https://api.github.com/repos/Kradoneem/TacticalRPG-Godot/git/trees/main?recursive=1
```

#### Belangrijke les over GitHub caching

Een branch-raw-URL zoals hieronder kan vlak na een push tijdelijk oude inhoud tonen:

```text
https://raw.githubusercontent.com/Kradoneem/TacticalRPG-Godot/main/...
```

Als een branch-raw-bestand en de commit-API elkaar tegenspreken:

- behandel de commit-API en de SHA-gepinde raw URL als betrouwbaar;
- claim niet dat werk ontbreekt voordat je de actuele commit-SHA hebt gecontroleerd;
- vraag bij twijfel om `git log -1 --oneline` en `git status` uit de lokale repository.

#### Pushfouten

Bij een GitHub-fout zoals `remote: Internal Server Error`:

- dit is doorgaans een tijdelijke serverfout, geen reden voor `--force`;
- laat de gebruiker eerst simpel herhalen:

```bash
git push origin main
```

- laat bij twijfel daarna controleren:

```bash
git status
git log -1 --oneline
git fetch origin
git push origin main
```

- adviseer nooit `git push --force` zonder een expliciete, gecontroleerde reden.

---

## 2. Mentorstijl en scopebewaking

De gebruiker wil expliciet dat de mentor kritisch is en scope bewaakt.

### Hoofdregel

**Migreer eerst bestaande Python-functionaliteit en bouw de noodzakelijke gameplay-architectuur. Voeg geen presentatiepolish of nieuwe battlefeatures toe tenzij die een directe technische voorwaarde zijn voor de volgende echte gameplay-milestone.**

De HP-bar-tween was de laatste toegestane kleine battle-presentationverbetering, omdat die bestaande combat feedback leesbaar maakte. Daarna is battle polish bevroren.

### Werkwijze per les

1. Controleer de actuele code en ontwerpbeslissingen.
2. Benoem welk probleem deze milestone oplost.
3. Geef een werkend, compleet voorbeeld.
4. Benoem welke bestanden wijzigen voordat code volgt.
5. Toon bij een wijziging altijd een **volledige functie**, geen fragment.
6. Laat de gebruiker testen, committen en pushen.
7. Pas daarna doorgaan.

### Niet doen

- Niet terugvallen op een combat-laag bovenop de tactical map.
- Niet opnieuw voorstellen om alle nearby enemy squads samen te voegen tot één side-view enemy formation.
- Niet een generiek unlock-framework bouwen zonder concrete gamecontent die het rechtvaardigt.
- Niet `battle_scene` uitbreiden met cosmetic polish zolang de tactical exploration/alert-loop ontbreekt.
- Niet Python letterlijk kopiëren als de Godot-architectuur een aantoonbaar beter patroon heeft. Migreer de functionaliteit, niet automatisch alle oude structuur.

---

## 3. Vastgelegde data- en abilityarchitectuur

### Kernprincipe

`SkillData` is de centrale catalogus van alle bestaande abilities. Een `Unit` bewaart alleen de IDs van abilities die permanent bekend zijn.

```text
SkillData
├── definitie van iedere ability
├── get_all_ability_ids()
├── get_all_skill_ids()
└── get_all_spell_ids()

Unit
├── learned_skills: Array[StringName]
└── learned_spells: Array[StringName]
```

### Geen `SkillUnlockService`

Een universele unlock-service is op dit moment onnodige abstractie.

Gebruik expliciete toekenning op het moment dat een gameplay-systeem een ability verleent:

| Oorzaak | Verantwoordelijk systeem | Actie |
|---|---|---|
| Startloadout | `UnitData` | `unit.learn_ability(id)` |
| Spell kopen | toekomstig shop-systeem | valideer voorraad/gold, daarna `unit.learn_ability(id)` |
| Quest reward | toekomstig quest/dialogue action-systeem | `unit.learn_ability(id)` |
| Level-up ability | toekomstig character progression data-systeem | `unit.learn_ability(id)` |
| Equipment-granted ability | toekomstig equipment-systeem | tijdelijk beschikbaar maken; niet permanent leren |

### Waarom dit juist is

Een prijs van bijvoorbeeld `250 gold` voor Blizzard is shopcontent, geen inherente spellregel. Een quest-ID is questcontent, geen eigenschap die de `Skill`-klasse hoeft te bezitten.

### Bevestigde abilitymigratie

Commit `a6a9656 — feat: expand skill and spell domain model` heeft toegevoegd:

- `Skill.Category`: `SKILL`, `SPELL`;
- effects: physical damage, magic damage, heal, drain, buff, debuff;
- targettypes: single enemy/ally, all enemies/allies, self;
- scaling types: attack, wisdom, flat;
- elementen, MP/HP/item costs, base value;
- gemigreerde Python-abilities plus bestaande Chapter 1 prototype-abilities.

Commit `39dca3c — refactor: unify learned skill and spell ownership` heeft toegevoegd:

- `Unit.learn_ability(ability_id)`;
- `Unit.forget_ability(ability_id)`;
- `Unit.knows_ability(ability_id)`;
- compatibility methods `learn_skill()` en `learn_spell()` die via `learn_ability()` correct routeren;
- `AutomaticActionResolver` zoekt nu in alle geleerde abilities;
- `SkillData.get_all_ability_ids()`, `get_all_skill_ids()` en `get_all_spell_ids()`.

### Belangrijke consistency-regel

`Mend` en `Patch Flesh` zijn inhoudelijk spells. Bestaande callers mogen tijdelijk nog `learn_skill()` gebruiken, omdat die compatibility method category-aware routeert. **Nieuwe code gebruikt altijd `learn_ability()`.**

---

## 4. Gecorrigeerde tactical gameplay-architectuur

### Terminologie: drie opeenvolgende states

Gebruik deze termen consequent. Noem de alert tactical laag niet simpelweg “battle”, omdat `battle_scene` de afzonderlijke side-view presentation is.

```mermaid
flowchart LR
    free["Vrije exploration<br>geen move budget"] --> notice["Enemy notice<br>binnen 10 tiles"]
    notice --> alert["Alert tactical state<br>turn-based squad movement"]
    alert --> choice["Adjacent enemy squad<br>tactical action menu"]
    choice --> transition["Attack<br>battle transition"]
    transition --> battle["2D side-view battle presentation<br>start ability → 2 rondes → finishing ability"]
    battle --> return["Terug naar exact dezelfde<br>tactical mapstate"]
    return --> alert
```

### 4.1 Vrije exploration

- De Main Squad beweegt vrij over dezelfde tactical grid.
- Er is in deze state geen move budget.
- Escape opent hier de universele Party Menu/pause overlay.
- De Party Menu is alleen beschikbaar als er geen actieve combat/alert action flow is.
- De speler verkent routes, resources en zichtbare enemy squad-tokens.

### 4.2 Enemy notice en alert tactical state

Wanneer een enemy squad binnen **10 tiles** van de Main Squad komt:

```text
Enemy squad wordt ALERT
→ de map gaat naar turn-based alert tactical state
→ alle squad-tokens krijgen tactical turns
```

Dit vervangt de oudere keuze “10 tiles = directe side-view battle”.

In de alert tactical state:

- squads hebben movement per turn op basis van een later te definiëren squad movement formula;
- de Main Squad beweegt tijdens zijn turn en krijgt daarna een tactical action menu;
- alle enemy squads blijven afzonderlijke tokens;
- niet-geaggroede squads voeren ook hun eigen gedrag uit, zoals static of patrol;
- een squad wordt `ALERT` zodra hij tijdens zijn eigen turn of een andere squadturn binnen 10 tiles van de party komt;
- de alert state is dus een globaal conflict op de tactical map, geen merge van tokens.

### 4.3 Enemy AI op tactical map

Begin klein en data-gedreven.

Eerste modes:

```text
STATIC
PATROL
```

Later mogelijke modes:

```text
INVESTIGATE
CHASE
GUARD
FLEE
```

Iedere enemy token houdt zelfstandig bij:

- eigen `Squad`;
- eigen grid-anchor;
- eigen AI mode;
- eventuele patrol route;
- eigen alert status;
- defeated status.

### 4.4 Adjacent tactical action

Wanneer de Main Squad adjacent aan een enemy squad staat, krijgt de speler tijdens de eigen tactical turn een action menu, bijvoorbeeld:

```text
Attack
Defend
Items
Wait
```

Eerste implementatie:

- `Attack` functioneert volledig;
- Attack laat de speler een adjacent enemy squad kiezen als er meer dan één adjacent token is;
- `Defend`, `Items` en `Wait` mogen eerst als structurele placeholders bestaan, maar moeten niet doen alsof ze al volledig werken;
- Attack verbruikt de tactical actie en start de battle transition.

### 4.5 Cruciale regel: squads mergen nooit

Een tactical map token vertegenwoordigt altijd precies één squad.

- Een enemy squad die in de buurt komt, wordt alert en neemt deel aan de **tactical map conflictlaag**.
- Hij wordt niet toegevoegd aan de enemy formation van een andere squad.
- Hij wordt niet opgenomen in de `EncounterContext` van een andere squad.
- Hij krijgt zijn eigen turns, eigen AI en kan later zelf adjacent komen en een eigen attack transition starten.

Daarom blijft voorlopig de bestaande `EncounterContext`vorm correct:

```text
player_squad
enemy_squad
initiator
active_strategy
```

**Bouw geen multi-squad encountergroup, reinforcement-selectie of side-view formation-capacity-systeem.**

De maximaal vier formation slots in `battle_scene` gelden uitsluitend voor de individuele units van de ene betrokken enemy squad. Andere tactical tokens hebben daar geen invloed op.

---

## 5. Battle presentation: definitieve lifecycle

### Battle-scene rol

`battle_scene.tscn` is geen langdurige klassieke battle mode en geen tactical grid. Hij resolveert een korte clash tussen precies:

```text
Main Squad ↔ één aangevallen enemy squad
```

### Vaste lifecycle

```text
1. Equipable start ability
2. Volledige ronde 1
   - protagonist command
   - overige partyleden automatisch
   - enemy squad automatisch
3. Volledige ronde 2
   - protagonist command
   - overige partyleden automatisch
   - enemy squad automatisch
4. Equipable finishing ability
5. Terugkeer naar dezelfde tactical map en tactical turn context
```

De protagonist krijgt dus normaal twee handmatige commandmomenten per transition: één per volledige ronde.

### Vroege beëindiging

Een battle transition mag eerder eindigen wanneer:

- de betrokken enemy squad volledig is verslagen;
- de Main Squad volledig is verslagen.

### Wanneer beide squads nog leven na ronde 2

- battle presentation eindigt alsnog;
- dezelfde `Unit`-objecten houden HP, MP en later status-effects;
- beide squads keren terug naar hun bestaande tactical token/state;
- tactical alert flow gaat verder.

### Start- en finishing abilities

De uitrusting/loadout-infrastructuur bestaat nog niet. Bouw daarom later lifecycle hooks die veilig overslaan als niets equipped is:

```text
Geen start ability → start phase overslaan
Geen finishing ability → finishing phase overslaan
```

Bouw niet nu al een equipment-systeem als omweg om deze fase zichtbaar te maken.

### Belangrijke implicatie voor de huidige code

De bestaande `BattleSession`/battle presentation gedraagt zich nog grotendeels als een gevecht dat doorgaat tot een zijde verslagen is. Dat moet worden aangepast vóór de grote tactical exploration slice, omdat het nieuwe contract exact twee rondes plus lifecycle-phases vereist.

---

## 6. Map-clear, XP en loot

- Iedere defeated enemy squad blijft een individuele verslagen tactical token / wordt van de map verwijderd.
- Een dungeon/map is pas cleared wanneer alle enemy squad-tokens defeated zijn.
- Pas dan verschijnt één gezamenlijke results screen met de totale XP en loot van de hele map.
- Geef niet alvast verzonnen rewards, XP-waarden of loot tabellen.
- Migreer eerst de relevante Python reward-, item- en result-logica wanneer deze milestone aan de beurt is.

Geen results screen na elke korte battle transition, tenzij de gebruiker dit later expliciet verandert.

---

## 7. Huidige technische status

### Werkend en bevestigd

- Godot 4 projectstructuur met `GameState` en `SceneManager` autoloads.
- Tactical grid prototype met player squad token en enemy squad token.
- Player-initiated en enemy-initiated encounters.
- Tijdelijke squad strategy prompt bij zelf geïnitieerde encounter.
- `Unit`, `Squad`, `Skill`, `SkillData`, `BattleSession`, `CombatResolver` en `AutomaticActionResolver` als domeinstructuur.
- Protagonist kent `Focused Strike`.
- Best Friend kent `Mend`.
- Corrupted Acolyte kent `Patch Flesh`.
- Automatic supportgedrag werkt voor allies en enemies.
- Side-view `battle_scene` bestaat en keert terug naar dezelfde tactical context.
- Battle unit cards behouden hun nodes en HP-bars tweenen soepel tussen values.
- Expanded ability model en unified learned skill/spell ownership zijn op GitHub bevestigd in commits `a6a9656` en `39dca3c`.
- BattleSession ondersteunt een configureerbare maximum_rounds snapshot via EncounterContext.
- De battle lifecycle werkt als:
  START_ABILITY → herhaalde volledige rondes → FINISHING_ABILITY → RESOLVED.
- Start- en finishing-hooks skippen veilig zolang loadouts ontbreken.
- De battle transition eindigt na maximum_rounds wanneer beide squads nog leven.
- Tactical alert state ondersteunt vrije exploration, enemy notice, globale turn order,
  cursor-gebaseerde player movement commitment, STATIC en PATROL.
- Patrols bewegen één waypoint-stap na een geldige exploration-beweging en op hun
  eigen alert tactical beurt.
- Enemy squads blijven zelfstandige tokens; alert propagates via een notice-chain.


### Nog niet bouwen of als af beschouwen

- Party Menu in Godot.
- Echte vrije exploration map als content slice.
- Squad movement formula.
- Items/equipment/loadout port.
- Quest/dialogue/shop systems.
- Map-clear rewards, XP en loot.
- Save/load voor de nieuwe data.

---

## 8. Eerstvolgende roadmap

### Milestone A — Battle transition contract corrigeren

Doel: `battle_scene` voldoet aan het nieuwe vaste lifecycle-contract.

1. Maak expliciete battle phases:

```text
START_ABILITY
ROUND_ONE
ROUND_TWO
FINISHING_ABILITY
RESOLVED
```

2. Laat iedere volledige ronde bestaan uit:

```text
protagonist command → automatic allies → automatic enemies
```

3. Return na twee rondes als niemand is verslagen.
4. Houd dezelfde Unit- en Squad-objecten vast.
5. Voeg nog geen equipment/loadout UI toe; phases mogen veilig skippen.

### Milestone B — Tactical alert foundation

Doel: tacticaltest is niet langer enkel een combatproef maar kan vrije exploration en alert state onderscheiden.

1. Introduceer states zoals:

```text
FREE_EXPLORATION
ALERT_PLAYER_TURN
ALERT_ENEMY_TURNS
TACTICAL_ACTION_MENU
BATTLE_TRANSITION
```

2. Voeg notice distance van 10 tiles toe.
3. Maak tactical turn ownership expliciet.
4. Behoud tokens als afzonderlijke squads.

### Milestone C — Grote sewer exploration testmap

1. Breid de huidige testmap fors uit.
2. Plaats speler in een veilige hoek, buiten notice range.
3. Voeg meerdere enemy squad-tokens toe.
4. Voeg `STATIC` en `PATROL` toe.
5. Laat patrols alert worden zodra zij binnen 10 tiles komen.
6. Laat de speler adjacent target selection en `Attack` gebruiken.

### Milestone D — Party Menu

Pas bouwen zodra `FREE_EXPLORATION` echt bestaat.

- Openen met Escape.
- Alleen toegestaan tijdens vrije exploration.
- Eerst: Party inspecteren, learned skills/spells bekijken, items gebruiken.
- Geen battle-commandmenu voor automatische squadleden.

### Milestone E — Rewards en map clear

Na werkende meerdere enemy squads en defeated token-state:

- migreer Python XP/loot/item-resultlogica;
- aggregeer opbrengsten per dungeon/map;
- toon één map-clear results screen.

---

## 9. Ontwerpprincipes die bij iedere volgende stap bewaakt moeten worden

- Randomness zit in input en situatie, niet in uitkomst.
- Tactical fouten mogen consequenties hebben, maar moeten voor de speler leesbaar zijn.
- Een tactical token is altijd één squad; individuele units krijgen normaal geen eigen tactical-gridpositie.
- De side-view battle presentation is een tijdelijke resolution/presentation layer, niet een tweede navigatielaag.
- De Main Squad bevat de protagonist als eerste member; alleen de protagonist krijgt klassieke handmatige battlecommands.
- Andere Main Squad-members en alle latere autonome squads handelen via strategy/AI/loadout.
- Nieuwere expliciete keuzes van de gebruiker overschrijven oudere persona-notities. Benoem die botsing expliciet voordat je code voorstelt.
- Bij ieder combatvoorstel altijd onderscheid maken tussen:
  1. tactical map state;
  2. side-view battle presentation;
  3. data en resolution logic.

---

## 10. Startinstructie voor een nieuwe chat

Begin een volgende sessie ongeveer als volgt:

> Lees eerst de actuele `main` commit van `Kradoneem/TacticalRPG-Godot` via de GitHub commit-API. Bevestig daarna kort de huidige status: ability ownership is gemigreerd; de volgende milestone is de `BattleSession` lifecycle omzetten naar start ability → twee volledige rondes → finishing ability → terugkeer naar dezelfde tactical context. Houd enemy squads strikt gescheiden: zij mergen nooit in een gezamenlijke side-view encounter.

Vraag alleen om verduidelijking als de concrete betekenis van een tactical round, Defend/Items in de alertlaag, of de gewenste squad movement formula niet uit de actuele context blijkt.

11. Dingen die niet opnieuw moeten worden voorgesteld
Stel niet opnieuw voor, tenzij de developer deze fundamentele keuzes expliciet herziet:

Een extra combatlaag boven op de tactical grid.
Multi-squad of reinforcement-merging in side-view battles.
Een losse klassieke battle mode die doorgaat tot één kant volledig verslagen is.
Battle presentation-polish voordat de exploration- en alert-loop functioneert.
Squad merging.
Gekopieerde units tussen tactical en battle state.
Gridposities op tijdelijke battle sprites.
Een generieke SkillUnlockService.

Afgeronde sessiemilestone: vier sewer-artplaceholders
De gebruiker bevestigt dat alle kamers gereed zijn en dat ook de 4K asymmetrische kamer is gelukt. De Blender-scriptupdates zijn lokaal uitgevoerd; daadwerkelijke bestandsnamen, gekozen nummerachtervoegsels, Godot-import en Git-status moeten nog worden gecontroleerd.
Elke uitvoering exporteert .blend, _color.png en _depth_normalized.png naar:
~/ComfyUI/output/sewer_tactical_anchors/
Herhaald uitvoeren gebruikt nummerachtervoegsels. .blend-export slaat het hele geopende Blender-document op onder een nieuwe actieve bestandsnaam, niet uitsluitend de nieuwe scene.
Wat nog niet bewezen is
Geen Godot-integratie, scrolling, gridkalibratie, collision of terrain-costs is in deze sessie gebouwd of getest.
Niet vastgesteld welke assets of scripts al in de repository staan.
Geen uniforme pixels-per-tegel-schaal voor alle vier backgrounds bevestigd.
Geen perception-, lockpick-, cache-, verborgen-uitgang- of waterbewegingslogica geïmplementeerd.
De eerdere maintenance-cache werd in de ComfyUI-output onvoldoende herkenbaar als afgesloten kist. Een aparte interactieve prop is daarom de voorgestelde vervolgaanpak, niet een afgeronde feature.
Eerstvolgende technische stap
Artwerk parkeren en de Godot-milestone herijken tegen actuele code. De bestaande technische prioriteit blijft BattleSession naar de vaste encounter-lifecycle, daarna tactical alert-turncontroller en grote exploration-testmap, tenzij de actuele repository of een nieuwe expliciete gebruikerskeuze aanleiding geeft om die volgorde te veranderen.
De nieuwe chat begint met:
Actuele lokale Git-status en laatste commit controleren.
Huidige GitHub main-HEAD via API ophalen; daarna SHA-gepinde handoff en relevante code lezen.
Vaststellen of de BattleSession-lifecycle inmiddels gereed is. Niet afgaan op oudere notities.
Eén concrete volgende milestone kiezen. Als BattleSession nog ontbreekt: eerst die refactor. Als die gereed is: exploration/alert-loop met de grote map als testcontext.
Bij eventuele assetintegratie: viewport 1080p behouden, grote achtergrond niet tot één scherm verkleinen, en gridprojectie/tegelschaal expliciet valideren.
Lokale controles in ~/tactical-rpg:
De laatste opdracht vereist ten minste twee commits. Inspecteer ook de actuele handoff-documenten en relevante scripts. Handoff-updates zorgvuldig samenvoegen, niet bestaande inhoud blind overschrijven. Na een afgeronde, geteste milestone: relevante bestanden committen en pushen. Bij remote: Internal Server Error: opnieuw git push origin main, niet force-pushen.Art-pipeline en resolutie
Het beoogde spelvenster is 1920 × 1080. Achtergronden mogen groter zijn voor scrolling; viewportresolutie en achtergrondresolutie zijn verschillende zaken.
De gekozen tactical-artpipeline is Blender-color-render als img2img-basis, met bijbehorende Blender-depth als SDXL Depth ControlNet-input. Niet teruggaan naar uitsluitend depth + per-kamer uitgebreide prompts zonder duidelijke noodzaak.
Gebruik één vrijwel vaste sewer-stijlprompt. Layout, materiaalverdeling, openingen en belangrijke props komen primair uit Blender. Alleen een minimale contentaanpassing als die werkelijk nodig is.
De gebruiker heeft vastgesteld dat verschillen tussen Blender-bases een belangrijke bron van stijlvariatie zijn. Controleer daarom eerst geometry, baksteen- en tegelmaten, voegen, camera, framing, materialen en belichting voordat je prompt of denoise verandert.
Onderscheid cameraoriëntatie, orthographic scale, framing en pixels per wereldafstand. Gelijke oriëntatie en resolutie betekenen niet automatisch gelijke tegelschaal. Vergelijk achtergronden op werkelijke weergaveschaal, niet alleen op verkleinde previews.
De huidige kleine achtergronden zijn 1080p; de grote asymmetrische map is 4K. Entrance en corridor gebruiken automatische framing, dus de serie heeft nog geen bewezen uniforme pixels-per-tegel-schaal. Dit niet opnieuw als opgelost presenteren.
Blender 5.2: behoud de werkende Eevee- en compositorpatronen, inclusief Viewer-gebaseerde depth-export. Geen ongeteste overstap naar oudere compositor-API's.
Lever bij scriptwijzigingen volledige vervangende scripts. Gebruik nieuwe exportnamen en bescherm bestaande bestanden tegen overschrijven. Pas de depth-afmetingencontrole samen met de renderresolutie aan.
Houd renders reproduceerbaar. Verander één variabele per test; behoud checkpoint, seed, sampler en prompt tenzij juist die variabele wordt onderzocht.
De huidige maps zijn gameplay-placeholders. Geen nieuwe art-polishronde beginnen voordat een gameplay-milestone dat nodig maakt.
Interactieve props en licht
Een in de achtergrond ingebakken cache of poort kan niet zichtbaar openen of verdwijnen door alleen een interactiezone toe te voegen. Gebruik later afzonderlijke props of passende beeldvarianten als een visuele toestand moet veranderen.
Dynamisch fakkellicht is backlog: begin zo nodig met CanvasModulate + PointLight2D; normal maps en complexere schaduwen pas na een concrete behoefte.
Perception en lockpicks zijn nieuwe contentwensen, nog geen geïmplementeerde regels. Ontdekken, slot openen en loot toekennen blijven afzonderlijke stappen. Verzin geen checkformules, verbruik of rewarddata.
