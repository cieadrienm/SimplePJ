# SimplePJ

Contrôleur de vidéoprojecteurs **PJLink (Classe 1 & Classe 2)** natif, ultra-léger (~2,5 Mo, zéro dépendance) et pensé pour le plateau sur macOS, dans la lignée de **SimpleAudio**, **SimpleScanner**, **SimpleMIDIPlayer** et **SimpleRecorder** (**cie Adrien M**).

## Fonctionnalités

- **PJLink Classe 1 & Classe 2 complet (TCP/UDP `:4352`)** :
  - **Volet / Obturateur (`AVMT`)** : Noir plateau vidéo + audio (`31`), ouverture (`30`), coupe vidéo seule (`11`/`10`) ou audio seul (`21`/`20`).
  - **Alimentation (`POWR`)** : Allumage (`1`), mise en veille (`0`) avec sécurité anti-extinction accidentelle en spectacle (contournable avec `⌥`), suivi temps réel du préchauffage (`3`) et du refroidissement (`2`).
  - **Entrées vidéo intelligentes (`INPT`, `INST`, `INNM`)** : détection automatique de la liste des entrées disponibles sur chaque projecteur et lecture des noms réels des connecteurs en Classe 2 (*HDMI 1*, *12G-SDI*, *DIGITAL LINK*, *HDBaseT*…).
  - **Gel d'image (`FREZ`) & Résolutions (`IRES` / `RRES`)** : gel d'image instantané et affichage de la résolution du signal entrant face à la matrice native.
  - **Santé & Maintenance (`ERST`, `LAMP`, `FILT`, `SNUM`, `SVER`, `RLMP`, `RFIL`)** : surveillance des 6 capteurs matériels (*Ventilateur*, *Lampe/Laser*, *Température*, *Capot*, *Filtre*, *Autre*), heures de chaque source lumineuse et du filtre, numéro de série, firmware et références de consommables.
- **Découverte éclair & Déverrouillage malin** :
  - Scan parallèle du port TCP `4352` sur tout un `/24` en ~1,5 s + broadcast UDP `%2SRCH` (Classe 2) + association automatique de l'adresse MAC depuis la table ARP (pour le **Wake-on-LAN** et le suivi DHCP).
  - **Déverrouillage automatique** : sur un projecteur protégé par `PJLINK 1` (`ERRA`), teste en un clic les mots de passe d'usine courants (*panasonic*, *admin*, *pjlink*, *JBMIA*, *0000*, *1234*, *EPSONWEB*…).
- **Pensé pour le plateau : Groupes `#tags`, Barre Maîtresse & Simulateur** :
  - **Groupes par `#tags`** : nommez un projecteur `Face Cour #face #cour` ou `Cyclo Haut #cyclo` pour créer instantanément des groupes filtrables et pilotables d'un clic droit ou en OSC.
  - **Barre Maîtresse de plateau** : déclenchez un **Noir plateau (`⌘B`)**, l'ouverture des volets (`⇧⌘B`), le gel d'image ou un changement d'entrée synchronisé sur tout le parc, un groupe ou une sélection multiple.
  - **Simulateur de plateau intégré (4 VP)** : lance en un clic 4 vrais serveurs TCP PJLink Classe 2 sur `127.0.0.1` (*Panasonic PT-RZ990*, *Epson EB-PU2010B*, *Barco UDX-4K32*) pour préparer et tester une conduite hors plateau.
- **Pilotage externe OSC, HTTP & Ligne de commande** :
  - **OSC UDP sur `:9130`** (`SIMPLEPJ_OSC_IN_PORT`) : `/simplepj/all/shutter 1`, `/simplepj/group/face/shutter 0`, `/simplepj/pj/1/input 31`, `/simplepj/pj/face-cour/power 1`…
  - **API HTTP JSON sur `127.0.0.1:17930/v1`** (`SIMPLEPJ_API_PORT`).
  - **CLI intégrée** : `--discover`, `--cmd`, `--self-test`, `--snapshot`, `--version`.

## Compilation & Installation

```bash
# Générer l'icône et assembler /Applications/SimplePJ.app
chmod +x Scripts/bundle.sh
Scripts/bundle.sh release

# Suite de tests unitaires et d'intégration
swift test

# Auto-test de bout en bout (serveurs PJLink TCP loopback) et capture PNG hors écran
.build/debug/SimplePJ --self-test
.build/debug/SimplePJ --snapshot /tmp/simplepj.png
```

## Ligne de commande

```bash
# Découvrir les projecteurs PJLink du réseau local
/Applications/SimplePJ.app/Contents/MacOS/SimplePJ --discover 192.168.1.0/24 --format txt

# Fermer ou ouvrir le volet d'un projecteur ou d'une plage
/Applications/SimplePJ.app/Contents/MacOS/SimplePJ --cmd 192.168.1.21 shutter-close
/Applications/SimplePJ.app/Contents/MacOS/SimplePJ --cmd 192.168.1.21:192.168.1.24 shutter-open
/Applications/SimplePJ.app/Contents/MacOS/SimplePJ --cmd 192.168.1.21 status --password panasonic
```

## Crédits & Licence

**Adrien Mondot · cie Adrien M** (Compagnie Adrien M) — Bundle ID : `net.cieadrienm.simplepj`.
Distribué sous licence publique générale GNU (GPL v3+). Voir [`LICENSE`](LICENSE).
