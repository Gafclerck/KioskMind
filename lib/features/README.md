# lib/features

One folder per feature. Every feature respects three layers:

```text
<feature>/
  presentation/   widgets, pages, state management
  domain/         entities, use cases, repository contracts
  data/           models, data sources, repository implementations
```

Dependencies flow inward: `presentation` and `data` depend on `domain`, and
`domain` depends on nothing from the outer layers.

Business logic and data access never live inside widgets.

## Features

| Feature | Responsibility |
|---|---|
| `auth/` | Login, register, shop profile. Firebase Auth, state management with Riverpod |
| `products_stock/` | Products and stock movements, offline-first on Firestore, stock updates via `FieldValue.increment` to avoid offline overwrite conflicts |
| `sales/` | Sales records, history, dashboard |
| `alerts_predictions/` | Low stock alerts and stockout prediction, push notifications through a Firestore-triggered Cloud Function and FCM |
| `voice_assistant/` | Voice orchestration: microphone UI, intent interpretation, mapping intents to other features' use cases, offline fallback parser |
| `clients_credit/` | Customers and debts, balances, repayments |
| `export_reporting/` | Export of purchases and sales to Excel |

Each folder's `.gitkeep` records what belongs in each of its three layers.

The layers exist to fix the boundaries, not to be filled upfront. Add code to a
layer when you implement it. Do not create placeholder classes, and do not put
feature-specific helpers in `lib/core/`.
