# Game Design — Skyline Architect

Working title: **Skyline Architect**. An original vertical city/building management
simulation. Inspiration is the *fantasy* of growing a living tower; mechanics, look,
terminology and interface are our own.

## Pillars

1. **A living cross-section.** A realistic architectural side cutaway in which every
   person is simulated, every room is furnished, and the building visibly works.
2. **Vertical logistics is the puzzle.** Moving thousands of people up and down —
   elevator banks, sky lobbies, stairs, escalators — is the core optimization challenge.
3. **Honest systems.** Every number has a traceable origin: rent comes from tenants
   who chose your building for reasons you can inspect; vacancy emerges from the
   simulation, not from a dice roll.
4. **From one plot to an empire.** Start with a single lot and a foundation; grow to
   multiple towers across cities with different economies.

## Player fantasy & loop

Short loop (minutes): build space → tenants/visitors arrive → watch flows →
spot congestion/complaints → adjust (elevators, amenities, rents).
Mid loop (hours): expand upward/downward, unlock systems, manage cash & loans,
respond to events. Long loop: reputation, new properties, new cities, scenarios.

## Terminology (original to this game)

| Term | Meaning |
|------|---------|
| Plot | A property's buildable land: frontage (columns), basement limit, soil |
| Module | 1 m horizontal placement unit |
| Bay | Structural span, 8 modules; columns sit on bay lines |
| Floor | 4 m storey; 0 = ground (“G”), negative = basements (“B1”…) |
| Grade | Ground level, y = 0 |
| Core | Vertical circulation zone (shafts, stairs) — Phase 2+ |
| Sky lobby | Transfer floor between express and local elevators — Phase 7 |

## Visual direction

Realistic, clean, modern, architectural, detailed; never cartoon. Palette: muted
natural materials (concrete, steel, glass, soil strata), blueprint-cyan grid overlay,
restrained accent colors for UI and warnings. See GRAPHICS.md.

## Construction model (Phase 2+)

Free construction on the grid: floors (slabs spanning columns), walls, corridors,
doors, stairs, escalators, elevator shafts, rooms. Structural rules keep towers
plausible (floors need support below; basement depth limited by plot; foundations
determine achievable height — Phase 10 ties this to structure capacity). No hard floor cap.

## Room categories (data-driven)

Residential, office, retail, food, hotel, entertainment, health/fitness, services,
infrastructure — see the brief. Each room type is a JSON definition: size in modules/
floors, cost, rent range, capacity, schedule profile, noise/prestige emission, utility
demand, furniture layout recipe, unlock requirement. Engine code never switches on
room type ids.

## People

Individually simulated persons with identity, household, job, home, schedule, needs
(energy, hunger, entertainment…), mood, preferences. Far-away people are simulated
at lower fidelity but remain logically correct (SIMULATION.md).

## Economy (Phase 9)

Ledger-based: every transaction has a source entity and a reason. Income: rents,
hotel, parking, entertainment, services. Expenses: construction, wages, maintenance,
utilities, cleaning, security, loans, taxes. Bankruptcy is possible.

## Modes

Sandbox and data-driven scenarios (e.g. 5,000 inhabitants with average elevator
wait < 60 s while profitable).

## Speeds

Pause, 1×, 2×, 4×, 10×. Faster speeds run more fixed simulation ticks per real
second; they never scale the tick length (deterministic across speeds).

## Phase 1 player experience (current)

The player opens the game to a sandbox start: a 48 m lot in the fictional city of
Port Calder. The lot is shown in section: street-level pavement, soil strata down to
bedrock, and a prepared foundation (retaining walls, raft slab, bored piles, grade
slab with starter bars). The player can pan and zoom from a whole-city-block view
down to individual meters, toggle the architectural grid and inspect grid cells.
No construction or simulation yet.

## Phase 2 player experience (current)

The player builds on the prepared foundation with a palette generated from content:
**Floor** (drag across columns; upper floors must lie within the floor below — a tower
never widens as it rises; basements only within the excavation), rooms (lobby, corridor, office,
apartment, mechanical, parking — each with width limits and allowed floors) and shafts
(stairwell, elevator shaft — drag vertically across floors), and **Demolish** (rooms, or an
empty top floor, with a 40 % refund). A live ghost shows green with size and cost, or red
with the reason. Undo/redo, quicksave, load and autosave work. Construction cost is shown
but not yet charged; elevators have shafts but no cars; rooms have finishes but no furniture.

## Phase 3 player experience (current)

Every room the player places is furnished automatically from content layouts that adapt to
the room's width: offices fill with workstations and gain a meeting table when wide enough,
studios get a kitchenette or a full kitchen and (when wide) a bathroom, lobbies a reception
desk, parking levels parked cars. Zoomed out, towers show a glass façade; zooming in reveals
the furnished cutaway. People arrive in Phase 4.

