# Drop Cookie System — Design v2

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

## Goal

Supprimer le systeme d'auth par cookies navigateur. Garder uniquement OAuth Claude Code (Keychain). Sandboxer l'app. Supprimer tout partage fichier entre app et widget.

## Contexte

Feedback communaute Reddit sur la v1.x :
- Credentials stockees en JSON plaintext → demande Keychain
- App non sandboxee → demande sandbox
- Pas de notarization → pas faisable sans Apple Developer Program ($100/an)
- KeychainOAuthReader pas documente → deja corrige dans README

## Contraintes

- **Pas d'Apple Developer Program** → pas d'App Group, pas de notarization
- **Keychain ACL verifiee** : l'item "Claude Code-credentials" autorise deja TokenEater.app ET ClaudeUsageWidgetExtension.appex (confirme via `security dump-keychain`)
- **Apres un nouveau build** : macOS affiche un prompt "TokenEater wants to access..." → user clique "Always Allow" → fonctionne pour toujours jusqu'au prochain build

## Architecture cible

```
App hote (SANDBOXEE — nouveau)
  ├─ Keychain → "Claude Code-credentials" → OAuth token
  ├─ URLSession (+ proxy SOCKS5 optionnel via Settings)
  ├─ Menu bar popover (metriques, refresh)
  ├─ Settings (proxy, display, notifications)
  └─ Cache local dans son propre container sandbox

Widget Extension (sandboxee — deja le cas)
  ├─ Keychain → "Claude Code-credentials" → OAuth token
  ├─ URLSession (+ proxy SOCKS5 optionnel via AppIntentConfiguration)
  └─ Cache local dans son propre container sandbox

Zero partage fichier entre app et widget.
Zero JSON plaintext de credentials.
Zero App Group.
Zero Apple Developer Program requis.
```

## Decisions de design

### 1. Keychain pur — pas de SharedStorage

L'app et le widget lisent **tous les deux** directement le Keychain via `KeychainOAuthReader`. Plus besoin de `SharedStorage`, `SharedConfig`, ni de fichier JSON partage.

Justification :
- ACL Keychain deja configuree pour les deux binaires
- Elimine tout stockage plaintext
- Permet le sandboxing complet (plus besoin d'ecrire dans le container de l'autre)

Risque : apres un nouveau build, le widget perd l'acces Keychain jusqu'au prompt utilisateur. Mitigation : le widget affiche les donnees en cache si Keychain echoue.

### 2. Sandbox de l'app hote

Ajout de `com.apple.security.app-sandbox` + `com.apple.security.network.client` dans les entitlements de l'app. C'est possible parce que :
- On supprime les cookies → plus besoin de lire les fichiers navigateur
- On supprime SharedStorage → plus besoin d'ecrire dans le container du widget
- Le Keychain est accessible depuis une app sandboxee (avec prompt utilisateur)

### 3. Proxy widget via AppIntentConfiguration

Le widget ne peut plus lire la config proxy de l'app (pas de partage fichier). Solution : le widget a ses propres parametres proxy via `AppIntentConfiguration` (ecran "Edit Widget" du systeme).

C'est le mecanisme officiel Apple pour configurer les widgets. 100% securise, stocke dans le container sandboxe du widget par le systeme.

L'app garde ses propres settings proxy dans son container sandbox (UserDefaults ou fichier local).

### 4. Cache independant

Chaque cible (app et widget) maintient son propre cache de donnees dans son container sandbox. Plus de `SharedStorage.writeCache(fromHost:)`.

## Ce qui est supprime

| Element | Fichier(s) | Lignes |
|---------|-----------|--------|
| `BrowserCookieReader` | `ClaudeUsageApp/BrowserCookieReader.swift` | ~343 |
| `SharedStorage` | `Shared/UsageModels.swift` | ~50 |
| `SharedConfig.sessionKey/organizationID` | `Shared/UsageModels.swift` | ~10 |
| `AuthMethod.cookies` | `Shared/ClaudeAPIClient.swift` | ~60 |
| UI cookies (champs manuels, browser picker, import) | `ClaudeUsageApp/SettingsView.swift` | ~200 |
| ~35 cles localization mortes | `Shared/{en,fr}.lproj/Localizable.strings` | ~35 |
| Guide methods 2 et 3 | `ClaudeUsageApp/SettingsView.swift` | ~60 |

