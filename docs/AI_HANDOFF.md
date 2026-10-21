# Minimale dialogue-loop bij sewer-entrance

- DialogueLine, DialogueChoice en DialogueDefinition zijn Resources.
- DialogueSession bewaart tijdelijke voortgang zonder wereld-/UI-dependencies.
- Prototype: opening → één keuze → reactie → afronden.
- DialogueController leeft onder Main, buiten GameLayer; geen nieuwe Autoload.
- Bestaande GameLayer-process-mode en Party-blocker worden gebruikt.
- Escape annuleert zonder resultaat; alleen afronding commit de keuze.
- GameState bewaart completion en gekozen antwoord in bestaande flags.
- Resultaat wordt eenmaal vastgelegd en blijft bij kamerwisselingen behouden.
- Nieuwe game reset flags; disk-save/load is niet geïmplementeerd.
- Entrance-interactie op (3,3)/(4,3), met Enter/Spatie, getest via Main.
- Questbanner wacht tijdens dialogue.
- Geen rewards, statbonussen, definitieve lore of uitgebreide branching.
- Teststatus: automatische en handmatige tests geslaagd.

# AI Handoff — TacticalRPG-Godot

Bijgewerkt: 21 oktober 2026. Volledige historie en oude persona-patch: `docs/archive/AI_HANDOFF_2026-10-21_full.md`.
Lore en Chapter 1: `docs/AI-BG-Handoff.md`.
Werkafspraken staan in de projectpersona, niet hier.

Legenda: **[G]** in code + door gebruiker getest · **[O]** ontwerpbesluit · **[?]** niet gevalideerd of nog te bouwen.

## Status

- Repo: https://github.com/Kradoneem/TacticalRPG-Godot · branch `main` · lokaal `~/tactical-rpg`.
- Python-bron: https://github.com/Kradoneem/TacticalRPG
  (`skill.py`, `skill_data.py`, `unit.py`, `game_state.py`, `party_menu.py`, `battle.py`, `battle_scene.py`, `battle_results_scene.py`).
- Laatste gameplay-commit: `c3f5d26 — feat: enable manual ally healing and consolidate battle commands`.
  Teststatus: automatische en handmatige tests geslaagd.
- **Volgende milestone: nog niet gekozen.** Herijken tegen actuele code en Python-migratie. Geen art- of battle-polish.

## Afgeronde milestones (nieuwste eerst) — alle [G]

