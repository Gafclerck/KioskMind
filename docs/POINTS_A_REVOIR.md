# Points à Revoir & Dette Technique Post-Hackathon

Ce document répertorie les points d'optimisation et d'architecture identifiés lors de l'introspection critique du pipeline vocal et des fonctionnalités transverses, mis de côté temporairement pour le MVP du hackathon et à traiter lors de la prochaine phase d'industrialisation.

---

## 1. Volume du catalogue transmis au LLM dans `RemoteCloudIntentParser` (Priorité Moyenne)

* **Composant :** [`RemoteCloudIntentParser`](file:///D:/kiosk_mind/lib/features/voice_assistant/data/parsers/remote_cloud_intent_parser.dart)
* **État actuel :**
  Lors d'une requête Cloud NLU / Gemini, la totalité du catalogue actif est sérialisée dans le payload JSON envoyé à la fonction Cloud :
  ```dart
  final List<ProductSnapshot> catalog = await catalogReader.readActiveProducts();
  ```
* **Contexte Hackathon :**
  Pour un kiosque typique (20 à 50 références de produits), la taille du payload est dérisoire (~2-5 Ko), la latence reste bien inférieure au budget de 2000 ms, et le grounding strict Decision D5 fonctionne à 100%.
* **À revoir pour l'industrialisation (supérette > 500 articles) :**
  - **Coût en tokens :** Envoyer un catalogue volumineux à chaque requête LLM augmente la facture de l'API.
  - **Latence :** Temps de sérialisation et d'inférence plus élevé.
  - **Solution cible préconisée :**
    1. Pré-filtrer les produits par similarité phonétique / textuelle avec la phrase brute prononcée.
    2. Plafonner la liste aux `k` produits les plus fréquents / récents (ex. Top 50) + les correspondances floues.

---

## 2. Quantités fractionnaires sur les mouvements de stock (`StockMovement.quantity`) (Basse Priorité)

* **Composant :** [`StockMovement`](file:///D:/kiosk_mind/lib/features/products_stock/domain/entities/stock_movement.dart) & [`RealRecordRestockHandler`](file:///D:/kiosk_mind/lib/features/voice_assistant/data/handlers/real/real_record_restock_handler.dart)
* **État actuel :**
  `StockMovement.quantity` est typé en `int` dans le domaine `products_stock`. Les commandes vocales arrivant avec des quantités décimales (ex. 1.5 kg de riz) sont converties via `.toInt()`.
* **À revoir :**
  Migrer `StockMovement.quantity` vers `double` ou supporter les unités fractionnaires (grammes, millilitres) pour les produits vendus au poids ou au volume.
