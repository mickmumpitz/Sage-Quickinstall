@echo off
setlocal enabledelayedexpansion

REM ── Set script directory ──
set "SCRIPT_DIR=%~dp0"

REM ============================================
echo ============================================
echo    Triton-Windows Quick Installer
echo ============================================
echo.

REM ── Step 1: Prompt for ComfyUI folder ──
:prompt_path
echo Step 1: Enter ComfyUI portable folder path
echo   (e.g., D:\ComfyUI_windows_portable)
set "COMFYUI_DIR="
set /p "COMFYUI_DIR=> "

if not defined COMFYUI_DIR (
    echo.
    echo   ERROR: No path entered.
    echo.
    goto prompt_path
)

REM Strip surrounding quotes
set "COMFYUI_DIR=%COMFYUI_DIR:"=%"

REM Strip trailing backslash
if "%COMFYUI_DIR:~-1%"=="\" set "COMFYUI_DIR=%COMFYUI_DIR:~0,-1%"

if not exist "!COMFYUI_DIR!" (
    echo.
    echo   ERROR: Path does not exist: !COMFYUI_DIR!
    echo.
    goto prompt_path
)

REM ── Detect python_embeded directory ──
echo.
echo   Checking for Python...
set "PYTHON_DIR="
set "PYTHON_FOLDER="
if exist "!COMFYUI_DIR!\python_embeded" (
    set "PYTHON_DIR=!COMFYUI_DIR!\python_embeded"
    set "PYTHON_FOLDER=python_embeded"
) else if exist "!COMFYUI_DIR!\python_embedded" (
    set "PYTHON_DIR=!COMFYUI_DIR!\python_embedded"
    set "PYTHON_FOLDER=python_embedded"
)

if not defined PYTHON_DIR (
    echo   ERROR: Could not find python_embeded or python_embedded in:
    echo     !COMFYUI_DIR!
    echo.
    goto prompt_path
)

echo   Found: !PYTHON_DIR!
echo.

REM ── Step 2: Environment Info ──
echo Step 2: Environment Info

REM Python version (write to temp file to avoid for /f quoting issues)
set "PY_VER=not found"
"!PYTHON_DIR!\python.exe" --version > "%TEMP%\_sage_pyver.tmp" 2>&1
if exist "%TEMP%\_sage_pyver.tmp" (
    set /p "_PY_LINE="<"%TEMP%\_sage_pyver.tmp"
    del "%TEMP%\_sage_pyver.tmp" >nul 2>&1
    for /f "tokens=2" %%A in ("!_PY_LINE!") do set "PY_VER=%%A"
)
echo   Python:   !PY_VER!

REM PyTorch version
set "TORCH_VER=not found"
"!PYTHON_DIR!\python.exe" -c "import torch; print(torch.__version__)" > "%TEMP%\_sage_torch.tmp" 2>nul
if exist "%TEMP%\_sage_torch.tmp" (
    set /p "TORCH_VER="<"%TEMP%\_sage_torch.tmp"
    del "%TEMP%\_sage_torch.tmp" >nul 2>&1
)
echo   PyTorch:  !TORCH_VER!

REM CUDA version
set "CUDA_VER=not found"
"!PYTHON_DIR!\python.exe" -c "import torch; print(torch.version.cuda)" > "%TEMP%\_sage_cuda.tmp" 2>nul
if exist "%TEMP%\_sage_cuda.tmp" (
    set /p "CUDA_VER="<"%TEMP%\_sage_cuda.tmp"
    del "%TEMP%\_sage_cuda.tmp" >nul 2>&1
)
echo   CUDA:     !CUDA_VER!
echo.

REM ── Step 3: Install triton-windows ──
echo Step 3: Installing triton-windows...
echo.

if "!TORCH_VER!"=="not found" (
    echo   ERROR: PyTorch not detected. Cannot determine triton-windows version.
    echo.
    pause
    exit /b 1
)

set "TORCH_MINOR="
for /f "tokens=1,2 delims=.+" %%A in ("!TORCH_VER!") do (
    set "TORCH_MINOR=%%B"
)

set "TRITON_SPEC="
set "TRITON_LABEL="

if "!TORCH_MINOR!"=="4" (
    set "TRITON_SPEC=triton-windows>=3.1,<3.2"
    set "TRITON_LABEL=3.1.x"
) else if "!TORCH_MINOR!"=="5" (
    set "TRITON_SPEC=triton-windows>=3.1,<3.2"
    set "TRITON_LABEL=3.1.x"
) else if "!TORCH_MINOR!"=="6" (
    set "TRITON_SPEC=triton-windows>=3.2,<3.3"
    set "TRITON_LABEL=3.2.x"
) else if "!TORCH_MINOR!"=="7" (
    set "TRITON_SPEC=triton-windows>=3.3,<3.4"
    set "TRITON_LABEL=3.3.x"
) else if "!TORCH_MINOR!"=="8" (
    set "TRITON_SPEC=triton-windows>=3.4,<3.5"
    set "TRITON_LABEL=3.4.x"
) else if "!TORCH_MINOR!"=="9" (
    set "TRITON_SPEC=triton-windows>=3.5,<3.6"
    set "TRITON_LABEL=3.5.x"
) else if "!TORCH_MINOR!"=="10" (
    set "TRITON_SPEC=triton-windows>=3.6,<3.7"
    set "TRITON_LABEL=3.6.x"
) else if "!TORCH_MINOR!"=="11" (
    set "TRITON_SPEC=triton-windows>=3.7,<3.8"
    set "TRITON_LABEL=3.7.x"
)

if not defined TRITON_SPEC (
    echo   ERROR: Unknown PyTorch minor version "!TORCH_MINOR!" - no triton mapping found.
    echo.
    pause
    exit /b 1
)

echo   PyTorch 2.!TORCH_MINOR! -^> triton-windows !TRITON_LABEL!
echo   Installing triton-windows...
echo.
"!PYTHON_DIR!\python.exe" -m pip install -U "!TRITON_SPEC!"

if !ERRORLEVEL! NEQ 0 (
    echo.
    echo   Installation failed.
    echo.
    pause
    exit /b 1
)

echo.
echo   triton-windows !TRITON_LABEL! installed successfully.
echo.
pause
