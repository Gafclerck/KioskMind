"""Tests de la machine à états des alertes (UC13) et de la prédiction (UC14).

Exécute functions/main.py tel quel, avec un Firestore et un FCM simulés en
mémoire : aucune dépendance réseau, aucun émulateur, aucune donnée réelle.

Lancement :
    python3 functions/tests/test_alert_state_machine.py
    # ou, si pytest est installé :
    pytest functions/tests/test_alert_state_machine.py

Ce sont exactement les scénarios qui ont fait échouer l'audit du PR #32 :
réappro après stock négatif, réappro pendant une prédiction, arrondi à
0 jour, échec FCM, anti-doublon de notification.
"""

import importlib.util
import sys
import types
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

MAIN_PY = Path(__file__).resolve().parents[1] / "main.py"


# --------------------------------------------------------------------- stubs
class _Doc:
    def __init__(self, store, path):
        self.store, self.path = store, path

    @property
    def id(self):
        return self.path.rsplit("/", 1)[-1]

    @property
    def exists(self):
        return self.path in self.store

    def collection(self, *parts):
        return _Coll(self.store, "/".join((self.path,) + parts))

    def to_dict(self):
        return dict(self.store[self.path]) if self.exists else None

    def get(self):
        return self

    def set(self, data, merge=False):
        if merge and self.path in self.store:
            self.store[self.path].update(data)
        else:
            self.store[self.path] = dict(data)

    def update(self, data):
        if self.path not in self.store:
            raise KeyError(f"NOT_FOUND : {self.path}")
        for champ, valeur in data.items():
            if isinstance(valeur, _ArrayRemove):
                actuel = self.store[self.path].get(champ, [])
                for mort in valeur.valeurs:
                    if mort in actuel:
                        actuel.remove(mort)
            else:
                self.store[self.path][champ] = valeur


class _Coll:
    def __init__(self, store, path):
        self.store, self.path = store, path

    def document(self, *parts):
        return _Doc(self.store, "/".join((self.path,) + parts))

    def stream(self):
        prefix = self.path + "/"
        for cle in list(self.store):
            if cle.startswith(prefix) and "/" not in cle[len(prefix):]:
                yield _Doc(self.store, cle)


class _FakeDB:
    def __init__(self):
        self.store = {}

    def collection(self, *parts):
        return _Coll(self.store, "/".join(parts))


class _ArrayRemove:
    """Conteneur marquant une suppression de tableau (firestore.ArrayRemove)."""

    def __init__(self, *valeurs):
        self.valeurs = valeurs


DB = _FakeDB()
ENVOYES = []


class _UnregisteredError(Exception):
    """Équivalent du messaging.UnregisteredError (token mort)."""


def _envoyer_stub(message):
    """Réponse FCM simulée : tous les tokens sont valides par défaut."""
    ENVOYES.append(message)
    tokens = message.get("tokens", [])
    return types.SimpleNamespace(
        success_count=len(tokens),
        failure_count=0,
        responses=[
            types.SimpleNamespace(success=True, exception=None) for _ in tokens
        ],
    )


def _installer_stubs():
    """Place des modules firebase factices avant d'importer main.py."""
    firebase_admin = types.ModuleType("firebase_admin")
    firebase_admin.initialize_app = lambda *a, **k: None
    firebase_admin.firestore = types.SimpleNamespace(
        client=lambda: DB, ArrayRemove=_ArrayRemove
    )
    firebase_admin.messaging = types.SimpleNamespace(
        MulticastMessage=lambda **k: k,
        Notification=lambda **k: k,
        AndroidConfig=lambda **k: k,
        AndroidPriority=types.SimpleNamespace(HIGH="HIGH", NORMAL="NORMAL"),
        UnregisteredError=_UnregisteredError,
        send_each_for_multicast=_envoyer_stub,
    )
    sys.modules["firebase_admin"] = firebase_admin

    def _deco(**_kwargs):
        return lambda fn: fn

    firestore_fn = types.ModuleType("firestore_fn")
    firestore_fn.on_document_updated = _deco
    firestore_fn.Event = object
    scheduler_fn = types.ModuleType("scheduler_fn")
    scheduler_fn.on_schedule = _deco
    scheduler_fn.ScheduledEvent = object
    firebase_functions = types.ModuleType("firebase_functions")
    firebase_functions.firestore_fn = firestore_fn
    firebase_functions.scheduler_fn = scheduler_fn
    sys.modules["firebase_functions"] = firebase_functions


