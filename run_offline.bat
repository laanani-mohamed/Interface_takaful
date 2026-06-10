@echo off
cd /d "%~dp0"

set "PYTHON=%~dp0python_portable\python.exe"
set "GET_PIP=%~dp0python_portable\get-pip.py"

:: -------------------------------------------------
:: 1⃣  Vérifier que python.exe existe
:: -------------------------------------------------
if not exist "%PYTHON%" (
    echo ERREUR : python.exe introuvable dans python_portable\
    echo Verifiez que le dossier python_portable est bien present.
    pause
    exit /b 1
)

:: -------------------------------------------------
:: 2⃣  Installer pip si absent
:: -------------------------------------------------
"%PYTHON%" -m pip --version >nul 2>&1
if errorlevel 1 (
    echo Pip absent - installation via get-pip.py ...
    if not exist "%GET_PIP%" (
        echo ERREUR : get-pip.py introuvable dans python_portable\
        echo Copiez get-pip.py dans le dossier python_portable.
        pause
        exit /b 1
    )
    "%PYTHON%" "%GET_PIP%" --no-index --find-links=.
) else (
    echo Pip deja present.
)

:: -------------------------------------------------
:: 3⃣  Activer l'import des packages (pth fix)
:: -------------------------------------------------
echo import site > "%~dp0python_portable\sitecustomize.py"

:: -------------------------------------------------
:: 4⃣  Installer tous les wheels locaux
:: -------------------------------------------------
set "WHEEL_FOUND=0"
for %%F in ("%~dp0*.whl") do (
    echo Installation : %%~nxF
    "%PYTHON%" -m pip install --no-index --find-links="%~dp0" "%%F"
    set "WHEEL_FOUND=1"
)

if "%WHEEL_FOUND%"=="0" (
    echo Aucun fichier .whl trouve - verifiez le dossier Scripts.
)

:: -------------------------------------------------
:: 5⃣  Installer depuis requirements.txt
:: -------------------------------------------------
if exist "%~dp0requirements.txt" (
    echo Installation depuis requirements.txt ...
    "%PYTHON%" -m pip install --no-index --find-links="%~dp0" -r "%~dp0requirements.txt"
) else (
    echo requirements.txt absent - etape ignoree.
)

:: -------------------------------------------------
:: 6⃣  Lancer le script principal
:: -------------------------------------------------
echo.
echo ==============================
echo  Lancement de S_polars.py
echo ==============================
"%PYTHON%" "%~dp0S_polars.py"
pause
