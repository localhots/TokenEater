# TokenEater

Widget macOS natif affichant votre consommation Claude (session, hebdo, Sonnet) directement sur le bureau.

![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![WidgetKit](https://img.shields.io/badge/WidgetKit-native-blue)

## Fonctionnalites

- **Session (5h)** — Fenetre glissante, countdown avant reset
- **Hebdomadaire** — Tous modeles (Opus, Sonnet, Haiku)
- **Sonnet** — Limite dediee Sonnet
- **Refresh automatique** toutes les 15 min
- **Deux tailles** : medium (anneaux circulaires) et large (barres de progression)
- **Indicateur hors-ligne** avec fallback sur cache

## Installation

### Pre-requis

- macOS 14 (Sonoma) ou plus
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build

```bash
# Generer le projet Xcode
xcodegen generate

# IMPORTANT : re-ajouter NSExtension dans ClaudeUsageWidget/Info.plist
# (XcodeGen le supprime a chaque regeneration)

# Build
xcodebuild -project ClaudeUsageWidget.xcodeproj \
  -scheme ClaudeUsageApp \
  -configuration Debug \
  -derivedDataPath build build

# Installer
cp -R "build/Build/Products/Debug/TokenEater.app" /Applications/
killall NotificationCenter
open "/Applications/TokenEater.app"
```

### Configuration

1. Ouvrir **claude.ai** dans Chrome et se connecter
2. DevTools (`Cmd + Option + I`) > **Application** > **Cookies** > **claude.ai**
3. Copier le cookie **sessionKey** (`sk-ant-sid01-...`)
4. Copier le cookie **lastActiveOrg** (Organization ID)
5. Coller les deux dans l'app TokenEater
6. Ajouter le widget : clic droit bureau > **Modifier les widgets** > chercher "TokenEater"

### Partager a un collegue

```bash
# Zipper l'app
cd /Applications
zip -r ~/Desktop/TokenEater.zip "TokenEater.app"
```

Le collegue doit :
1. Dezipper `TokenEater.app` dans `/Applications`
2. Clic droit > **Ouvrir** (bypass Gatekeeper la premiere fois)
3. Configurer ses cookies dans l'app

## Architecture

```
ClaudeUsageApp/       # App hote (settings, pas dans le Dock)
ClaudeUsageWidget/    # Widget Extension (WidgetKit)
Shared/               # Code partage (modeles, API client, extensions)
project.yml           # Config XcodeGen
```

L'app hote ecrit la config dans le container sandbox du widget. Le widget lit depuis son propre container. Pas besoin d'App Groups.

## API

Endpoint : `GET https://claude.ai/api/organizations/{org_id}/usage`

Auth via cookie `sessionKey`. Les cookies expirent environ chaque mois.
