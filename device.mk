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
# EXEC-BIT MECHANISM (2026-09-05, verified in AOSP build/make/core/Makefile,
# android-12.1): the recovery ramdisk compose rule
# $(INTERNAL_RECOVERY_RAMDISK_FILES_TIMESTAMP) copies the device recovery/root
# into the ramdisk staging with a bare "cp -rf $(recovery_root_private)
# $(TARGET_RECOVERY_OUT)/" as the LAST writer run, AFTER PRODUCT_COPY_FILES
# (which are only dependencies of that rule). It has no -p/-preserve flag, so:
#   1) PRODUCT_COPY_FILES can never force a mode that survives for files that
#      already exist under recovery/root (the later cp -rf always overwrites)
#      -> the old "re-copy through PCF" fix was wrong for these entries;
#   2) the effective mode in the ramdisk is whatever the cp -rf source/mask
#      produces in the build workspace (git 100755 + umask 022 -> 0755, but if
#      the checkout or umask drops the x bit all crypto services die with
#      'cannot execv(...) Permission denied' / status 127).
# So the repo fixes the bit at the workspace level (workflow normalizes 0755
# on the checkout before mka) and re-verifies it post-build (workflow repacks
# the final recovery cpio through magiskboot add'ing 0755 entries + `test -x`).
# (PCF entries deliberately removed: they cannot win against the cp -rf below;
# the workflow normalizes exec bits in the workspace checkout instead.)

