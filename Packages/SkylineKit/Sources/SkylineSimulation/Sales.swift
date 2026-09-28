import Foundation
import SkylineCore

/// Selling flats (0.20.3): the player offers a vacant flat for sale instead of for rent.
/// A household buys it for its asking rent × `saleMonths` (paid to the player at once) and
/// then pays monthly service charges; it holds on longer before moving out. A sold flat stays
/// privately owned: when its owner leaves, another household buys it from them (a resale:
/// no money to the player, service charges go on).
extension Leasing {
    public enum TenureError: Error, Equatable, CustomStringConvertible {
        case notAUnit, noBuyers, occupied, sold

        public var description: String {
            switch self {
            case .notAUnit: "Only rentable units can be sold"
            case .noBuyers: "No household buys this kind of unit"
            case .occupied: "Only a vacant unit can change"
            case .sold: "Already sold to a private owner"
            }
        }
    }

    /// Households buy; businesses always rent.
    static func buys(_ type: TenantType) -> Bool { type.kind == "household" }

    /// Whether any household type would live in this kind of room.
    public static func canBeSold(_ room: Room, rules: SimulationRules) -> Bool {
        rules.tenantTypes(for: room.definitionID).contains(where: buys)
    }

    public static func salePrice(_ room: Room, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> Int? {
        askingRent(room, world: world, catalog: catalog).map { Int((Double($0) * (rules.economy?.salePriceMonths ?? 100)).rounded()) }
    }

    /// Monthly service charges an owner pays.
    public static func serviceCharge(_ room: Room, world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> Int? {
        askingRent(room, world: world, catalog: catalog).map { Int((Double($0) * (rules.economy?.serviceShare ?? 0.25)).rounded()) }
    }

    /// Offers a vacant, unsold unit for rent or for sale.
    public static func setTenure(_ tenure: Tenure, room id: RoomID, world: inout GameWorld, rules: SimulationRules,
                                 catalog: BuildCatalog) throws {
        guard let room = world.rooms[id], catalog.spec(room.definitionID)?.rentPerModule != nil else { throw TenureError.notAUnit }
        guard !room.isPrivatelyOwned, tenure != .owned else { throw TenureError.sold }
        guard tenure == .rent || canBeSold(room, rules: rules) else { throw TenureError.noBuyers }
        guard !world.tenants.values.contains(where: { $0.room == id }) else { throw TenureError.occupied }
        world.setTenure(tenure, room: id)
    }

    /// Whether `type` would sign for `room` at all: businesses do not buy flats.
    static func takes(_ room: Room, type: TenantType) -> Bool {
        (room.tenure ?? .rent) == .rent || buys(type)
    }

    /// The contract of a new tenant of `room`: a lease, a purchase from the player (the
    /// price is booked as a sale and the flat becomes privately owned) or a resale.
    static func contract(_ id: TenantID, type: TenantType, name: String, room: Room, at now: Tick, satisfaction: Double,
                         world: inout GameWorld, rules: SimulationRules, catalog: BuildCatalog) -> Tenant {
        let rent = askingRent(room, world: world, catalog: catalog) ?? 0
        var tenant = Tenant(id: id, typeID: type.id, name: name, buildingID: room.buildingID, room: room.id, rent: rent,
                            since: now, satisfaction: satisfaction)
        switch world.rooms[room.id]?.tenure ?? .rent {
        case .rent:
            break
        case .forSale:
            let price = salePrice(room, world: world, catalog: catalog, rules: rules) ?? 0
            tenant.purchasePrice = price
            tenant.rent = serviceCharge(room, world: world, catalog: catalog, rules: rules) ?? 0
            world.setTenure(.owned, room: room.id)
            if price > 0 {
                let unit = catalog.spec(room.definitionID)?.name ?? room.definitionID
                world.ledger.post(Transaction(tick: now, amount: price, category: .sales,
                                              detail: "Sale — \(unit) \(FloorLabel.label(for: room.floors.lowest)) to \(name)",
                                              building: room.buildingID, room: room.id, tenant: id))
            }
        case .owned:
            tenant.purchasePrice = 0                                     // bought from the previous owner
            tenant.rent = serviceCharge(room, world: world, catalog: catalog, rules: rules) ?? 0
        }
        return tenant
    }
}
