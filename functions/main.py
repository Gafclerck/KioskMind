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
@firestore_fn.on_document_updated(document="users/{uid}/products/{product_id}")
def verifier_stock(event: firestore_fn.Event) -> None:
    """UC13 : notifie quand le stock franchit le seuil d'alerte,
    ou devient négatif."""
    db = firestore.client()
    avant = event.data.before.to_dict() or {}
    apres = event.data.after.to_dict() or {}
    product_id = event.params["product_id"]
    uid = event.params["uid"]

    stock = apres.get("quantity")
    seuil = apres.get("alertThreshold")
    if stock is None or seuil is None or stock == avant.get("quantity"):
        return  # le stock n'a pas changé (ex. modification du prix)

    nom = apres.get("name", product_id)
    print(f"[verifier_stock] {nom} : quantity {avant.get('quantity')} -> {stock}")

    # On enrichit le produit avec l'uid pour que _envoyer_notification puisse l'utiliser
    apres_avec_uid = {**apres, "_uid": uid}

    if stock < 0:
        _resoudre_alerte(db, product_id, TYPE_LOW_STOCK)
        _resoudre_alerte(db, product_id, TYPE_PREDICTED)
        _creer_alerte_et_notifier(db, uid, product_id, nom, TYPE_NEGATIVE, stock, apres_avec_uid)
    elif stock <= seuil:
        # On repasse d'un stock négatif à un stock bas : l'alerte
        # NEGATIVE_STOCK doit être résolue, sinon elle reste ACTIVE
        # en parallèle de LOW_STOCK.
        _resoudre_alerte(db, product_id, TYPE_NEGATIVE)
        _resoudre_alerte(db, product_id, TYPE_PREDICTED)
        _creer_alerte_et_notifier(db, uid, product_id, nom, TYPE_LOW_STOCK, stock, apres_avec_uid)
    else:
        _resoudre_alerte(db, product_id, TYPE_LOW_STOCK)
        _resoudre_alerte(db, product_id, TYPE_NEGATIVE)
        # Un réapprovisionnement invalide aussi la prédiction de rupture :
        # sans cela, elle reste affichée jusqu'à l'exécution du lendemain.
        _resoudre_alerte(db, product_id, TYPE_PREDICTED)


# ---------------------------------------------------------------- UC14
@scheduler_fn.on_schedule(schedule="every day 06:00")
def predictions_quotidiennes(event: scheduler_fn.ScheduledEvent) -> None:
    """UC14 : prédiction de rupture, basée sur les 7 derniers
    documents dailyStats plutôt que sur les ventes individuelles."""
    db = firestore.client()

    for user_doc in db.collection("users").stream():
        uid = user_doc.id
        for doc in db.collection("users").document(uid).collection("products").stream():
            produit = doc.to_dict()
            product_id = doc.id
            nom = produit.get("name", product_id)
            stock = produit.get("quantity")
            seuil = produit.get("alertThreshold")

            if stock is None or seuil is None:
                continue

            if stock <= seuil:
                continue  # déjà pris en charge par UC13 (LOW_STOCK ou NEGATIVE_STOCK)

            total_vendu = _total_vendu_depuis_dailystats(db, uid, product_id)
            if total_vendu == 0:
                _resoudre_alerte(db, product_id, TYPE_PREDICTED)
                continue

            jours = stock / (total_vendu / FENETRE_JOURS)
            print(f"[predictions_quotidiennes] {nom} : {jours:.1f} jour(s) estimés")

            produit_avec_uid = {**produit, "_uid": uid}
            if jours <= LIMITE_JOURS:
                # max(1, ...) : sous une demi-journée, round() vaudrait 0 et
                # la notification dirait "plus de stock dans 0 jour(s)".
                jours_affiches = max(1, round(jours))
                _creer_alerte_et_notifier(
                    db, uid, product_id, nom, TYPE_PREDICTED, jours_affiches, produit_avec_uid
                )
            else:
                _resoudre_alerte(db, product_id, TYPE_PREDICTED)


