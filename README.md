# EvolutionX 10.17 Xperia XZ1 Compact rebuild files

This branch stores local rebuild assets for EvolutionX 10.17 / Android 15.

## Files

- `build_variants.sh`: local variant build script.
- `patches/`: local source patches that are not pushed upstream.

## Apply order

Run these from the Android source root after syncing EvolutionX sources:

```bash
git -C build/make apply /path/to/patches/build_make_envsetup_lilac_defaults.patch
git -C frameworks/base apply /path/to/patches/frameworks_base_network_policy_external_apps.patch
git -C frameworks/av apply /path/to/patches/frameworks_av_alac_omx.patch
git -C frameworks/native apply /path/to/patches/frameworks_native_omx_audio_alac.patch
git -C hardware/qcom-caf/msm8998/media apply /path/to/patches/hardware_qcom_msm8998_media_alac_registry.patch
git -C hardware/qcom-caf/msm8998/media apply /path/to/patches/hardware_qcom_msm8998_media_android_bp.patch
```

Notes:

- `frameworks/native/headers/media_plugin/media/openmax/OMX_Audio.h.rej` is a reject file and is intentionally not included.
- `kernel/sony/msm8998/KernelSU-Next/kernel/kernel` is an untracked submodule-local file and is intentionally not included.
