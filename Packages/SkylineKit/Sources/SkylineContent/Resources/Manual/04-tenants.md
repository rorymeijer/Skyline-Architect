# Tenants and units

Offices, flats and amenity rooms are **units**: rooms you can let. Tenants pay rent every day; how well a unit is served decides who signs and who stays.

## Who comes

Every game hour, prospects of each tenant type look for a unit in your city. A prospect looks at every vacant unit it could use, scores each one and takes the best one it can afford, if the score is good enough.

| Tenant | Unit | Budget per m | Cares most about | From |
|---|---|---|---|---|
| Call centre | Small Office | $400 | rent | the start |
| Design studio | Small Office | $430 | view and quiet | Class B |
| Consultancy | Small Office | $460 | access | Class A |
| Couple | Studio Apartment | $260 | rent and access | the start |
| Retired couple | Studio Apartment | $240 | quiet | the start |
| Single professional | Studio Apartment | $300 | access | Class B |

Amenities have their own operators (see [Amenities and visitors](amenities.md)). How many prospects come depends on the city's demand, your reputation, the weather and scenario events.

## How a unit is judged

Each unit scores from 0 to 1 on:

- **Rent**: how far the asking rent is below the tenant's budget. Over budget, it is out of the question.
- **Access**: the time from the street to the unit, including elevator waits: 30 seconds is perfect, five minutes is hopeless. A unit nobody can reach scores nothing at all.
- **Quiet**: noise from the neighbours. Rooms side by side count fully; rooms above and below count half. Plant rooms, cinemas and fitness clubs are loud.
- **View**: higher is better, up to floor 15.
- **Services**: electricity, water, climate and data supplied, plus cleanliness and condition. Without a utility a unit is nearly worthless (see [Utilities and staff](facilities.md)).

Open amenities in the building make every unit a little more attractive.

## Why prospects say no

The **Leasing** panel (`⌥⌘L`) counts every refusal by reason:

| Reason | What to do |
|---|---|
| **No vacancy** | Nothing they could use is free: build more of that unit type. |
| **Too expensive** | Lower the rent, for the building or for this unit. |
| **Hard to reach** | Add or improve elevators, or a closer stairwell. |
| **Too noisy** | Move loud rooms away, or put quiet rooms next to homes. |
| **Poor view** | Higher floors let better. |
| **Poor services** | A utility is missing, or rooms are dirty or worn: check the plant and hire staff. |

## The unit inspector

Click a unit to open its inspector. It shows the tenant, their satisfaction and the score on each criterion. For a vacant unit it lists every tenant type with ✓ and a score when they would sign, or ✗ with the reason when they would not. It also shows the utilities, cleanliness, condition and the last leasing events.

## Rent

- A unit asks its room's rent per metre × its width, 1 % more for each storey up, times your rent levels and the city's price level. A game day is one rent month, so rent comes in at every daily closing.
- **Rent level** in the Economy panel sets all rents from 60 % to 160 %. The unit inspector sets one unit's rent the same way. Higher rent earns more per tenant but scares prospects away.
- A signed rent is a contract: changing the level only affects new tenants.

## Selling flats

A vacant flat can be offered for sale instead (**Offer for Sale** in the inspector). The price is 100 months of its rent, paid at once. The owner then pays you service charges of a quarter of the rent every month. Owners are patient: they leave only after nine bad reviews in a row, and then sell the flat on privately. A sold flat is no longer yours to rent, cut or demolish. Offices and amenities are always rented.

## Satisfaction and moving out

Every morning at 06:00 each tenant reviews their unit; satisfaction moves toward today's score. After **three bad reviews in a row** a tenant moves out. The inspector warns you: "Unhappy for 2 days — leaves at 3".
