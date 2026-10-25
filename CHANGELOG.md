# Changelog — SimplePJ

## [1.0.0] — 2026-10-25
- Première version de **SimplePJ** (**cie Adrien M**).
- Protocole **PJLink Classe 1 & Classe 2** complet (TCP & UDP `:4352`) avec authentification MD5 (`PJLINK 1`), reconnexion transparente et déverrouillage automatique des mots de passe d'usine courants.
- Découverte réseau ultra-rapide par scan TCP `:4352` parallèle, broadcast UDP `%2SRCH` et résolution MAC via table ARP + Wake-on-LAN.
- Interface macOS native sombre : vue **Plateau** (cartes tactiles avec faisceau optique, volet, alimentation, gel, entrées nommées `INNM`, signal `IRES`, heures lampe/filtre et diagnostic 6 capteurs `ERST`), vue **Liste** triable, **Barre maîtresse de plateau**, groupes par `#tags`, inspecteur détaillé et console protocole en direct.
- Simulateur de plateau intégré (4 vidéoprojecteurs PJLink Classe 2 sur `127.0.0.1`).
- Pilotage externe **OSC UDP** (`:9130`), **API HTTP JSON** (`127.0.0.1:17930/v1`) et ligne de commande (`--discover`, `--cmd`, `--self-test`, `--snapshot`).
