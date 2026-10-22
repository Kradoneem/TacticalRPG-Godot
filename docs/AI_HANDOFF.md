# AI Handoff — TacticalRPG-Godot

Bijgewerkt: 22 oktober 2026. Volledige historie en oude persona-patch: `docs/archive/AI_HANDOFF_2026-10-21_full.md`.
Lore en Chapter 1: `docs/AI-BG-handoff.md`.
Werkafspraken staan in de projectpersona, niet hier.

Legenda: **[G]** in code + door gebruiker getest · **[O]** ontwerpbesluit · **[?]** niet gevalideerd of nog te bouwen.

## Status
- Laatste geteste gameplay-milestone: **World map** (feat: add world map travel with explicit location context). [G] door gebruiker getest. Zet Shops ervoor in de plaats als "Daarvoor: Shops (796b416)".
- Volgorde [O]: world map → Tavern → treasure chests → Chapter 1 refinen.
- Buiten deze volgorde: resterende Python-combatpariteit en Save/Load.
- Combatuitbreidingen en art-polish blijven geparkeerd.
- Repo: https://github.com/Kradoneem/TacticalRPG-Godot · branch `main` · lokaal `~/tactical-rpg`.
- Python-bron: https://github.com/Kradoneem/TacticalRPG
  (`skill.py`, `skill_data.py`, `unit.py`, `game_state.py`, `party_menu.py`, `battle.py`, `battle_scene.py`, `battle_results_scene.py`).
  `game_state.py` kent geen dag, locatie of reizen: de world map is nieuw Godot-ontwerp, geen migratie.
- City selection + guild sewerquest: commit-message `feat: add standalone city label editor and image-relative layout`; commit-SHA niet geverifieerd.
- Handmatige city/guild- en city↔sewer-acceptatietests: niet afzonderlijk bevestigd.

## Afgeronde milestones (nieuwste eerst) — alle [G]

| Milestone | Kern |
|---|---|
| World map | Door gebruiker getest. WorldLocation + WorldMapData (Aldenmoor + 2 prototypelocaties, hub-topologie), GameState.travel_to_location (1 dag/verbinding via advance_day, geen GameplayClock-tick), WorldMapScreen (select/confirm), LocationStubScreen, SceneManager.change_game_scene(path, context) met prepare_location_entry, CityDestination.Kind.WORLD_MAP. tests/test_world_travel.gd aanwezig. |
| Shops (`796b416`) | Door gebruiker getest. `ShopDefinition`/`ShopOffer` als Resources, `ShopData` koppelt stad + bestemming-ID, `ShopTransaction.resolve()` via `GameState.buy_shop_product`/`sell_shop_product`. `ShopScreen` (Talk / Buy / Sell, confirm-stap) onder `CityScreen`. Zie Ontwerpbesluiten → Shops. `tests/test_shops.gd` aanwezig. |
| City selection + guild sewerquest | [Code aanwezig; automatische en handmatige tests geslaagd] CityScreen heeft selecteerbare bestemmingen zonder tactical grid. Guilddialogue ondersteunt accepteren/later; annuleren kent niets toe. Guild activeert expliciet de prototypequest voor corridor+junction via GameState. Geen rewards of sewer-toegangsgate. SceneManager heeft city↔sewer-overgangen met behoud van explorationcache. City-background is optioneel; zonder texture wordt een kleur-placeholder getoond. |
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

