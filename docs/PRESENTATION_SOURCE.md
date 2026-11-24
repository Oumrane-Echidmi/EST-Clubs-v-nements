# EST Clubs & Événements — Source pour la présentation (8 diapositives)

> Document destiné à l'outil de présentation (MXbook / IA slides). Tout ce qui est ici est vérifié dans le code du dépôt, sauf les passages marqués **(général)** = connaissance générale, pas une mesure faite sur ce projet.
> Langue conseillée de la présentation : français. Style visuel : reprendre la charte de l'application (voir « Design » en fin de document).

---

## DIAPO 1 — Titre

- **Titre** : EST Clubs & Événements
- **Sous-titre** : Application mobile Android de gestion des clubs et des événements du campus
- **Établissement** : École Supérieure de Technologie (EST) — Université Ibn Zohr (UIZ), Agadir
- **Type de projet** : Projet de fin de module / application mobile + API
- **Équipe (2 développeurs)** : Développeur 1 = application mobile Flutter ; Développeur 2 = backend NestJS / base de données. *(à compléter : noms, encadrant, année universitaire 2026)*
- **Accroche** : « Découvre les clubs, ne rate aucun événement, inscris-toi en 1 clic. »
- **Visuels disponibles** : captures d'écran de l'app (login, accueil, clubs, détail événement, tableau de bord club) ; maquettes Stitch dans `docs/design/`.

---

## DIAPO 2 — Besoins et problématique

**Contexte** : à l'EST, la vie associative (8 clubs : informatique/cyber, robotique, théâtre, sport, solidarité, entrepreneuriat/Enactus, photo/cinéma, musique) s'organise par affiches, groupes de messagerie et formulaires papier.

**Problèmes constatés**
1. Information dispersée : l'étudiant ne sait pas quels événements existent ni quand.
2. Inscriptions non fiables : pas de limite de places → sur-réservation, listes papier perdues.
3. Pas de suivi : le bureau du club ne sait pas combien de personnes viendront ni qui était présent.
4. Pas de validation : n'importe quel événement peut être annoncé sans contrôle de l'administration.
5. Pas de rappel : l'étudiant oublie, les places restent vides.

**Problématique** : *Comment centraliser et fiabiliser la découverte, l'inscription et le suivi des événements associatifs du campus, pour trois types d'acteurs (étudiants, bureaux de clubs, administration) ?*

**Besoins fonctionnels**
- Étudiant : voir clubs/événements, s'inscrire/annuler, retrouver ses inscriptions, recevoir des notifications, ajouter au calendrier.
- Bureau de club : créer/modifier/supprimer ses événements, suivre les inscrits, pointer les présences, gérer la fiche du club.
- Super administrateur : valider ou refuser les événements, gérer les utilisateurs (activer/désactiver), voir les statistiques.

