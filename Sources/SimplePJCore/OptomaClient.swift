import CryptoKit
import Darwin
import Foundation

public let kOptomaTelnetPort: UInt16 = 23
public let kOptomaHTTPPort: UInt16 = 80
public let kEpsonESCVPNetPort: UInt16 = 3629
public let kEpsonHTTPPort: UInt16 = 80
public let kPanasonicNTControlPort: UInt16 = 1024
public let kPanasonicHTTPPort: UInt16 = 80

/// Built-in test patterns across:
/// - **Panasonic PT-RZ / PT-RQ / PT-MZ** (`00OTS:07` Crosshatch Grid, `00OTS:00` Off…)
/// - **Epson Pro L / EB-PU** (`EB-L1755U` `POPPAT 01` / `KEY 90`…)
/// - **Optoma ProScene** (`ZU920ST` `~00195 1`…)
public enum OptomaTestPattern: Int, Codable, CaseIterable, Identifiable, Sendable {
    case off = 0
    case whiteGrid = 1
    case greenGrid = 3
    case magentaGrid = 4
    case white = 2
    case black = 5
    case colorBars = 7

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .off: return L("Aucune (Off)", "None (Off)")
        case .whiteGrid: return L("Grille de calage", "Alignment Grid")
        case .greenGrid: return L("Grille 2 / Verte", "Grid 2 / Green")
        case .magentaGrid: return L("Grille M / Diag.", "M / Diag. Grid")
        case .white: return L("Blanc plein", "Full White")
        case .black: return L("Noir", "Black")
        case .colorBars: return L("Barres couleur", "Color Bars")
        }
    }

    public var shortLabel: String {
        switch self {
        case .off: return "Off"
        case .whiteGrid: return L("Grille", "Grid")
        case .greenGrid: return L("Grille 2", "Grid 2")
        case .magentaGrid: return L("Grille M", "M Grid")
        case .white: return L("Blanc", "White")
        case .black: return L("Noir", "Black")
        case .colorBars: return L("Mire", "Bars")
        }
    }

    public var symbol: String {
        switch self {
        case .off: return "xmark.square"
        case .whiteGrid, .greenGrid, .magentaGrid: return "squareshape.split.3x3"
        case .white: return "square.fill"
        case .black: return "square"
        case .colorBars: return "slider.horizontal.below.square.and.square.filled"
        }
    }

    /// Optoma RS232-over-IP / Telnet (`:23`) ASCII command (`~00195 n\r`).
    public var rs232Command: String {
        "~00195 \(rawValue)"
    }

    /// Optoma HTTP CGI form payload for `/tgi/control.tgi`.
    public var cgiFormPayload: String {
        "test_pattern=\(rawValue)&Pattern=\(rawValue)"
    }

    /// Epson ESC/VP21 (`:3629`) commands for EB-L1755U / Pro L series.
    public var epsonESCVPCommands: [String] {
        switch self {
        case .off: return ["POPPAT 00", "KEY 1F"]
        case .whiteGrid: return ["POPPAT 01", "KEY 90"]
        case .greenGrid, .magentaGrid: return ["POPPAT 02"]
        case .white: return ["POPPAT 03"]
        case .black: return ["POPPAT 04"]
        case .colorBars: return ["POPPAT 05"]
        }
    }

    /// Epson HTTP Web Control query for `/cgi-bin/directsend`.
    public var epsonDirectSendQuery: String {
        switch self {
        case .off: return "POPPAT=00&KEY=1F"
        case .whiteGrid: return "POPPAT=01&KEY=90"
        case .greenGrid, .magentaGrid: return "POPPAT=02"
        case .white: return "POPPAT=03"
        case .black: return "POPPAT=04"
        case .colorBars: return "POPPAT=05"
        }
    }

    /// Panasonic NTCONTROL (`:1024`) command (`00OTS:nn`) for PT-RZ / PT-RQ / PT-MZ series.
    public var panasonicNTCommand: String {
        switch self {
        case .off: return "00OTS:00"
        case .whiteGrid: return "00OTS:07"      // Crosshatch Alignment Grid
        case .greenGrid: return "00OTS:08"      // Inverse / Fine Grid
        case .magentaGrid: return "00OTS:11"    // Diagonal Crosshatch
        case .white: return "00OTS:01"          // White
        case .black: return "00OTS:02"          // Black
        case .colorBars: return "00OTS:05"      // Color Bars
        }
    }

    /// Panasonic HTTP CGI query for `/cgi-bin/proj_ctl.cgi`.
    public var panasonicCGIQuery: String {
        switch self {
        case .off: return "key=ots:00&lang=e&osd=on"
        case .whiteGrid: return "key=ots:07&lang=e&osd=on"
        case .greenGrid: return "key=ots:08&lang=e&osd=on"
        case .magentaGrid: return "key=ots:11&lang=e&osd=on"
        case .white: return "key=ots:01&lang=e&osd=on"
        case .black: return "key=ots:02&lang=e&osd=on"
        case .colorBars: return "key=ots:05&lang=e&osd=on"
        }
    }

    /// Flexible parser for OSC, HTTP `/v1/pattern`, and MCP calls.
    public static func parse(_ raw: String) -> OptomaTestPattern? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "0", "off", "none", "aucune", "non", "false":
            return .off
        case "1", "grid", "grille", "white-grid", "whitegrid", "grille-blanche", "crosshatch", "true", "on":
            return .whiteGrid
        case "3", "green-grid", "greengrid", "green", "grille-verte", "vert", "grid2", "grille2":
            return .greenGrid
        case "4", "magenta-grid", "magentagrid", "magenta", "grille-magenta", "diag":
            return .magentaGrid
        case "2", "white", "blanc":
            return .white
        case "5", "black", "noir":
            return .black
        case "7", "bars", "colorbars", "color-bars", "mire", "barres":
            return .colorBars
        default:
            if let code = Int(s) {
                return OptomaTestPattern(rawValue: code)
            }
            return nil
        }
    }
}

