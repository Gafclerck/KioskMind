from datetime import datetime, timedelta, timezone

from firebase_admin import firestore, initialize_app, messaging
from firebase_functions import firestore_fn, scheduler_fn

initialize_app()

FENETRE_JOURS = 7
LIMITE_JOURS = 3

TYPE_LOW_STOCK = "LOW_STOCK"
TYPE_PREDICTED = "PREDICTED_STOCKOUT"
TYPE_NEGATIVE = "NEGATIVE_STOCK"

# Textes de notification par langue — langue lue depuis users/{uid}.language
MESSAGES = {
    "fr": {
        TYPE_LOW_STOCK: lambda nom, stock: (
            "Stock bas",
            f"{nom} : il ne reste que {stock} unité(s)",
        ),
        TYPE_NEGATIVE: lambda nom, stock: (
            "Stock négatif",
            f"{nom} : stock à {stock}, vérifiez vos ventes récentes",
        ),
        TYPE_PREDICTED: lambda nom, jours: (
            "Rupture de stock prévue",
            f"{nom} : plus de stock dans environ {jours} jour(s)",
        ),
    },
    "en": {
        TYPE_LOW_STOCK: lambda nom, stock: (
            "Low stock",
            f"{nom}: only {stock} unit(s) left",
        ),
        TYPE_NEGATIVE: lambda nom, stock: (
            "Negative stock",
            f"{nom}: stock at {stock}, check recent sales",
        ),
        TYPE_PREDICTED: lambda nom, jours: (
            "Stockout predicted",
            f"{nom}: out of stock in about {jours} day(s)",
        ),
    },
}


# ---------------------------------------------------------------- UC13
@firestore_fn.on_document_updated(document="products/{product_id}")
def verifier_stock(event: firestore_fn.Event) -> None:
    """UC13 : notifie quand le stock franchit le seuil d'alerte,
    ou devient négatif."""
    db = firestore.client()
    avant = event.data.before.to_dict() or {}
    apres = event.data.after.to_dict() or {}
    product_id = event.params["product_id"]

    stock = apres.get("stock")
    seuil = apres.get("alertThreshold")
    if stock is None or seuil is None or stock == avant.get("stock"):
        return  # le stock n'a pas changé (ex. modification du prix)

    nom = apres.get("name", product_id)
    print(f"[verifier_stock] {nom} : stock {avant.get('stock')} -> {stock}")

    if stock < 0:
        _resoudre_alerte(db, product_id, TYPE_LOW_STOCK)
        _resoudre_alerte(db, product_id, TYPE_PREDICTED)
        _creer_alerte_et_notifier(db, product_id, nom, TYPE_NEGATIVE, stock, apres)
    elif stock <= seuil:
        _resoudre_alerte(db, product_id, TYPE_PREDICTED)
        _creer_alerte_et_notifier(db, product_id, nom, TYPE_LOW_STOCK, stock, apres)
    else:
        _resoudre_alerte(db, product_id, TYPE_LOW_STOCK)
        _resoudre_alerte(db, product_id, TYPE_NEGATIVE)


# ---------------------------------------------------------------- UC14
@scheduler_fn.on_schedule(schedule="every day 06:00")
def predictions_quotidiennes(event: scheduler_fn.ScheduledEvent) -> None:
    """UC14 : prédiction de rupture, basée sur les 7 derniers
    documents dailyStats plutôt que sur les ventes individuelles."""
    db = firestore.client()

    for doc in db.collection("products").stream():
        produit = doc.to_dict()
        product_id = doc.id
        nom = produit["name"]
        stock = produit["stock"]
        seuil = produit["alertThreshold"]

        if stock <= seuil:
            continue  # déjà pris en charge par UC13 (LOW_STOCK ou NEGATIVE_STOCK)

        total_vendu = _total_vendu_depuis_dailystats(db, product_id)
        if total_vendu == 0:
            _resoudre_alerte(db, product_id, TYPE_PREDICTED)
            continue

        jours = stock / (total_vendu / FENETRE_JOURS)
        print(f"[predictions_quotidiennes] {nom} : {jours:.1f} jour(s) estimés")

        if jours <= LIMITE_JOURS:
            _creer_alerte_et_notifier(
                db, product_id, nom, TYPE_PREDICTED, round(jours), produit
            )
        else:
            _resoudre_alerte(db, product_id, TYPE_PREDICTED)


