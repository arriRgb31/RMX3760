#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/realme/RMX3760

# Dynamic Partitions Setup
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# VNDK / SDK
TARGET_SUPPORTS_VNDK := true
BOARD_VNDK_VERSION := current

PRODUCT_PLATFORM := ums9230

# Virtual A/B OTA & Compression
ENABLE_VIRTUAL_AB := true
PRODUCT_VIRTUAL_AB_COMPRESSION := true

# A/B Partitions Configuration
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    init_boot \
    l_agdsp \
    l_deltanv \
    l_fixnv1 \
    l_fixnv2 \
    l_gdsp \
    l_ldsp \
    l_modem \
    odm \
    pm_sys \
    product \
    sdc \
    sml \
    system \
    system_ext \
    teecfg \
    trustos \
    uboot \
    vbmeta \
    vbmeta_odm \
    vbmeta_product \
    vbmeta_system \
    vbmeta_system_ext \
    vbmeta_vendor \
    vendor \
    vendor_boot \
    vendor_dlkm

# Update Engine & Postinstall Setup
PRODUCT_PACKAGES += \
    otapreopt_script \
    cppreopts.sh \
    update_engine \
    update_verifier \
    update_engine_sideload

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=erofs \
    POSTINSTALL_OPTIONAL_system=true

# Boot Control HAL 1.2 (Unisoc UMS9230)
PRODUCT_PACKAGES += \
#    android.hardware.boot@1.2-impl-recovery \
#    android.hardware.boot@1.2-impl \
#   android.hardware.boot@1.2-service

#PRODUCT_PACKAGES += \
#    bootctrl.ums9230 \
#    bootctrl.ums9230.recovery

#PRODUCT_PACKAGES_DEBUG += \
    bootctrl \
    update_engine_client

# Health HAL
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service

# Fastbootd
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.0-impl-mock \
    android.hardware.fastboot@1.0-impl-mock.recovery \

# VINTF Manifests & Non-ELF Scripts
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/etc/vintf/manifest/android.hardware.boot-service.default.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/vintf/manifest/android.hardware.boot-service.default.xml \
    $(LOCAL_PATH)/recovery/root/system/etc/vintf/manifest/vendor.sprd.hardware.boot-service.default.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/vintf/manifest/vendor.sprd.hardware.boot-service.default.xml \
    $(LOCAL_PATH)/recovery/root/system/bin/create_splloader_dual_slot_byname_path.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/create_splloader_dual_slot_byname_path.sh \
    $(LOCAL_PATH)/recovery/root/system/etc/init/android.hardware.boot-service.default_recovery.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/android.hardware.boot-service.default_recovery.rc \
    $(LOCAL_PATH)/recovery/root/system/etc/init/vendor.sprd.hardware.boot-service.default_recovery.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/vendor.sprd.hardware.boot-service.default_recovery.rc

# Injeksi Bootconfig Fisik & Pustaka Vendor Terisolasi (Android 15 Stock)
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/bootconfig:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/bootconfig \
    $(LOCAL_PATH)/bootconfig:$(TARGET_COPY_OUT_RECOVERY)/root/bootconfig \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libc++.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libc++.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libc.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libc.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/libm.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/libm.so \
    $(LOCAL_PATH)/recovery/root/vendor/lib64/hw/android.hardware.boot@1.0.so:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/lib64/hw/android.hardware.boot@1.0.so

# A15 bionic (libc/libm w/ memset_explicit) extracted from stock
# com.android.runtime APEX. Ramdisk libc (A13) lacks memset_explicit which
# stock A15 vold requires -> vold must resolve libc via /system/lib64/a15.
# servicemanager (stock A15) also needs the full A15 lib chain (libbinder has
# _ZTVN7android2os14ConnectionInfoE) resolved exclusively through
# /system/lib64/a15 (per-service setenv, GUI-safe).
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libc.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libc.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libm.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libm.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libbinder.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libbinder.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libbase.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libbase.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libvintf.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libvintf.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libcutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libcutils.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/liblog.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/liblog.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libselinux.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libselinux.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libutils.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libutils.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libc++.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libc++.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libdl.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libdl.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libapexsupport.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libapexsupport.so \
    $(LOCAL_PATH)/recovery/root/system/lib64/a15/libvndksupport.so:$(TARGET_COPY_OUT_RECOVERY)/root/system/lib64/a15/libvndksupport.so