## Phase 4 player experience (current)

Rooms come alive: offices get workers (0.3 per metre of width) and studios two residents
each. A day starts at 06:00; residents leave for work in the morning and return in the
evening, office workers arrive around 08:15, go out for lunch and leave around 17:15 — all
walking in from the street, through the entrance and up the stairwell. The clock runs at
1× (a day ≈ 60 real minutes) up to 10×; Space pauses. Floors without stairs are
unreachable and reported. No money, needs or elevators yet.

## Phase 5 player experience (current)

People find their way through any arrangement of stairwells: a tower whose upper floors are
served by a second stairwell starting higher up works — people climb, cross the transfer
floor and continue. Rebuilding or removing stairs takes effect immediately: people already
on their way re-route from where they are, or give up and leave if no way remains, and the
UI reports how many people cannot reach their home or work. In developer builds, ⌥⌘N shows
the navigation graph and everyone's route. Elevators still have no cars (Phase 6).

## Phase 6 player experience (current)

Elevator shafts now have cars. People going more than two storeys walk to the landing,
wait at the doors, board, ride and get out at their floor; the car collects everyone
travelling its way and turns at the last call. Morning and evening rushes form visible
queues, and the HUD shows how many people wait and for how long. One car per shaft;
banks, express elevators and smarter dispatching come in Phase 7.

## Phase 7 player experience (current)

Elevator shafts placed side by side work as a bank: people press the call button and are
sent to one of its cars. The Elevator Banks panel (⌥⌘E) lets the player choose how each bank
dispatches — collective, zoning or destination — and shows average and maximum waits,
passengers per hour and how many people gave up and took the stairs. The traffic overlay
(⌥⌘T) shows every queue with its longest wait in green, amber or red. Express shafts run
non-stop to a sky lobby where people change to a second bank, so towers can grow past the
point where one bank is enough.

## Phase 8 player experience (current)

A new building starts empty. Prospective households and businesses come by every hour,
look at the vacant units they could rent and sign if the unit is good enough for them —
affordable, quick to reach from the street (including how long the elevators actually
take), quiet and with a view that suits them. Clicking a room shows who lives or works
there and how they rate it, or why nobody has taken it yet ("design studio: poor view").
Tenants who become unhappy — for instance because their floor can no longer be reached —
leave after three days. Rent is recorded but not yet charged (Phase 9).

## Phase 9 player experience (current) — M1 First Playable

The game opens on a main menu (Continue, New Game, Load). A new sandbox starts with
$2.5 M: every floor and room costs money when placed (undo gives it back), and the preview
says so when the cash is short. Tenants pay rent at every morning's closing; maintenance,
utilities and loan interest are paid at the same time, all listed line by line in the
Economy panel. The player can borrow, repay and set the building's rent level — higher rents
earn more per tenant but scare off prospects. Evenings darken, occupied homes light up at
night. Seven days in the red end the game.

## Phase 10 player experience (current)

Buildings now need plant: electrical, mechanical and telecom rooms supply power, water,
climate and data to the floors within their reach, up to their capacity. Rooms get dirty
and wear out; equipment that wears out fails and cuts the supply. The player hires
janitors and technicians (paid daily) who come in every morning, walk and ride to the
most urgent jobs — service elevators keep them out of the tenants' cars — and fix things.
Tenants notice: units with missing utilities are unusable and dirty, worn units lose
tenants. The services overlay shows at a glance where the building is failing.

## Phase 11 player experience (current)

A new game is now a **standard game**. The lot starts as a class C building. It may rise to
floor 12, and some room types are still locked: the service elevator, the express elevator
and the sky lobby. Every morning the building's reputation moves toward what its tenants
experience: how happy they are, whether the services work, how long they wait for the lift
and how full the building is. A good reputation brings more prospective tenants.

Once the building has enough people, a good enough reputation and the required rooms, it is
promoted. A banner announces the new class and what it unlocks: taller floors, new room
types and more demanding tenants. The standing panel always shows what the next class
needs. Classes are never lost, but a neglected building's reputation, and with it its
demand, sinks. The sandbox keeps everything unlocked.

## Phase 12 player experience (current)

The day now has a colour:

* The morning starts rose.
* The late afternoon turns golden.
* The sunset glows amber at the horizon.
* The night is deep blue.

As the light fades, the city lights up behind the tower, the neighbours' windows come on
and the street lamps glow. Inside the tower, offices shine cool white while people work
and go dark when they leave. Homes glow warm in the evening and go out one by one after
22:30; lobbies and corridors stay dimly lit all night. Zoomed out, the tower's lit rooms
show as windows on its façade.

Light costs money. The facilities panel shows the current lighting load, and every
morning's closing bills the night's energy. Cutting the power, for instance by demolishing
the electrical room, turns the tower dark.

## Phase 13 player experience (current)