/// Motorized lens & optical actions across:
/// - **Panasonic PT-RZ / PT-RQ / PT-MZ** (`00VXX:LNSI2..5` & `/cgi-bin/proj_ctl.cgi`)
/// - **Epson Pro L / EB-PU** (`EB-L1755U` + `ELPLU03`/`ELPLU03S` `LENS`, `HLENS`, `FOCUS`, `ZOOM`, `DISTORTION`)
/// - **Optoma ProScene** (`ZU920ST` `~0084`, `~00140`)
public enum OptomaLensAction: String, CaseIterable, Identifiable, Sendable {
    case shiftUp = "up"
    case shiftDown = "down"
    case shiftLeft = "left"
    case shiftRight = "right"
    case focusPlus = "focus+"
    case focusMinus = "focus-"
    case zoomPlus = "zoom+"
    case zoomMinus = "zoom-"
    case distortionPlus = "distortion+"
    case distortionMinus = "distortion-"
    case lensCenter = "center"
    case lensUnlock = "unlock"
    case lensLock = "lock"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .shiftUp: return L("Lens Shift Haut ▲", "Lens Shift Up ▲")
        case .shiftDown: return L("Lens Shift Bas ▼", "Lens Shift Down ▼")
        case .shiftLeft: return L("Lens Shift Gauche ◀", "Lens Shift Left ◀")
        case .shiftRight: return L("Lens Shift Droite ▶", "Lens Shift Right ▶")
        case .focusPlus: return L("Focus + (Netteté +)", "Focus + (Near)")
        case .focusMinus: return L("Focus − (Netteté −)", "Focus − (Far)")
        case .zoomPlus: return L("Zoom + (Agrandir)", "Zoom + (Wide)")
        case .zoomMinus: return L("Zoom − (Réduire)", "Zoom − (Tele)")
        case .distortionPlus: return L("Distorsion + (ELPLU03)", "Distortion + (ELPLU03)")
        case .distortionMinus: return L("Distorsion − (ELPLU03)", "Distortion − (ELPLU03)")
        case .lensCenter: return L("Centrer l'optique (Home)", "Center Lens (Home)")
        case .lensUnlock: return L("Déverrouiller l'optique", "Unlock Lens")
        case .lensLock: return L("Verrouiller l'optique", "Lock Lens")
        }
    }

    /// Optoma RS232-over-IP / Telnet (`:23`) ASCII commands (`~0084` / `~00140`).
    public var rs232Commands: [String] {
        switch self {
        case .shiftUp: return ["~0084 3", "~00140 66"]
        case .shiftDown: return ["~0084 4", "~00140 67"]
        case .shiftLeft: return ["~0084 5", "~00140 64"]
        case .shiftRight: return ["~0084 6", "~00140 65"]
        case .focusPlus: return ["~00140 34"]
        case .focusMinus: return ["~00140 35"]
        case .zoomPlus: return ["~00140 32"]
        case .zoomMinus: return ["~00140 33"]
        case .distortionPlus: return ["~00140 34"]
        case .distortionMinus: return ["~00140 35"]
        case .lensCenter: return ["~0084 2"]
        case .lensUnlock: return ["~0084 0"]
        case .lensLock: return ["~0084 1"]
        }
    }

    /// Optoma HTTP CGI form payload for `/tgi/control.tgi`.
    public var cgiFormPayload: String {
        switch self {
        case .shiftUp: return "lens_shift=up&btn_lens_up=1&LensShift=3"
        case .shiftDown: return "lens_shift=down&btn_lens_down=1&LensShift=4"
        case .shiftLeft: return "lens_shift=left&btn_lens_left=1&LensShift=5"
        case .shiftRight: return "lens_shift=right&btn_lens_right=1&LensShift=6"
        case .focusPlus: return "focus=in&btn_focus_inc=1&Focus=1"
        case .focusMinus: return "focus=out&btn_focus_dec=1&Focus=2"
        case .zoomPlus: return "zoom=in&btn_zoom_inc=1&Zoom=1"
        case .zoomMinus: return "zoom=out&btn_zoom_dec=1&Zoom=2"
        case .distortionPlus: return "distortion=inc"
        case .distortionMinus: return "distortion=dec"
        case .lensCenter: return "lens_center=1&LensShift=2"
        case .lensUnlock: return "lens_lock=0&LensLock=0"
        case .lensLock: return "lens_lock=1&LensLock=1"
        }
    }

    /// Epson ESC/VP21 (`:3629`) commands for EB-L1755U + ELPLU03 / ELPLU03S motorized lens.
    public var epsonESCVPCommands: [String] {
        switch self {
        case .shiftUp: return ["LENS INC"]
        case .shiftDown: return ["LENS DEC"]
        case .shiftLeft: return ["HLENS DEC"]
        case .shiftRight: return ["HLENS INC"]
        case .focusPlus: return ["FOCUS INC"]
        case .focusMinus: return ["FOCUS DEC"]
        case .zoomPlus: return ["ZOOM INC"]
        case .zoomMinus: return ["ZOOM DEC"]
        case .distortionPlus: return ["DISTORTION INC"]
        case .distortionMinus: return ["DISTORTION DEC"]
        case .lensCenter: return ["LENS 512", "HLENS 512"]
        case .lensUnlock: return ["LENSLOCK OFF"]
        case .lensLock: return ["LENSLOCK ON"]
        }
    }

    /// Epson HTTP Web Control query for `/cgi-bin/directsend`.
    public var epsonDirectSendQuery: String {
        switch self {
        case .shiftUp: return "LENS=INC"
        case .shiftDown: return "LENS=DEC"
        case .shiftLeft: return "HLENS=DEC"
        case .shiftRight: return "HLENS=INC"
        case .focusPlus: return "FOCUS=INC"
        case .focusMinus: return "FOCUS=DEC"
        case .zoomPlus: return "ZOOM=INC"
        case .zoomMinus: return "ZOOM=DEC"
        case .distortionPlus: return "DISTORTION=INC"
        case .distortionMinus: return "DISTORTION=DEC"
        case .lensCenter: return "LENS=512&HLENS=512"
        case .lensUnlock: return "LENSLOCK=OFF"
        case .lensLock: return "LENSLOCK=ON"
        }
    }

    /// Panasonic NTCONTROL (`:1024`) commands (`00VXX:LNSI...`) for PT-RZ / PT-RQ / PT-MZ series.
    /// Uses fine step (`00001`/`00101`) when `fast == false` and normal/coarse step (`00010`/`00110`) when `fast == true`.
    public func panasonicNTCommand(fast: Bool = false) -> String {
        let posStep = fast ? "+00010" : "+00001"
        let negStep = fast ? "+00110" : "+00101"
        switch self {
        case .shiftUp: return "00VXX:LNSI2=\(posStep)"
        case .shiftDown: return "00VXX:LNSI2=\(negStep)"
        case .shiftRight: return "00VXX:LNSI3=\(posStep)"
        case .shiftLeft: return "00VXX:LNSI3=\(negStep)"
        case .focusPlus: return "00VXX:LNSI4=\(posStep)"
        case .focusMinus: return "00VXX:LNSI4=\(negStep)"
        case .zoomPlus: return "00VXX:LNSI5=\(posStep)"
        case .zoomMinus: return "00VXX:LNSI5=\(negStep)"
        case .distortionPlus: return "00VXX:LNSI4=\(posStep)"
        case .distortionMinus: return "00VXX:LNSI4=\(negStep)"
        case .lensCenter: return "00VXX:LNSI1=+00001"
        case .lensUnlock: return "00VXX:LNSI0=+00000"
        case .lensLock: return "00VXX:LNSI0=+00001"
        }
    }

    /// Panasonic HTTP CGI query for `/cgi-bin/proj_ctl.cgi`.
    public func panasonicCGIQuery(fast: Bool = false) -> String {
        let lvl = fast ? "2" : "1"
        switch self {
        case .shiftUp: return "key=lns_up\(lvl)&lang=e&osd=on"
        case .shiftDown: return "key=lns_down\(lvl)&lang=e&osd=on"
        case .shiftLeft: return "key=lns_left\(lvl)&lang=e&osd=on"
        case .shiftRight: return "key=lns_right\(lvl)&lang=e&osd=on"
        case .focusPlus: return "key=lns_foc_p\(lvl)&lang=e&osd=on"
        case .focusMinus: return "key=lns_foc_m\(lvl)&lang=e&osd=on"
        case .zoomPlus: return "key=lns_zom_p\(lvl)&lang=e&osd=on"
        case .zoomMinus: return "key=lns_zom_m\(lvl)&lang=e&osd=on"
        case .distortionPlus: return "key=lns_foc_p\(lvl)&lang=e&osd=on"
        case .distortionMinus: return "key=lns_foc_m\(lvl)&lang=e&osd=on"
        case .lensCenter: return "key=lns_cent&lang=e&osd=on"
        case .lensUnlock: return "key=osd_on&lang=e&osd=on"
        case .lensLock: return "key=osd_off&lang=e&osd=on"
        }
    }

    public static func parse(_ raw: String) -> OptomaLensAction? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "up", "haut", "u", "north": return .shiftUp
        case "down", "bas", "d", "south": return .shiftDown
        case "left", "gauche", "l", "west": return .shiftLeft
        case "right", "droite", "r", "east": return .shiftRight
        case "focus+", "focus_in", "focusin", "focus-plus", "near": return .focusPlus
        case "focus-", "focus_out", "focusout", "focus-minus", "far": return .focusMinus
        case "zoom+", "zoom_in", "zoomin", "zoom-plus", "in", "wide": return .zoomPlus
        case "zoom-", "zoom_out", "zoomout", "zoom-minus", "out", "tele": return .zoomMinus
        case "distortion+", "dist+", "distortion-plus": return .distortionPlus
        case "distortion-", "dist-", "distortion-minus": return .distortionMinus
        case "center", "centre", "centrer", "home", "reset": return .lensCenter
        case "unlock", "deverrouiller", "déverrouiller", "open": return .lensUnlock
        case "lock", "verrouiller": return .lensLock
        default: return nil
        }
    }
}

