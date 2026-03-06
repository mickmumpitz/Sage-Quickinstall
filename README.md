# ComfyUI-Sage-EasyInstall

One-click installers for [SageAttention](https://github.com/woct0rdho/SageAttention) on Windows with ComfyUI portable.

Automatically detects your Python, PyTorch, and CUDA versions, selects the correct wheel, installs [triton-windows](https://github.com/triton-lang/triton-windows), and creates a ready-to-use launcher.

## Installers

| File | Description |
|---|---|
| `install-sage-only.bat` | Installs SageAttention + Triton and creates a launcher |
| `install-comfyui-setup.bat` | Same as above, plus optionally installs [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager) and network access (`--listen`) |

## Prerequisites

Install these before running the installer:

- [Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)
- [Git](https://git-scm.com/downloads) (only needed for ComfyUI-Manager in `install-comfyui-setup.bat`)

## Requirements

- Windows 10/11
- ComfyUI portable (with embedded Python)
- NVIDIA GPU with CUDA 12.x or 13.x
- PyTorch 2.4+

### GPU Support

| GPU | Minimum PyTorch | Minimum CUDA |
|---|---|---|
| RTX 50xx (Blackwell) | 2.7 | 12.8 |
| RTX 40xx (Ada) | 2.4 | 12.4 |
| RTX 30xx (Ampere) | 2.4 | 12.4 |

GTX 16xx / RTX 20xx (Turing) support was dropped in triton-windows 3.3+ (PyTorch 2.7+). Use PyTorch 2.6 or older.

## How to Use

1. Download the [latest version](https://github.com/mickmumpitz/Sage-Quickinstall/releases/latest/download/sage-quickinstall.zip) or clone this repository
2. Double-click `install-sage-only.bat` or `install-comfyui-setup.bat`
3. Enter the path to your ComfyUI portable folder (e.g. `D:\ComfyUI_windows_portable`)
4. The installer auto-detects your environment and installs everything
5. Use the generated `run_nvidia_gpu_sage.bat` in your ComfyUI folder to launch with SageAttention enabled

## Troubleshooting

- **c10.dll error** — Install the [Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)
- **ComfyUI won't start** — Update your NVIDIA drivers to the latest version
- **Wheel auto-detection fails** — The installer falls back to manual wheel selection

## Third-Party Licenses

See the [THIRD_PARTY](THIRD_PARTY/) folder for licenses of bundled components:

- [SageAttention](https://github.com/woct0rdho/SageAttention) — Apache 2.0
- [triton-windows](https://github.com/triton-lang/triton-windows) — MIT
- [CPython](https://www.python.org/) — PSF License v2 (include/libs)

## License

[MIT](LICENSE)
