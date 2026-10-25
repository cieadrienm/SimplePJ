# Décisions d'Architecture — SimplePJ

## 1. Zéro dépendance externe & Sockets BSD non-bloquants (~2,5 Mo)
- **Contexte** : En régie plateau, un utilitaire PJLink doit s'ouvrir instantanément, envoyer un ordre de volet (Noir plateau) sur 6 vidéoprojecteurs en quelques millisecondes et ne dépendre d'aucun runtime lourd.
- **Décision** : Paquet SwiftPM pur (`macOS 15`, outils 6.0, mode Swift 5), utilisant `CryptoKit` pour le défi MD5 PJLink (`PJLINK 1 <random>`) et des sockets BSD `Darwin` non-bloquants (`poll()`, `TCP_NODELAY`, `SO_NOSIGPIPE`).

## 2. Gestion transparente des projecteurs mono-commande par connexion TCP
- **Contexte** : Selon les marques (Panasonic, Epson, Barco, Sony, Christie), certains vidéoprojecteurs acceptent plusieurs commandes PJLink sur la même session TCP, tandis que d'autres ferment la socket dès la première réponse envoyée.
- **Décision** : `PJLinkClient.executeBatch` réutilise la connexion ouverte tant qu'elle répond et rouvre automatiquement une session authentifiée dès que le projecteur clôt la socket, ce qui garantit à la fois la vitesse maximale et une compatibilité universelle.

## 3. Séparation nette Volet (Noir plateau) vs Alimentation (Lampe/Laser)
- **Contexte** : L'erreur classique en régie consiste à éteindre un projecteur (`POWR 0`) au lieu de fermer son volet optique (`AVMT 31`), provoquant plusieurs minutes de refroidissement puis de préchauffage.
- **Décision** : Le bouton **VOLET FERMÉ · NOIR** (`⌘B`) et **OUVRIR VOLET** (`⇧⌘B`) occupe la place centrale sur chaque carte, dans la barre maîtresse de plateau et dans l'inspecteur. La mise en veille (`POWR 0`) affiche une feuille de confirmation explicite rappelant l'existence du volet (sauf si l'opérateur maintient `⌥` Option).

## 4. Groupes par `#tags` et Cible dynamique
- **Contexte** : Sur un plateau (face cour/jardin, cyclo haut/bas, tulle, sol), on pilote rarement les projecteurs un par un ou tous ensemble seulement.
- **Décision** : Tout `#tag` écrit dans le nom d'un projecteur (`Face Cour #face #cour`) crée automatiquement un groupe dans la barre latérale et une route OSC dédiée (`/simplepj/group/face/shutter 1`). La barre maîtresse de plateau agit dynamiquement sur la sélection, le groupe actif ou tout le parc.

## 5. Simulateur PJLink Classe 2 intégré (`PJLinkDemoRig`)
- **Contexte** : Préparer une conduite OSC (`OSCScore`, `Montage`, `eMotion`) au bureau sans vidéoprojecteurs physiques nécessite de vrais serveurs TCP PJLink.
- **Décision** : `SimplePJCore` embarque `PJLinkSimulatedServer`, un serveur TCP PJLink Classe 2 complet sur `127.0.0.1` accessible en un clic (« Simuler un plateau (4 VP) ») ainsi que dans `--self-test`.