/// Network client for extended projector optics & test patterns across:
/// - **Panasonic PT-RZ / PT-RQ / PT-MZ (`PT-RZ990`, `PT-RQ22K`, `PT-RZ21K`…)**:
///   1. **Panasonic NTCONTROL on TCP port `1024`** (`NTCONTROL 0/1` MD5 auth + `00OTS:07`, `00VXX:LNSI2..5`)
///   2. **HTTP Web Control CGI on port `80`** (`GET /cgi-bin/proj_ctl.cgi?key=...` with Basic Auth `admin1:<pwd>`)
/// - **Epson Pro L / EB-PU (`EB-L1755U` + `ELPLU03`/`ELPLU03S`)**:
///   1. **ESC/VP.net on TCP port `3629`** (16-byte `ESC/VP.net\x10\x03...` handshake + ASCII ESC/VP21 `LENS`, `HLENS`, `FOCUS`, `ZOOM`, `DISTORTION`, `POPPAT`)
///   2. **HTTP Web Control CGI on port `80`** (`GET /cgi-bin/directsend?...` with `Referer` & Basic Auth `EPSONWEB:<pwd>`)
/// - **Optoma ProScene (`ZU920ST` / ZU series)**:
///   1. **TCP RS232-over-IP on port `23`** (`~00195`, `~0084`, `~00140`)
///   2. **HTTP Web Control CGI on port `80`** (`POST /tgi/control.tgi`)
public enum OptomaClient {
    public struct Result: Sendable {
        public var ok: Bool
        public var transport: String
        public var exchange: PJLinkExchange
    }

