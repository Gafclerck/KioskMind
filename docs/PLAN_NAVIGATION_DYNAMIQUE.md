# Plan — Navigation dynamique & Onboarding conditionnel

> **Rédigé le** : 2026-10-03  
> **Branche de travail cible** : `develop`  
> **Branche active au moment de l'analyse** : `fix/voice-honest-metrics`  
> **Auteur** : Antigravity (assistant architectural)

---

## 1. État des lieux — Diagnostic complet

### 1.1 Architecture de navigation actuelle (sur `develop`)

```
app.dart
└── home: const OnboardingPage()   ← TOUJOURS affiché au démarrage
         └── _startApp()  →  Navigator.pushReplacement → LoginPage
                                 └── (succès login)  →  RIEN (dans develop)
                                 └── _goToSignup()   →  Navigator.push → SignupPage
                                                           └── maybePop()  →  retour LoginPage
```

**`lib/core/routing/app_router.dart`** (GoRouter) :
```dart
final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(path: '/dashboard', builder: (_,__) => const MainNavigationPage()),
  ],
);
```
→ Ce router existe mais **n'est JAMAIS utilisé** dans `app.dart`. Il est mort.

### 1.2 Problèmes identifiés

| # | Problème | Impact |
|---|----------|--------|
| P1 | `app.dart` hardcode `home: OnboardingPage()` — l'onboarding s'affiche **à chaque lancement** | Régression UX critique |
| P2 | Le `GoRouter` (`app_router.dart`) est déclaré mais jamais branché à `MaterialApp` | Lettre morte, confusion pour les développeurs |
| P3 | Après un login réussi, aucune navigation n'est déclenchée dans `develop` (le succès affiche juste un toast, puis rien) | L'utilisateur est bloqué sur la page login |
| P4 | Toutes les transitions utilisent `Navigator.pushReplacement` / `Navigator.push` manuels sans coordination | Fragile, impossible à tester, aucun deep-link possible |
| P5 | Il n'existe aucun `authStateProvider` (Stream Firebase `authStateChanges`) — le router ne peut pas réagir à l'état de session | Impossible de sécuriser les routes sans ce bloc |
| P6 | Aucun mécanisme de persistance du flag "onboarding déjà vu" (pas de `shared_preferences`) | L'onboarding re-apparaît à chaque cold start |
| P7 | `OnboardingState` / `OnboardingNotifier` vivent en mémoire uniquement | Même si on navigue, le prochain lancement repart de 0 |

---

### 1.3 Analyse des modifications non committées (branche `fix/voice-honest-metrics`)

La branche actuelle a **1 seul commit d'avance sur `develop`** (`d79dfa3 fix(pubspec)`), le reste est commun.

Les **modifications non committées** (working directory) sont :

#### `lib/features/auth/presentation/pages/login_page.dart`
```diff
+ Navigator.of(context).pushReplacement(
+   MaterialPageRoute<void>(builder: (_) => const MainNavigationPage()),
+ );
```
**Objectif identifié** : Corriger le P3 (absence de navigation post-login) en ajoutant manuellement un `pushReplacement` vers `MainNavigationPage` après un login réussi.

**Verdict** : C'est un **fix légitime mais incomplet** — il court-circuite le router, ne gère pas la session Firebase, et introduit un couplage fort. Ce patch va dans le bon sens mais doit être intégré proprement dans la solution GoRouter finale. **Ne pas commiter tel quel.**

#### `lib/features/navigation/main_navigation_page.dart`
Deux natures de changements :

