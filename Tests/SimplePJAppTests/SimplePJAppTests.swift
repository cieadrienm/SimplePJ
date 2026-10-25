import Foundation
import Testing
@testable import SimplePJ
@testable import SimplePJCore
@testable import SimplePJMCPCore

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

    @Test("SimplePJMCPServer handles initialize, tools/list, and tools/call")
    func mcpServerProtocol() {
        let server = SimplePJMCPServer(transport: { method, path, _ in
            APIResponse(
                status: 200,
                data: Data("{\"ok\":true,\"method\":\"\(method)\",\"path\":\"\(path)\"}".utf8),
                contentType: "application/json"
            )
        })

        let initResp = server.handle(line: "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}") ?? ""
        #expect(initResp.contains("\"name\":\"simplepj\""))

        let listResp = server.handle(line: "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}") ?? ""
        #expect(listResp.contains("simplepj_shutter"))
        #expect(listResp.contains("simplepj_snapshot"))

        let callResp = server.handle(line: "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"simplepj_shutter\",\"arguments\":{\"target\":\"#face\",\"closed\":true}}}") ?? ""
        #expect(callResp.contains("/v1/shutter"))
    }
}
