import Foundation
import Testing
@testable import SimplePJCore

@Suite("PJLink Protocol & Core Tests")
struct SimplePJCoreTests {
    @Test("PJLink greeting parsing handles PJLINK 0, PJLINK 1 challenge, and PJLINK ERRA")
    func greetingParsing() {
        #expect(PJLinkGreeting.parse("PJLINK 0\r") == .noAuth)
        #expect(PJLinkGreeting.parse("PJLINK 1 498e4a67\r") == .challenge("498e4a67"))
        #expect(PJLinkGreeting.parse("PJLINK ERRA\r") == .authError)
        #expect(PJLinkGreeting.parse("HTTP/1.1 200 OK") == nil)
    }

    @Test("PJLink MD5 challenge authentication matches JBMIA specification vector")
    func md5ChallengeVector() {
        let hash = PJLinkAuth.md5Digest(challenge: "498e4a67", password: "JBMIAProjectorLink")
        #expect(hash == "5d8409bc1c3fa39749434aa3a5c38682")

        let framed = PJLinkAuth.frameCommand("%1POWR 1", challenge: "498e4a67", password: "JBMIAProjectorLink")
        #expect(framed == "5d8409bc1c3fa39749434aa3a5c38682%1POWR 1\r")
    }

    @Test("PJLinkReply parses Class 1, Class 2, and error replies")
    func replyParsing() {
        let powr = PJLinkReply.parse("%1POWR=1\r")
        #expect(powr?.pjlinkClass == 1)
        #expect(powr?.command == "POWR")
        #expect(powr?.value == "1")
        #expect(powr?.error == nil)

        let innm = PJLinkReply.parse("%2INNM=DIGITAL LINK\r")
        #expect(innm?.pjlinkClass == 2)
        #expect(innm?.command == "INNM")
        #expect(innm?.value == "DIGITAL LINK")

        let err = PJLinkReply.parse("%1INPT=ERR2\r")
        #expect(err?.error == .outOfParameter)

        let erra = PJLinkReply.parse("PJLINK ERRA\r")
        #expect(erra?.error == .authenticationFailure)
    }

    @Test("PJLinkErrorStatus parses 6-component ERST codes and reports severity")
    func errorStatusParsing() {
        let healthy = PJLinkErrorStatus(code: "000000")
        #expect(healthy.isHealthy)
        #expect(healthy.highestSeverity == .ok)
        #expect(healthy.rawCode == "000000")

        let alert = PJLinkErrorStatus(code: "012010")
        #expect(!alert.isHealthy)
        #expect(alert.fan == .ok)
        #expect(alert.lamp == .warning)
        #expect(alert.temperature == .error)
        #expect(alert.coverOpen == .ok)
        #expect(alert.filter == .warning)
        #expect(alert.other == .ok)
        #expect(alert.highestSeverity == .error)
    }

    @Test("PJLinkLamp parses single and dual-lamp responses")
    func lampParsing() {
        let single = PJLinkLamp.parseList("1420 1")
        #expect(single.count == 1)
        #expect(single.first?.hours == 1420)
        #expect(single.first?.isOn == true)

        let dual = PJLinkLamp.parseList("2140 1 2138 0")
        #expect(dual.count == 2)
        #expect(dual[0].hours == 2140 && dual[0].isOn == true)
        #expect(dual[1].hours == 2138 && dual[1].isOn == false)
    }

    @Test("Projector model extracts #tags and applies Class 1 & 2 replies")
    func projectorModelUpdates() {
        var pj = Projector(ip: "2.0.0.21", label: "Face Cour #face #cour")
        #expect(pj.cleanLabel == "Face Cour")
        #expect(pj.tags == ["#face", "#cour"])

        pj.apply(reply: PJLinkReply(pjlinkClass: 1, command: "INF1", value: "Panasonic"))
        pj.apply(reply: PJLinkReply(pjlinkClass: 1, command: "INF2", value: "PT-RZ990"))
        pj.apply(reply: PJLinkReply(pjlinkClass: 1, command: "POWR", value: "1"))
        pj.apply(reply: PJLinkReply(pjlinkClass: 1, command: "AVMT", value: "31"))
        pj.apply(reply: PJLinkReply(pjlinkClass: 1, command: "INST", value: "31 32 52"))
        pj.applyInputName(code: "52", name: "DIGITAL LINK")

        #expect(pj.hardwareTitle == "Panasonic PT-RZ990")
        #expect(pj.power == .on)
        #expect(pj.shutter == .videoAndAudioMuted)
        #expect(pj.isShutterClosed == true)
        #expect(pj.availableInputs.count == 3)
        #expect(pj.availableInputs.first(where: { $0.code == "52" })?.displayName == "DIGITAL LINK")
    }

