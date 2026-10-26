import Foundation

public let simplePJToolDefinitions: [[String: Any]] = [
    [
        "name": "simplepj_state",
        "description": "Returns the current state of SimplePJ: projector count, onlineCount, projectingCount, shutterClosedCount, standbyCount, alertCount, active groups (#tags), scanRange, isScanning, isDemoRigActive, oscInPort, apiPort, version.",
        "inputSchema": ["type": "object", "properties": [:] as [String: Any]],
    ],
    [
        "name": "simplepj_projectors",
        "description": "Returns the complete JSON fleet of PJLink projectors (id, ip, port, mac, label, tags, manufacturer, modelName, pjlinkClass, serialNumber, power, shutter, freeze, currentInput, availableInputs, inputResolution, lamps, filterHours, errors, latencyMs).",
        "inputSchema": ["type": "object", "properties": [:] as [String: Any]],
    ],
    [
        "name": "simplepj_help",
        "description": "Returns the full HTTP API, MCP tool reference, OSC address map, and AppleScript commands.",
        "inputSchema": ["type": "object", "properties": [:] as [String: Any]],
    ],
    [
        "name": "simplepj_shutter",
        "description": "Opens or closes the optical shutter / AV Mute (AVMT 31/30, video-only 11/10, audio-only 21/20) on all projectors ('all'), a #tag group ('#face', '#cyclo'), or a specific projector (1-based index, IP, or name).",
        "inputSchema": [
            "type": "object",
            "properties": [
                "target": ["type": "string", "description": "'all' (default), a group tag like '#face', a 1-based index ('1'), an IP ('10.0.0.2'), or a projector name"],
                "closed": ["type": "boolean", "description": "true to close shutter / blackout (AVMT 31), false to open shutter (AVMT 30)"],
                "mode": ["type": "string", "enum": ["all", "video", "audio"], "description": "Optional mute channel: 'all' (default AVMT 31/30), 'video' (11/10), or 'audio' (21/20)"],
            ],
            "required": ["closed"],
        ],
    ],
    [
        "name": "simplepj_power",
        "description": "Powers on (POWR 1) or puts into standby (POWR 0) all projectors ('all'), a #tag group ('#face'), or a specific projector.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "target": ["type": "string", "description": "'all' (default), '#tag', 1-based index, IP, or name"],
                "on": ["type": "boolean", "description": "true to power on (POWR 1), false for standby (POWR 0)"],
            ],
            "required": ["on"],
        ],
    ],
    [
        "name": "simplepj_input",
        "description": "Switches the video input (INPT) on 'all', a '#tag' group, or a specific projector. Accepts a PJLink 2-digit code ('31', '52') or an input name ('HDMI 1', 'HDBaseT', 'SDI').",
        "inputSchema": [
            "type": "object",
            "properties": [
                "target": ["type": "string", "description": "'all' (default), '#tag', 1-based index, IP, or name"],
                "code": ["type": "string", "description": "PJLink input code ('31', '32', '52') or label ('HDMI 1', 'HDBaseT')"],
            ],
            "required": ["code"],
        ],
    ],
    [
        "name": "simplepj_freeze",
        "description": "Freezes or unfreezes the projected image (PJLink Class 2 %2FREZ 1/0) on 'all', a '#tag' group, or a specific projector.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "target": ["type": "string", "description": "'all' (default), '#tag', 1-based index, IP, or name"],
                "freeze": ["type": "boolean", "description": "true to freeze image, false to unfreeze"],
            ],
            "required": ["freeze"],
        ],
    ],
    [
        "name": "simplepj_pattern",
        "description": "Displays or hides the internal test pattern / alignment grid on Optoma ProScene (ZU920ST) via TCP :23 (~00195) / HTTP :80 and Epson Pro L (EB-L1755U) via ESC/VP.net :3629 (POPPAT / KEY 90) / HTTP /cgi-bin/directsend.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "target": ["type": "string", "description": "'all', '#tag', 1-based index, IP, or projector name"],
                "pattern": ["type": "string", "enum": ["off", "white-grid", "green-grid", "magenta-grid", "white", "black", "bars"], "description": "Test pattern to display ('white-grid' for alignment grid, 'off' to hide)"],
            ],
            "required": ["pattern"],
        ],
    ],
    [
        "name": "simplepj_lens",
        "description": "Controls the motorized optical block (Lens Shift Up/Down/Left/Right, Focus +/-, Zoom +/-, Distortion +/- for ELPLU03/03S, Center, Unlock/Lock) on Optoma ProScene (ZU920ST) and Epson Pro L (EB-L1755U + ELPLU03/ELPLU03S).",
        "inputSchema": [
            "type": "object",
            "properties": [
                "target": ["type": "string", "description": "'all', '#tag', 1-based index, IP, or projector name"],
                "action": ["type": "string", "enum": ["up", "down", "left", "right", "focus+", "focus-", "zoom+", "zoom-", "distortion+", "distortion-", "center", "unlock", "lock"], "description": "Motorized lens action"],
                "steps": ["type": "integer", "description": "Number of motor step impulses (1 to 10, default 1)"],
            ],
            "required": ["action"],
        ],
    ],
    [
        "name": "simplepj_discover",
        "description": "Scans a CIDR/IP range for PJLink projectors on TCP/UDP 4352, toggles the 4-projector simulated stage rig, or imports saved projectors from SIGMASIX ProjectorManager.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "range": ["type": "string", "description": "Optional CIDR or IP range to scan (e.g. '10.0.0.0/24')"],
                "simulate": ["type": "boolean", "description": "When true, toggles the 4-projector loopback Class 2 stage simulator"],
                "importProjectorManager": ["type": "boolean", "description": "When true, imports saved projectors from ch.sigmasix.ProjectorManager preferences"],
            ],
        ],
    ],
    [
        "name": "simplepj_add_projector",
        "description": "Adds or updates a projector in the fleet (IP, port, stage label with optional #tags, password, notes).",
        "inputSchema": [
            "type": "object",
            "properties": [
                "ip": ["type": "string", "description": "IPv4 address of the projector"],
                "port": ["type": "integer", "description": "TCP port (default 4352)"],
                "label": ["type": "string", "description": "Stage name and optional #tags, e.g. 'Face Cour #face #cour'"],
                "password": ["type": "string", "description": "Optional PJLink password"],
                "notes": ["type": "string", "description": "Optional stage notes (lens, rigging, circuit)"],
            ],
            "required": ["ip"],
        ],
    ],
    [
        "name": "simplepj_command",
        "description": "Sends a raw PJLink command (e.g. '%1LAMP ?', '%2SNUM ?', '%1AVMT 31') or refreshes the fleet.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "target": ["type": "string", "description": "Projector index ('1'), IP, or name (or 'all' for refresh)"],
                "raw": ["type": "string", "description": "Raw PJLink command body, e.g. '%1LAMP ?'"],
                "refresh": ["type": "boolean", "description": "When true, polls all projectors"],
            ],
        ],
    ],
    [
        "name": "simplepj_snapshot",
        "description": "Captures the SimplePJ window as a PNG image ('cards' or 'table' view).",
        "inputSchema": [
            "type": "object",
            "properties": [
                "view": ["type": "string", "enum": ["cards", "table"], "description": "Optional view mode ('cards' or 'table')"],
            ],
        ],
    ],
]
