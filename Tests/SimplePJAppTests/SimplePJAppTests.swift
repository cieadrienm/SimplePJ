import Foundation
import Testing
@testable import SimplePJ
@testable import SimplePJCore

@Suite("SimplePJ App & Snapshot Tests")
@MainActor
struct SimplePJAppTests {
    @Test("SyntheticFleet populates groups, counts, and filters")
    func syntheticFleetFiltering() {
        let model = AppModel(startServices: false, persistEnabled: false)
        SyntheticFleet.load(into: model)

        #expect(model.fleet.projectors.count == 6)
        #expect(model.fleet.projectingCount == 3)
        #expect(model.fleet.shutterClosedCount == 3)
        #expect(model.fleet.standbyCount == 1)

        model.fleet.sidebarFilter = .tag("#cyclo")
        #expect(model.fleet.visibleProjectors.count == 2)

        model.fleet.sidebarFilter = .all
        model.fleet.searchQuery = "Barco"
        #expect(model.fleet.visibleProjectors.count == 1)
        #expect(model.fleet.visibleProjectors.first?.modelName == "UDX-4K32")
    }

    @Test("Offscreen PNG snapshots render for Cards, Table, and Sheets")
    func offscreenSnapshotsRender() {
        let model = AppModel(startServices: false, persistEnabled: false)
        SyntheticFleet.load(into: model)

        let cardsPNG = Snapshot.renderOffscreenPNG(model: model)
        #expect((cardsPNG?.count ?? 0) > 15_000)

        model.viewMode = .table
        let tablePNG = Snapshot.renderOffscreenPNG(model: model)
        #expect((tablePNG?.count ?? 0) > 15_000)
    }
}