def _charger_main():
    _installer_stubs()
    spec = importlib.util.spec_from_file_location("kioskmind_functions_main", MAIN_PY)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


main = _charger_main()


# ------------------------------------------------------------- utilitaires
class _Changement:
    def __init__(self, donnees):
        self._donnees = donnees

    def to_dict(self):
        return dict(self._donnees)


def _user(uid="u1", tokens=("token-1",), langue="fr"):
    DB.store[f"users/{uid}"] = {"fcmTokens": list(tokens), "language": langue}


def _produit(pid, quantite, seuil, nom="Riz", uid="u1"):
    DB.store[f"users/{uid}/products/{pid}"] = {
        "name": nom,
        "quantity": quantite,
        "alertThreshold": seuil,
    }


def _declencher(avant, apres, pid="riz", uid="u1"):
    evenement = types.SimpleNamespace(
        data=types.SimpleNamespace(before=_Changement(avant), after=_Changement(apres)),
        params={"uid": uid, "product_id": pid},
    )
    main.verifier_stock(evenement)


def _produit_apres(pid, uid="u1"):
    return DB.store[f"users/{uid}/products/{pid}"]


def _statut(pid, type_alerte):
    doc = DB.store.get(f"alerts/{pid}_{type_alerte}")
    return doc.get("status") if doc else None


def _derniers_messages():
    return [m.get("notification", {}) for m in ENVOYES]


