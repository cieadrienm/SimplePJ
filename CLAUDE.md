# Instructions Agent — SimplePJ

## Lire d'abord
- `~/Programmation/SimpleFamily/GUIDELINES.md` — les règles communes de la famille Simple (G1…).
- `DECISIONS.md` — D1…, le pourquoi de chaque choix. **Ajouter une entrée pour tout choix structurant.**
- `README.md` — fonctionnalités, ligne de commande, limites.

## Identité & Crédits
- Compagnie : **cie Adrien M** (ou **Compagnie Adrien M**), Adrien Mondot.
- Identifiant de bundle : `net.cieadrienm.simplepj`.
- Famille : SimpleAudio, SimpleScanner, SimpleMIDIPlayer, SimpleText, SimpleRecorder (même palette sombre, mêmes composants, mêmes scripts).
- Ports réseau dédiés :
  - PJLink TCP / UDP cible : `:4352` (standard JBMIA PJLink Classe 1 & Classe 2)
  - Entrée OSC UDP : `:9130` (`SIMPLEPJ_OSC_IN_PORT`, retour `:9131`)
  - API HTTP locale (`/v1`) : `127.0.0.1:17930` (`SIMPLEPJ_API_PORT`)

## Architecture
- `Sources/SimplePJCore` : Cœur pur sans dépendance UI (`Foundation`, `CryptoKit`, `Darwin`).
  - `PJLinkProtocol.swift` : Encodeur/décodeur PJLink Classe 1 (`%1`) & Classe 2 (`%2`), authentification par défi MD5 (`PJLINK 1 <random>` via `CryptoKit.Insecure.MD5`), états typés (`POWR`, `AVMT`, `INPT`, `INST`, `ERST`, `LAMP`, `NAME`, `INF1`, `INF2`, `INFO`, `CLSS`, `SNUM`, `SVER`, `INNM`, `IRES`, `RRES`, `FILT`, `RLMP`, `RFIL`, `FREZ`, `SVOL`, `MVOL`) et dictionnaire des mots de passe d'usine courants.
  - `PJLinkClient.swift` : Client TCP non-bloquant sur sockets BSD (`poll()`, `TCP_NODELAY`, `SO_NOSIGPIPE`), reconnexion transparente pour les projecteurs qui ferment la connexion après une commande, mesure de latence à la milliseconde et déverrouillage automatique (`probeCommonPasswords`).
  - `PJLinkDiscovery.swift` : Découverte parallèle sur port TCP `:4352` par lots de 64 sockets non-bloquants (~1,5 s par `/24`) + diffusion UDP `%2SRCH\r` (Classe 2) + lecture de la table ARP (`arp -an`) pour associer l'adresse MAC + `WakeOnLAN`.
  - `PJLinkSimulator.swift` : Serveur TCP PJLink Classe 2 embarqué (`PJLinkSimulatedServer` & `PJLinkDemoRig`) simulant jusqu'à 4 projecteurs de plateau sur `127.0.0.1` (avec préchauffage, refroidissement, volets, entrées nommées et authentification MD5).
  - `PJLinkFleetFile.swift` : Format de fichier `.simplepj` (JSON) et export de fiche technique plateau (`.txt`, `.csv`, `.json`, `ip:port`).
  - `OptomaClient.swift` : Pilotage réseau des mires internes (grilles de calage) et des optiques motorisées (Lens Shift H/V, Focus, Zoom, Distorsion ELPLU03/03S, Centrage, Lens Lock) pour **Panasonic PT-RZ/RQ/MZ** (`NTCONTROL :1024` + HTTP `/cgi-bin/proj_ctl.cgi`), **Epson EB-L1755U / Pro L** (`ESC/VP.net :3629` + HTTP `/cgi-bin/directsend`) et **Optoma ZU920ST / ProScene** (`TCP :23` + HTTP `/tgi/control.tgi`).
  - `Localization.swift` : Localisation bilingue dynamique Français / English (`L(fr, en)`).
  - `SimpleUpdater.swift` : Système de mise à jour automatique zéro-dépendance (GitHub Releases + manifeste JSON + vérification SHA-256 et `codesign`).
  - `OSCAndHTTP.swift` : Encodeur/décodeur OSC 1.0 et serveur UDP `:9130`.
- `Sources/SimplePJ` : Interface macOS native SwiftUI + AppKit (`Theme`, `Components`, `FleetController`, `AppModel`, vue Plateau par cartes tactiles `CardsGridView`, vue Liste triable `ProjectorTableView`, barre maîtresse de plateau `StageMasterBar`, inspecteur complet `InspectorView`, tiroir de console protocole `ConsoleDrawer`, `SyntheticFleet`, `Snapshot`, `SelfTest`, `HeadlessCLI`).

## Vérification
- Toujours valider par :
  - `swift test`
  - `.build/debug/SimplePJ --self-test`
  - `.build/debug/SimplePJ --snapshot /tmp/simplepj.png` (et `--view table`, `--view about`, `--view osc`)
- Pour générer l'icône et installer `/Applications/SimplePJ.app` :
  - `chmod +x Scripts/bundle.sh && Scripts/bundle.sh release`