World map [G] — gebouwd en getest.
- Locaties: Aldenmoor + twee expliciet gemarkeerde prototypelocaties ("Prototype Location A/B", `is_prototype`, geen lore). Topologie (aanname): hub Aldenmoor↔A en Aldenmoor↔B; geen A↔B; alleen directe verbindingen zijn kiesbaar, geen multi-hop.
- Reizen kost voorlopig 1 dag per verbinding (`WorldMapData.TRAVEL_DAYS`, constante) via `GameState.advance_day()`. Reizen tickt de `GameplayClock` niet. Dagtijd en kosten per verbinding zijn niet vastgesteld.
- Flow: world map toont huidige locatie; bestemming selecteren → confirm → `GameState.travel_to_location()`. Annuleren en "Terug" veranderen locatie en dag niet. Geen tactical grid op de world map.
- State: `GameState.world_location_id` is de bron van waarheid voor de wereldpositie; alleen `travel_to_location()` muteert die.
- Contract: `WorldLocation` (Resource) + `WorldMapData` (content). Niet verwarren met `LocationData` (combat-clear-manifests). `SceneManager.change_game_scene(path, context)` roept `prepare_location_entry(context) -> bool` aan na `instantiate()` en vóór teardown/`_ready`; weigering laat de huidige scene intact. Scenes met locatiecontext: `can_open_party_menu()`, `can_show_quest_updates()`.
- Bestemmingstype bepaalt de scene: `CITY` → `CityScreen`, `PROTOTYPE_STUB` → `LocationStubScreen`. `CityScreen` weigert alles behalve Aldenmoor (expliciete guard). Zonder context valt `CityScreen` terug op Aldenmoor (directe lancering, tests).
- Party: beschikbaar op world map en stub, niet tijdens de reisbevestiging.
- Volgorde: world map → Tavern → treasure chests → Chapter 1 refinen.
- Niet in deze milestone: tweede stad (`CityData`/`ShopData`/`CityScreen` per stad), reiskosten in gold, reisevents/encounters, dagtijd, routelijnen/art, multi-hop, cache-behoud over wereldreizen, save/load.

**Wereld, city en gebouwen — gebruikerskeuze**
- City: selectiescreen met prerendered stadsbeeld en labels op relevante gebouwen. Geen tactical grid of squadmovement. `CityDestination.Kind.WORLD_MAP` (bestemming `world_map`) opent de world map; positie is een placeholder.
- Dungeon: bestaande grid-gebaseerde exploration/alert-loop blijft behouden.
- Shop: eigen shopping screen met Talk / Buy / Sell; eigenaardialogue moet questinteracties kunnen ondersteunen.
- Tavern: eigen prerendered interieur met selecteerbare personen die dialogue starten.
- Adventurer's Guild: vroege bestemming waar de speler de sewerquest krijgt.
- Home: later dialogue en achievements; nu niet bouwen.
- Castle en overige guilds: interacties nog niet uitgewerkt.
- World-locatie, stadsgebouw en dungeonkamer zijn verschillende contexten; geen fictieve city-gridcel gebruiken.
- Questacceptatie en sewer-toegang zijn afzonderlijke regels; er is geen questgate toegevoegd.
- Tijdskosten binnen de stad en de relatie tussen dagtijd en GameplayClock zijn nog niet vastgesteld.
- Shopspecificieke prijzen en voorwaarden horen niet in ItemData of SkillData.

**Shops [G] — gebouwd en getest (`796b416`)**
- Eigen ShopDefinition per shop; ShopData koppelt stad + bestemming-ID.
- Consumables en equipment; onbeperkte voorraad; één exemplaar per bevestiging.
- Koopprijzen zijn shopcontent, niet ItemData/EquipmentData.
- Verkoopprijs is helft van plaatselijke koopprijs, naar beneden afgerond.
- Alleen losse inventory en opgenomen shopproducten; uitgerust equipment eerst afleggen.
- Flags beperken Buy; Sell van
- Flags beperken Buy; Sell van opgenomen producten blijft mogelijk ongeacht kooplock.
- Gold/inventory worden vóór signals samen gecommit; aankoop valideert flags opnieuw.
- Talk gebruikt bestaande herhaalbare dialogue; geen questtoekenning/inlevering gebouwd.
- Aldenmoor-prijzen zijn nieuw prototypecontent, geen Python-migratie of definitieve balans.
- Geen tijdskosten; geen nieuwe startvoorraad/gold; geen restockstate.
- Cross-city handelswinst is mogelijk bij toekomstige prijsverschillen; nog geen economische regels toegevoegd.