# ------------------------------------------------------------------- tests
class MachineAEtatsAlertes(unittest.TestCase):
    """Scénarios UC13 (seuil bas / stock négatif) et UC14 (prédiction)."""

    def setUp(self):
        DB.store.clear()
        ENVOYES.clear()
        self._envoi_reussi = main.messaging.send_each_for_multicast
        _user()

    def tearDown(self):
        main.messaging.send_each_for_multicast = self._envoi_reussi

    def _simuler_vente(self, pid, avant, apres, uid="u1"):
        avant_doc = dict(_produit_apres(pid, uid))
        avant_doc["quantity"] = avant
        _produit_apres(pid, uid)["quantity"] = apres
        _declencher(avant_doc, _produit_apres(pid, uid), pid, uid)

    # ------------------------------------------------------------- UC13
    def test_stock_passe_sous_le_seuil(self):
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, 8)
        self.assertEqual(_statut("riz", "LOW_STOCK"), "ACTIVE")
        self.assertEqual(len(ENVOYES), 1)

    def test_update_sans_changement_de_stock_n_notifie_pas(self):
        _produit("riz", 8, 10)
        self._simuler_vente("riz", 8, 8)
        self.assertIsNone(_statut("riz", "LOW_STOCK"))
        self.assertEqual(len(ENVOYES), 0)

    def test_update_sous_le_seuil_ne_renvoie_pas_la_notification(self):
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, 8)
        self._simuler_vente("riz", 8, 7)
        self.assertEqual(len(ENVOYES), 1)

    def test_stock_negatif_resout_low_stock(self):
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, 7)
        self._simuler_vente("riz", 7, -2)
        self.assertEqual(_statut("riz", "NEGATIVE_STOCK"), "ACTIVE")
        self.assertEqual(_statut("riz", "LOW_STOCK"), "RESOLVED")

    def test_reappro_depuis_un_negatif_resout_negative_stock(self):
        """REGRESSION PR #32 : la branche `elif stock <= seuil` oubliait
        NEGATIVE_STOCK, qui restait ACTIVE en parallèle de LOW_STOCK."""
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, -2)
        self._simuler_vente("riz", -2, 8)
        self.assertEqual(_statut("riz", "NEGATIVE_STOCK"), "RESOLVED")
        self.assertEqual(_statut("riz", "LOW_STOCK"), "ACTIVE")

    def test_reappro_complet_resout_tout(self):
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, -2)
        self._simuler_vente("riz", -2, 25)
        for type_alerte in ("LOW_STOCK", "NEGATIVE_STOCK", "PREDICTED_STOCKOUT"):
            statut = _statut("riz", type_alerte)
            self.assertIn(statut, (None, "RESOLVED"), type_alerte)

    def test_reappro_complet_resout_la_prediction(self):
        """REGRESSION PR #32 : la branche `else` ne résolvait pas
        PREDICTED_STOCKOUT, qui restait affichée jusqu'au lendemain."""
        DB.store["alerts/riz_PREDICTED_STOCKOUT"] = {
            "type": "PREDICTED_STOCKOUT",
            "productId": "riz",
            "productName": "Riz",
            "userId": "u1",
            "stockAtCreation": 8,
            "status": "ACTIVE",
            "estimatedDaysLeft": 2,
            "createdAt": datetime.now(timezone.utc),
        }
        _produit("riz", 8, 10)
        self._simuler_vente("riz", 8, 25)
        self.assertEqual(_statut("riz", "PREDICTED_STOCKOUT"), "RESOLVED")

    def test_un_seuil_modifie_sans_changement_de_stock_n_alerte_pas(self):
        _produit("riz", 12, 10)
        avant = dict(_produit_apres("riz"))
        _produit_apres("riz")["alertThreshold"] = 20
        _declencher(avant, _produit_apres("riz"))
        self.assertIsNone(_statut("riz", "LOW_STOCK"))

    # --------------------------------------------------- anti-doublon / FCM
    def test_echec_fcm_ne_marque_pas_comme_notifie(self):
        """REGRESSION PR #32 : notifiedAt était écrit même quand FCM
        échouait, ce qui supprimait toute possibilité de retry."""
        _produit("riz", 12, 10)

        def _echec(*_args, **_kwargs):
            raise RuntimeError("FCM hors ligne")

        main.messaging.send_each_for_multicast = _echec
        self._simuler_vente("riz", 12, 8)

        alerte = DB.store["alerts/riz_LOW_STOCK"]
        self.assertNotIn("notifiedAt", alerte)
        self.assertEqual(alerte["status"], "ACTIVE")

        # Le retour à la normale permet de renvoyer la notification.
        main.messaging.send_each_for_multicast = self._envoi_reussi
        self._simuler_vente("riz", 8, 7)
        self.assertEqual(len(ENVOYES), 1)
        self.assertIn("notifiedAt", DB.store["alerts/riz_LOW_STOCK"])

    def test_notification_deja_envoyee_n_est_pas_renvoyee(self):
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, 8)
        self._simuler_vente("riz", 8, 7)
        self.assertEqual(len(ENVOYES), 1)

    def test_pas_de_token_aucune_notification_marquee(self):
        _user(tokens=())
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, 8)
        self.assertNotIn("notifiedAt", DB.store["alerts/riz_LOW_STOCK"])

    def test_notification_en_francais(self):
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, 8)
        self.assertEqual(_derniers_messages()[0]["title"], "Stock bas")

    def test_notification_en_anglais_si_choisie(self):
        _user(langue="en")
        _produit("riz", 12, 10)
        self._simuler_vente("riz", 12, 8)
        self.assertEqual(_derniers_messages()[0]["title"], "Low stock")

    # ------------------------------------------------------------- UC14
    def _remplir_daily_stats(self, pid, ventes_par_jour):
        for i in range(7):
            jour = (datetime.now(timezone.utc) - timedelta(days=i)).strftime("%Y%m%d")
            DB.store[f"users/u1/dailyStats/{jour}"] = {
                "qtyByProduct": {pid: ventes_par_jour}
            }

    def test_prediction_creee_quand_la_rupture_est_proche(self):
        _produit("huile", 8, 5, "Huile")
        self._remplir_daily_stats("huile", 3)  # 3/jour -> 8/3 = 2.7 jours
        main.predictions_quotidiennes(None)
        self.assertEqual(_statut("huile", "PREDICTED_STOCKOUT"), "ACTIVE")
        alerte = DB.store["alerts/huile_PREDICTED_STOCKOUT"]
        self.assertEqual(alerte["estimatedDaysLeft"], 3)
        self.assertNotIn("0 jour(s)", str(_derniers_messages()[-1]))

    def test_prediction_non_creee_quand_le_stock_tient(self):
        _produit("huile", 80, 5, "Huile")
        self._remplir_daily_stats("huile", 3)  # 80/3 = 26 jours
        main.predictions_quotidiennes(None)
        self.assertIsNone(_statut("huile", "PREDICTED_STOCKOUT"))

    def test_prediction_moins_d_un_jour_n_affiche_jamais_zero_jour(self):
        """REGRESSION PR #32 : round(0.2) valait 0 -> « dans 0 jour(s) »."""
        _produit("sucre", 1, 0, "Sucre")
        self._remplir_daily_stats("sucre", 5)  # 1/5 = 0.2 jour
        main.predictions_quotidiennes(None)
        alerte = DB.store["alerts/sucre_PREDICTED_STOCKOUT"]
        self.assertEqual(alerte["estimatedDaysLeft"], 1)
        self.assertNotIn("0 jour(s)", str(_derniers_messages()[-1]))

    def test_prediction_sans_vente_resout_et_ne_crash_pas(self):
        _produit("sel", 50, 5, "Sel")
        self._remplir_daily_stats("sel", 0)
        main.predictions_quotidiennes(None)
        self.assertIsNone(_statut("sel", "PREDICTED_STOCKOUT"))

    def test_produit_sous_le_seuil_est_laisse_a_uc13(self):
        """UC14 ne doit pas toucher aux produits déjà gérés par UC13."""
        _produit("riz", 5, 10)  # 5 <= 10 -> LOW_STOCK côté client/UC13
        self._remplir_daily_stats("riz", 2)
        main.predictions_quotidiennes(None)
        self.assertIsNone(_statut("riz", "PREDICTED_STOCKOUT"))

    def test_produit_incomplet_est_ignore(self):
        DB.store["users/u1/products/bizarre"] = {"name": "Bizarre"}  # ni quantity ni seuil
        self._remplir_daily_stats("bizarre", 2)
        main.predictions_quotidiennes(None)
        self.assertIsNone(_statut("bizarre", "PREDICTED_STOCKOUT"))


