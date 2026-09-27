lib/
├── core/
│   ├── di/                    -> injection de dépendances (service locator)
│   ├── constants/              -> valeurs constantes, seuils par défaut
│   ├── errors/                 -> Failure, exceptions personnalisées
│   ├── network/                -> connectivity checker, client HTTP, file de synchronisation offline
│   ├── theme/                  -> thème et styles partagés
│   ├── localization/           -> configuration i18n (FR/EN), delegate de traduction
│   ├── routing/                -> configuration des routes
│   ├── usecase/                -> classe abstraite UseCase<Type, Params> commune
│   ├── voice_services/         -> adapters techniques bruts (STT/TTS multilingue), sans logique métier
│   └── widgets/                -> widgets UI partagés (badges d'état, boutons)
│
├── features/
│   ├── auth/
│   │   ├── presentation/       -> pages login, register, profil boutique + state management
│   │   ├── domain/             -> entités (User, ShopProfile), use cases (Login, Register, ConfigureShopProfile)
│   │   └── data/                -> modèles, datasource Firebase Auth, repository impl
│   │
│   ├── products_stock/
│   │   ├── presentation/
│   │   ├── domain/             -> entités (Product, StockMovement), use cases (CreateProduct, UpdateProduct, DeleteProduct, AddStockEntry, AddManualStockExit, GetStockStatus)
│   │   └── data/                -> datasource locale (cache offline) + distante (Firestore), repository avec logique de sync
│   │
│   ├── sales/
│   │   ├── presentation/
│   │   ├── domain/             -> entités (Sale), use cases (RecordSale, GetSalesHistory, GetSalesDashboard)
│   │   └── data/
│   │
│   ├── alerts_predictions/
│   │   ├── presentation/        -> écran historique des alertes
│   │   ├── domain/              -> entités (StockAlert), use cases (EvaluateLowStockThreshold, PredictStockout), interface NotificationSender
│   │   └── data/                 -> intégration FCM, appel au moteur prédictif
│   │
│   ├── voice_assistant/          -> orchestration métier du vocal (pas les adapters bruts, qui sont dans core)
│   │   ├── presentation/         -> UI du micro, feedback pendant l'écoute
│   │   ├── domain/               -> entités (VoiceCommand, Intent), use cases (InterpretVoiceCommand, ConfirmMissingData)
│   │   └── data/                  -> agent_loop, mapping intent -> use cases des autres features exposés comme tools, parseur offline de secours
│   │
│   ├── clients_credit/ (bonus)
│   │   ├── presentation/
│   │   ├── domain/               -> entités (Client, Debt), use cases (CreateClient, RecordDebt, RecordRepayment, GetClientBalance)
│   │   └── data/
│   │
│   └── export_reporting/ (bonus)
│       ├── presentation/
│       ├── domain/                -> use case ExportPurchasesAndSales
│       └── data/                   -> génération du fichier Excel
│
├── app.dart                        -> widget racine, router, thème
└── main.dart                       -> point d'entrée, init Firebase, DI, localization