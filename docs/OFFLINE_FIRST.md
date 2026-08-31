# Architecture Offline-First

> **Principe fondateur :** l'utilisateur ne doit pas perdre son travail à cause
> d'une mauvaise connexion Internet.

## 1. Le renversement

Avant, l'interface lisait l'API et se rabattait sur un cache si le réseau
manquait. C'est un modèle *network-first* : hors ligne, l'application était
dégradée, et une écriture ratée était une écriture perdue.

Désormais, la base locale est la **source de vérité de l'interface**. Le réseau
n'est plus une dépendance de l'affichage, seulement un moyen de propager.

```text
Écran
  ↓
Repository
  ↓
Base locale SQLite   ←── source de vérité de l'UI
  ↓
Sync Engine
  ↓
API Django
```

Une lecture n'échoue jamais faute de réseau. Une écriture n'est jamais perdue
faute de réseau.

## 2. Où vivent les données

| Emplacement | Contenu | Pourquoi |
|---|---|---|
| **Coffre système** (Keystore / Trousseau) | jetons JWT, vérificateur de mot de passe, session mémorisée | ce sont des secrets ; ils étaient jusqu'ici en clair dans SharedPreferences |
| **SQLite** (`dodome_offline.db`) | documents métier, file de synchronisation, correspondance d'identifiants | besoin de **transactions** : le document et son ordre d'envoi doivent être écrits ensemble ou pas du tout |

Cette séparation est délibérée : aucun secret dans la base métier, aucune donnée
métier dans le coffre.

### Pourquoi SQLite et pas un cache clé/valeur

Hive était déjà présent dans le projet mais n'était utilisé par aucun écran.
Il a été retiré. Le moteur de synchronisation doit écrire *atomiquement* un
enregistrement métier **et** l'opération correspondante — sans transaction, une
application tuée entre les deux écritures perd soit la donnée, soit l'ordre de
l'envoyer. C'est exactement ce que l'architecture doit interdire.

Les documents sont stockés **sous leur forme JSON serveur**. Les modèles du
projet n'exposent que `fromJson` : conserver la forme d'origine permet de les
réutiliser sans écrire un seul `toJson` ni dupliquer le schéma.

## 3. Identifiants temporaires

Le backend déclare `id` en lecture seule dans tous ses sérialiseurs : le client
ne peut pas imposer l'identifiant d'une création.

Une entité créée hors ligne reçoit donc un identifiant local `local:<uuid>`.
Quand le serveur accepte la création, son identifiant remplace l'ancien **dans
la base, dans la file et dans tous les payloads qui le référencent**.

La table de correspondance est conservée après coup : un écran ouvert avant la
synchronisation peut encore citer l'ancien identifiant longtemps après.

## 4. Compaction : ne pas envoyer ce qui ne sert à rien

Une heure de travail hors ligne produit des séquences très redondantes. La file
est réduite **avant** tout appel réseau :

```text
CREATE → UPDATE            ⇒ CREATE (payload fusionné)
CREATE → UPDATE → DELETE   ⇒ rien           (n'a jamais existé côté serveur)
UPDATE → UPDATE            ⇒ UPDATE fusionné
UPDATE → DELETE            ⇒ DELETE
```

Deux garde-fous : les **actions métier** (clôturer une tâche, valider une
réservation) et les **envois de fichiers** ne sont jamais fusionnés — chacun
porte un effet de bord propre — et une action *gèle* la fusion des opérations
qui la suivent, car réordonner autour d'elle changerait le résultat.

## 5. Idempotence : la condition du « zéro doublon »

Entre le moment où le serveur commite et celui où le client reçoit la réponse,
tout peut échouer. Le client ne sait alors pas si l'opération a abouti, et sa
seule option raisonnable est de réessayer.

Sans garde-fou, chaque réessai crée un doublon — donc le client cesse de
réessayer, donc des opérations se perdent.

Le client envoie un en-tête `Idempotency-Key` **stable entre les tentatives**.
Le serveur (`accounts/idempotency.py`) mémorise la première réponse réussie et
la rejoue avec `Idempotent-Replay: true`.

> **Piège rencontré :** un middleware Django s'exécute *avant* l'authentification
> DRF. `request.user` n'est alimenté que par les sessions, inexistantes pour une
> API en Bearer token. S'y fier laissait `user_id` à `None` pour tout le monde et
> rendait les clés **globales** — la clé d'un appareil pouvait renvoyer à un
> autre compte sa réponse mémorisée. Le porteur du jeton est donc résolu
> explicitement (`_resolve_user_id`). Couvert par
> `IdempotencyTests.test_keys_are_scoped_per_user`.

## 6. Conflits : une stratégie par entité, jamais globale

Appliquer « le serveur gagne » partout ferait perdre du travail hors ligne ;
« le client gagne » partout écraserait celui des collègues.

