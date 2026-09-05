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

# A15 crypto stack is baked at RAMDISK ROOT /crypto (recovery/root is copied
# wholesale into the recovery ramdisk): binaries + full ELF lib closures for
# keymint/gatekeeper/boot-hal (crypto/bin/vendor + crypto/lib/vendor),
# keystore2/vold/vdc/fsck.f2fs (crypto/bin/sys + crypto/lib/system) and the
# manager A15 libbinder/libvintf bundle (crypto/lib/man). Because /crypto
# lives at the ramdisk ROOT it survives the late stock /system /vendor /odm
# overlay; the managers' setenv (servicemanager_patch/*.rc) and
# keymint_unisoc.rc reference /crypto only. Per-service setenv, GUI stays A12.1.
#
# FIX (2026-09-05): the wholesale recovery/root copy STRIPS the exec bit
# (dmesg0: 'cannot execv(/crypto/bin/...) Permission denied', exit 127 for all
# five services, though git has 100755). PRODUCT_COPY_FILES preserves modes
# (proven: create_splloader *.sh lands 0755 in the image), so re-copy every
# crypto binary through PCF to force 0755 in the baked ramdisk.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/crypto/bin/vendor/android.hardware.gatekeeper@1.0-service.trusty:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/vendor/android.hardware.gatekeeper@1.0-service.trusty \
    $(LOCAL_PATH)/recovery/root/crypto/bin/vendor/android.hardware.security.keymint@2.0-unisoc.service.trusty:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/vendor/android.hardware.security.keymint@2.0-unisoc.service.trusty \
    $(LOCAL_PATH)/recovery/root/crypto/bin/vendor/vendor.sprd.hardware.boot@1.2-service:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/vendor/vendor.sprd.hardware.boot@1.2-service \
    $(LOCAL_PATH)/recovery/root/crypto/bin/sys/fsck.f2fs:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/sys/fsck.f2fs \
    $(LOCAL_PATH)/recovery/root/crypto/bin/sys/keystore2:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/sys/keystore2 \
    $(LOCAL_PATH)/recovery/root/crypto/bin/sys/keystore_cli_v2:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/sys/keystore_cli_v2 \
    $(LOCAL_PATH)/recovery/root/crypto/bin/sys/vdc:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/sys/vdc \
    $(LOCAL_PATH)/recovery/root/crypto/bin/sys/vold:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/sys/vold \
    $(LOCAL_PATH)/recovery/root/crypto/bin/sys/crypto_diag.sh:$(TARGET_COPY_OUT_RECOVERY)/root/crypto/bin/sys/crypto_diag.sh

