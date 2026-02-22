# Pacing Intelligent — Design

## Problem

Les trackers d'usage Claude (dont le concurrent Claude Usage Tracker) affichent un % brut. 45% d'usage weekly, c'est bien ou pas ? Impossible a dire sans savoir ou on en est dans la semaine. TokenEater va plus loin avec du **coaching intelligent**.

## Solution

Calculer le delta entre la consommation reelle et la consommation lineaire attendue, basee sur le temps ecoule dans la periode. Afficher ce delta partout : menu bar, popover, widget dedie.

## Formule

```
resetsAt         = date de reset du bucket (seven_day)
totalDuration    = 7 jours (604800s)
startOfPeriod    = resetsAt - totalDuration
elapsed          = (now - startOfPeriod) / totalDuration     // 0.0 a 1.0
expectedUsage    = elapsed * 100                              // % attendu
delta            = utilization - expectedUsage                // + = trop vite, - = marge
```

### Zones

| Zone | Condition | Couleur | Copies (random) |
|------|-----------|---------|------------------|
| chill | delta < -10 | Vert (#32D74B) | "Tranquille, t'as du stock" / "Claude t'attend, envoie du lourd" / "Mode cruise active" |
| onTrack | -10 <= delta <= +10 | Bleu (#0A84FF) | "Pile dans le rythme" / "Steady as she goes" / "Tu geres" |
| hot | delta > +10 | Rouge (#FF453A) | "Doucement cowboy" / "Tu flambes" / "Leve le pied" |

Les copies sont pickees aleatoirement a chaque refresh pour rester frais.

## Composants

### 1. PacingCalculator (Shared)

```swift
enum PacingZone {
    case chill    // marge
    case onTrack  // dans le rythme
    case hot      // trop vite
}

struct PacingResult {
    let delta: Double           // ex: -13.2
    let expectedUsage: Double   // ex: 43.0
    let actualUsage: Double     // ex: 30.0
    let zone: PacingZone
    let message: String         // copy fun random
}
```

Calcul base sur `seven_day.utilization` et `seven_day.resetsAt`. Si `resetsAt` est nil, pas de pacing disponible.

### 2. Menu bar — nouvelle metrique pinnable

- Ajout `case pacing` dans `MetricID` avec shortLabel `"P"`
- Pinnable/unpinnable comme les 3 metriques existantes
- Deux modes d'affichage (configurable UserDefaults `pacingDisplayMode`):
  - **dot** : juste `●` colore
  - **dotDelta** : `● -13%` colore
- Desactive par defaut (l'utilisateur l'active dans le popover)

### 3. Popover — section pacing separee

Apres les 3 metriques et avant les boutons d'action :

```
── Pacing ─────────────────────
████████░░░░░░░░│░░░░░░░░░░░░░
             ▲ ideal
-13% · Tranquille, t'as du stock
```

- Barre de progression coloree (conso reelle)
- Marker vertical semi-transparent a la position `expectedUsage`
- Delta + copy fun en dessous
- Cachee si `seven_day` ou `resetsAt` est nil

### 4. Petit widget WidgetKit (.systemSmall)

Widget dedie pacing, style distinctif :

```
┌──────────────────┐
│  Weekly Pacing   │
│                  │
│  ████████│░░░░░  │
│       ▲ ideal    │
│                  │
│  -13%  marge     │
│  reset 4j 12h    │
└──────────────────┘
```

- Barre split avec marker ideal
- Delta colore + label texte (zone)
- Countdown avant reset
- Background degrade subtil qui change selon la zone
- Accessible depuis le widget picker WidgetKit

## Localisation

Copies fun en francais (default) et anglais.

### Anglais
| Zone | Copies |
|------|--------|
| chill | "Plenty of room" / "Claude's waiting, go wild" / "Cruise mode on" |
| onTrack | "Right on pace" / "Steady as she goes" / "You're on track" |
| hot | "Easy there cowboy" / "Burning through it" / "Slow down" |

### Francais
| Zone | Copies |
|------|--------|
| chill | "Tranquille, t'as du stock" / "Claude t'attend, envoie du lourd" / "Mode cruise active" |
| onTrack | "Pile dans le rythme" / "Steady as she goes" / "Tu geres" |
| hot | "Doucement cowboy" / "Tu flambes" / "Leve le pied" |

## Donnees disponibles

On a deja tout ce qu'il faut dans `UsageBucket` :
- `utilization: Double` — % reel (0-100)
- `resetsAt: String?` — date ISO 8601 du prochain reset
- `resetsAtDate: Date?` — computed property deja implementee

Duree totale connue : 7 jours pour `seven_day`.

## Edge cases

- `resetsAt` nil → pas de pacing, on masque la section
- Debut de periode (elapsed ~0%) → delta potentiellement volatile, on affiche quand meme
- Fin de periode (elapsed ~100%) → le pacing converge vers le % reel, normal
- Usage a 0% → delta toujours negatif = chill
