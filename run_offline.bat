@echo off
cd /d "%~dp0"
set "PYTHON_EXEC=%~dp0python_portable\python.exe"
set "PIP_EXEC=%~dp0python_portable\pip.exe"

if not exist ".venv" (
    echo Création de l'environnement virtuel …
    "%PYTHON_EXEC%" -m venv .venv
) else (
    echo Environnement virtuel déjà présent.
)

call .venv\Scripts\activate.bat

if exist "*.whl" (
    echo Installation du package local …
    "%PIP_EXEC%" install --no-index --find-links=. *.whl
) else (
    echo Aucun fichier *.whl trouvé – vérifiez le dossier.
)

if exist "requirements.txt" (
    echo Installation depuis requirements.txt …
    "%PIP_EXEC%" install --no-index --find-links=. -r requirements.txt
)

echo Lancement du script …
"%PYTHON_EXEC%" S_polars.py
pause
