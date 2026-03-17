@echo off
echo ==========================================
echo    ACTUALIZADOR DE PETTY CASH APP
echo ==========================================
echo.
echo Este script aplicará los cambios realizados (OCR, Borrado, Excel)
echo y los subirá a la web automáticamente.
echo.
echo 1. Liberando archivos y limpiando...
taskkill /F /IM dart.exe /T >nul 2>&1
taskkill /F /IM flutter.exe /T >nul 2>&1
if exist build rmdir /s /q build
echo.
echo 2. Compilando para Web (Esto puede tardar 2-3 minutos)...
call flutter build web --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo.
    echo ERROR: No se pudo compilar. Asegúrate de tener Flutter instalado.
    pause
    exit /b %errorlevel%
)
echo.
echo 3. Subiendo a Firebase...
call firebase deploy --only hosting --non-interactive --project pettycashapp-80f5e
if %errorlevel% neq 0 (
    echo.
    echo ERROR: No se pudo subir a Firebase. Revisa tu conexión.
    pause
    exit /b %errorlevel%
)
echo.
echo ==========================================
echo    ¡PROCESO COMPLETADO CON ÉXITO!
echo ==========================================
echo Ya puedes abrir https://pettycashapp-80f5e.web.app
echo Recuerda presionar Ctrl+F5 en el navegador.
echo.
pause
