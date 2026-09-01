#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Installs gsi keys into ramdisk, to boot a developer GSI with verified boot.
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_keys.mk)

# Configure emulated_storage.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Virtual A/B OTA Support
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)

# Inherit from RMX3760 device
$(call inherit-product, device/realme/RMX3760/device.mk)

# Inherit some common TWRP stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

# Inherit OrangeFox-specific settings (empty when building plain TWRP)
$(call inherit-product-if-exists, device/realme/RMX3760/fox_RMX3760.mk)

# Product Identifiers RMX3760
PRODUCT_DEVICE := RMX3760
PRODUCT_NAME := twrp_RMX3760
PRODUCT_BRAND := realme
PRODUCT_MODEL := RMX3760
PRODUCT_MANUFACTURER := realme

PRODUCT_GMS_CLIENTID_BASE := android-oppo

# Build Properties & Fingerprint (Sesuai prop.default original RMX3760)
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="ussi_arm64_full-user 15 AP3A.240905.015.A2 40 release-keys" \
    TARGET_DEVICE="RMX3760" \
    PRODUCT_NAME="RMX3760" \
    PRODUCT_MODEL="RMX3760" \
    PRODUCT_DEVICE="RMX3760"

BUILD_FINGERPRINT := realme/RMX3760/RE58C2:15/AP3A.240905.015.A2/T.R4T2.1777915050:user/release-keys
