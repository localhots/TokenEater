# Claude Usage Widget — Setup

Widget macOS natif pour afficher la consommation Claude (session, hebdo tous modeles, hebdo Sonnet).

## Prerequis

1. **macOS 14 (Sonoma)** ou plus recent
2. **Xcode.app** installe depuis le Mac App Store (gratuit)
3. **Homebrew** (pour XcodeGen)

### Installer Xcode

```bash
# Depuis le Mac App Store ou :
xcode-select --install  # CommandLineTools seulement — PAS suffisant pour WidgetKit

# Apres installation de Xcode.app :
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Build

```bash
cd ClaudeUsageWidget
./build.sh
```

Le script :
1. Verifie que Xcode.app est installe
2. Installe XcodeGen si besoin (via Homebrew)
3. Genere le `.xcodeproj` depuis `project.yml`
4. Build l'app en Release
5. Affiche le chemin de l'app buildee

### Installation

```bash
cp -R "build/.../Claude Usage.app" /Applications/
open "/Applications/Claude Usage.app"
```

## Configuration

1. Lancez **Claude Usage.app**
2. Collez votre **Session Key** :
   - Ouvrez [claude.ai](https://claude.ai) dans Chrome
   - DevTools (`Cmd + Option + I`) > **Application** > **Cookies** > **claude.ai**
   - Copiez la valeur de `sessionKey` (commence par `sk-ant-sid01-`)
3. Cliquez **Tester la connexion**
   - L'Organization ID est auto-detecte
   - Si ca echoue, entrez-le manuellement (visible dans l'URL claude.ai : `/organizations/VOTRE-UUID/...`)
4. Ajoutez le widget : **clic droit sur le bureau** > **Modifier les widgets** > cherchez "Claude Usage"

## Structure

```
ClaudeUsageWidget/
├── project.yml                  # Config XcodeGen
├── build.sh                     # Script de build
├── ClaudeUsageApp/              # App hote (settings)
│   ├── ClaudeUsageApp.swift
│   ├── SettingsView.swift
│   └── ClaudeUsageApp.entitlements
├── ClaudeUsageWidget/           # Widget Extension
│   ├── ClaudeUsageWidget.swift  # Widget entry point
│   ├── Provider.swift           # TimelineProvider (fetch 15 min)
│   ├── UsageEntry.swift         # TimelineEntry
│   ├── UsageWidgetView.swift    # Vue SwiftUI
│   ├── Info.plist
│   └── ClaudeUsageWidget.entitlements
└── Shared/                      # Code partage (App Group)
    ├── ClaudeAPIClient.swift    # Client HTTP claude.ai
    └── UsageModels.swift        # Modeles de donnees
```

## API claude.ai

- **Endpoint** : `GET https://claude.ai/api/organizations/{org_id}/usage`
- **Auth** : Cookie `sessionKey`
- **Reponse** :
  - `five_hour.utilization` — Session (fenetre glissante 5h)
  - `seven_day.utilization` — Hebdo tous modeles
  - `seven_day_sonnet.utilization` — Hebdo Sonnet seulement

Le cookie expire environ chaque mois. Mettez-le a jour dans l'app si le widget affiche une erreur.

## Troubleshooting

| Probleme | Solution |
|----------|----------|
| Widget affiche "Session expiree" | Mettez a jour le sessionKey dans l'app |
| Widget affiche "Ouvrez l'app" | Lancez l'app et configurez le sessionKey |
| Build echoue | Verifiez que `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` pointe vers Xcode.app |
| Widget non visible | Deconnectez/reconnectez votre session ou redemarrez |