    /// Sets the active test pattern (e.g. Alignment Grid, Off) on a Panasonic, Epson, or Optoma projector.
    public static func setTestPattern(
        _ pattern: OptomaTestPattern,
        on projector: Projector,
        timeout: TimeInterval = 0.85
    ) -> Result {
        if projector.isPanasonic {
            let cmd = pattern.panasonicNTCommand
            return sendPanasonic(
                ntCommands: [cmd],
                cgiQuery: pattern.panasonicCGIQuery,
                label: "PANA \(cmd) (\(pattern.shortLabel))",
                projector: projector,
                timeout: timeout
            )
        }
        if projector.isEpson {
            let primary = pattern.epsonESCVPCommands.first ?? "POPPAT"
            return sendEpson(
                escvpCommands: pattern.epsonESCVPCommands,
                directSendQuery: pattern.epsonDirectSendQuery,
                label: "EPSON \(primary) (\(pattern.shortLabel))",
                projector: projector,
                timeout: timeout
            )
        }
        return sendOptoma(
            rs232Commands: [pattern.rs232Command],
            cgiPayload: pattern.cgiFormPayload,
            label: "OPTOMA \(pattern.rs232Command) (\(pattern.shortLabel))",
            projector: projector,
            timeout: timeout
        )
    }

    /// Triggers a motorized lens action (Lens Shift H/V, Focus +/-, Zoom +/-, Distortion +/-, Center, Unlock/Lock).
    public static func triggerLens(
        _ action: OptomaLensAction,
        steps: Int = 1,
        on projector: Projector,
        timeout: TimeInterval = 0.85
    ) -> Result {
        let clampedSteps = max(1, min(10, steps))
        let stepSuffix = clampedSteps > 1 ? " ×\(clampedSteps)" : ""

        if projector.isPanasonic {
            let fast = clampedSteps >= 3
            let cmd = action.panasonicNTCommand(fast: fast)
            let repeatCount = fast ? max(1, clampedSteps / 3) : clampedSteps
            let cmds = Array(repeating: cmd, count: repeatCount)
            return sendPanasonic(
                ntCommands: cmds,
                cgiQuery: action.panasonicCGIQuery(fast: fast),
                steps: repeatCount,
                label: "PANA \(cmd)\(stepSuffix)",
                projector: projector,
                timeout: timeout
            )
        }

        if projector.isEpson {
            var cmds: [String] = []
            for _ in 0..<clampedSteps {
                cmds.append(contentsOf: action.epsonESCVPCommands)
            }
            let primary = action.epsonESCVPCommands.first ?? action.rawValue
            return sendEpson(
                escvpCommands: cmds,
                directSendQuery: action.epsonDirectSendQuery,
                steps: clampedSteps,
                label: "EPSON \(primary)\(stepSuffix)",
                projector: projector,
                timeout: timeout
            )
        }

        var cmds: [String] = []
        for _ in 0..<clampedSteps {
            cmds.append(contentsOf: action.rs232Commands)
        }
        let primary = action.rs232Commands.first ?? action.rawValue
        return sendOptoma(
            rs232Commands: cmds,
            cgiPayload: action.cgiFormPayload,
            label: "OPTOMA \(primary)\(stepSuffix)",
            projector: projector,
            timeout: timeout
        )
    }

