# IFC01 CleanUp VDTC — Documentation Technique (Polars)

Ce document décrit en détail la logique interne et le fonctionnement du script Python `S_polars.py`. Ce script assure la transformation, le nettoyage et le lettrage comptable de fichiers CSV d'assurance (encaissements et annulations) pour l'intégration dans l'ERP SunSystems.

## Architecture Globale

Le script est conçu autour de la bibliothèque **Polars**, permettant une exécution vectorisée (en C/Rust) pour traiter des fichiers volumineux de manière efficace, tout en évitant les itérations ligne par ligne (comme c'était le cas en PowerShell).

## Installation

1. Installer Python 3 (version 3.8+ recommandée).
2. Copier `S_polars.py` dans le dossier `Xfolder_test/Scripts` ou adapter `BASE_FOLDER` vers votre dossier de travail.
3. Installer la dépendance requise :
   ```bash
   pip install polars
   ```
4. Lancer le script depuis `Xfolder_test/Scripts` :
   ```bash
   python S_polars.py
   ```

> Le script attend des fichiers source dans `Brut/` et écrit les résultats dans `Ready/`. Le fichier de règles `MatriceArrondiTakaful.csv` doit rester dans `Scripts/`.

### 1. Variables de Configuration et Règles Métier

- **`BASE_FOLDER`** : Point d'entrée principal. Le script lit depuis `Brut/`, écrit dans `Ready/` et lit sa matrice dans `Scripts/`.
- **`RULES` et `PAYCLIENT_RULES`** : Structures déclaratives remplaçant les très nombreuses conditions (`if/else`) du code Legacy. Elles mappent un couple de colonnes (ex: `DECES MT prime_TTC`) vers ses attributs comptables (`Group1`, `Group2`, `CritereCompte`, etc.).

---

## Description des Fonctions

### 1. `log_error(msg)`
**Rôle :** Gère la journalisation des erreurs.
**Fonctionnement :**
Prend en entrée un message d'erreur, l'imprime dans la console de l'utilisateur et l'ajoute (en mode "append") dans le fichier `error.txt` situé à la racine du projet, avec un horodatage précis (`datetime.now()`). Cela permet un audit asynchrone des échecs de traitement de fichiers.

### 2. `parse_dmy(col_name)`
**Rôle :** Convertit et normalise les dates.
**Fonctionnement :**
Utilise l'API Expression de Polars (`pl.Expr`) pour extraire une colonne sous forme de chaîne de caractères, la parser selon le format Européen/Français `jj/mm/aaaa` (avec `str.to_date("%d/%m/%Y")`), puis la reformater immédiatement en `jjmmaaaa` (avec `dt.strftime("%d%m%Y")`). Si la date est vide ou invalide, elle renvoie une chaîne vide (grâce à `.fill_null("")`).

### 3. `build_critere_expr(pattern)`
**Rôle :** Génère l'identifiant analytique (`CritereCompte`) dynamiquement.
**Fonctionnement :**
Traduit un motif textuel (ex: `{prefix}{code3}-PRIME_TTC`) en une expression Polars. 
Il utilise des expressions régulières (`re`) pour détecter les variables `{prefix}`, `{code3}`, et `{code03}`. 
Il crée ensuite des concaténations vectorisées (`pl.concat_str`) qui vont chercher les valeurs directement dans les autres colonnes dynamiques du jeu de données (par exemple, prendre les 3 premiers caractères du `Code d'actes de Gestion`).

### 4. `process_files()`
**Rôle :** Fonction principale d'orchestration de l'ETL (Extract, Transform, Load).
**Fonctionnement détaillé par phases :**

#### A. Initialisation et Chargement
- Lit le fichier de mapping (`MatriceArrondiTakaful.csv`) en forçant la lecture en tant que texte pur (`infer_schema_length=0`) pour éviter les erreurs de typage (`i64` vs `Utf8`) lors des futurs calculs monétaires. Renomme la colonne `ID` en `CritereCompte` pour permettre la jointure.
- Boucle sur tous les fichiers présents dans le dossier `Brut/`.

#### B. Phase 1 : Nettoyage et Restructuration (.RND)
- **Nettoyage texte (Simulation PowerShell) :** Ouvre le fichier en mode texte brut (`cp1252`) et effectue un nettoyage *ligne par ligne* des espaces multiples et des caractères accentués (`è`, `é`, `ê`). Ceci empêche la destruction de la structure CSV, imitant le comportement natif de `Get-Content` sous Windows.
- **Chargement DataFrame :** Le texte nettoyé est injecté dans Polars via un buffer mémoire (`StringIO`).
- **Filtres d'éligibilité :** 
  - Si encaissement (`ENC...`) : ignore les lignes sans `Date Reglement`.
  - Si annulation (`AQ...`) : ne garde que les codes contenant un "P" en 3ème position.
- **Alignement des colonnes :** Ajout de colonnes fantômes vides si le fichier source diffère, et renommage insensible à la casse pour ignorer les changements aléatoires des entêtes sources (ex: `police` vs `Police`).
- **Unpivot (Transformation Verticale) :** Applique les `RULES` et `PAYCLIENT_RULES`. Utilise des opérations `unpivot` pour transformer une ligne horizontale (comprenant Primes, Taxes, Commissions) en autant de lignes comptables verticales, tout en calculant les signes financiers selon le type (`EQ`, `ENC`, etc.).
- **Génération Bancaire :** Génération d'une ligne de totalisation `TTLBANQUE` qui consolide le montant total encaissé/annulé par date.

#### C. Phase 2 : Lettrage et Ajustement des Écarts d'Arrondi (.SUN)
- **Jointure des Coefficients :** Fusion (`left join`) du tableau nettoyé avec la `mapping_df` via la clé `CritereCompte`.
- **Calcul Financier :** Multiplication du `Montant` par le coefficient `Data` de la matrice pour obtenir le `Solde` avec une précision strictement arrêtée à 2 décimales.
- **Regroupement et Différentiel :** Les soldes sont agrégés par bloc d'opération (`Group1` et `Group2`) pour identifier d'éventuels écarts de quelques centimes liés aux arrondis.
- **Création des lignes de redressement :** 
  - Si la somme du bloc diffère de `0`, une ligne correctrice (contrepartie) est générée automatiquement.
  - Selon l'écart (supérieur à `0.01` ou inférieur à `-0.01`), le compte bascule sur `GRANDECARTP` / `GRANDECARTN` ou `ECARTPOSITIF` / `ECARTNEGATIF`.
  - La fonction `.first()` de Polars est utilisée avec `maintain_order=True` pour extraire intelligemment le `NoPolice` et `CodeIFC` de la première transaction financière du bloc, garantissant la complétude de la ligne d'ajustement.

#### D. Exportation finale
- Aligne l'ordre final de la trentaine de colonnes nécessaires au format attendu par SunSystems.
- Exporte conjointement vers 2 fichiers (un `.SUN` et un `.csv`) dans le dossier `Ready/`, en utilisant un délimiteur `;` et en forçant l'absence totale de guillemets (`quote_style="never"`).
