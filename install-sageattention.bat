@echo off
setlocal enabledelayedexpansion

REM ── Set script directory ──
set "SCRIPT_DIR=%~dp0"

REM ============================================
echo ============================================
echo    SageAttention Quick Installer
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

REM ── Step 3: List available wheels ──
:select_wheel
echo Step 3: Select wheel

set "WHL_COUNT=0"
for %%F in ("%SCRIPT_DIR%assets\wheels\sageattention*.whl") do (
    set /a WHL_COUNT+=1
    set "WHL_!WHL_COUNT!=%%F"
    set "WHL_NAME_!WHL_COUNT!=%%~nxF"
)

if %WHL_COUNT% EQU 0 (
    echo.
    echo   ERROR: No sageattention .whl files found in %SCRIPT_DIR%assets\wheels\
    echo.
    pause
    exit /b 1
)

for /l %%I in (1,1,%WHL_COUNT%) do (
    echo   [%%I] !WHL_NAME_%%I!
)
echo   [0] Cancel
echo.

:prompt_choice
set "USER_CHOICE="
set /p "USER_CHOICE=  Choose [0-%WHL_COUNT%]: "

if not defined USER_CHOICE goto prompt_choice

if "%USER_CHOICE%"=="0" (
    echo.
    echo   Cancelled.
    pause
    exit /b 0
)

REM Validate choice is a number in range
set "VALID=0"
for /l %%I in (1,1,%WHL_COUNT%) do (
    if "%USER_CHOICE%"=="%%I" set "VALID=1"
)

if "%VALID%"=="0" (
    echo   Invalid choice. Please enter a number between 0 and %WHL_COUNT%.
    goto prompt_choice
)

set "SELECTED_WHL=!WHL_%USER_CHOICE%!"
set "SELECTED_NAME=!WHL_NAME_%USER_CHOICE%!"
echo.
echo   Selected: !SELECTED_NAME!
echo.

REM ── Step 4: Installation ──
echo Step 4: Installing...
echo.

REM Install triton-windows
echo   Installing triton-windows...
"!PYTHON_DIR!\python.exe" -m pip install -U "triton-windows<3.7"
echo.

REM Copy include/libs
set "SOURCE=%SCRIPT_DIR%assets\python_3.13.2_include_libs"
if exist "!SOURCE!" (
    echo   Copying include/libs...
    robocopy "!SOURCE!" "!PYTHON_DIR!" /E /MT:8 >nul
    if !ERRORLEVEL! LEQ 3 (
        echo   Copy completed successfully.
    ) else (
        echo   Warning: Error occurred during copy. Error level: !ERRORLEVEL!
    )
    echo.
)

REM Install sageattention wheel
echo   Installing sageattention...
"!PYTHON_DIR!\python.exe" -m pip install "!SELECTED_WHL!"

if !ERRORLEVEL! NEQ 0 (
    echo.
    echo   Installation failed. Please select a different wheel.
    echo.
    goto select_wheel
)

echo.
echo   SageAttention installed successfully.
echo.

REM ── Step 5: Create run_nvidia_gpu_sage.bat ──
echo Step 5: Create launcher

set "EXTRA_FLAGS="
echo.
echo   Expose ComfyUI to your local network?
echo   (Adds --listen --port=8188)
echo   [1] Yes
echo   [2] No
echo.

:prompt_network
set "NET_CHOICE="
set /p "NET_CHOICE=  Choose [1-2]: "

if "!NET_CHOICE!"=="1" (
    set "EXTRA_FLAGS= --listen --port=8188"
) else if "!NET_CHOICE!"=="2" (
    set "EXTRA_FLAGS="
) else (
    goto prompt_network
)

set "LAUNCHER=!COMFYUI_DIR!\run_nvidia_gpu_sage.bat"

(
    echo .\!PYTHON_FOLDER!\python.exe -s ComfyUI\main.py --windows-standalone-build --use-sage-attention!EXTRA_FLAGS!
    echo echo If you see this and ComfyUI did not start try updating your Nvidia Drivers to the latest. If you get a c10.dll error you need to install vc redist that you can find: https://aka.ms/vc14/vc_redist.x64.exe
    echo pause
) > "!LAUNCHER!"

echo.
echo   Created: !LAUNCHER!
echo.
echo   Done!
echo.
pause
