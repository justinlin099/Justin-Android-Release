#!/bin/bash

ROM_TYPE="EvolutionX"
DATE_STR=$(date +%Y%m%d)
TARGET_RELEASE_CONFIG="bp1a"
TARGET_BUILD_VARIANT="userdebug"

# 定義目標列表：格式為 "TARGET_PRODUCT:DEVICE_NAME"
TARGETS=("lineage_lilac:lilac" "lineage_lilac_dcm:lilac")

OTA_URL_BASE="https://justinlin099.github.io/Justin-Android-Release/ota/Evo"
DEVICE_DIRS=("device/sony/lilac" "device/sony/yoshino-common" "kernel/sony/msm8998" "vendor/sony/lilac" "vendor/sony/yoshino-common")
UPDATER_STRINGS="packages/apps/Updater/app/src/main/res/values/strings.xml"
UPDATER_DEFAULT_URL="https://raw.githubusercontent.com/Evolution-X/OTA/vic/builds/{device}.json"

BUILD_STD=true
BUILD_KSU=true

for arg in "$@"; do
    case $arg in
        --ksu-only|-k) BUILD_KSU=true; BUILD_STD=false ;;
        --std-only|-s) BUILD_STD=true; BUILD_KSU=false ;;
    esac
done

echo ">>> Generating ROM-wide changelog (cached)..."
TEMP_CHANGELOG=$(mktemp)
read -p "Enter date of last release (YYYY-MM-DD) [7 days ago]: " SINCE_DATE
[ -z "$SINCE_DATE" ] && SINCE_DATE=$(date -d "7 days ago" +%Y-%m-%d)
repo forall -c 'LOG=$(git log --oneline --no-merges --since="'"$SINCE_DATE"'"); [ -z "$LOG" ] || (echo "project $REPO_PROJECT/"; echo "$LOG" | sed "s/^/  * /"; echo "")' > "$TEMP_CHANGELOG"

cleanup_files() {
    local defconfig=$1
    sed -i '/CONFIG_KSU/d' "$defconfig" 2>/dev/null
    [ -f "updater_strings.xml.bak" ] && mv "updater_strings.xml.bak" "$UPDATER_STRINGS"
}