    // MARK: - Panasonic PT-RZ / PT-RQ / PT-MZ: NTCONTROL (:1024) + HTTP /cgi-bin/proj_ctl.cgi (:80)

    private static func sendPanasonic(
        ntCommands: [String],
        cgiQuery: String,
        steps: Int = 1,
        label: String,
        projector: Projector,
        timeout: TimeInterval
    ) -> Result {
        let start = DispatchTime.now()

        // 1. Simulated projector on loopback
        if projector.isSimulated || (projector.ip == "127.0.0.1" && projector.port != kPJLinkDefaultPort) {
            if let reply = sendRS232OverTCP(ip: projector.ip, port: projector.port, commands: ntCommands, expectPJLinkGreeting: true, timeout: timeout) {
                let ms = elapsedMs(since: start)
                return Result(
                    ok: true,
                    transport: "SIM:\(projector.port)",
                    exchange: PJLinkExchange(
                        projectorIP: projector.endpointLabel,
                        projectorTitle: projector.displayTitle,
                        tx: label,
                        rx: "\(reply) (SIM)",
                        durationMs: ms,
                        isError: false
                    )
                )
            }
        }

        // 2. Panasonic NTCONTROL on TCP port 1024
        if let reply = sendPanasonicNTControl(ip: projector.ip, port: kPanasonicNTControlPort, password: projector.password, commands: ntCommands, timeout: timeout) {
            let ms = elapsedMs(since: start)
            return Result(
                ok: true,
                transport: "NTCONTROL:1024",
                exchange: PJLinkExchange(
                    projectorIP: projector.endpointLabel,
                    projectorTitle: projector.displayTitle,
                    tx: label,
                    rx: "\(reply) (NTCONTROL:1024)",
                    durationMs: ms,
                    isError: false
                )
            )
        }

        // 3. Fallback to Panasonic HTTP Web Control (/cgi-bin/proj_ctl.cgi on port 80)
        if let httpStatus = sendPanasonicHTTPCGI(ip: projector.ip, port: kPanasonicHTTPPort, password: projector.password, query: cgiQuery, steps: steps, timeout: timeout) {
            let ms = elapsedMs(since: start)
            let ok = (200..<400).contains(httpStatus)
            return Result(
                ok: ok,
                transport: "HTTP:80",
                exchange: PJLinkExchange(
                    projectorIP: projector.endpointLabel,
                    projectorTitle: projector.displayTitle,
                    tx: "GET /cgi-bin/proj_ctl.cgi?\(cgiQuery)",
                    rx: "HTTP \(httpStatus)",
                    durationMs: ms,
                    isError: !ok
                )
            )
        }

        let ms = elapsedMs(since: start)
        return Result(
            ok: false,
            transport: "NONE",
            exchange: PJLinkExchange(
                projectorIP: projector.endpointLabel,
                projectorTitle: projector.displayTitle,
                tx: label,
                rx: L("Ports Panasonic NTCONTROL :1024 / HTTP :80 injoignables", "Panasonic NTCONTROL :1024 / HTTP :80 unreachable"),
                durationMs: ms,
                isError: true
            )
        )
    }

    /// Connects to Panasonic NTCONTROL on TCP `:1024`, performs `NTCONTROL 0` or `NTCONTROL 1 <challenge>` MD5 auth (`admin1:<pwd>:<challenge>`), and sends `00...` commands.
    public static func sendPanasonicNTControl(
        ip: String,
        port: UInt16 = kPanasonicNTControlPort,
        username: String = "admin1",
        password: String = "",
        commands: [String],
        timeout: TimeInterval = 0.85
    ) -> String? {
        guard let fd = connectTCP(ip: ip, port: port, timeout: timeout) else { return nil }
        defer { Darwin.close(fd) }

        var authPrefix = ""
        if let greeting = readAvailable(fd: fd, timeoutMs: 250) {
            let trimmed = greeting.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.uppercased().hasPrefix("NTCONTROL 1") {
                let parts = trimmed.split(separator: " ")
                if parts.count >= 3 {
                    let challenge = String(parts[2])
                    let pwd = password.isEmpty ? "panasonic" : password
                    let token = "\(username):\(pwd):\(challenge)"
                    let digest = Insecure.MD5.hash(data: Data(token.utf8))
                    authPrefix = digest.map { String(format: "%02x", $0) }.joined()
                }
            }
        }

        var lastReply = "00OK"
        for (idx, cmd) in commands.enumerated() {
            let prefix = (idx == 0) ? authPrefix : ""
            let payload = prefix + (cmd.hasSuffix("\r") ? cmd : (cmd + "\r"))
            let bytes = Array(payload.utf8)
            let sent = bytes.withUnsafeBytes { ptr in
                Darwin.send(fd, ptr.baseAddress!, bytes.count, 0)
            }
            guard sent == bytes.count else { return nil }
            if let rx = readAvailable(fd: fd, timeoutMs: 180), !rx.isEmpty {
                let clean = rx.trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.uppercased().contains("ERR") {
                    return nil
                }
                if !clean.isEmpty {
                    lastReply = clean
                }
            }
        }
        return lastReply
    }

