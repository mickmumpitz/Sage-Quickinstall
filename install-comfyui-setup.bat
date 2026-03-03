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

REM ── Step 3: Auto-select wheel ──
:select_wheel
echo Step 3: Selecting wheel...

REM Determine CUDA major version (12 vs 13) - minor version doesn't matter for SageAttention
set "CUDA_MAJOR="
if not "!CUDA_VER!"=="not found" (
    for /f "tokens=1 delims=." %%A in ("!CUDA_VER!") do (
        set "CUDA_MAJOR=%%A"
    )
)

REM Determine torch minor version for wheel matching
set "TORCH_MAJOR="
set "TORCH_MINOR="
set "TORCH_PATCH="
if not "!TORCH_VER!"=="not found" (
    for /f "tokens=1,2,3 delims=.+" %%A in ("!TORCH_VER!") do (
        set "TORCH_MAJOR=%%A"
        set "TORCH_MINOR=%%B"
        set "TORCH_PATCH=%%C"
    )
)

REM Try to find matching wheel
set "SELECTED_WHL="
set "SELECTED_NAME="

if not defined CUDA_MAJOR goto manual_select
if not defined TORCH_MINOR goto manual_select

REM PyTorch >= 2.9 uses the "andhigher" wheel (libtorch stable ABI)
set "USE_ANDHIGHER=0"
if !TORCH_MINOR! GEQ 9 set "USE_ANDHIGHER=1"

REM CUDA minor version doesn't matter for SageAttention, only major (12 vs 13)
REM So cu128 works for cu124/cu126/cu128 etc., cu130 works for cu130/cu131 etc.
if "!USE_ANDHIGHER!"=="1" (
    for %%F in ("%SCRIPT_DIR%assets\wheels\sageattention*+cu!CUDA_MAJOR!*torch2.9.0andhigher*-win_amd64.whl") do (
        set "SELECTED_WHL=%%F"
        set "SELECTED_NAME=%%~nxF"
    )
) else (
    REM Try matching CUDA major + exact torch version
    for %%F in ("%SCRIPT_DIR%assets\wheels\sageattention*+cu!CUDA_MAJOR!*torch!TORCH_MAJOR!.!TORCH_MINOR!.*-win_amd64.whl") do (
        set "SELECTED_WHL=%%F"
        set "SELECTED_NAME=%%~nxF"
    )
)

if defined SELECTED_WHL (
    echo   Auto-detected: !SELECTED_NAME!
    echo.
    goto install_wheel
)

echo   Could not auto-detect a matching wheel for CUDA !CUDA_VER! + PyTorch !TORCH_VER!
echo.

:manual_select
REM Fallback: let user pick manually
echo   Available wheels:
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

:install_wheel

REM ── Step 4: Installation ──
echo Step 4: Installing...
echo.

REM Detect triton-windows version from PyTorch minor version
set "TRITON_SPEC="
set "TRITON_LABEL="
if "!TORCH_VER!"=="not found" (
    echo   WARNING: PyTorch not detected. Cannot determine triton-windows version.
    echo   [1] Continue without triton-windows
    echo   [2] Cancel
    echo.
    set "TRITON_SKIP_CHOICE="
    set /p "TRITON_SKIP_CHOICE=  Choose [1-2]: "
    if "!TRITON_SKIP_CHOICE!"=="2" (
        echo.
        echo   Cancelled.
        pause
        exit /b 0
    )
    goto skip_triton
)

for /f "tokens=1,2 delims=.+" %%A in ("!TORCH_VER!") do (
    set "TORCH_MINOR=%%B"
)

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
)

if not defined TRITON_SPEC (
    echo   WARNING: Unknown PyTorch minor version "!TORCH_MINOR!" - no triton mapping found.
    echo   [1] Continue without triton-windows
    echo   [2] Cancel
    echo.
    set "TRITON_SKIP_CHOICE="
    set /p "TRITON_SKIP_CHOICE=  Choose [1-2]: "
    if "!TRITON_SKIP_CHOICE!"=="2" (
        echo.
        echo   Cancelled.
        pause
        exit /b 0
    )
    goto skip_triton
)

echo   PyTorch 2.!TORCH_MINOR! -^> triton-windows !TRITON_LABEL!
echo   Installing triton-windows...
"!PYTHON_DIR!\python.exe" -m pip install -U "!TRITON_SPEC!"
echo.
:skip_triton

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

REM ── Step 5: ComfyUI-Manager (optional) ──
if exist "!COMFYUI_DIR!\ComfyUI\custom_nodes\comfyui-manager" (
    echo Step 5: ComfyUI-Manager already installed, skipping.
    echo.
    goto after_manager
)

echo Step 5: Install ComfyUI-Manager?
echo   ComfyUI-Manager lets you install/update custom nodes from the UI.
echo   [1] Yes
echo   [2] No
echo.

:prompt_manager
set "MGR_CHOICE="
set /p "MGR_CHOICE=  Choose [1-2]: "

if "!MGR_CHOICE!"=="2" (
    echo.
    echo   Skipping ComfyUI-Manager.
    echo.
    goto after_manager
)

if not "!MGR_CHOICE!"=="1" goto prompt_manager

echo.
echo   Installing gitpython...
"!PYTHON_DIR!\python.exe" -s -m pip install gitpython
echo.
echo   Cloning ComfyUI-Manager...
"!PYTHON_DIR!\python.exe" -c "import git; git.Repo.clone_from('https://github.com/ltdrdata/ComfyUI-Manager', r'!COMFYUI_DIR!\ComfyUI\custom_nodes\comfyui-manager')"
if !ERRORLEVEL! NEQ 0 (
    echo   WARNING: Failed to clone ComfyUI-Manager. Skipping.
    echo.
    goto after_manager
)
echo.
echo   Installing ComfyUI-Manager requirements...
"!PYTHON_DIR!\python.exe" -s -m pip install -r "!COMFYUI_DIR!\ComfyUI\custom_nodes\comfyui-manager\requirements.txt"
echo.
echo   ComfyUI-Manager installed successfully.
echo.

:after_manager

REM ── Step 6: Create run_nvidia_gpu_sage.bat ──
echo Step 6: Create launcher

set "EXTRA_FLAGS="
echo.
echo   Allow access to ComfyUI from other devices on your network?
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