| Entité | Stratégie | Raison |
|---|---|---|
| Article, catégorie, procédure, tâche récurrente | **Fusion champ par champ** | mélange de saisie utilisateur et d'état calculé : seuls les champs réellement édités en local partent |
| Tâche d'entretien | **Serveur gagne** | le workflow (statut, étapes, clôture) applique RM-11 côté serveur |
| Mouvement de stock, commentaire, rappel | **Client gagne** | ce sont des faits datés, append-only ; le serveur n'a rien à en dire |
| Réservation | **Arbitrage manuel** | engage une ressource partagée : deux appareils hors ligne peuvent réserver le même article, seul l'utilisateur peut décider qui cède |
| Rôles, membres | **Lecture seule hors ligne** | objets de sécurité : appliquer un changement de droits en local ouvrirait une fenêtre de permissions non validées |

La fusion est une **fusion trois voies** : elle compare la version locale à la
copie serveur de référence (`base_payload`) pour distinguer « ce champ n'a pas
changé » de « ce champ a été remis à sa valeur d'origine ». Sans cette
référence, on écraserait tout.

## 7. Détection de connexion

Être associé à un Wi-Fi ne prouve pas qu'Internet fonctionne, et Internet ne
prouve pas que l'API répond (portail captif, VPN, DNS, serveur éteint).

Le changement d'interface réseau signalé par le système n'est qu'un
**déclencheur** — c'est une réponse réelle de `GET /api/health/` qui fait
basculer l'application en ONLINE. Toute requête métier aboutie sert aussi de
preuve fraîche, ce qui évite de sonder pour rien.

## 8. Authentification

| Situation | Comportement |
|---|---|
| Première connexion | **Réseau obligatoire** |
| Inscription | **Réseau obligatoire** — aucun compte local fictif |
| Connexion Google | **Réseau obligatoire** |
| Reconnexion sur un appareil connu | **Hors ligne autorisée** |
| Réouverture de l'application | **Hors ligne autorisée** |

Le mot de passe n'est jamais stocké. L'appareil conserve un **vérificateur**
PBKDF2-HMAC-SHA256 (120 000 itérations, sel aléatoire par appareil), calculé sur
un isolate secondaire pour ne pas figer l'écran de connexion. Il permet de dire
« ce mot de passe est bien celui de la dernière connexion réussie » sans pouvoir
le reconstituer ni le rejouer sur le serveur.

Une session hors ligne est acceptée pendant **30 jours** sans revalidation
serveur : trop court, l'utilisateur en déplacement est bloqué ; trop long, un
appareil perdu reste exploitable indéfiniment.

> **Bug corrigé au passage :** `SessionController._restore()` traitait toute
> erreur non-401 comme une déconnexion. Une simple coupure réseau mettait donc
> l'utilisateur dehors — et lui rendait inaccessible son travail encore en
> attente de synchronisation. Désormais seul un rejet explicite du serveur (401)
> déconnecte.

## 9. Déconnexion

Elle **refuse de s'exécuter** s'il reste des opérations en attente, sauf
confirmation explicite (`logout(force: true)`). Effacer la base d'un utilisateur
qui a travaillé une journée sans réseau, sans le prévenir, est précisément ce
que cette architecture doit empêcher.

## 10. Erreurs et reprise

- **Erreur réseau** → replanification avec backoff exponentiel : 5 s, 15 s,
  45 s, 2 min, 6 min… plafonné à 30 minutes. L'opération n'est jamais perdue.
- **Rejet métier définitif** (4xx) → l'opération reste en base, visible, et
  attend une décision de l'utilisateur.
- **409** → le serveur a déjà appliqué l'opération : c'est un succès.
- **404 sur un DELETE** → le résultat voulu est atteint : c'est un succès.
- **Opération interrompue** par une application tuée → remise en file au
  démarrage, sinon elle resterait bloquée pour toujours.

## 11. Ce qui reste volontairement en ligne

Tableau de bord, statistiques et historique filtré sont des **agrégats que seul
le serveur sait calculer**. Ils ne sont pas des entités : pas d'identifiant, pas
de modification, donc rien à mettre en file. Ils sont conservés tels quels et
servis depuis leur dernière copie hors ligne — sinon l'écran d'accueil serait
vide dès la première coupure.

L'analyse de photo par l'IA et l'invitation d'un membre exigent le réseau :
simuler leur succès produirait un état mensonger.

## 12. Ajouter une entité

Tout passe par `lib/core/offline/entity_registry.dart` : endpoints, ordre de
synchronisation, stratégie de conflit, capacité hors ligne, champs appartenant
au serveur, références vers d'autres entités. Une entrée suffit.

L'ordre de passage encode les dépendances — une catégorie avant l'article qui la
cite, l'article avant la tâche qui le cible.

## 13. Tests

```bash
flutter test                                   # 77 tests
python manage.py test accounts.tests.IdempotencyTests accounts.tests.HealthTests
```

Les tests de persistance tournent sur le **vrai moteur SQLite** (via
`sqflite_common_ffi`), pas sur un faux en mémoire : la garantie « rien n'est
perdu quand l'application est fermée » n'a de valeur que si elle porte sur le
moteur de production. Fermer puis rouvrir la base y simule exactement ce que
fait le système quand l'utilisateur tue l'application.
