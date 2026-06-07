# LineageOS 22.2 Xperia XZ1 Compact rebuild files

This branch stores local rebuild assets for LineageOS 22.2 / Android 15.

## Files

- `build_variants.sh`: local variant build script.
- `patches/`: local source patches that are not pushed upstream.

## Apply order

Run these from the Android source root after syncing LineageOS sources:

```bash
git -C build/soong apply /path/to/patches/build_soong_disable_filesystem_creator.patch
git -C frameworks/av apply /path/to/patches/frameworks_av_alac_omx.patch
git -C frameworks/native apply /path/to/patches/frameworks_native_omx_audio_alac.patch
```

Notes:

- `kernel/sony/msm8998/KernelSU-Next/kernel/kernel` is an untracked submodule-local file and is intentionally not included.