**Besoins non fonctionnels** : sécurité (authentification, rôles), fiabilité (jamais plus d'inscrits que de places), rapidité, simplicité, interface en français, utilisable sur smartphone.

---

## DIAPO 3 — Fonctionnalités conceptuelles

### Trois rôles
| Rôle | Ce qu'il fait |
| --- | --- |
| **STUDENT** (étudiant) | Accueil personnalisé, clubs (recherche, filtres, suivre), événements (recherche, filtres par thématique), détail avec compte à rebours, s'inscrire / annuler avec confirmation, « Mes inscriptions » (à venir / terminées / annulées), notifications, profil, ajout au calendrier |
| **CLUB_ADMIN** (bureau du club) | Tableau de bord (alerte billetterie, total inscriptions, remplissage), créer/modifier/supprimer événement (avec affiche), liste des inscrits, pointer présent, annuler une inscription, export CSV, modifier la fiche du club (description, logo) |
| **SUPER_ADMIN** | Statistiques globales, validation des événements (approuver / refuser avec motif), recherche d'utilisateurs, activer/désactiver un compte |

### Règles métier importantes (décidées par le serveur)
- Une inscription réserve une place ; **jamais de sur-réservation** (verrou de ligne PostgreSQL `SELECT … FOR UPDATE`).
- États d'inscription calculés par le serveur : OPEN, FULL, DEADLINE_PASSED, NOT_PUBLISHED, ENDED, REGISTERED, CANCELLED_BY_ME.
- Annulation possible seulement avant le début moins 60 minutes (réglable).
- Un événement créé par un bureau est **en attente de validation** ; l'administrateur le publie ou le refuse (avec motif).
- Modifier un événement publié (titre, dates, capacité…) le renvoie en validation.
- Notifications : nouvel événement, inscription confirmée/annulée, événement modifié, rappels 24 h et 1 h avant.

### Fonctionnalités de l'application mobile (écrans)
Onboarding · Connexion (étudiant / bureau) · Inscription · Mot de passe oublié / réinitialisation · Accueil · Clubs + détail · Agenda (événements) + détail · Mes inscriptions · Profil (modifier, mot de passe, notifications) · Tableau de bord club · Formulaire événement · Inscrits · Éditeur de club · Statistiques admin · Validation · Utilisateurs.

---

## DIAPO 4 — Pourquoi Flutter ? Pourquoi une application mobile ? Pourquoi ces plateformes ?

### 4.1 Pourquoi une application mobile (et pas seulement un site)
| Argument | Preuve / explication |
| --- | --- |
| L'étudiant a toujours son téléphone | Cible = étudiants : usage quotidien du smartphone **(général)** |
| Notifications push et rappels | Rappels 24 h / 1 h avant l'événement, alertes « places limitées » (API prête ; push FCM prévu, non branché) |
| Appareil photo / galerie / calendrier | Envoi d'affiche, logo, avatar ; **ajout de l'événement au calendrier du téléphone** (fonction implémentée) |
| Session persistante et sécurisée | Jetons stockés dans le stockage sécurisé du téléphone (Keystore Android) |
| Expérience fluide et hors-ligne partiel | Images en cache, interface réactive |

### 4.2 Pourquoi Flutter (tableau comparatif)
| Critère | Flutter | Natif Android (Kotlin) | React Native | Web (PWA) |
| --- | --- | --- | --- | --- |
| Un seul code pour Android **et** iOS | Oui | Non (Android seul) | Oui | Oui |
| Interface identique à la maquette (pixel-perfect) | Oui : moteur de rendu propre | Oui | Dépend des composants natifs | Oui |
| Rapidité de développement (hot reload) | Très bon | Moyen | Bon | Bon |
| Performance | Code compilé en natif (ARM) | Excellente | Via un pont JS | Moyenne |
| Accès caméra/calendrier/stockage sécurisé | Plugins officiels | Natif | Plugins | Limité |
| Langage | Dart (typé, proche Java/TS) | Kotlin | JavaScript/TS | JS |

**Preuves tirées de CE projet**
- **Un seul code Dart (≈ 5 200 lignes)** a produit : un APK Android, une version web (utilisée pour vérifier chaque écran) et la base iOS.
- **Les maquettes Stitch ont été reproduites à l'identique** (cartes, dégradés, chips, frise de progression) grâce à la liberté de rendu de Flutter.
- **34 tests automatisés passent** (tests unitaires et de widgets) + 6 tests « live » contre le vrai serveur.
- Même technologie sur 3 cibles : `flutter build apk`, `flutter build web` réussis.
- Hot reload : itérations très rapides sur l'interface (plusieurs dizaines de passes de design).

### 4.3 Pourquoi cette pile technique (« ces types de plateformes »)
| Brique | Choix | Raison |
| --- | --- | --- |
| Mobile | Flutter + Dart, Material 3 | Un code, deux plateformes, UI sur mesure |
| État | Riverpod | Simple, testable, pas de dépendance au contexte |
| Navigation | GoRouter | Redirections par rôle, liens profonds |
| Réseau | Dio + intercepteur | Jeton automatique, rafraîchissement unique sur 401 |
| API | NestJS (TypeScript) | Architecture modulaire, validation, Swagger |
| Base de données | PostgreSQL + Prisma | Transactions, verrous, contraintes CHECK, migrations |
| Conteneurs | Docker Compose | Base de données identique pour toute l'équipe |
| Design | Google Stitch → code Flutter | Maquettes UI générées puis fidèlement reproduites |

---

## DIAPO 5 — Permissions nécessaires

### 5.1 Permissions de l'application Android (manifeste)
| Permission | Pourquoi | Statut |
| --- | --- | --- |
| `INTERNET` | Appels vers l'API (connexion, événements, inscriptions) | **Obligatoire** — déclarée |
| `READ_MEDIA_IMAGES` | Choisir une photo (avatar, affiche, logo) via la galerie | Demandée uniquement quand l'utilisateur choisit une image |
| Accès calendrier | « Ajouter au calendrier » | Passe par l'application Calendrier du téléphone (l'utilisateur confirme) |
| `POST_NOTIFICATIONS` (Android 13+) | Notifications push | **Prévue** (Firebase non branché dans cette version ; les notifications existent dans l'app) |
| Trafic HTTP non chiffré | Uniquement en **debug** pour joindre le serveur de test local | Désactivé en production → **HTTPS obligatoire** |

iOS (clés ajoutées) : `NSPhotoLibraryUsageDescription`, `NSCalendarsUsageDescription`, `NSCalendarsFullAccessUsageDescription`.
Principe : **le minimum de permissions**, demandées au moment de l'usage.

### 5.2 Permissions par rôle (RBAC, appliquées côté serveur)
| Action | Étudiant | Bureau club | Super admin |
| --- | :-: | :-: | :-: |
| Voir clubs approuvés / événements publiés | ✔ | ✔ | ✔ |
| S'inscrire / annuler sa place | ✔ | — | — |
| Créer / modifier / supprimer un événement | ✖ | ✔ (son club seulement) | ✔ |
| Voir les inscrits, pointer présent | ✖ | ✔ (son club) | ✔ |
| Approuver / refuser un événement | ✖ | ✖ | ✔ |
| Gérer les utilisateurs (activer, rôle) | ✖ | ✖ | ✔ |
| Statistiques globales | ✖ | ✖ | ✔ |

Sécurité associée : mots de passe hachés (bcrypt, coût 12) ; jeton d'accès 15 min ; jeton de rafraîchissement 30 jours **rotatif avec détection de réutilisation** ; limitation de débit (10 connexions / 15 min) ; en-têtes Helmet ; validation stricte des entrées ; le serveur recharge rôle et statut du compte à chaque requête.

---

## DIAPO 6 — Architecture du projet

```
┌──────────────────────┐   HTTPS / JSON    ┌───────────────────────────┐    SQL     ┌──────────────┐
│  Application Flutter │ ───────────────▶  │   API REST NestJS (/api)  │ ─────────▶ │ PostgreSQL 17│
│  (Android / iOS/web) │ ◀───────────────  │  JWT · Guards · Swagger   │ ◀───────── │  via Prisma  │
└──────────────────────┘  {data, meta}     └───────────────────────────┘            └──────────────┘
   Riverpod · GoRouter · Dio                 Tâches planifiées (rappels)               12 tables
   Stockage sécurisé (jetons)                Stockage fichiers (images WebP)           contraintes CHECK
```

### Application mobile (Flutter) — architecture par fonctionnalité
```
mobile/lib/
 ├─ core/     config (URL API) · network (Dio + refresh) · router (redirection par rôle)
 │            theme (charte Stitch) · widgets réutilisables · stockage sécurisé
 └─ features/ auth · home · clubs · events · club_admin · super_admin · notifications · profile
              (chaque feature : data → repository, domain → modèles, presentation → écrans)
```
Principe : **écran → provider (Riverpod) → repository → Dio → API**. Le serveur est la seule source de vérité (places, états, droits).

### Backend (NestJS) — modules
`auth · users · clubs · club-members · events · registrations · notifications · announcements · uploads · calendar · home · admin` — chacun avec contrôleur, service, DTO validés, gardes (JWT, rôles, portée du club).

### Base de données — 12 tables
User, Club, ClubMember, ClubFollow, Event, Registration, Announcement, Notification, DeviceToken, RefreshToken, PasswordResetToken, NotificationOutbox.
Places disponibles **jamais stockées** : `capacité − inscrits actifs`, calculé à chaque lecture.

### Chiffres clés (vérifiés)
| Élément | Valeur |
| --- | --- |
| Endpoints REST documentés (OpenAPI) | **56** (36 schémas) |
| Code Flutter / Dart | ≈ **5 200** lignes |
| Code backend TypeScript | ≈ **4 000** lignes |
| Tests mobile automatisés | **34** (unitaires + widgets) + **6** tests live contre l'API |
| Tests backend (rapport de vérification) | 10 unitaires + 28 d'intégration, dont la course de 20 inscriptions simultanées pour 5 places → exactement 5 réussies et 15 `EVENT_FULL` |
| Données de démonstration | 182 utilisateurs, 8 clubs, 29 événements, ≈ 1 055 inscriptions |

### Qualité / DevOps
Git (branches main/develop, commits conventionnels) · Docker Compose · OpenAPI + Swagger (`/api/docs`) · documentation `docs/` (API, intégration, vérification, sécurité).

---

## DIAPO 7 — Workflow complet (parcours utilisateur)

### 7.1 Parcours étudiant
```
Lancement → (1re fois) Onboarding 3 écrans → Connexion (ou Créer un compte / Mot de passe oublié)
   → Accueil : hero événement + clubs en direct + filtres + liste de la semaine
      ├─ Clubs → fiche club → Suivre / voir ses événements
      ├─ Agenda → recherche + filtre thématique → Détail événement
      │      └─ « Réserver ma place » → confirmation → inscrit (places −1, notification)
      │              └─ « Annuler » (si autorisé) → places +1  |  « Ajouter au calendrier »
      ├─ Pass → Mes inscriptions : À venir / Terminées / Annulées
      └─ Profil → modifier, mot de passe, notifications, déconnexion
```

### 7.2 Parcours bureau de club
```
Connexion (Bureau) → Tableau de bord : alerte billetterie · total inscriptions · remplissage
   → Créer un événement (titre, description, lieu, dates, capacité, catégorie, affiche)
        → statut « En attente de validation »
   → (après approbation) événement visible des étudiants
   → Inscrits : liste, pointer « Présent », annuler, export CSV
   → Mon club : description, logo        |  Bascule « Étudiant » pour voir l'app comme un étudiant
```

### 7.3 Parcours super administrateur
```
Connexion → Statistiques (utilisateurs, clubs, événements, inscriptions, en attente)
   → Validation : événement en attente → Approuver (publié + notifications) ou Refuser (motif obligatoire)
   → Utilisateurs : recherche → activer / désactiver un compte
```

### 7.4 Flux technique d'une inscription (détail pour un schéma de séquence)
1. L'étudiant appuie sur « Réserver » → l'app envoie `POST /events/{id}/register` avec son jeton.
2. Le serveur ouvre une transaction et **verrouille la ligne de l'événement**.
3. Il vérifie : publié ? délai non dépassé ? pas déjà inscrit ? places restantes ?
4. Il crée l'inscription (ou réactive une annulée) et valide la transaction.
5. **Après** validation : notification créée (une erreur de notification n'annule pas l'inscription).
6. L'app recharge l'événement : nouvelles places, nouvel état « REGISTERED », bouton « Annuler » si autorisé.
Erreurs normalisées : `EVENT_FULL`, `ALREADY_REGISTERED`, `REGISTRATION_CLOSED`, `CANCELLATION_NOT_ALLOWED`… traduites en français dans l'app.

### 7.5 Session et sécurité (schéma possible)
Jeton d'accès expiré (401) → **un seul** appel de rafraîchissement partagé par toutes les requêtes en cours → nouvelle paire de jetons → requêtes rejouées une fois. Échec → déconnexion automatique.

---

## DIAPO 8 — Merci / Questions

- « Merci de votre attention — des questions ? »
- Rappel en 3 points : **un code Flutter**, **une API sûre (aucune sur-réservation)**, **trois rôles couverts de bout en bout**.
- Démo possible : connexion étudiant → réserver → voir les places diminuer → connexion bureau → pointer présent.

---

## ANNEXES (pour les questions du jury)

### État du projet et limites (honnêteté)
- ✔ Fonctionnel de bout en bout : application ↔ API vérifiée par tests automatisés réels et captures d'écran sur données de démonstration.
- ✔ APK de débogage généré et configuré pour un téléphone sur le même Wi-Fi.
- ✖ **Pas encore testé sur un émulateur/téléphone Android** pendant le développement (vérification faite sur la version web et par tests).
- ✖ Notifications push (Firebase/FCM) **non branchées** ; les notifications internes à l'application fonctionnent.
- ✖ Pas de scan de QR code (remplacé par pointage manuel des présences) ; pas de gestion de clubs par le super administrateur dans l'app (réalisable via l'API).
- Traductions : français par défaut ; anglais et arabe partiellement préparés.

