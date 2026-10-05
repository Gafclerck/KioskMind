"""
Script de test manuel contre l'émulateur Firestore local.
Adapté au schéma officiel (users/{uid}/products, alerts, users/{uid}/dailyStats).

Lance d'abord `firebase emulators:start` dans un autre terminal,
puis exécute ce script avec `python test_manual.py`.

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

# USER_ID doit correspondre à l'UID Firebase Auth utilisé dans l'app.
# Avec l'émulateur Auth actif, crée un compte dans l'app puis copie l'UID ici,
# ou utilise "user_test" si tu crées manuellement le user dans l'émulateur Auth.
USER_ID = "test_alerts_uid" # pour le test metter le même id ici que celui dans alerts_providers.dart


PRODUIT_RIZ = "riz"
PRODUIT_HUILE = "huile"


def _ref_produit(produit_id):
    """Chemin officiel : users/{uid}/products/{id}"""
    return db.collection("users").document(USER_ID).collection("products").document(produit_id)


def preparer_user_de_test():
    print("Création du user de test...")
    db.collection("users").document(USER_ID).set({
        "name": "Commerçant Test",
        "shopName": "Kiosque Test",
        "phone": "+261000000000",
        "language": "fr",
        "currency": "XOF",
        "fcmTokens": ["COLLER_ICI_VOTRE_TOKEN_FCM"], # "IMPORTANT N'oubliez pas ceci pour le test 
        "createdAt": datetime.now(timezone.utc),
    })


def _ajouter_vente_journaliere(produit_id, quantite_par_jour):
    """Ajoute 7 jours de dailyStats dans users/{uid}/dailyStats/ (schéma officiel)."""
    aujourdhui = datetime.now(timezone.utc)
    for i in range(7):
        jour = aujourdhui - timedelta(days=i)
        doc_id = jour.strftime("%Y%m%d")
        # Chemin officiel : users/{uid}/dailyStats/{date}
        ref = db.collection("users").document(USER_ID).collection("dailyStats").document(doc_id)
        existant = ref.get()
        donnees = existant.to_dict() if existant.exists else {
            "revenue": 0, "cost": 0, "salesCount": 0, "qtyByProduct": {}
        }
        donnees["qtyByProduct"][produit_id] = quantite_par_jour
        ref.set(donnees)


def preparer_produit_riz_pour_uc13():
    """Seuil proche du stock : destiné à tester verifier_stock (UC13)."""
    print("Création du produit 'Riz' (test UC13)...")
    # Chemin officiel : users/{uid}/products/{id}
    # Champ "quantity" (et non "stock") — aligné avec main.py
    _ref_produit(PRODUIT_RIZ).set({
        "name": "Riz",
        "nameNormalized": "riz",
        "unit": "KG",
        "price": 2500,
        "purchasePrice": 2000,
        "quantity": 12,         
        "alertThreshold": 10,
        "isArchived": False,
        "createdAt": datetime.now(timezone.utc),
        "updatedAt": datetime.now(timezone.utc),
    })
    _ajouter_vente_journaliere(PRODUIT_RIZ, 2)  # 2 kg/jour


def preparer_produit_huile_pour_uc14():
    """Seuil bas (5) mais vente rapide (3/jour) : UC14 doit détecter la rupture prévue."""
    print("Création du produit 'Huile' (test UC14)...")
    _ref_produit(PRODUIT_HUILE).set({
        "name": "Huile",
        "nameNormalized": "huile",
        "unit": "LITRE",
        "price": 3000,
        "purchasePrice": 2200,
        "quantity": 8,          
        "alertThreshold": 5,
        "isArchived": False,
        "createdAt": datetime.now(timezone.utc),
        "updatedAt": datetime.now(timezone.utc),
    })
    _ajouter_vente_journaliere(PRODUIT_HUILE, 3)  # 3 litres/jour


def simuler_une_vente_qui_declenche_l_alerte():
    print("Simulation : la quantity de riz passe de 12 à 8 (sous le seuil de 10)...")
    _ref_produit(PRODUIT_RIZ).update({"quantity": 8})
    print("Écriture faite. Vérifie les logs de l'émulateur Functions.\n")


def simuler_un_stock_negatif():
    print("Simulation : la quantity de riz passe à -2 (vente malgré rupture)...")
    _ref_produit(PRODUIT_RIZ).update({"quantity": -2})
    print("Écriture faite. Alerte NEGATIVE_STOCK attendue.\n")


def simuler_un_reapprovisionnement():
    print("Simulation : réapprovisionnement du riz, la quantity passe à 25...")
    _ref_produit(PRODUIT_RIZ).update({"quantity": 25})
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
# vous pouvez décommenter pour test
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
    print("\nPuis vérifie les alertes avec :")
    print(f"  python -c \"from test_manual import afficher_les_alertes, PRODUIT_HUILE; afficher_les_alertes(PRODUIT_HUILE)\"")