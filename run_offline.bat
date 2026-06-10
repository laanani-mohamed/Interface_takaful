@echo off
:: -------------------------------------------------
::  Double‑clic : crée l'environnement, installe le wheel et lance le script
:: -------------------------------------------------

:: 1️⃣ Se placer dans le répertoire du script
cd /d "%~dp0"

:: 2️⃣ Créer l'environnement virtuel (si absent)
if not exist ".venv" (
    echo Création de l'environnement virtuel …
    python -m venv .venv
) else (
    echo Environnement virtuel déjà présent.
)

:: 3️⃣ Activer l'environnement
call .venv\Scripts\activate.bat

:: 4️⃣ Installer le wheel local (aucun accès Internet)
if exist "*.whl" (
    echo Installation du package local …
    pip install --no-index --find-links=. *.whl
) else (
    echo Aucun fichier *.whl trouvé – vérifiez le dossier.
)

:: 5️⃣ (Optionnel) installer les dépendances listées dans requirements.txt
if exist "requirements.txt" (
    echo Installation depuis requirements.txt …
    pip install --no-index --find-links=. -r requirements.txt
)

:: 6️⃣ Lancer le script principal
echo Lancement du script …
python S_polars.py

:: 7️⃣ Garder la fenêtre ouverte
pause