Total estime : **~750 lignes supprimees**

## Ce qui est ajoute/modifie

| Element | Fichier(s) | Detail |
|---------|-----------|--------|
| Sandbox entitlement app | `ClaudeUsageApp/ClaudeUsageApp.entitlements` | `app-sandbox` + `network.client` |
| `ClaudeAPIClient` OAuth only | `Shared/ClaudeAPIClient.swift` | Suppression dual-auth, simplification |
| Proxy local app | `Shared/UsageModels.swift` ou UserDefaults | Config proxy locale a l'app |
| Widget AppIntentConfiguration | `ClaudeUsageWidget/` | Parametres proxy dans "Edit Widget" |
| Nouvelles cles i18n | `Shared/{en,fr}.lproj/Localizable.strings` | `error.notoken`, `error.tokenexpired`, `connect.noclaudecode` |
| Cache local par cible | `Shared/ClaudeAPIClient.swift` | Chaque cible cache dans son propre container |

## Flow utilisateur

1. User installe Claude Code + fait `/login`
2. User installe TokenEater (Homebrew Cask ou build from source)
3. Premier lancement → macOS prompt "TokenEater veut acceder a 'Claude Code-credentials'" → "Always Allow"
4. Clic "Connect" → detecte le token OAuth → affiche "Claude Code (auto)"
5. Widget se refresh → meme prompt Keychain → "Always Allow"
6. Tout fonctionne, zero maintenance (OAuth se refresh auto par Claude Code)

## Reponse aux points Reddit

| Critique Reddit | Solution v2.0.0 |
|---|---|
| Credentials plaintext JSON | Keychain uniquement, zero fichier JSON |
| App non sandboxee | Sandboxee (`app-sandbox` + `network.client`) |
| Pas de notarization | Non resolvable sans $100/an — sandbox ameliore la confiance |
| KeychainOAuthReader pas documente | Deja ajoute dans le README |

## Point de decision critique

**Sandbox + Keychain au build :** Si l'app sandboxee ne peut pas lire le Keychain "Claude Code-credentials", fallback : retirer `com.apple.security.app-sandbox` des entitlements. On perd le sandbox mais on garde tous les autres benefices (suppression cookies, simplification, zero plaintext). A tester empiriquement.

## Resume des fichiers

| Action | Fichier | Raison |
|--------|---------|--------|
| **DELETE** | `ClaudeUsageApp/BrowserCookieReader.swift` | 343 lignes de crypto/SQLite mortes |
| **REWRITE** | `Shared/ClaudeAPIClient.swift` | OAuth only, plus de dual-auth |
| **REWRITE** | `Shared/UsageModels.swift` | Suppression SharedStorage/SharedConfig, cache local |
| **MODIFY** | `ClaudeUsageApp/SettingsView.swift` | Retrait UI cookies, simplification |
| **MODIFY** | `ClaudeUsageApp/MenuBarView.swift` | `isConfigured` au lieu de `resolveAuthMethod()` |
| **MODIFY** | `ClaudeUsageWidget/Provider.swift` | `isConfigured`, AppIntentConfiguration |
| **MODIFY** | `ClaudeUsageApp/ClaudeUsageApp.entitlements` | Sandbox + network.client |
| **MODIFY** | `Shared/en.lproj/Localizable.strings` | Nettoyage cles mortes + nouvelles cles |
| **MODIFY** | `Shared/fr.lproj/Localizable.strings` | Nettoyage cles mortes + nouvelles cles |
| **MODIFY** | `CLAUDE.md` | Mise a jour architecture et features |
| **MODIFY** | `README.md` | Mise a jour docs, Claude Code requis |
| **ADD** | `ClaudeUsageWidget/ProxyIntent.swift` (ou similaire) | AppIntent pour config proxy widget |