    private static func sendPanasonicHTTPCGI(
        ip: String,
        port: UInt16,
        password: String,
        query: String,
        steps: Int,
        timeout: TimeInterval
    ) -> Int? {
        var lastStatus: Int? = nil
        let pwd = password.isEmpty ? "panasonic" : password
        let token = Data("admin1:\(pwd)".utf8).base64EncodedString()
        for _ in 0..<max(1, min(10, steps)) {
            guard let fd = connectTCP(ip: ip, port: port, timeout: timeout) else { return lastStatus }
            defer { Darwin.close(fd) }

            let req =
                "GET /cgi-bin/proj_ctl.cgi?\(query) HTTP/1.1\r\n" +
                "Host: \(ip)\r\n" +
                "Authorization: Basic \(token)\r\n" +
                "Connection: close\r\n\r\n"

            let reqBytes = Array(req.utf8)
            let sent = reqBytes.withUnsafeBytes { ptr in
                Darwin.send(fd, ptr.baseAddress!, reqBytes.count, 0)
            }
            guard sent == reqBytes.count else { return lastStatus }

            if let response = readAvailable(fd: fd, timeoutMs: Int32(timeout * 1000)),
               let firstLine = response.split(whereSeparator: \.isNewline).first {
                let parts = firstLine.split(separator: " ")
                if parts.count >= 2, let code = Int(parts[1]) {
                    lastStatus = code
                }
            }
        }
        return lastStatus
    }

    // MARK: - Epson Pro L (EB-L1755U + ELPLU03/03S): ESC/VP.net (:3629) + HTTP /cgi-bin/directsend (:80)

    private static func sendEpson(
        escvpCommands: [String],
        directSendQuery: String,
        steps: Int = 1,
        label: String,
        projector: Projector,
        timeout: TimeInterval
    ) -> Result {
        let start = DispatchTime.now()

        // 1. Simulated projector on loopback
        if projector.isSimulated || (projector.ip == "127.0.0.1" && projector.port != kPJLinkDefaultPort) {
            if let reply = sendRS232OverTCP(ip: projector.ip, port: projector.port, commands: escvpCommands, expectPJLinkGreeting: true, timeout: timeout) {
                let ms = elapsedMs(since: start)
                return Result(
                    ok: true,
                    transport: "SIM:\(projector.port)",
                    exchange: PJLinkExchange(
                        projectorIP: projector.endpointLabel,
                        projectorTitle: projector.displayTitle,
                        tx: label,
                        rx: "\(reply) (SIM)",
                        durationMs: ms,
                        isError: false
                    )
                )
            }
        }

        // 2. Epson ESC/VP.net on TCP port 3629 (native EB-L1755U protocol)
        if let reply = sendEpsonESCVPNet(ip: projector.ip, port: kEpsonESCVPNetPort, password: projector.password, commands: escvpCommands, timeout: timeout) {
            let ms = elapsedMs(since: start)
            return Result(
                ok: true,
                transport: "ESC/VP.net:3629",
                exchange: PJLinkExchange(
                    projectorIP: projector.endpointLabel,
                    projectorTitle: projector.displayTitle,
                    tx: label,
                    rx: "\(reply) (ESC/VP.net:3629)",
                    durationMs: ms,
                    isError: false
                )
            )
        }

        // 3. Fallback to Epson HTTP Web Control (/cgi-bin/directsend on port 80)
        if let httpStatus = sendEpsonHTTPDirectSend(ip: projector.ip, port: kEpsonHTTPPort, password: projector.password, query: directSendQuery, steps: steps, timeout: timeout) {
            let ms = elapsedMs(since: start)
            let ok = (200..<400).contains(httpStatus)
            return Result(
                ok: ok,
                transport: "HTTP:80",
                exchange: PJLinkExchange(
                    projectorIP: projector.endpointLabel,
                    projectorTitle: projector.displayTitle,
                    tx: "GET /cgi-bin/directsend?\(directSendQuery)",
                    rx: "HTTP \(httpStatus)",
                    durationMs: ms,
                    isError: !ok
                )
            )
        }

        let ms = elapsedMs(since: start)
        return Result(
            ok: false,
            transport: "NONE",
            exchange: PJLinkExchange(
                projectorIP: projector.endpointLabel,
                projectorTitle: projector.displayTitle,
                tx: label,
                rx: L("Ports Epson ESC/VP.net :3629 / HTTP :80 injoignables", "Epson ESC/VP.net :3629 / HTTP :80 unreachable"),
                durationMs: ms,
                isError: true
            )
        )
    }