1. **Refactoring cosmétique** (formatage, réduction de verbosité) — neutre.
2. **Fonctionnel** :
   - Remplacement du `SnackBar('Assistant vocal')` par `openVoiceSession(context)` — branche la vraie session vocale.
   - Ajout de `Semantics` + `Tooltip` sur le bouton micro (accessibilité).
   - Remplacement de `IndexedStack` par `_pages[_currentIndex]` ← **à réévaluer** (IndexedStack préserve l'état des pages).

**Objectif identifié** : Connecter le bouton vocal à la vraie session modale.

**Verdict** : **Changement fonctionnel important**, à commiter avec le `voice_session_sheet.dart`.

#### Fichiers non-trackés nouveaux
- `lib/features/voice_assistant/presentation/widgets/voice_session_sheet.dart` — nouveau widget modal vocal
- `test/voice/voice_session_sheet_test.dart` — ses tests
- `docs/EXPLA2.md`, `docs/EXPLANATION.md`, `docs/KioskMind_Modelisation_v2.md` — documentation

---

## 2. Stratégie — Gestion des modifications non committées

> ⚠️ **Règle d'or** : On ne switche pas de branche, on ne perd pas ces modifications.

Les modifs non committées forment **trois lots logiques distincts** :

### Lot A — Feature voix complète ✅ À commiter maintenant
- `lib/features/voice_assistant/presentation/widgets/voice_session_sheet.dart`
- `test/voice/voice_session_sheet_test.dart`
- La partie fonctionnelle de `main_navigation_page.dart` (snackbar → `openVoiceSession`, Semantics/Tooltip)
- Le refactoring cosmétique de `main_navigation_page.dart`

### Lot B — Fix navigation post-login ❌ Ne pas commiter — à absorber dans la solution router
- La partie de `login_page.dart` qui ajoute `Navigator.pushReplacement → MainNavigationPage`
- Cette logique sera **automatiquement gérée** par le redirect GoRouter (étape 3)

### Lot C — Documentation 📄 À commiter séparément
- `docs/EXPLA2.md`, `docs/EXPLANATION.md`, `docs/KioskMind_Modelisation_v2.md`

### Ordre d'exécution

```
1. git restore lib/features/auth/presentation/pages/login_page.dart (annuler Lot B)
2. git add [Lot A] → commit "feat(voice): wire voice session sheet to nav button + accessibility"
3. git add [Lot C] → commit "docs: add architecture explanations"
4. git checkout develop (maintenant safe — rien de non commité)
5. git merge fix/voice-honest-metrics
6. Implémenter le plan navigation ci-dessous sur develop
```

---

## 3. Plan d'implémentation — Navigation dynamique

### Vue d'ensemble de l'architecture cible

```
main.dart
└── KioskMindApp (ConsumerWidget)
    └── MaterialApp.router(routerConfig: ref.watch(appRouterProvider))
                    ↑
            GoRouter avec redirect dynamique
                    ↓
        ┌──────────────────────────────────┐
        │  authStateProvider               │
        │  StreamProvider<User?>           │
        │  (Firebase authStateChanges)     │
        │                                  │
        │  onboardingSeenProvider          │
        │  (SharedPreferences flag)        │
        └──────────────────────────────────┘
                    ↓
        Redirect logic :
        - !onboardingSeen  →  /onboarding
        - user == null     →  /login
        - user != null     →  /dashboard
```

---

### ÉTAPE 0 — Pré-requis : Commiter les modifs de voix (Lot A + C)

**Durée estimée** : 15 min | **Risque** : Nul

1. `git restore lib/features/auth/presentation/pages/login_page.dart` (annuler Lot B uniquement)
2. `git add` des fichiers du Lot A
3. `git commit -m "feat(voice): wire voice session sheet to nav button and add accessibility"`
4. `git add docs/` → `git commit -m "docs: add architecture explanations"`
5. Merger `fix/voice-honest-metrics` → `develop`
6. Se positionner sur `develop` et continuer

> **Note importante** : Le changement `IndexedStack → _pages[_currentIndex]` est inclus dans Lot A mais sera **révisé à l'étape 8** pour revenir à `IndexedStack` dans la `ShellRoute`. Ce changement crée des rebuilds inutiles lors des changements d'onglets.

---

### ÉTAPE 1 — Ajouter `shared_preferences` pour persister l'onboarding

**Durée estimée** : 30 min | **Risque** : Faible

**1.1** Ajouter dans `pubspec.yaml` :
```yaml
dependencies:
  shared_preferences: ^2.3.5
```

**1.2** Créer `lib/core/storage/app_preferences.dart` (interface) :
```dart
abstract class AppPreferences {
  Future<bool> hasSeenOnboarding();
  Future<void> markOnboardingSeen();
}
```

**1.3** Créer `lib/core/storage/shared_preferences_app_prefs.dart` (implémentation concrète).

**1.4** Créer `lib/core/storage/app_preferences_provider.dart` :
```dart
// Initialisé dans main.dart via ProviderScope overrides
final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => throw UnimplementedError(),
);
```

**1.5** Créer `lib/core/storage/onboarding_seen_provider.dart` :
```dart
final onboardingSeenProvider = StateProvider<bool>((ref) => false);
// Initialisé au démarrage via main.dart après lecture SharedPreferences
```

---

### ÉTAPE 2 — Créer le `authStateProvider`

**Durée estimée** : 20 min | **Risque** : Faible

Créer `lib/features/auth/presentation/providers/auth_state_provider.dart` :
```dart
/// Expose le Stream<User?> de Firebase Auth.
/// Null = non connecté, non-null = session active.
/// Firebase résout cet état depuis son cache local au démarrage
/// sans requête réseau — redirection instantanée garanti.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
```

---

### ÉTAPE 3 — Refondre `app_router.dart` avec redirect conditionnel

**Durée estimée** : 1h | **Risque** : Moyen (cœur de la feature)

**3.1** Créer `lib/core/routing/app_routes.dart` :
```dart
abstract class AppRoutes {
  static const String splash     = '/splash';
  static const String onboarding = '/onboarding';
  static const String login      = '/login';
  static const String signup     = '/signup';
  static const String dashboard  = '/dashboard';
  static const String stock      = '/stock';
  static const String sales      = '/ventes';
  static const String profile    = '/profil';
}
```

**3.2** Refondre `lib/core/routing/app_router.dart` :
```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState      = ref.watch(authStateProvider);
  final onboardingSeen = ref.watch(onboardingSeenProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      // Attendre la résolution du stream Firebase
      if (authState.isLoading) return null;

      final bool seenOnboarding = onboardingSeen;
      final bool isLoggedIn     = authState.value != null;
      final String location     = state.uri.path;

      // Priorité 1 : Onboarding jamais vu
      if (!seenOnboarding && location != AppRoutes.onboarding) {
        return AppRoutes.onboarding;
      }

      // Priorité 2 : Non connecté sur route protégée
      final List<String> publicRoutes = [
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.splash,
      ];
      if (!isLoggedIn && !publicRoutes.contains(location)) {
        return AppRoutes.login;
      }

      // Priorité 3 : Connecté sur route publique → dashboard
      if (isLoggedIn && publicRoutes.contains(location)) {
        return AppRoutes.dashboard;
      }

      return null; // Pas de redirection
    },
    routes: [
      GoRoute(path: AppRoutes.splash,     builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingPage()),
      GoRoute(path: AppRoutes.login,      builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.signup,     builder: (_, __) => const SignupPage()),
      ShellRoute(
        builder: (_, __, child) => MainNavigationPage(child: child),
        routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const SalesDashboardPage()),
          GoRoute(path: AppRoutes.stock,     builder: (_, __) => const StockPlaceholderPage()),
          GoRoute(path: AppRoutes.sales,     builder: (_, __) => const SalesHistoryPage()),
          GoRoute(path: AppRoutes.profile,   builder: (_, __) => const ProfilePlaceholderPage()),
        ],
      ),
    ],
  );
});
```

**3.3** Adapter `app.dart` :
```dart
class KioskMindApp extends ConsumerWidget {
  const KioskMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      routerConfig: router,
      title: 'KioskMind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppToastHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
```

---

### ÉTAPE 4 — Adapter `main.dart` : initialiser `SharedPreferences`

**Durée estimée** : 15 min | **Risque** : Faible

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
  final AppPreferences appPrefs = SharedPreferencesAppPrefs(sharedPrefs);
  final bool seenOnboarding = await appPrefs.hasSeenOnboarding();

  runApp(
    ProviderScope(
      overrides: [
        appPreferencesProvider.overrideWithValue(appPrefs),
        onboardingSeenProvider.overrideWith((ref) => seenOnboarding),
      ],
      child: const KioskMindApp(),
    ),
  );
}
```

> **Pourquoi lire le flag AVANT `runApp`** : on évite un flash de redirect au premier frame. Le GoRouter a déjà la valeur dès son premier build.

---

### ÉTAPE 5 — Adapter `OnboardingPage` : marquer le flag à la fin

**Durée estimée** : 20 min | **Risque** : Faible

`_startApp()` ne navigue plus impérativement :
```dart
Future<void> _startApp() async {
  // 1. Persister le flag sur disque
  await ref.read(appPreferencesProvider).markOnboardingSeen();
  // 2. Notifier Riverpod → GoRouter redirect se re-évalue automatiquement
  ref.read(onboardingSeenProvider.notifier).state = true;
  // Pas de Navigator.push → GoRouter gère la suite selon authState
}
```

---

### ÉTAPE 6 — Nettoyer les navigations impératives dans toutes les pages

**Durée estimée** : 30 min | **Risque** : Faible

| Fichier | Code à supprimer / modifier | Remplacement |
|---------|----------------------------|--------------|
| `login_page.dart` | `Navigator.pushReplacement → MainNavigationPage` | **Supprimer** — le redirect GoRouter gère ça via `authStateProvider` |
| `login_page.dart` | `Navigator.push → SignupPage` | `context.push(AppRoutes.signup)` |
| `signup_page.dart` | `Navigator.maybePop()` retour login | `context.pop()` |
| `onboarding_page.dart` | `Navigator.pushReplacement → LoginPage` | **Supprimer** — remplacé par `_startApp()` étape 5 |

---

### ÉTAPE 7 — Splash screen / Loading state

**Durée estimée** : 20 min | **Risque** : Faible

Créer `lib/core/presentation/pages/splash_page.dart` :
```dart
/// Page affichée pendant la résolution du stream Firebase.
/// Elle n'est visible qu'une fraction de seconde.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
```

Le GoRouter redirige automatiquement depuis `/splash` dès que `authStateProvider` résout.

---

### ÉTAPE 8 — Adapter `MainNavigationPage` pour la `ShellRoute`

**Durée estimée** : 30 min | **Risque** : Faible

`MainNavigationPage` reçoit un `child` de la `ShellRoute` au lieu de gérer un `IndexedStack` interne :

```dart
class MainNavigationPage extends StatelessWidget {
  final Widget child;
  const MainNavigationPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final int currentIndex = _indexFromLocation(location);

