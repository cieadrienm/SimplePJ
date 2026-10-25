import AppKit
import Foundation
import SimplePJCore

@MainActor
enum SelfTest {
    static func runAndExit() -> Never {
        var failures: [String] = []
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() {
                failures.append(message)
                fputs("FAIL: \(message)\n", stderr)
            } else {
                print("PASS: \(message)")
            }
        }

        // 1. Start two real loopback TCP PJLink Class 2 servers:
        //    - Server A: open (PJLINK 0), closes socket after each command (like Epson/Sony)
        //    - Server B: MD5 password-protected (PJLINK 1 <challenge>, password "panasonic")
        let serverA = PJLinkSimulatedServer(
            config: .init(
                name: "VP-TEST-COUR",
                manufacturer: "Panasonic",
                modelName: "PT-RZ990",
                pjlinkClass: 2,
                serialNumber: "SN-COUR-01",
                password: "",
                initialPower: .on,
                initialShutter: .open,
                initialInput: "31",
                transitionDuration: 0,
                closeAfterEachCommand: true
            )
        )
        let serverB = PJLinkSimulatedServer(
            config: .init(
                name: "VP-TEST-JARDIN",
                manufacturer: "EPSON",
                modelName: "EB-PU2010B",
                pjlinkClass: 2,
                serialNumber: "SN-JARDIN-02",
                password: "panasonic",
                initialPower: .standby,
                initialShutter: .videoAndAudioMuted,
                initialInput: "52",
                errors: PJLinkErrorStatus(filter: .warning),
                transitionDuration: 0,
                closeAfterEachCommand: false
            )
        )

        do {
            let portA = try serverA.start()
            let portB = try serverB.start()
            defer {
                serverA.stop()
                serverB.stop()
            }

            // 2. Test TCP discovery across both loopback ports
            let endpoints = [
                PJLinkEndpoint(ip: "127.0.0.1", port: portA),
                PJLinkEndpoint(ip: "127.0.0.1", port: portB),
            ]
            let discoveredInitial = PJLinkDiscovery.scan(endpoints: endpoints)
            check(discoveredInitial.count == 2, "Discovery finds both loopback PJLink servers")

            let discA = discoveredInitial.first { $0.port == portA }
            let discB = discoveredInitial.first { $0.port == portB }
            check(discA?.connectionState == .online, "Open projector A is online")
            check(discA?.manufacturer == "Panasonic" && discA?.modelName == "PT-RZ990", "Projector A identity parsed")
            check(discA?.serialNumber == "SN-COUR-01", "Projector A Class 2 SNUM parsed")
            check(discB?.connectionState == .authRequired, "Password-protected projector B reports authRequired without password")

            // 3. Test smart factory password auto-discovery on projector B
            let crackedPassword = PJLinkClient.probeCommonPasswords(ip: "127.0.0.1", port: portB)
            check(crackedPassword == "panasonic", "Auto-unlock discovers factory password 'panasonic'")

            // 4. Poll projector B with password and test commands
            var pjB = Projector(ip: "127.0.0.1", port: portB, password: "panasonic")
            pjB = PJLinkClient.poll(pjB, includeIdentity: true, includeClass2: true).updatedProjector
            check(pjB.connectionState == .online, "Projector B is online with MD5 challenge auth")
            check(pjB.errors.filter == .warning, "Projector B ERST filter warning parsed")

            // 5. Test Shutter, Input, Freeze, and Power commands on Projector A
            if var pjA = discA {
                pjA = try PJLinkClient.execute(.shutterClose, on: pjA).updatedProjector
                pjA = PJLinkClient.poll(pjA, includeIdentity: false, includeClass2: false).updatedProjector
                check(pjA.isShutterClosed, "Shutter close (AVMT 31) sets videoAndAudioMuted")

                pjA = try PJLinkClient.execute(.shutterOpen, on: pjA).updatedProjector
                pjA = PJLinkClient.poll(pjA, includeIdentity: false, includeClass2: false).updatedProjector
                check(!pjA.isShutterClosed, "Shutter open (AVMT 30) restores open state")

                pjA = try PJLinkClient.execute(.inputSelect("52"), on: pjA).updatedProjector
                pjA = PJLinkClient.poll(pjA, includeIdentity: false, includeClass2: false).updatedProjector
                check(pjA.currentInput == "52", "Input switch (INPT 52) updates currentInput")

                pjA = try PJLinkClient.execute(.freeze(true), on: pjA).updatedProjector
                pjA = PJLinkClient.poll(pjA, includeIdentity: false, includeClass2: true).updatedProjector
                check(pjA.freeze == true, "Class 2 Freeze (FREZ 1) activates freeze")
            }

            // 6. Test OSC codec & controller integration
            let model = AppModel(startServices: false, persistEnabled: false)
            SyntheticFleet.load(into: model)
            model.fleet.handleOSCMessage(OSCCodec.Message(address: "/simplepj/group/face/shutter", arguments: [.int(1)]))
            check(model.fleet.projectors.count == 6, "Synthetic fleet loaded with 6 projectors")

            // 6b. Test ProjectorManager importer parsing
            let samplePM = ProjectorManagerImporter.parseProjsObject([["10.0.0.2", ""], ["172.16.1.218", "panasonic"]])
            check(samplePM.count == 2 && samplePM[1].password == "panasonic", "ProjectorManagerImporter parses projs array")

            // 7. Test offscreen PNG snapshot rendering
            let pngCards = Snapshot.renderOffscreenPNG(model: model)
            check((pngCards?.count ?? 0) > 15_000, "Offscreen cards PNG renders (> 15 KB)")
            model.viewMode = .table
            let pngTable = Snapshot.renderOffscreenPNG(model: model)
            check((pngTable?.count ?? 0) > 15_000, "Offscreen table PNG renders (> 15 KB)")
        } catch {
            failures.append("Unexpected exception: \(error)")
        }

        if failures.isEmpty {
            print("SimplePJ self-test: ALL PASSED")
            exit(0)
        } else {
            fputs("SimplePJ self-test: \(failures.count) FAILURE(S)\n", stderr)
            exit(1)
        }
    }
}