    /// Executes the 16-byte `ESC/VP.net` handshake on TCP `:3629` and sends ESC/VP21 commands (`LENS INC\r`, `FOCUS INC\r`, `POPPAT 01\r`…).
    public static func sendEpsonESCVPNet(
        ip: String,
        port: UInt16 = kEpsonESCVPNetPort,
        password: String = "",
        commands: [String],
        timeout: TimeInterval = 0.85
    ) -> String? {
        guard let fd = connectTCP(ip: ip, port: port, timeout: timeout) else { return nil }
        defer { Darwin.close(fd) }

        var handshake: [UInt8] = Array("ESC/VP.net".utf8) + [0x10, 0x03, 0x00, 0x00, 0x00, 0x00]
        if !password.isEmpty {
            handshake[15] = 0x01
            var pwdBytes = Array(password.utf8.prefix(16))
            while pwdBytes.count < 16 { pwdBytes.append(0x00) }
            handshake.append(contentsOf: [0x01, 0x10])
            handshake.append(contentsOf: pwdBytes)
        }

        let hsSent = handshake.withUnsafeBytes { ptr in
            Darwin.send(fd, ptr.baseAddress!, handshake.count, 0)
        }
        guard hsSent == handshake.count else { return nil }

        var hsReply = [UInt8](repeating: 0, count: 32)
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        if Darwin.poll(&pfd, 1, 250) > 0 {
            let n = Darwin.recv(fd, &hsReply, hsReply.count, 0)
            if n >= 16, hsReply[14] != 0x20 {
                return nil
            }
        }

        var lastReply = ":"
        for cmd in commands {
            let payload = cmd.hasSuffix("\r") ? cmd : (cmd + "\r")
            let bytes = Array(payload.utf8)
            let sent = bytes.withUnsafeBytes { ptr in
                Darwin.send(fd, ptr.baseAddress!, bytes.count, 0)
            }
            guard sent == bytes.count else { return nil }
            if let rx = readAvailable(fd: fd, timeoutMs: 180), !rx.isEmpty {
                let clean = rx.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    lastReply = clean
                }
            }
        }
        return lastReply
    }

    private static func sendEpsonHTTPDirectSend(
        ip: String,
        port: UInt16,
        password: String,
        query: String,
        steps: Int,
        timeout: TimeInterval
    ) -> Int? {
        var lastStatus: Int? = nil
        for _ in 0..<max(1, min(10, steps)) {
            guard let fd = connectTCP(ip: ip, port: port, timeout: timeout) else { return lastStatus }
            defer { Darwin.close(fd) }

            var authHeader = ""
            if !password.isEmpty {
                let token = Data("EPSONWEB:\(password)".utf8).base64EncodedString()
                authHeader = "Authorization: Basic \(token)\r\n"
            }

            let req =
                "GET /cgi-bin/directsend?\(query) HTTP/1.1\r\n" +
                "Host: \(ip)\r\n" +
                "Referer: http://\(ip)/cgi-bin/webconf\r\n" +
                authHeader +
                "Connection: close\r\n\r\n"

            let reqBytes = Array(req.utf8)
            let sent = reqBytes.withUnsafeBytes { ptr in
                Darwin.send(fd, ptr.baseAddress!, reqBytes.count, 0)
            }
            guard sent == reqBytes.count else { return lastStatus }

            if let response = readAvailable(fd: fd, timeoutMs: Int32(timeout * 1000)),
               let firstLine = response.split(whereSeparator: \.isNewline).first {
                let parts = firstLine.split(separator: " ")
                if parts.count >= 2, let code = Int(parts[1]) {
                    lastStatus = code
                }
            }
        }
        return lastStatus
    }

    // MARK: - Optoma Dual Transport (TCP :23 RS232-over-IP + HTTP :80 CGI Fallback)

    private static func sendOptoma(
        rs232Commands: [String],
        cgiPayload: String,
        label: String,
        projector: Projector,
        timeout: TimeInterval
    ) -> Result {
        let start = DispatchTime.now()

        if projector.isSimulated || (projector.ip == "127.0.0.1" && projector.port != kPJLinkDefaultPort) {
            if let reply = sendRS232OverTCP(ip: projector.ip, port: projector.port, commands: rs232Commands, expectPJLinkGreeting: true, timeout: timeout) {
                let ms = elapsedMs(since: start)
                return Result(
                    ok: true,
                    transport: "SIM:\(projector.port)",
                    exchange: PJLinkExchange(
                        projectorIP: projector.endpointLabel,
                        projectorTitle: projector.displayTitle,
                        tx: label,
                        rx: "\(reply) (SIM)",
                        durationMs: ms,
                        isError: false
                    )
                )
            }
        }

        if let reply = sendRS232OverTCP(ip: projector.ip, port: kOptomaTelnetPort, commands: rs232Commands, expectPJLinkGreeting: false, timeout: timeout) {
            let ms = elapsedMs(since: start)
            return Result(
                ok: true,
                transport: "TCP:23",
                exchange: PJLinkExchange(
                    projectorIP: projector.endpointLabel,
                    projectorTitle: projector.displayTitle,
                    tx: label,
                    rx: "\(reply) (TCP:23)",
                    durationMs: ms,
                    isError: false
                )
            )
        }

        if let httpStatus = sendHTTPCGI(ip: projector.ip, port: kOptomaHTTPPort, password: projector.password, formBody: cgiPayload, timeout: timeout) {
            let ms = elapsedMs(since: start)
            let ok = (200..<400).contains(httpStatus)
            return Result(
                ok: ok,
                transport: "HTTP:80",
                exchange: PJLinkExchange(
                    projectorIP: projector.endpointLabel,
                    projectorTitle: projector.displayTitle,
                    tx: "HTTP /tgi/control.tgi (\(cgiPayload.prefix(24)))",
                    rx: "HTTP \(httpStatus)",
                    durationMs: ms,
                    isError: !ok
                )
            )
        }

        let ms = elapsedMs(since: start)
        return Result(
            ok: false,
            transport: "NONE",
            exchange: PJLinkExchange(
                projectorIP: projector.endpointLabel,
                projectorTitle: projector.displayTitle,
                tx: label,
                rx: L("Ports Optoma TCP:23 / HTTP:80 injoignables", "Optoma TCP:23 / HTTP:80 unreachable"),
                durationMs: ms,
                isError: true
            )
        )
    }

    private static func sendRS232OverTCP(
        ip: String,
        port: UInt16,
        commands: [String],
        expectPJLinkGreeting: Bool,
        timeout: TimeInterval
    ) -> String? {
        guard let fd = connectTCP(ip: ip, port: port, timeout: timeout) else { return nil }
        defer { Darwin.close(fd) }

        if expectPJLinkGreeting {
            _ = readAvailable(fd: fd, timeoutMs: 120)
        }

        var lastReply = "OK"
        for cmd in commands {
            let payload = cmd.hasSuffix("\r") ? cmd : (cmd + "\r")
            let bytes = Array(payload.utf8)
            let sent = bytes.withUnsafeBytes { ptr in
                Darwin.send(fd, ptr.baseAddress!, bytes.count, 0)
            }
            guard sent == bytes.count else { return nil }
            if let rx = readAvailable(fd: fd, timeoutMs: 160), !rx.isEmpty {
                let clean = rx.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    lastReply = clean
                }
            }
        }
        return lastReply
    }

    private static func sendHTTPCGI(
        ip: String,
        port: UInt16,
        password: String,
        formBody: String,
        timeout: TimeInterval
    ) -> Int? {
        guard let fd = connectTCP(ip: ip, port: port, timeout: timeout) else { return nil }
        defer { Darwin.close(fd) }

        var authHeader = ""
        if !password.isEmpty {
            let token = Data("admin:\(password)".utf8).base64EncodedString()
            authHeader = "Authorization: Basic \(token)\r\n"
        }

        let bodyBytes = Array(formBody.utf8)
        let req =
            "POST /tgi/control.tgi HTTP/1.1\r\n" +
            "Host: \(ip)\r\n" +
            authHeader +
            "Content-Type: application/x-www-form-urlencoded\r\n" +
            "Content-Length: \(bodyBytes.count)\r\n" +
            "Connection: close\r\n\r\n" +
            formBody

        let reqBytes = Array(req.utf8)
        let sent = reqBytes.withUnsafeBytes { ptr in
            Darwin.send(fd, ptr.baseAddress!, reqBytes.count, 0)
        }
        guard sent == reqBytes.count else { return nil }

        guard let response = readAvailable(fd: fd, timeoutMs: Int32(timeout * 1000)),
              let firstLine = response.split(whereSeparator: \.isNewline).first else {
            return nil
        }
        let parts = firstLine.split(separator: " ")
        if parts.count >= 2, let code = Int(parts[1]) {
            return code
        }
        return nil
    }

    private static func connectTCP(ip: String, port: UInt16, timeout: TimeInterval) -> Int32? {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return nil }

        let fd = Darwin.socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return nil }

        var one: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, socklen_t(MemoryLayout<Int32>.size))

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if res < 0 && errno != EINPROGRESS {
            Darwin.close(fd)
            return nil
        }

        if res != 0 {
            var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
            let waitMs = Int32(max(100, min(3000, Int(timeout * 1000))))
            let ready = Darwin.poll(&pfd, 1, waitMs)
            if ready <= 0 {
                Darwin.close(fd)
                return nil
            }
            var soError: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &soError, &len)
            if soError != 0 {
                Darwin.close(fd)
                return nil
            }
        }

        _ = fcntl(fd, F_SETFL, flags)
        return fd
    }

    private static func readAvailable(fd: Int32, timeoutMs: Int32) -> String? {
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = Darwin.poll(&pfd, 1, timeoutMs)
        guard ready > 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: 512)
        let n = Darwin.recv(fd, &buf, buf.count, 0)
        guard n > 0 else { return nil }
        return String(decoding: buf[0..<n], as: UTF8.self)
    }

    private static func elapsedMs(since start: DispatchTime) -> Double {
        let nanos = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        return Double(nanos) / 1_000_000.0
    }
}