    return Scaffold(
      extendBody: true,
      body: child, // ← géré par GoRouter (comportement équivalent à IndexedStack)
      bottomNavigationBar: _KioskMindBottomNavigation(
        currentIndex: currentIndex,
        onItemSelected: (index) => context.go(_routeFromIndex(index)),
      ),
      floatingActionButton: _VoiceButton(onPressed: () => openVoiceSession(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  int _indexFromLocation(String path) {
    return switch (path) {
      AppRoutes.dashboard => 0,
      AppRoutes.stock     => 1,
      AppRoutes.sales     => 2,
      AppRoutes.profile   => 3,
      _                   => 0,
    };
  }

  String _routeFromIndex(int index) {
    return switch (index) {
      0 => AppRoutes.dashboard,
      1 => AppRoutes.stock,
      2 => AppRoutes.sales,
      3 => AppRoutes.profile,
      _ => AppRoutes.dashboard,
    };
  }
}
```

---

### ÉTAPE 9 — Mettre à jour les tests

**Durée estimée** : 1h | **Risque** : Faible

1. **Créer** `test/routing/app_router_test.dart` — 3 scénarios de redirect :
   - `onboardingSeen=false` → redirige vers `/onboarding`
   - `onboardingSeen=true, user=null` → redirige vers `/login`
   - `onboardingSeen=true, user!=null` → redirige vers `/dashboard`

2. **Mettre à jour** `test/auth/login_page_test.dart` :
   - Supprimer les vérifications de `Navigator.pushReplacement` (navigation supprimée)
   - Vérifier que `loginProvider.state.success == true` déclenche bien le redirect (via GoRouter mock)

3. **Mettre à jour** `test/onboarding_test.dart` :
   - Vérifier que `_startApp()` appelle `markOnboardingSeen()` et met à jour `onboardingSeenProvider`

4. **Créer** `test/storage/app_preferences_test.dart`.

---

## 4. Séquence globale d'exécution

```
ÉTAPE 0 → Commit Lot A+C (voix + cosmétique) → Merger sur develop
ÉTAPE 1 → SharedPreferences + AppPreferences interface
ÉTAPE 2 → authStateProvider (Firebase Stream)
ÉTAPE 3 → Refondre app_router (redirect conditionnel + ShellRoute)
ÉTAPE 4 → main.dart (injection SharedPreferences avant runApp)
ÉTAPE 5 → OnboardingPage (marquer flag + Riverpod update)
ÉTAPE 6 → Nettoyer navigations impératives dans toutes les pages
ÉTAPE 7 → SplashPage (loading state)
ÉTAPE 8 → MainNavigationPage (adapter pour ShellRoute)
ÉTAPE 9 → Tests (router + storage + mise à jour existants)
```

---

## 5. Flux de navigation cible (après implémentation)

### Premier lancement (onboarding jamais vu, non connecté)
```
App start
  → main.dart: SharedPreferences.hasSeenOnboarding() = false
  → ProviderScope.overrides: onboardingSeenProvider = false
  → GoRouter redirect: !seenOnboarding → /onboarding
  → Utilisateur parcourt les 3 slides
  → Clique "Commencer" → markOnboardingSeen() + onboardingSeenProvider.state = true
  → GoRouter se re-évalue: seenOnboarding=true, user=null → /login
  → Utilisateur saisit ses identifiants → Firebase signIn
  → authStateProvider émet User non-null
  → GoRouter redirect: user!=null, sur /login → /dashboard
  → MainNavigationPage s'affiche ✅
```

### Deuxième lancement (onboarding vu, session Firebase active)
```
App start
  → main.dart: SharedPreferences.hasSeenOnboarding() = true
  → ProviderScope.overrides: onboardingSeenProvider = true
  → Firebase authStateChanges émet User depuis cache local
  → GoRouter redirect: seenOnboarding=true, user!=null → /dashboard directement
  → L'onboarding n'apparaît JAMAIS ✅
```

### Déconnexion
```
Utilisateur clique "Déconnexion"
  → FirebaseAuth.instance.signOut()
  → authStateProvider émet null
  → GoRouter redirect: user=null → /login automatiquement ✅
```

### Session expirée (token révoqué côté Firebase)
```
App en background, token expiré
  → Firebase émet null sur authStateChanges
  → GoRouter redirect → /login automatiquement ✅
  → Sans aucune action utilisateur
```

---

## 6. Points d'attention et risques

| Risque | Mitigation |
|--------|------------|
| **Flash d'écran** lors de la résolution du stream Firebase | SplashPage + `authStateChanges()` résout quasi-instantanément depuis le cache Firebase |
| **`appRouterProvider` re-crée un GoRouter** à chaque watch d'état | Utiliser `GoRouter.refreshListenable` ou `ChangeNotifier` pour notifier sans recréer l'instance |
| **Régression des tests existants** (`login_page_test`, `signup_page_test`) | Étape 9 obligatoire avant merge sur `develop` |
| **`IndexedStack` supprimé** dans les modifs non committées | Revenir à `IndexedStack` ou laisser GoRouter gérer la stack via `ShellRoute` (comportement équivalent) |
| **Pas de `shared_preferences`** dans `pubspec.yaml` actuellement | À ajouter explicitement (étape 1) |
| **`onboardingSeenProvider` doit se re-évaluer** sans relancer l'app | Utiliser `StateProvider<bool>` (pas `FutureProvider`) + `override` dans `main.dart` |

---

## 7. Arborescence des fichiers à créer / modifier

```
lib/
├── main.dart                                              ← MODIFIER (étape 4)
├── app.dart                                               ← MODIFIER (étape 3.3)
│
├── core/
│   ├── routing/
│   │   ├── app_routes.dart                                ← CRÉER  (étape 3.1)
│   │   └── app_router.dart                                ← REFONDRE (étape 3.2)
│   │
│   ├── storage/
│   │   ├── app_preferences.dart                           ← CRÉER (étape 1.2)
│   │   ├── shared_preferences_app_prefs.dart              ← CRÉER (étape 1.3)
│   │   ├── app_preferences_provider.dart                  ← CRÉER (étape 1.4)
│   │   └── onboarding_seen_provider.dart                  ← CRÉER (étape 1.5)
│   │
│   └── presentation/pages/
│       └── splash_page.dart                               ← CRÉER (étape 7)
│
└── features/
    ├── auth/
    │   └── presentation/
    │       ├── providers/
    │       │   └── auth_state_provider.dart               ← CRÉER (étape 2)
    │       └── pages/
    │           ├── login_page.dart                        ← MODIFIER (étape 6)
    │           └── signup_page.dart                       ← MODIFIER (étape 6)
    │
    ├── onboarding/
    │   └── presentation/pages/
    │       └── onboarding_page.dart                       ← MODIFIER (étape 5)
    │
    └── navigation/
        └── main_navigation_page.dart                      ← MODIFIER (étape 8)

test/
├── routing/
│   └── app_router_test.dart                               ← CRÉER (étape 9)
├── storage/
│   └── app_preferences_test.dart                         ← CRÉER (étape 9)
├── auth/
│   ├── login_page_test.dart                              ← METTRE À JOUR (étape 9)
│   └── signup_page_test.dart                             ← METTRE À JOUR (étape 9)
└── onboarding_test.dart                                   ← METTRE À JOUR (étape 9)
```

---

## 8. Décisions architecturales clés

| Décision | Justification |
|----------|---------------|
| **GoRouter comme source de vérité unique** | Plus aucun `Navigator.push` impératif hors du router. La navigation est traçable, testable, deep-linkable. |
| **`authStateProvider` (StreamProvider)** | Le router écoute Firebase directement. Session gérée automatiquement, même après expiration ou révocation. |
| **`StateProvider<bool>` pour l'onboarding** | Réactivité immédiate — pas d'attente d'un `FutureProvider` après `markOnboardingSeen()`. |
| **`shared_preferences`** | Léger, sans sur-ingénierie. Pas besoin de chiffrement pour un simple flag booléen. |
| **Redirect dans GoRouter** | La logique de garde est centralisée et testable — pas dans `initState` des pages. |
| **ShellRoute pour les onglets** | Chaque onglet a une URL propre, le bouton back Android fonctionne correctement, deep-links possibles. |
| **L'onboarding ne navigue plus lui-même** | Il écrit un flag et laisse le router décider de la suite selon l'état auth. |
| **Initialisation SharedPreferences avant `runApp`** | Évite un flash de redirect au premier frame — le GoRouter a déjà la valeur dès son premier build. |