# --------------------------------------------------- fonctions partagées
def _total_vendu_depuis_dailystats(db, uid: str, product_id: str) -> float:
    """Lit les 7 derniers documents dailyStats plutôt que de parcourir
    les ventes une par une — beaucoup plus rapide."""
    aujourdhui = datetime.now(timezone.utc)
    total = 0

    for i in range(FENETRE_JOURS):
        jour = aujourdhui - timedelta(days=i)
        doc_id = jour.strftime("%Y%m%d")
        doc = (
            db.collection("users")
            .document(uid)
            .collection("dailyStats")
            .document(doc_id)
            .get()
        )
        if doc.exists:
            qty_par_produit = doc.to_dict().get("qtyByProduct", {})
            total += qty_par_produit.get(product_id, 0)

    return total


def _ref_alerte(db, product_id, type_alerte):
    """ID déterministe {productId}_{type} : au plus une alerte par
    produit et par type, les écritures deviennent idempotentes."""
    return db.collection("alerts").document(f"{product_id}_{type_alerte}")


def _creer_alerte_et_notifier(db, uid: str, product_id: str, nom, type_alerte, valeur, produit) -> None:
    """Crée (ou réactive) l'alerte, et notifie seulement si ce n'est
    pas déjà fait pour cette occurrence (via notifiedAt, écrit
    uniquement quand l'envoi a réellement réussi)."""
    ref = _ref_alerte(db, product_id, type_alerte)
    existante = ref.get()
    etat = existante.to_dict() if existante.exists else None
    # notifiedAt ne marque qu'un ENVOI RÉUSSI : si l'envoi a échoué
    # (FCM en panne, token absent), la prochaine occurrence retente.
    deja_notifiee = (
        etat is not None
        and etat.get("status") == "ACTIVE"
        and etat.get("notifiedAt") is not None
    )

    donnees = {
        "type": type_alerte,
        "productId": product_id,
        "productName": nom,
        "userId": uid,              # indispensable pour filtrer côté Flutter
        "stockAtCreation": produit.get("quantity"),
        "status": "ACTIVE",
    }
    if type_alerte == TYPE_PREDICTED:
        donnees["estimatedDaysLeft"] = valeur

    if etat is None or etat.get("status") != "ACTIVE":
        donnees["createdAt"] = datetime.now(timezone.utc)

    ref.set(donnees, merge=True)

    if not deja_notifiee:
        if _envoyer_notification(db, uid, produit, type_alerte, nom, valeur):
            ref.update({"notifiedAt": datetime.now(timezone.utc)})


def _resoudre_alerte(db, product_id, type_alerte) -> None:
    ref = _ref_alerte(db, product_id, type_alerte)
    doc = ref.get()
    if doc.exists and doc.to_dict().get("status") == "ACTIVE":
        ref.update({
            "status": "RESOLVED",
            "resolvedAt": datetime.now(timezone.utc),
        })


def _envoyer_notification(db, uid: str, produit, type_alerte, nom, valeur) -> bool:
    """Renvoie True si la notification a atteint au moins un appareil."""
    # L'uid vient du chemin Firestore (users/{uid}/products/{id}), pas d'un champ du produit
    user_id = uid or produit.get("_uid")
    if not user_id:
        print(f"[notification] Aucun uid disponible pour le produit {nom}")
        return False

    user_doc = db.collection("users").document(user_id).get()
    if not user_doc.exists:
        print(f"[notification] Aucun user trouvé pour l'id {user_id}")
        return False

    user = user_doc.to_dict()
    tokens = user.get("fcmTokens", [])
    if not tokens:
        print(f"[notification] Pas de token FCM pour l'user {user_id}")
        return False

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
        # Au moins un appareil a reçu la notification : l'occurrence
        # est considérée comme notifiée.
        return reponse.success_count > 0
    except Exception as erreur:
        print(f"[notification] Échec de l'envoi : {erreur}")
        return False