### Perspectives
Notifications push FCM · QR code de présence · gestion des clubs par l'administrateur · statistiques détaillées par club (série temporelle côté API) · mode hors-ligne · publication sur le Play Store (HTTPS obligatoire).

### Design (charte à reprendre dans les slides)
- Couleurs : bleu marine `#1E3A8A` / `#00236F` ; orange d'action `#F97316` ; fond `#F8F9FF` ; texte `#0B1C30`.
- Polices : Plus Jakarta Sans (titres), Inter (texte).
- Style : cartes blanches arrondies (16 px), photos de clubs, pastilles, barre de progression bleu→orange.
- Maquettes source : projet Google Stitch « EST Clubs & Événements App » (4 écrans) ; exports HTML dans `docs/design/`.

### Comptes de démonstration (pour la démo)
`student1@est.example.edu` (étudiant) · `clubadmin2@est.example.edu` (bureau du club Informatique & Cybersécurité) · `superadmin@est.example.edu` (administrateur). Mot de passe : valeur de `SEED_PASSWORD` dans `backend/.env` (non publiée).

### Où trouver quoi dans le dépôt
`README.md` (démarrage) · `docs/API.md` + `docs/openapi.json` (contrat) · `docs/TASKS.md` (état) · `docs/INTEGRATION.md` · `docs/VERIFICATION.md` · `mobile/README.md` · `backend/README.md` · `docs/design/` (maquettes).
