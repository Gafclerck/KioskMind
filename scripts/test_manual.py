"""
Script de test manuel contre l'émulateur Firestore local.
Adapté au schéma officiel (users, products, alerts, dailyStats).

Lance d'abord `firebase emulators:start` dans un autre terminal,
puis exécute ce script avec `python test_manual_v2.py`.

Pour UC14, le déclenchement n'est PAS automatique dans l'émulateur :
après avoir lancé ce script, ouvre un 3e terminal et tape :
    firebase functions:shell
    predictions_quotidiennes()
"""
import os
import time
from datetime import datetime, timedelta, timezone
from google.cloud import firestore

os.environ["FIRESTORE_EMULATOR_HOST"] = "localhost:8080"

db = firestore.Client(project="kiosk-mind")

USER_ID = "user_test"
PRODUIT_RIZ = "riz"
PRODUIT_HUILE = "huile"


def preparer_user_de_test():
    print("Création du user de test...")
    db.collection("users").document(USER_ID).set({
        "name": "Commerçant Test",
        "shopName": "Kiosque Test",
        "phone": "+261000000000",
        "language": "fr",
        "currency": "XOF",
       "fcmTokens": ["d2H7Yb-2QNyUAhCj7z3gOV:APA91bHkoZIjjh9TcC9_T7Ywly6G0pwW39IF4ZgsFGnpg04SYBp-BaYsnLIUpO0kJgQpbPr8ONWS0FT6-Dz0xPEBjZZHO-12JZaw3V_hk3AjphEyrEn-diU","fF6Und1OTXOlLFGYCdqA50:APA91bEqsKYA4_Yc2mRY907SxP-8UZi6hBfckt3IWjpvNqSfFo4HQGbl3RvWBjAf8TAFuY-fbeQpnb9XuF_sFzftPzRpSlcBSfpb4lFgBVr0eltVqw6sfgU"],
        "createdAt": datetime.now(timezone.utc),
    })


def _ajouter_vente_journaliere(produit_id, quantite_par_jour):
    """Ajoute/complète 7 jours de dailyStats pour un produit donné,
    sans écraser ce qui existe déjà pour d'autres produits ce jour-là."""
    aujourdhui = datetime.now(timezone.utc)
    for i in range(7):
        jour = aujourdhui - timedelta(days=i)
        doc_id = jour.strftime("%Y%m%d")
        ref = db.collection("dailyStats").document(doc_id)
        existant = ref.get()
        donnees = existant.to_dict() if existant.exists else {
            "revenue": 0, "cost": 0, "salesCount": 0, "qtyByProduct": {}
        }
        donnees["qtyByProduct"][produit_id] = quantite_par_jour
        ref.set(donnees)


def preparer_produit_riz_pour_uc13():
    """Seuil proche du stock : destiné à tester verifier_stock (UC13)."""
    print("Création du produit 'Riz' (test UC13)...")
    db.collection("products").document(PRODUIT_RIZ).set({
        "name": "Riz",
        "nameNormalized": "riz",
        "unit": "KG",
        "price": 2500,
        "purchasePrice": 2000,
        "stock": 12,
        "alertThreshold": 10,
        "isArchived": False,
        "userId": USER_ID,
        "createdAt": datetime.now(timezone.utc),
        "updatedAt": datetime.now(timezone.utc),
    })
    _ajouter_vente_journaliere(PRODUIT_RIZ, 2)  # 2 kg/jour


def preparer_produit_huile_pour_uc14():
    """Seuil bas (5) mais vente rapide (3/jour) : le stock peut être
    AU-DESSUS du seuil tout en étant proche de la rupture — c'est le
    cas que UC14 doit détecter, contrairement à UC13."""
    print("Création du produit 'Huile' (test UC14)...")
    db.collection("products").document(PRODUIT_HUILE).set({
        "name": "Huile",
        "nameNormalized": "huile",
        "unit": "LITRE",
        "price": 3000,
        "purchasePrice": 2200,
        "stock": 8,  # au-dessus du seuil (5) -> pas ignoré par UC13
        "alertThreshold": 5,
        "isArchived": False,
        "userId": USER_ID,
        "createdAt": datetime.now(timezone.utc),
        "updatedAt": datetime.now(timezone.utc),
    })
    _ajouter_vente_journaliere(PRODUIT_HUILE, 3)  # 3 litres/jour


def simuler_une_vente_qui_declenche_l_alerte():
    print("Simulation : le stock de riz passe de 12 à 8 (sous le seuil de 10)...")
    db.collection("products").document(PRODUIT_RIZ).update({"stock": 8})
    print("Écriture faite. Vérifie les logs de l'émulateur Functions.\n")


def simuler_un_stock_negatif():
    print("Simulation : le stock de riz passe à -2 (vente malgré rupture)...")
    db.collection("products").document(PRODUIT_RIZ).update({"stock": -2})
    print("Écriture faite. Alerte NEGATIVE_STOCK attendue.\n")


def simuler_un_reapprovisionnement():
    print("Simulation : réapprovisionnement du riz, le stock passe à 25...")
    db.collection("products").document(PRODUIT_RIZ).update({"stock": 25})
    print("Écriture faite. Les alertes actives devraient se résoudre.\n")


def afficher_les_alertes(produit_id):
    for type_alerte in ["LOW_STOCK", "NEGATIVE_STOCK", "PREDICTED_STOCKOUT"]:
        doc = db.collection("alerts").document(f"{produit_id}_{type_alerte}").get()
        if doc.exists:
            print(f"  {type_alerte} :", doc.to_dict())
        else:
            print(f"  {type_alerte} : aucun document")


if __name__ == "__main__":
    preparer_user_de_test()

    # --- Scénario UC13 (riz) ---
    preparer_produit_riz_pour_uc13()
    print()

    simuler_une_vente_qui_declenche_l_alerte()
    time.sleep(2)
    print("--- Riz après la vente (LOW_STOCK attendu : ACTIVE) ---")
    afficher_les_alertes(PRODUIT_RIZ)

    print()
    simuler_un_stock_negatif()
    time.sleep(2)
    print("--- Riz après vente en négatif (NEGATIVE_STOCK attendu : ACTIVE) ---")
    afficher_les_alertes(PRODUIT_RIZ)

    print()
    simuler_un_reapprovisionnement()
    time.sleep(2)
    print("--- Riz après réapprovisionnement (tout attendu : RESOLVED) ---")
    afficher_les_alertes(PRODUIT_RIZ)

    # --- Scénario UC14 (huile) ---
    print()
    preparer_produit_huile_pour_uc14()
    print("\nProduit 'Huile' prêt pour UC14.")
    print("Dans un AUTRE terminal, lance :")
    print("  firebase functions:shell")
    print("  predictions_quotidiennes()")
    print("\nPuis relance ce script avec seulement la vérification :")
    print("  python -c \"from test_manual_v2 import afficher_les_alertes, PRODUIT_HUILE; afficher_les_alertes(PRODUIT_HUILE)\"")