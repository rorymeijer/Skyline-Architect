import Foundation
import SkylineCore

/// Developer view of navigation: the graph and the routes people are following, as world
/// space line segments. Pure data for the debug overlay (the app draws it only in developer
/// builds); nothing here affects the simulation.
public struct NavigationOverlay: Equatable, Sendable {
    public struct Segment: Equatable, Sendable {
        public var a: Vec2
        public var b: Vec2
    }

    /// Walk links between portals along a floor.
    public var walkLinks: [Segment] = []
    /// Storey links through stair shafts.
    public var stairLinks: [Segment] = []
    public var portals: [Vec2] = []
    /// Remaining route of each traveller (at most `maxRoutes`), as polylines.
    public var routes: [[Vec2]] = []

    /// Lines are drawn this far above the floor surface so they sit at walking height.
    public static let lift = 0.6

    public static func make(graph: NavigationGraph, world: GameWorld, now: Double, maxRoutes: Int = 300) -> NavigationOverlay {
        let grid = world.grid
        func point(_ floor: Int, _ x: Double) -> Vec2 { Vec2(x, grid.y(ofFloor: floor) + lift) }
        var overlay = NavigationOverlay()
        for (i, portal) in graph.portals.enumerated() {
            overlay.portals.append(point(portal.floor, portal.x))
            for edge in graph.edges[i] where edge.to > i {
                let other = graph.portals[edge.to]
                let segment = Segment(a: point(portal.floor, portal.x), b: point(other.floor, other.x))
                switch edge.kind {
                case .walk: overlay.walkLinks.append(segment)
                case .stairs: overlay.stairLinks.append(segment)
                }
            }
        }
        for person in world.people where person.buildingID == graph.buildingID && overlay.routes.count < maxRoutes {
            guard case let .travelling(legs, _) = person.place else { continue }
            var line: [Vec2] = []
            if let here = PersonMotion.sample(legs, at: now, grid: grid) {
                line.append(Vec2(here.position.x, here.position.y + lift))
            }
            for leg in legs where Double(leg.end) > now {
                switch leg {
                case let .walk(floor, _, toX, _, _):
                    line.append(point(floor, toX))
                case let .stairs(_, _, toFloor, leftX, rightX, _, _):
                    let mid = (leftX + rightX) / 2
                    if let last = line.last { line.append(Vec2(mid, last.y)) }
                    line.append(point(toFloor, mid))
                    line.append(point(toFloor, leftX))
                }
            }
            if line.count > 1 { overlay.routes.append(line) }
        }
        return overlay
    }
}
