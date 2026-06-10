@echo off
cd /d "%~dp0"

:: Chemins vers l’interpréteur Python et pip portable
set "PYTHON_EXEC=%~dp0python_portable\python.exe"
set "PIP_EXEC=%~dp0python_portable\pip.exe"

:: -------------------------------------------------
:: 1️⃣ Créer / ré‑utiliser le virtual‑env
:: -------------------------------------------------
if not exist ".venv" (
    echo Création de l'environnement virtuel …
    "%PYTHON_EXEC%" -m venv .venv
) else (
    echo Environnement virtuel déjà présent.
)

:: -------------------------------------------------
:: 2️⃣ Activer le virtual‑env
:: -------------------------------------------------
call .venv\Scripts\activate.bat

:: -------------------------------------------------
:: 3️⃣ Installer **tous** les wheels présents
:: -------------------------------------------------
set "WHEEL_FOUND=0"
for %%F in (*.whl) do (
    echo Installation du wheel %%F …
    "%PIP_EXEC%" install --no-index --find-links=. "%%F"
    set "WHEEL_FOUND=1"
)

if "%WHEEL_FOUND%"=="0" (
    echo Aucun fichier *.whl trouvé – vérifiez le dossier.
)

:: -------------------------------------------------
:: 4️⃣ (Optionnel) installer les dépendances listées 
::    dans requirements.txt (sans *.whl)
:: -------------------------------------------------
if exist "requirements.txt" (
    echo Installation depuis requirements.txt …
    "%PIP_EXEC%" install --no-index --find-links=. -r requirements.txt
)

:: -------------------------------------------------
:: 5️⃣ Lancer le script principal
:: -------------------------------------------------
echo Lancement du script …
"%PYTHON_EXEC%" S_polars.py
pause