    @Test("End-to-end TCP session against PJLinkSimulatedServer with MD5 auth & state changes")
    func simulatedServerEndToEnd() throws {
        let server = PJLinkSimulatedServer(
            config: .init(
                name: "VP-SIM",
                manufacturer: "Barco",
                modelName: "UDX-4K32",
                pjlinkClass: 2,
                serialNumber: "BC-42",
                password: "admin",
                initialPower: .standby,
                initialShutter: .videoAndAudioMuted,
                initialInput: "31",
                transitionDuration: 0
            )
        )
        let port = try server.start()
        defer { server.stop() }

        // Without password -> authRequired
        let noPwd = PJLinkClient.poll(Projector(ip: "127.0.0.1", port: port, password: "")).updatedProjector
        #expect(noPwd.connectionState == .authRequired)

        // Probe common passwords -> finds "admin"
        let cracked = PJLinkClient.probeCommonPasswords(ip: "127.0.0.1", port: port)
        #expect(cracked == "admin")

        // Poll with password -> online
        var pj = Projector(ip: "127.0.0.1", port: port, password: "admin")
        pj = PJLinkClient.poll(pj, includeIdentity: true, includeClass2: true).updatedProjector
        #expect(pj.connectionState == .online)
        #expect(pj.manufacturer == "Barco")
        #expect(pj.serialNumber == "BC-42")
        #expect(pj.power == .standby)
        #expect(pj.isShutterClosed == true)

        // Power On + Open Shutter + Switch Input + Freeze
        pj = try PJLinkClient.executeBatch([.powerOn, .shutterOpen, .inputSelect("33"), .freeze(true)], on: pj).updatedProjector
        pj = PJLinkClient.poll(pj, includeIdentity: false, includeClass2: true).updatedProjector
        #expect(pj.power == .on)
        #expect(pj.isShutterClosed == false)
        #expect(pj.currentInput == "33")
        #expect(pj.freeze == true)
    }

    @Test("OSCCodec round-trips messages with int, float, string, and bool arguments")
    func oscCodecRoundTrip() {
        let msg = OSCCodec.Message(
            address: "/simplepj/group/face/shutter",
            arguments: [.int(1), .string("HDMI 1"), .bool(true)]
        )
        let encoded = OSCCodec.encode(msg)
        let decoded = OSCCodec.decode(encoded)
        #expect(decoded == [msg])
    }

    @Test("FleetDocument & FleetExporter serialize and format projectors")
    func fleetSerializationAndExport() throws {
        let pj = Projector(ip: "192.168.1.21", label: "Face Cour #face", manufacturer: "Panasonic", modelName: "PT-RZ990")
        let fixedDate = Date(timeIntervalSince1970: 1_760_000_000)
        let doc = FleetDocument(createdAt: fixedDate, showTitle: "Spectacle", scanRange: "192.168.1.0/24", projectors: [pj])
        let data = try doc.encodeJSON()
        let restored = try FleetDocument.decodeJSON(data)
        #expect(restored == doc)

        let txt = FleetExporter.render([pj], format: .txt, showTitle: "Spectacle")
        #expect(txt.contains("Face Cour"))
        #expect(txt.contains("Panasonic PT-RZ990"))
    }

    @Test("ProjectorManagerImporter parses projs array and plist data")
    func projectorManagerImporterParsing() throws {
        let projs: [[String]] = [
            ["10.0.0.2", ""],
            ["10.0.0.3", "panasonic"],
            ["172.16.1.218", ""],
            ["10.0.0.2", "duplicate"],
        ]
        let entries = ProjectorManagerImporter.parseProjsObject(projs)
        #expect(entries.count == 3)
        #expect(entries[0] == .init(ip: "10.0.0.2", password: ""))
        #expect(entries[1] == .init(ip: "10.0.0.3", password: "panasonic"))
        #expect(entries[2] == .init(ip: "172.16.1.218", password: ""))

        let plistDict: [String: Any] = ["autoOnOff": 0, "projs": projs]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .binary, options: 0)
        let fromData = ProjectorManagerImporter.parsePlistData(plistData)
        #expect(fromData == entries)
    }
}
