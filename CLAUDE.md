# TokenEater

Widget macOS natif (WidgetKit + SwiftUI) affichant la consommation Claude.

## Architecture

- **ClaudeUsageApp/** — App hote macOS (settings : saisie sessionKey, test connexion)
- **ClaudeUsageWidget/** — Widget Extension (WidgetKit, refresh 15 min)
- **Shared/** — Code partage (fichier JSON dans le container du widget)

## API

Endpoint : `GET https://claude.ai/api/organizations/{org_id}/usage`
Auth : Cookie `sessionKey=sk-ant-sid01-...`

Reponse :
- `five_hour` : session (fenetre glissante 5h) — `utilization` (0-100), `resets_at` (ISO 8601)
- `seven_day` : hebdo tous modeles
- `seven_day_sonnet` : hebdo Sonnet

## Build

```bash
xcodegen generate
xcodebuild -project ClaudeUsageWidget.xcodeproj -scheme ClaudeUsageApp -configuration Debug -derivedDataPath build build
cp -R "build/Build/Products/Debug/TokenEater.app" /Applications/
```

Requiert Xcode.app + Homebrew (pour XcodeGen).

Note : apres chaque `xcodegen generate`, re-ajouter NSExtension dans `ClaudeUsageWidget/Info.plist`.

## Conventions

- Swift 5.9+, macOS 14+
- Zero dependance externe
- UI en francais
- Design sombre, accents orange (#F97316)
- Messages de commit en francais, concis