Every day has weather. A chip next to the clock shows today's weather, the temperature and
tomorrow's forecast.

* Summer brings clear days and the odd heatwave; autumn brings rain, fog and storms;
  winter brings snow.
* Storms keep prospective tenants at home and wear the building down, so the technicians
  and janitors have more to do.
* Heatwaves and frost push up the utilities bill, and the closing shows the temperature
  behind it.

The weather is visible too:

* grey skies and rain streaks, with lightning in a storm;
* fog swallowing the skyline;
* a warm haze in a heatwave;
* snow falling on the roofs and the street, which stays white on a cold day after.

## Phase 14 player experience (current)

Things go wrong.

**Fire.** Worn rooms and plant rooms can catch fire.

* An alert names the room, and its *Show* button takes the camera there.
* Flames rise and smoke gathers under the ceiling. The fire grows and can spread to
  the rooms beside, above and below.
* Everyone leaves by the stairs, never the elevators, and nobody goes back in while
  it burns.
* The fire brigade arrives after a quarter of an hour and parks at the kerb.
* A fire control room prevents most of this: its sprinklers cover fifteen floors above
  and below and put a fire out within minutes.
* Afterwards come the bill, soot in the damaged rooms until the technicians repair
  them, sometimes a tenant who leaves a destroyed unit, and a dent in the building's
  reputation.

**Weather.** Storms also tear at the building, heatwaves and storms can knock out the
electrical plant (the tower goes dark until it is repaired), and frost bursts pipes.

The incidents panel keeps the record.

## Phase 15 player experience (current)

The Quay Street tower is no longer the whole game. The estate panel lists land for sale
in three cities:

* **Port Calder:** another corner lot in the home city.
* **Harrowgate:** the inland capital, where rents are high, building is dear, tenants
  are plentiful and granite lies just under the street.
* **Saltmere:** a quiet harbour town on the marsh, with cheap land and cheap building but
  fewer and poorer tenants.

Buying a plot takes the money (or a loan) and moves the view there: a new street, a
different skyline, different ground in the cut-away. Each city has its own tenants, and
every tower keeps running while the player looks at another. The estate panel shows how
each property is doing and takes the player back with one click.

## Phase 16 player experience (current)

The main menu now has **Scenarios…**. Each one starts from a lot in one of the three
cities with a budget, a deadline and a few objectives:

* **Opening Day:** let a dozen units and turn a daily profit within ten days.
* **Harbour Revival:** bring Saltmere's waterfront back to life on a small budget.
* **Three Properties:** grow the Quay Street lot into an estate.
* **Crown Prestige:** a Class A address in Harrowgate with short elevator waits.
* **Skyline:** 1,500 people, waits under a minute and a profit, for a week.

The briefing says what counts. During play the objectives panel shows each objective's
progress and how many daily closings are left. Every morning's closing checks the
objectives. When they all hold, the scenario is won; when the money runs out or the
deadline passes, it is lost. Either way, the player can keep playing the estate afterwards.

## Phase 17 player experience (current)

The main menu has **Mods…**. The mod manager lists the content packs in the mods folder.
For each pack it shows what it adds and replaces, or, when it cannot load, which file and
entry are wrong. The player switches packs on and off, puts them in order and applies the
change, which reloads all content and starts a fresh game.

The game ships an example, **Kestrel Bay**: a seaside town with land for sale, a loft
apartment and the households who want one, a tower blueprint and a scenario. Its new city
appears in the estate panel, its room in the build palette and its scenario in the
browser, with no code involved. A broken mod never takes the game down: it is listed as
not loaded, with the reason.

## Phase 18 player experience (current)

*Load Game…* now opens the saves panel. It lists every save with where it lives: on this
device, in iCloud Drive, or a conflict copy. With **iCloud Drive** switched on, a tower
saved on the Mac is there on the iPad, and the other way round.

When both devices changed the same save before they could sync, nothing is lost. Both
versions stay, one of them named "… conflict ‹date›", and the player loads whichever they
want. A save deleted on one device disappears on the others, unless another device changed
it in the meantime. Autosaves stay on the device that made them.

## Phase 19 player experience (current)

Nothing new to click, but big towers stay smooth. A 211-storey tower with ten zones, sky
lobbies and express shuttles, and 950 people, runs a game day in under a second of
computer time. The morning closing no longer freezes the game for a second, and a
400-storey tower with more than 2,000 people keeps running. (Developers can load such
towers from the Build menu to see for themselves.)

## Phase 20 player experience (current)

The game has a face: an icon of a cut-away tower at dusk. The sky moves. Clouds drift
past the skyline on a fair day and crowd it on an overcast one. They stop when the game is
paused and hurry at 10×, and they turn to dark shapes at night. The panels look like one
family, and VoiceOver can name every button, including the icon-only tools. With Reduce
Motion on, storms no longer flash the screen.