| Milestone | Kern |
|---|---|
| Handmatige single-ally healing (`c3f5d26`) | Healing, damage en Attack Support delen één targetselectie. `AbilityResolver` valideert opnieuw en voert kosten/effect eenmaal uit. Annuleren of ongeldig target kost niets. Zelf-healing mag bij gewonde caster. `BattleScene` geeft `GameState.gameplay_clock` aan `BattleSession`. Compat-entrypoints `begin_enemy_target_selection`, `confirm_enemy_target` en `_on_enemy_target_selected` blijven bestaan. |
| Gameplayklok + Attack Support-buff | Eén `GameplayClock` in `GameState`, geen realtime Timer. Eén tick per volledig afgehandelde tactical ronde; afgebroken rondes en side-view geven geen tick. Exploration telt alleen geldige Main Squad-stappen. Attack Support: single living ally, +3 Attack, 4 MP, duur 5 ticks bij Wisdom 10, ±1 per 5 Wisdom verschil (naar nul afgerond, minimum 1). Duur en bonus worden gesnapshot; hetzelfde buff-ID vervangt en herstart. Attack = basis + equipment + buffs. |
| Gedeelde ability-uitvoering + protagonistcommandmenu | `AbilityResolver` voor handmatig en automatisch. `AutomaticActionResolver` kiest alleen het bestaande supportgedrag. `BattleAbilityMenu`: Attack, Skills, Spells uit bekende IDs. Python additive damage-scaling en defense gemigreerd. Focused Strike behoudt prototype-multiplier. |
| Quests | `QuestDefinition`/`QuestObjective` als Resources; `QuestData` met drie prototypequests (geen Chapter 1-lore). `LocationData`: `sewer_test_slice` = corridor + junction. `GameState` bewaart queststatus en behaalde objective-IDs; completion is een expliciete stap. Refresh bij map-entry en na encounterterugkeer. `QuestUpdateBanner` in Main, buiten GameLayer. Read-only Quest Log in Party. |
| Encounter-results (contract) | Na volledige enemy squad defeat: eenmaal rewards en één resultaatscherm na de transition. Geen normaal resultaatscherm als enemies na de laatste ronde leven. `EncounterResult` + `GameState.settle_encounter()`. Python-XP-formule gemigreerd; iedere levende deelnemer krijgt het volledige squadbedrag. Gold/loot defaults nul/leeg (geen geverifieerde data). |
| Equipment (`9c0546b`) | `EquipmentData`, `GameState.equipment_inventory`, `GameState.change_equipment()`. Slots: weapon, armor, accessory. Effectieve stats = basis + bonussen. HP-percentage blijft behouden (naar beneden afgerond; levend minimaal 1 HP). Party: squad → lid → slot → uitrusten/afleggen. |
| Items (`21fb38f`) | `ItemData`, `GameItem`/`ItemEffect`, `GameState.item_inventory`, `add_item()`/`use_item()`, `ItemUseResolver`. Party: item → squad → levend lid. Gebruik op vol target verbruikt één item (conform Python). Prototype: Potion 20 HP, Hi-Potion 50 HP, Ether 10 MP, Elixir 30 HP + 30 MP; startvoorraad 1 van elk (geen definitief budget). |
| Centrale Party (`3309293`) | `PartyMenuController` (Main, buiten GameLayer) is eigenaar en toegangspoort; `PartyMenu` bezit navigatie via `handle_menu_input(event)`. GameLayer tijdelijk `PROCESS_MODE_DISABLED`, geen SceneTree-pauze. Statusformattering gefixt. |
| Junction + zelfstandige squads (`0394d53`) | STATIC/PATROL-tokens, gedeelde exploration-architectuur, camera/scrolling, gekalibreerde grid, mapverbinding. |
| Battle-presentation (`87b4245`) | Aparte screen-space CanvasLayer in `SceneManager`; source-instance blijft behouden; bron-visibility/layers/process-mode hersteld na terugkeer. |
| Battle-lifecycle + alert-foundation | `BattleSession`: START_ABILITY → rondes → FINISHING_ABILITY → RESOLVED, `maximum_rounds` via `EncounterContext` (standaard 2). Alert: notice binnen 10 tiles, globale turn order, cursor-gebaseerde movement commitment, STATIC/PATROL, notice-chain. |
| Abilitymodel (`a6a9656`, `39dca3c`) | `Skill.Category`, effecttypes, targettypes, scaling; `Unit.learn_ability`/`forget_ability`/`knows_ability`; compat-methods `learn_skill`/`learn_spell`. |

## Ontwerpbesluiten [O]

**Tactical state**
- Vrije exploration: WASD, geen move budget, Escape opent Party.
- Enemy squad binnen 10 tiles → alert tactical state; alle tokens krijgen turns.
- Alert-beurt: speler selecteert één bereikbare eindcel binnen budget, bevestigt, token beweegt, daarna één tactical actie.
- Patrols: één waypointstap na elke geldige Main Squad-beweging in exploration; in alert op eigen beurt. STATIC blijft staan.
- Adjacent: speler kan teruglopen; Enter/Spatie opent actiemenu, Escape annuleert. Menu: Attack, Defend, Items, Wait. Bouw eerst alleen Attack volledig.
- Bij meerdere adjacent tokens kiest de speler één doel. De transition bevat alleen Main Squad + dat doel.
- Squads mergen nooit. `EncounterContext`: player_squad, enemy_squad, initiator, active_strategy, maximum_rounds.
- Movement en initiative (gewenste regels, niet verzinnen, eerst bestaande code lezen): movement hangt af van de langzaamste levende unit plus bonus voor minder leden; initiative combineert gemiddelde speed met kleine-squadbonus.

**Party-beschikbaarheid**
- Beschikbaar op sewer, stad en toekomstige locaties.
- Niet tijdens tactical alert, tactical acties, strategy selection, battle, actieve dialogue, modal exitinteractie, pending transitions of geregistreerde SceneManager-overlays.
- `set_blocked(reason, blocked)` is het aansluitpunt voor modal systemen.