class EnvoiNotification(unittest.TestCase):
    """Préférence utilisateur et purge des tokens (FCM)."""

    def setUp(self):
        DB.store.clear()
        ENVOYES.clear()
        self._envoi_reussi = main.messaging.send_each_for_multicast
        _user()

    def tearDown(self):
        main.messaging.send_each_for_multicast = self._envoi_reussi

    def _vendre(self, pid="riz"):
        """Passe le stock de 12 à 8 avec un seuil à 10 : déclenche UC13."""
        avant = {"name": "Riz", "quantity": 12, "alertThreshold": 10}
        apres = {"name": "Riz", "quantity": 8, "alertThreshold": 10}
        _produit(pid, 8, 10)
        _declencher(avant, apres, pid)

    def _reponse(self, tokens, exceptions):
        return types.SimpleNamespace(
            success_count=sum(1 for e in exceptions if e is None),
            failure_count=sum(1 for e in exceptions if e is not None),
            responses=[
                types.SimpleNamespace(success=e is None, exception=e)
                for e in exceptions
            ],
        )

    def test_payload_cible_le_canal_alertes(self):
        """Sans channel_id, Android classe le push dans un canal par défaut
        dont l'importance peut être silencieuse."""
        self._vendre()
        self.assertEqual(ENVOYES[-1]["android"]["channel_id"], main.CANAL_ALERTES)
        self.assertEqual(ENVOYES[-1]["data"]["productId"], "riz")

    def test_alertes_desactivees_ne_notifient_pas(self):
        DB.store["users/u1"]["stockAlertsEnabled"] = False
        self._vendre()
        # L'alerte reste créée : elle doit rester visible dans l'app.
        self.assertEqual(_statut("riz", "LOW_STOCK"), "ACTIVE")
        self.assertEqual(len(ENVOYES), 0)
        self.assertNotIn("notifiedAt", DB.store["alerts/riz_LOW_STOCK"])

    def test_preference_absente_notifie_par_defaut(self):
        """Clé absente = activé : aucun produit existant privé d'alertes."""
        self._vendre()
        self.assertEqual(len(ENVOYES), 1)

    def test_token_non_enregistre_est_purge(self):
        DB.store["users/u1"]["fcmTokens"] = ["vivant", "mort"]
        main.messaging.send_each_for_multicast = lambda m: self._reponse(
            m["tokens"], [None, _UnregisteredError("gone")]
        )
        self._vendre()
        self.assertEqual(DB.store["users/u1"]["fcmTokens"], ["vivant"])
        self.assertIn("notifiedAt", DB.store["alerts/riz_LOW_STOCK"])

    def test_erreur_transitoire_ne_purge_rien(self):
        """Supprimer sur une panne FCM priverait l'appareil de toute
        notification future, sans erreur visible."""
        DB.store["users/u1"]["fcmTokens"] = ["vivant"]
        main.messaging.send_each_for_multicast = lambda m: self._reponse(
            m["tokens"], [RuntimeError("FCM en panne")]
        )
        self._vendre()
        self.assertEqual(DB.store["users/u1"]["fcmTokens"], ["vivant"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
