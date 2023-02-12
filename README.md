# Plugin Tamil IdRef

**Tamil IdRef** est un plugin Koha qui permet d'exploiter dans Koha le
référentiel [IdRef](https://idref.fr) de l'ABES.

## Réservoir d'autorités

IdRef c'est d'abord le réservoir de **notices d'autorités** géré par l'ABES. 

- **Utilisation** - Ces notices d'autorités sont utilisées dans le Catalogue
  collectif des bibliothèques et centres de documentation des établissements
  français de l'enseignement supérieur et de la recherche, le **Sudoc**.
  D'autres bases de données utilisent IdRef : celles de l'ABES, Calames et
  Theses ; celles d'organismes ou d'établissements indépendants de l'ABES,
  comme [Frantiq](https://www.frantiq.fr).

- **PPN** -Chaque autorité est identifiée par un identifiant unique, appelé PPN

- **Types d'autorités** - Le référentiel IdRef est divisé en sous-catégories. Il
  y a plusieurs types d'autorités : Nom de personne, Nom de collectivité,
  Congrès, Nom commun, Forme ou genre Rameau, Nom géographique, Famille, Titre,
  Auteur-Titre, Nom de marque.

## Application

IdRef c'est ensuite **une application** qui permet d’interroger, d'enrichir
et/ou de corriger les notices autorités existantes, de créer de nouvelles
entités. La recherche et l’utilisation des autorités n'exigent aucune
authentification préalable. En revanche, un _login_ est impératif pour modifier
ou créer des autorités.

L'application IdRef peut être utilisée via une interface web, ou bien exploitée
directement depuis une autre application de base de données. C'est ce que permet
de faire le plugin Koha **Tamil IdRef**.

Le plugin Tamil IdRef permet d'exploiter IdRef depuis Koha et de réaliser deux
grandes catégories de tâches :

1. **Catalogage** — Dans les grilles de saisie de Koha, sur les champs que l'on
   choisit de lier à IdRef, un bouton est ajouté qui permet de lancer une
   recherche des autorités IdRef. L'autorité sélectionée sert à remplir les
   zones et sous-zones Unimarc idoines.

1. **Réalignement** — Dans le référentiel IdRef, des termes sont supprimés,
   déplacés, fusionnés. Un mécanisme exploitant les services web de IdRef permet
   de reporter automatiquement ces modifications dans le Catalogue Koha. Les
   notices bibligraphiques du Catalogue Koha sont scannées. Pour chaque chaque
   zone liée à IdRef, le PPN est contrôlé dans IdRef. Les infos d'IdRef sont
   reportés dans les notices.

## Installation

**Activation des plugins** — Si ce n'est pas déjà fait, dans Koha, activez les
plugins. Demandez à votre prestataire Koha de le faire, ou bien vérifiez les
points suivants :

- Dans `koha-conf.xml`, activez les plugins.
- Dans le fichier de configuration d'Apache, définissez l'alias `/plugins`.
  Faites en sorte que le répertoire pointé ait les droits nécessaires.

**📁 TÉLÉCHARGEMENT** — Récupérez sur le site [Tamil](https://www.tamil.fr)
l'archive de l'Extension **[Tamil
IdRef](https://www.tamil.fr/download/koha-plugin-tamil-idref-1.0.2.kpz)**.

Dans l'interface pro de Koha, allez dans `Outils > Outils de Plugins`. Cliquez
sur Télécharger un plugin. Choisissez l'archive **téléchargée** à l'étape
précédente. Cliquez sur Télécharger.

## Utilisation du plugin

### Configuration

Dans les Outils de plugins, vous voyez l'Extension **Tamil IdRef > Actions >
Configurer**. Le paramétrage est divisé en deux sections : IdRef et Page
Catalogage:

- **IdRef** — Les infos permettant d'établir un lien au service IdRef de
  l'ABES:
  - **Point d'accès** — L'URL du pont d'accès à IdRef. Par défaut
    `https://www.idref.fr`. En phase de test, on peut obtenir de l'ABES une
    autre URL.
  - **ID Client** — Identifiant de l'établissement utilisant les services web
    de l'ABES. Cet identifiant permet à l'ABES de tenir à jour des statistiques
    d'usage de ses services par établissement.

- **Page Catalogage** — Fonctionnement du plugin dans la page de catalogage de
  Koha:
  - **Activer** — Bascule permettant d'activer/desactiver l'utilisation de
    IdRef en catalogage.
  - **Champs** — La liste des champs pour lesquels le lien à IdRef est établi.
    Le lien aux zones 7xx est pleinement fonctionnel. Pour les zones Rameau
    (6xx), ce n'est pas encore totalement le cas.


### Catalogage

### Réalignement



## VERSIONS

* **1.0.2** / février 2023
* **1.0.0** / octobre 2021 — Version initiale

## LICENCE

This software is copyright (c) 2023 by Tamil s.a.r.l..

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