**Battle**
- Alleen de protagonist krijgt per eigen beurt een handmatig command menu (pijltjes/WASD, Enter/Spatie). Overige leden en alle latere eigen squads handelen automatisch.
- Zelf geïnitieerde encounter: korte prompt om strategie tijdelijk aan te passen. Vijand-geïnitieerd: eerder ingestelde strategie.
- Max. vier formation-slots per zijde. Een Companion Boss mag een groot slot krijgen; bosses mogen meerdere slots beslaan.
- Eindig eerder bij volledig verslagen squad. HP/MP/status blijven behouden.
- Side-view acties, rondes en animaties geven geen gameplayticks.

**Rewards en clear**
- Encounter-rewards zijn eenmalig per verslagen enemy squad (zie contract).
- Defeated enemy squads worden individueel verwijderd of gemarkeerd.
- Dungeon cleared = alle enemy-squad-tokens defeated.
- Squad defeat, map clear en locatie-mapclear zijn aparte questvoorwaarden, geen extra rewardtriggers.
- Verzin geen rewarddata.

## Bekende grenzen en backlog [?]

- Formation in Party is placeholder.
- Niet gebouwd: equipment-granted abilities, start-/finishing-loadouts, classrestricties, durability, battle-itemgebruik, automatische itemstrategieën, revival, groepsheals/-buffs, buff-AI, dispels, drain, ingredientkosten, elemental resistances.
- Niet gebouwd: dialogue, shops, NPC-inlevering, questrewards, progression/level-upabilities, save/load (mapcache is sessiestate).
- Niet end-to-end gevalideerd: dialogueblokkering van Party; meerdere verbindingen tussen dezelfde maps; bewaarde maps accepteren hun opgeslagen vertrekcel.
- Ontbreekt: begrensd cache-ontlaadbeleid.
- Legacy `tacticaltest.gd` heeft nog eigen PartyMenu-aansturing. Ruim gericht op; maak geen tweede controller, geen `ExplorationPartyMenu`, geen extra Party-Autoload.
- Encounter-party-heal en perception/lockpicks zijn contentwensen, nog geen regels. Ontdekken, openen en loot toekennen blijven afzonderlijke stappen.
- Dynamisch fakkellicht is backlog (zo nodig `CanvasModulate` + `PointLight2D`).
- Open vraag: definitieve Chapter-1-resourcebudgetten en content (huidige items, gear en quests zijn prototypes).

## Lokale repositoryhygiëne

Laatst bekende lokale status: untracked `art/`, losse kalibratie-exports en een verdacht bestand `tatus --short`.
Inspecteer dat bestand vóór verwijderen. Gebruik geen `git add .` en geen brede cleanup.

## Art

- Spelvenster 1920 × 1080; achtergrondresolutie staat los van viewportresolutie. Kleine achtergronden zijn 1080p, de grote asymmetrische map is 4K.
- Entrance en corridor gebruiken automatische framing. Een uniforme pixels-per-tegel-schaal is **niet bewezen**; presenteer dit niet als opgelost. Vergelijk op werkelijke weergaveschaal.
- Pipeline: Blender-color-render als img2img-basis, Blender-depth als SDXL Depth ControlNet. Eén vrijwel vaste sewer-stijlprompt.
  Layout, materialen, openingen en props komen uit Blender. Controleer bij stijlverschil eerst geometry, tegelmaat, voegen, camera, framing, materialen en licht voordat prompt of denoise verandert.
- Eén variabele per test; houd checkpoint, seed, sampler en prompt vast.
- Blender 5.2: behoud Eevee-/compositorpatronen en Viewer-gebaseerde depth-export. Volledige vervangende scripts, nieuwe exportnamen, depth-afmetingencontrole samen met renderresolutie aanpassen.
- Een in de achtergrond ingebakken cache of poort kan niet visueel openen. Gebruik later aparte props of beeldvarianten.
- Maps zijn gameplay-placeholders. Geen art-polishronde zonder gameplay-behoefte.

## Afsluiten van een milestone

Voeg bovenaan een nieuwe rij toe aan "Afgeronde milestones" met commit en teststatus. Werk "Status" en "Volgende milestone" bij.
Verplaats opgeloste punten uit "Bekende grenzen". Voeg geen nieuwe persona- of werkafspraken toe aan dit bestand.