# --------------------------------------------------- fonctions partagées
def _total_vendu_depuis_dailystats(db, product_id) -> float:
    """Lit les 7 derniers documents dailyStats plutôt que de parcourir
    les ventes une par une — beaucoup plus rapide."""
    aujourdhui = datetime.now(timezone.utc)
    total = 0

    for i in range(FENETRE_JOURS):
        jour = aujourdhui - timedelta(days=i)
        doc_id = jour.strftime("%Y%m%d")
        doc = db.collection("dailyStats").document(doc_id).get()
        if doc.exists:
            qty_par_produit = doc.to_dict().get("qtyByProduct", {})
            total += qty_par_produit.get(product_id, 0)

    return total


def _ref_alerte(db, product_id, type_alerte):
    """ID déterministe {productId}_{type} : au plus une alerte par
    produit et par type, les écritures deviennent idempotentes."""
    return db.collection("alerts").document(f"{product_id}_{type_alerte}")


def _creer_alerte_et_notifier(db, product_id, nom, type_alerte, valeur, produit) -> None:
    """Crée (ou réactive) l'alerte, et notifie seulement si ce n'est
    pas déjà fait pour cette occurrence (via notifiedAt)."""
    ref = _ref_alerte(db, product_id, type_alerte)
    existante = ref.get()
    deja_notifiee = existante.exists and existante.to_dict().get("statut") == "ACTIVE"

    donnees = {
        "type": type_alerte,
        "productId": product_id,
        "productName": nom,
        "stockAtCreation": produit.get("stock"),
        "status": "ACTIVE",
    }
    if type_alerte == TYPE_PREDICTED:
        donnees["estimatedDaysLeft"] = valeur

    if not existante.exists or existante.to_dict().get("status") != "ACTIVE":
        donnees["createdAt"] = datetime.now(timezone.utc)

    ref.set(donnees, merge=True)

    if not deja_notifiee:
        _envoyer_notification(db, produit, type_alerte, nom, valeur)
        ref.update({"notifiedAt": datetime.now(timezone.utc)})


def _resoudre_alerte(db, product_id, type_alerte) -> None:
    ref = _ref_alerte(db, product_id, type_alerte)
    doc = ref.get()
    if doc.exists and doc.to_dict().get("status") == "ACTIVE":
        ref.update({
            "status": "RESOLVED",
            "resolvedAt": datetime.now(timezone.utc),
        })


def _envoyer_notification(db, produit, type_alerte, nom, valeur) -> None:
    user_id = produit.get("userId") or produit.get("ownerId")
    if not user_id:
        print(f"[notification] Aucun userId trouvé sur le produit {nom}")
        return

    user_doc = db.collection("users").document(user_id).get()
    if not user_doc.exists:
        print(f"[notification] Aucun user trouvé pour l'id {user_id}")
        return

    user = user_doc.to_dict()
    tokens = user.get("fcmTokens", [])
    if not tokens:
        print(f"[notification] Pas de token FCM pour l'user {user_id}")
        return

    langue = user.get("language", "fr")
    construire_message = MESSAGES.get(langue, MESSAGES["fr"])[type_alerte]
    titre, corps = construire_message(nom, valeur)

    try:
        reponse = messaging.send_each_for_multicast(
            messaging.MulticastMessage(
                tokens=tokens,
                notification=messaging.Notification(title=titre, body=corps),
            )
        )
        print(f"[notification] Envoyée à {reponse.success_count}/{len(tokens)} appareil(s)")
    except Exception as erreur:
        print(f"[notification] Échec de l'envoi : {erreur}")