run_build() {
    local product=$1
    local device=$2
    local is_ksu=$3
    
    # 決定這次編譯的 defconfig
    local defconfig_path="kernel/sony/msm8998/arch/arm64/configs/lineage-msm8998-yoshino-lilac_defconfig"
    [ "$product" == "lineage_lilac_dcm" ] && defconfig_path="kernel/sony/msm8998/arch/arm64/configs/lineage-msm8998-yoshino-lilac_dcm_defconfig"
    
    local ota_name="lilac"
    [ "$product" == "lineage_lilac_dcm" ] && ota_name="lilac_dcm"
    local build_out="out/target/product/lilac"
    
    echo ""
    echo "=================================================="
    echo "  BUILDING: $product (KSU: $is_ksu)"
    echo "  DEFCONFIG: $defconfig_path"
    echo "=================================================="

    cleanup_files "$defconfig_path"
    
    # 強迫清除核心配置與 DTB，確保 KSU 標誌能正確套用，且防止 DTB 污染
    rm -rf out/target/product/lilac/obj/KERNEL_OBJ
    rm -f "$build_out"/*lilac*.zip
    rm -rf "$build_out/obj/PACKAGING/target_files_intermediates"
    rm -rf "$build_out/obj/PACKAGING/ota_intermediates"

    source build/envsetup.sh
    local ota_json_name="${ota_name}.json"
    if [ "$is_ksu" = true ]; then
        export WITH_KSU=true
        export KSU_ENABLED=true
        echo "CONFIG_KSU=y" >> "$defconfig_path"
        ota_json_name="${ota_name}_ksu.json"
    else
        export WITH_KSU=false
        export KSU_ENABLED=false
        echo "# CONFIG_KSU is not set" >> "$defconfig_path"
    fi

    local ota_url="${OTA_URL_BASE}/${ota_json_name}"
    [ -f "$UPDATER_STRINGS" ] && cp "$UPDATER_STRINGS" "updater_strings.xml.bak" && sed -i "s|$UPDATER_DEFAULT_URL|$ota_url|g" "$UPDATER_STRINGS"

    # Use the full lunch combo so build/make does not need local envsetup hacks.
    breakfast "${product}-${TARGET_RELEASE_CONFIG}-${TARGET_BUILD_VARIANT}" || {
        echo "!!! ERROR: breakfast failed for ${product}-${TARGET_RELEASE_CONFIG}-${TARGET_BUILD_VARIANT}. Aborting build."
        exit 1
    }
    
    # 執行編譯
    mka evolution && {
        # 尋找產物
        if [ "$product" == "lineage_lilac_dcm" ]; then
            RAW_ZIP=$(ls -t "$build_out"/*lilac_dcm*.zip "$build_out"/*lilac-dcm*.zip 2>/dev/null | head -n 1)
        else
            RAW_ZIP=$(find "$build_out" -maxdepth 1 -type f -name '*lilac*.zip' ! -iname '*dcm*.zip' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
        fi
        RAW_NAME=$(basename "$RAW_ZIP")
        
        # 重新命名產物（區分版本）
        NEW_NAME="$RAW_NAME"
        if [ "$product" == "lineage_lilac_dcm" ]; then
            # 使用 shopt nocasematch 進行不區分大小寫的檢查，避免重複添加
            if [[ "$NEW_NAME" != *DCM* && "$NEW_NAME" != *dcm* ]]; then
                NEW_NAME="${NEW_NAME/lilac/lilac-DCM}"
            else
                # 如果已經有小寫 dcm，將其替換為大寫 DCM 以保持美觀
                NEW_NAME="${NEW_NAME/lilac_dcm/lilac-DCM}"
                NEW_NAME="${NEW_NAME/lilac-dcm/lilac-DCM}"
            fi
        fi
        [ "$is_ksu" = true ] && [[ "$NEW_NAME" != *KSU* ]] && NEW_NAME="${NEW_NAME/.zip/-KSU.zip}"
        
        FOLDER_NAME="${NEW_NAME%.zip}"
        FINAL_OUT="$HOME/$DATE_STR/$FOLDER_NAME"
        mkdir -p "$FINAL_OUT"
        
        cp "$RAW_ZIP" "$FINAL_OUT/$NEW_NAME"
        sha256sum "$FINAL_OUT/$NEW_NAME" | awk '{print $1}' > "$FINAL_OUT/$NEW_NAME.sha256sum"
        md5sum "$FINAL_OUT/$NEW_NAME" | awk '{print $1}' > "$FINAL_OUT/$NEW_NAME.md5sum"
        
        # --- 產生 README.md ---
        cat <<MD > "$FINAL_OUT/README.md"
# $ROM_TYPE Release for Sony Xperia XZ1 Compact ($([ "$product" == "lineage_lilac_dcm" ] && echo "SO-02K" || echo "G8441"))

**Build Date:** $(date +%Y-%m-%d)
**Model:** $([ "$product" == "lineage_lilac_dcm" ] && echo "Japanese (DCM)" || echo "International (Generic)")

## Changelog
### Device Side Changelog
MD
        for dir in "${DEVICE_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                LOGS=$(git -C "$dir" log --oneline --no-merges --since="$SINCE_DATE")
                if [ -n "$LOGS" ]; then
                    echo "#### $dir" >> "$FINAL_OUT/README.md"
                    echo "$LOGS" | sed "s/^/* /" >> "$FINAL_OUT/README.md"
                    echo "" >> "$FINAL_OUT/README.md"
                fi
            fi
        done

        cat <<MD >> "$FINAL_OUT/README.md"
### ROM Side Changelog
* Synced with latest $ROM_TYPE sources.
MD
        cp "$TEMP_CHANGELOG" "$FINAL_OUT/Changelog_${ROM_TYPE}_${DATE_STR}.txt"

        local download_url="https://sourceforge.net/projects/justin-android-release/files/Releases/XZ1C/${ROM_TYPE}/${FOLDER_NAME}/$NEW_NAME/download"
        
        cat <<JSON > "$FINAL_OUT/$ota_json_name"
{ "response": [ { "timestamp": $(date +%s), "filename": "$NEW_NAME", "md5": "$(cat "$FINAL_OUT/$NEW_NAME.md5sum")", "size": $(stat -c "%s" "$FINAL_OUT/$NEW_NAME"), "download": "$download_url", "version": "$(echo "$NEW_NAME" | cut -d'-' -f2)", "maintainer": "justinlin099" } ] }
JSON
        [ -f "$build_out/recovery.img" ] && cp "$build_out/recovery.img" "$FINAL_OUT/recovery-${FOLDER_NAME}.img"
    }
    
    # 清理，為下一個版本做準備
    cleanup_files "$defconfig_path"
}

# 遍歷所有目標
for t in "${TARGETS[@]}"; do
    PRODUCT=$(echo $t | cut -d':' -f1)
    DEVICE=$(echo $t | cut -d':' -f2)
    
    [ "$BUILD_STD" = true ] && run_build "$PRODUCT" "$DEVICE" false
    [ "$BUILD_KSU" = true ] && run_build "$PRODUCT" "$DEVICE" true
done

rm "$TEMP_CHANGELOG"
echo ">>> All builds completed!"
