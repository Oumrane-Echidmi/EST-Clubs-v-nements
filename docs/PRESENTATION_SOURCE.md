# EST Clubs & Événements — Source pour la présentation (8 diapositives)

> Document de référence pour l'outil de présentation. Contenu général, volontairement non technique.
> Langue conseillée : français.

---

## DIAPO 1 — Titre

- **Titre** : EST Clubs & Événements
- **Sous-titre** : Application mobile de gestion des clubs et des événements du campus
- **Établissement** : École Supérieure de Technologie (EST) — Université Ibn Zohr, Agadir
- **Équipe** : 2 étudiants développeurs (une personne sur l'application mobile, une sur le serveur et la base de données) *(à compléter : noms, encadrant, année universitaire)*
- **Accroche** : « Découvre les clubs, ne rate aucun événement, inscris-toi en 1 clic. »

---

## DIAPO 2 — Besoins et problématique

**Contexte** : la vie associative de l'EST compte plusieurs clubs (informatique et cybersécurité, robotique, théâtre, sport, solidarité, entrepreneuriat, photo et cinéma, musique). Aujourd'hui, l'information circule par affiches, groupes de messagerie et listes papier.

**Problèmes constatés**
1. L'information est dispersée : les étudiants ne savent pas quels événements existent.
2. Les inscriptions ne sont pas fiables : pas de limite de places, listes perdues.
3. Le bureau du club ne sait pas combien de personnes viendront, ni qui était présent.
4. Aucun contrôle de l'administration avant la publication d'un événement.
5. Aucun rappel : l'étudiant oublie, les places restent vides.

**Problématique** : *Comment centraliser et fiabiliser la découverte, l'inscription et le suivi des événements associatifs du campus pour trois types d'acteurs : les étudiants, les bureaux de clubs et l'administration ?*

**Besoins des utilisateurs**
- **Étudiant** : voir les clubs et événements, s'inscrire ou annuler, retrouver ses inscriptions, être prévenu, ajouter l'événement à son agenda.
- **Bureau de club** : publier ses événements, suivre les inscrits, noter les présences, présenter son club.
- **Administration** : valider les événements, gérer les comptes, suivre l'activité du campus.

**Exigences générales** : sécurité des comptes, fiabilité des places, rapidité, simplicité d'usage, interface en français, utilisation sur smartphone.

---

## DIAPO 3 — Fonctionnalités conceptuelles

### Trois profils d'utilisateurs
| Profil | Ce qu'il peut faire |
| --- | --- |
| **Étudiant** | Accueil personnalisé · découvrir et suivre les clubs · rechercher et filtrer les événements par thématique · voir le détail avec compte à rebours · s'inscrire ou annuler · consulter « Mes inscriptions » (à venir, terminées, annulées) · recevoir des notifications · ajouter à son calendrier · gérer son profil |
| **Bureau de club** | Tableau de bord du club · créer, modifier, supprimer un événement avec son affiche · voir la liste des inscrits · noter les présences · exporter la liste · modifier la présentation du club |
| **Administrateur** | Statistiques globales · valider ou refuser les événements (avec un motif) · rechercher les utilisateurs · activer ou désactiver un compte |

### Règles de fonctionnement
- Une place réservée est garantie : **jamais plus d'inscrits que de places**.
- L'état de chaque événement est clair pour l'étudiant : ouvert, complet, inscriptions closes, terminé, déjà inscrit…
- L'annulation est possible jusqu'à une heure avant le début.
- Un événement créé par un club est **soumis à validation** avant d'être visible.
- Des **notifications** informent des nouveaux événements, des confirmations, des modifications et des rappels (24 h et 1 h avant).

### Écrans principaux
Présentation d'accueil · Connexion · Création de compte · Accueil · Clubs · Agenda des événements · Détail d'un événement · Mes inscriptions · Profil · Tableau de bord du club · Gestion des inscrits · Statistiques et validation pour l'administration.

---

## DIAPO 4 — Pourquoi Flutter ? Pourquoi une application mobile ?

### Pourquoi une application mobile
| Argument | Explication |
| --- | --- |
| Toujours à portée de main | Les étudiants utilisent leur smartphone en permanence |
| Notifications et rappels | Prévenir au bon moment, réduire les places vides |
| Appareil photo, galerie, calendrier | Ajouter une affiche, une photo de profil ; enregistrer l'événement dans l'agenda du téléphone |
| Connexion mémorisée et sécurisée | L'étudiant reste connecté sans ressaisir son mot de passe |
| Expérience fluide | Affichage rapide, images conservées en mémoire |

### Pourquoi Flutter (comparatif)
| Critère | Flutter | Natif Android | React Native | Site web |
| --- | --- | --- | --- | --- |
| Un seul développement pour Android et iOS | Oui | Non | Oui | Oui |
| Interface fidèle à la maquette | Excellente | Excellente | Bonne | Bonne |
| Rapidité de développement | Très bonne | Moyenne | Bonne | Bonne |
| Performance | Très bonne (application compilée) | Excellente | Bonne | Moyenne |
| Accès aux fonctions du téléphone | Oui | Oui | Oui | Limité |
| Coût de maintenance | Faible (un seul projet) | Élevé si deux plateformes | Moyen | Faible |

**Pourquoi nous l'avons choisi**
- Un seul projet pour Android, iOS et le web : gain de temps et de maintenance pour une équipe de deux.
- Liberté totale sur l'interface : le résultat est identique à la maquette de conception.
- Technologie soutenue par Google, grande communauté, mises à jour régulières.
- Démonstration possible sur plusieurs supports à partir du même travail.

### Choix des plateformes
- **Smartphone Android** en priorité : plateforme la plus répandue chez les étudiants.
- **Serveur centralisé** : une seule source de vérité pour toutes les données.
- **Base de données relationnelle** : adaptée aux inscriptions, aux places et aux droits.

---

## DIAPO 5 — Permissions nécessaires

### Permissions de l'application sur le téléphone
| Permission | Pourquoi | Quand |
| --- | --- | --- |
| **Internet** | Échanger avec le serveur (connexion, événements, inscriptions) | Toujours |
| **Photos / galerie** | Choisir une photo de profil, une affiche ou un logo | Seulement quand l'utilisateur choisit une image |
| **Calendrier** | Ajouter un événement à l'agenda | À la demande de l'utilisateur, avec sa confirmation |
| **Notifications** | Recevoir les rappels et les alertes | À l'activation par l'utilisateur |

Principe : **demander le strict minimum**, uniquement au moment où la fonction est utilisée.

### Droits selon le profil
| Action | Étudiant | Bureau de club | Administrateur |
| --- | :-: | :-: | :-: |
| Consulter clubs et événements publiés | ✔ | ✔ | ✔ |
| S'inscrire / annuler sa place | ✔ | — | — |
| Créer / modifier / supprimer un événement | ✖ | ✔ (son club) | ✔ |
| Voir les inscrits, noter les présences | ✖ | ✔ (son club) | ✔ |
| Valider ou refuser un événement | ✖ | ✖ | ✔ |
| Gérer les comptes utilisateurs | ✖ | ✖ | ✔ |
| Consulter les statistiques globales | ✖ | ✖ | ✔ |

### Sécurité
Mots de passe protégés · connexion à durée limitée et renouvelée automatiquement · limitation des tentatives · vérification des droits à chaque action · données échangées de façon sécurisée.

---

## DIAPO 6 — Architecture du projet

```
┌─────────────────────┐        ┌─────────────────────────┐        ┌───────────────────────┐
│ Application mobile  │ ─────▶ │  Serveur (API)          │ ─────▶ │ Base de données       │
│ Étudiants, bureaux, │ ◀───── │  Règles métier, droits, │ ◀───── │ Clubs, événements,    │
│ administrateurs     │        │  sécurité, notifications│        │ inscriptions, comptes │
└─────────────────────┘        └─────────────────────────┘        └───────────────────────┘
        Flutter                    Services web (REST)                PostgreSQL
```

### Les trois couches
1. **Application mobile** : affiche les informations et envoie les demandes de l'utilisateur. Elle ne décide jamais des places ni des droits.
2. **Serveur** : applique toutes les règles (places disponibles, délais, droits par profil, validation des événements), envoie les notifications, stocke les images.
3. **Base de données** : conserve clubs, événements, inscriptions, utilisateurs et notifications, avec des contraintes qui empêchent les données incohérentes.

### Principe clé
Le serveur est la **seule source de vérité** : le nombre de places restantes est recalculé à chaque consultation, ce qui évite toute erreur de comptage.

### Organisation du travail
Répartition en deux parties (mobile / serveur) · interface conçue d'abord sous forme de maquettes puis reproduite fidèlement · documentation partagée · données de démonstration réalistes pour présenter l'application.

### Quelques repères
- 3 profils d'utilisateurs · 8 clubs · une trentaine d'événements de démonstration · plus de 1 000 inscriptions de démonstration.

---

## DIAPO 7 — Workflow complet (parcours utilisateur)

### Parcours de l'étudiant
```
Ouverture de l'application → (première fois) présentation en 3 écrans → Connexion
   → Accueil : événement à la une · clubs · filtres par thématique · événements de la semaine
      ├─ Clubs → fiche d'un club → suivre le club / voir ses événements
      ├─ Agenda → rechercher / filtrer → fiche de l'événement
      │      └─ « Réserver ma place » → confirmation → inscription validée + notification
      │              └─ « Annuler » (si possible)   |   « Ajouter au calendrier »
      ├─ Mes inscriptions : à venir / terminées / annulées
      └─ Profil : modifier ses informations, mot de passe, notifications, déconnexion
```

### Parcours du bureau de club
```
Connexion (espace bureau) → Tableau de bord : alerte billetterie · total des inscriptions · remplissage
   → Créer un événement (titre, description, lieu, dates, capacité, affiche)
        → « En attente de validation »
   → Après approbation : l'événement devient visible pour les étudiants
   → Suivi des inscrits : liste, présences, export
   → Présentation du club : description et logo
```

### Parcours de l'administrateur
```
Connexion → Statistiques (utilisateurs, clubs, événements, inscriptions)
   → Validation des événements : approuver, ou refuser avec un motif
   → Utilisateurs : recherche, activation ou désactivation d'un compte
```

### Déroulé d'une inscription (pour un schéma de séquence)
1. L'étudiant ouvre un événement et appuie sur « Réserver ma place ».
2. Une confirmation lui est demandée.
3. Le serveur vérifie : événement publié ? délai respecté ? pas déjà inscrit ? places disponibles ?
4. Si tout est correct, la place est réservée immédiatement.
5. Une notification de confirmation est envoyée.
6. L'écran se met à jour : places restantes, état « Inscrit », possibilité d'annuler ou d'ajouter à l'agenda.
Si l'événement est complet ou fermé, l'étudiant reçoit un message clair en français.

---

## DIAPO 8 — Merci / Questions

- « Merci pour votre attention — nous restons à votre disposition pour vos questions. »
- À retenir : **une application pour trois profils**, **des inscriptions fiables sans sur-réservation**, **une expérience simple et rapide sur smartphone**.
- Démonstration possible : un étudiant réserve une place → le nombre de places diminue → le bureau du club voit l'inscrit et note sa présence.

---

## ANNEXES (pour les questions)

### Limites actuelles et perspectives
- Notifications poussées sur le téléphone : prévues (les notifications dans l'application fonctionnent déjà).
- Présence par QR code : prévue (aujourd'hui, le bureau note les présences à la main).
- Gestion des clubs par l'administrateur depuis l'application : à ajouter.
- Évolutions : statistiques détaillées par club, mode hors ligne, publication sur le Play Store.

### Identité visuelle
- Couleurs : bleu marine (confiance, institution) et orange (action, énergie), fond clair.
- Style : cartes blanches arrondies, photos de clubs, pastilles de statut, barres de progression des places.
- Ton : moderne, simple, en français.

### Profils pour la démonstration
Un compte étudiant, un compte bureau de club et un compte administrateur sont disponibles avec des données réalistes.