**Dialogue**
- Bestaande entrance-dialogue blijft one-shot.
- DialogueDefinition.allow_replay ondersteunt herhaalbare gesprekken.
- Bij herhaalbare gesprekken bewaren flags de laatst afgeronde keuze.
- DialogueController.finished geeft dialogue-ID, choice-ID en commitstatus terug.
- Main routeert het resultaat naar de oorspronkelijke actieve aanvrager en wist de aanvraag ook bij annuleren.
- De guildinteractie kent de quest expliciet toe; dialogue-tekstdata voert geen gameplaycalls uit.
- Accepteren telt pas na bevestiging van de reactiepagina; annuleren ervoor activeert geen quest.

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
- Beschikbaar op sewer, stad, world map en toekomstige locaties.
- Niet tijdens tactical alert, tactical acties, strategy selection, battle, actieve dialogue, modal exitinteractie, shop- of reisbevestiging, pending transitions of geregistreerde SceneManager-overlays.
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
- Niet gebouwd: NPC-inlevering, questrewards, progression/level-upabilities, save/load (mapcache is sessiestate), Tavern-personenselectie, treasure chests.
- `change_game_scene` wist `_exploration_cache`; of sewer-positie/-state een wereldreis overleeft is niet gevalideerd (`defeated_enemy_squads` is globaal en blijft).
- World map: `current_city`, `current_location` en `in_city` overlappen; gebruikers niet geïnventariseerd. Controleer met `grep -rn "current_city\|current_location\|in_city" scripts tests`.
- `city_screen.tscn` koppelt alleen `city_background`; `city_layout` (labelpositie-`.tres`) gekoppeld aan assets/city_layouts/castletown_labels_2026-10-22T11-25-27.tres. Bestemming `world_map` heeft een placeholderpositie.
- Niet end-to-end gevalideerd: meerdere verbindingen tussen dezelfde maps; bewaarde maps accepteren hun opgeslagen vertrekcel.
- Ontbreekt: begrensd cache-ontlaadbeleid.
- Legacy `tacticaltest.gd` heeft nog eigen PartyMenu-aansturing. Ruim gericht op; maak geen tweede controller, geen `ExplorationPartyMenu`, geen extra Party-Autoload.
- Encounter-party-heal en perception/lockpicks zijn contentwensen, nog geen regels. Ontdekken, openen en loot toekennen blijven afzonderlijke stappen.
- Dynamisch fakkellicht is backlog (zo nodig `CanvasModulate` + `PointLight2D`).
- Open vraag: definitieve Chapter-1-resourcebudgetten en content (huidige items, gear en quests zijn prototypes).
- Handmatige city/guild-inputisolatie en city↔sewer-statebehoud nog afzonderlijk te bevestigen.
- Quest-objectivetest activeert drie expliciete fixtures, niet de volledige catalogus.
- Guildquest gebruikt alleen de bestaande sewer test-slice corridor+junction, niet het volledige toekomstige dungeon.
- Guild-inlevering, questrewards en verdere NPC-dialogue ontbreken.

## City layouts
- City scene en layouts getest, koppeling met sewer werkt.
- Art beschikbaar.
- Guildtest initialiseert CityScreen vóór callbacks die UI vernieuwen.
- City-background lokaal beschikbaar: `assets/backgrounds/castletown.png`.
- Koppeling gebeurt via `CityScreen.city_background` in `scenes/city/city_screen.tscn`.

## Minimale dialogue-loop bij sewer-entrance
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

Voeg bovenaan een nieuwe rij toe aan "Afgeronde milestones" met commit en teststatus. Werk "Status" bij.
Verplaats opgeloste punten uit "Bekende grenzen". Voeg geen nieuwe persona- of werkafspraken toe aan dit bestand.

