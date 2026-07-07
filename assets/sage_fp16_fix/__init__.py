"""SageAttention fp16 black-frame fix for ComfyUI (optional drop-in node).

WHY THIS EXISTS
---------------
On Blackwell GPUs (RTX 50xx / sm_120), ComfyUI's `--use-sage-attention` auto-selects
an fp8 SageAttention kernel. When a model runs its math in fp16 (e.g. WAN with fp8
weights, which are dequantized to fp16 for compute), that kernel can produce values
larger than fp16 can represent (max 65504) as activation magnitudes grow during
denoising -> inf -> NaN -> fully black frames. Plain PyTorch attention avoids this by
accumulating in fp32.

WHAT IT DOES
------------
Wraps the `sageattn` symbol that ComfyUI's `attention_sage` calls. For fp16 inputs it
runs sage in bf16 (fp32-range exponent, so no overflow) using the Triton backend
instead of the fp8 one. bf16 attention is numerically indistinguishable from fp16 here,
and you keep sage's speedup. Non-fp16 inputs are passed straight through unchanged.

No ComfyUI files are modified -- this is a runtime monkey-patch applied on startup, so
it survives ComfyUI updates. Just having this folder in custom_nodes/ activates it.

TOGGLES (environment variables)
-------------------------------
  SAGE_FP16_FIX=0        Disable the fix entirely (behave as if this node weren't here).
  SAGE_FP16_FIX_GUARD=1  Extra safety net: if a sage call still returns NaN/Inf, redo
                         just that call with fp32 PyTorch attention. Off by default
                         because the Triton path is stable on its own; enable it if a
                         different model still shows black frames. Costs one GPU sync
                         per attention call.

LICENSE: MIT (matches Sage-Quickinstall).
"""
import os
import logging

NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}

log = logging.getLogger("sage_fp16_fix")


def _truthy(name, default="0"):
    return os.environ.get(name, default).strip().lower() in ("1", "true", "yes", "on")


def _install():
    if os.environ.get("SAGE_FP16_FIX", "1").strip().lower() in ("0", "false", "no", "off"):
        log.info("[sage_fp16_fix] disabled via SAGE_FP16_FIX=0")
        return

    try:
        import torch
        import comfy.ldm.modules.attention as A
    except Exception as e:
        log.warning("[sage_fp16_fix] ComfyUI attention module not importable: %s", e)
        return

    if not getattr(A, "SAGE_ATTENTION_IS_AVAILABLE", False) or not hasattr(A, "sageattn"):
        # Sage isn't active (no --use-sage-attention, or not installed). Nothing to do.
        return

    try:
        from sageattention import sageattn_qk_int8_pv_fp16_triton as _sage_triton
    except Exception as e:
        log.warning("[sage_fp16_fix] Triton sage backend unavailable, leaving sage as-is: %s", e)
        return

    _orig_sageattn = A.sageattn
    guard = _truthy("SAGE_FP16_FIX_GUARD")

    def _sdpa(q, k, v, attn_mask, tensor_layout):
        # q,k,v as given by layout; SDPA wants (batch, heads, seq, dim)
        if tensor_layout == "NHD":
            qr, kr, vr = (t.transpose(1, 2) for t in (q, k, v))
        else:
            qr, kr, vr = q, k, v
        m = attn_mask.float() if (attn_mask is not None and attn_mask.is_floating_point()) else attn_mask
        o = torch.nn.functional.scaled_dot_product_attention(qr.float(), kr.float(), vr.float(), attn_mask=m)
        if tensor_layout == "NHD":
            o = o.transpose(1, 2)
        return o

    def sageattn_fp16fix(q, k, v, attn_mask=None, is_causal=False, tensor_layout="HND", *args, **kwargs):
        # Only intervene for fp16 -- the dtype that overflows. Everything else uses the
        # normal sage auto-dispatch untouched.
        if q.dtype is not torch.float16:
            return _orig_sageattn(q, k, v, attn_mask=attn_mask, is_causal=is_causal,
                                  tensor_layout=tensor_layout, *args, **kwargs)

        qb, kb, vb = q.to(torch.bfloat16), k.to(torch.bfloat16), v.to(torch.bfloat16)
        m = attn_mask
        if m is not None and m.is_floating_point() and m.dtype == torch.float16:
            m = m.to(torch.bfloat16)

        try:
            out = _sage_triton(qb, kb, vb, attn_mask=m, is_causal=is_causal, tensor_layout=tensor_layout)
        except Exception as e:
            # Triton refused this shape (e.g. mask + large head_dim); fall back to fp32 SDPA.
            log.debug("[sage_fp16_fix] triton raised, using SDPA: %s", e)
            return _sdpa(q, k, v, attn_mask, tensor_layout).to(torch.float16)

        if guard and (torch.isnan(out).any() or torch.isinf(out).any()):
            out = _sdpa(q, k, v, attn_mask, tensor_layout)

        return out.to(torch.float16)

    A.sageattn = sageattn_fp16fix
    log.info("[sage_fp16_fix] active: fp16 sage routed through bf16 Triton backend%s",
             " (+NaN guard)" if guard else "")


_install()
