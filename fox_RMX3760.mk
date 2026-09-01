#
# Copyright (C) 2026 The OrangeFox Recovery Project
# SPDX-License-Identifier: Apache-2.0
#
# OrangeFox-specific overrides for RMX3760.
# Included by twrp_RMX3760.mk only when building OrangeFox (FOX_BUILD_DEVICE set).
#

# Inherit from RMX3760 device
$(call inherit-product, device/realme/RMX3760/device.mk)

# Inherit some common OrangeFox stuff.
$(call inherit-product, vendor/recovery/config/common.mk)

# OrangeFox product identifiers
PRODUCT_NAME := fox_RMX3760
PRODUCT_MODEL := RMX3760
PRODUCT_DEVICE := RMX3760
PRODUCT_BRAND := realme
PRODUCT_MANUFACTURER := realme

# OrangeFox-specific settings directory
PRODUCT_PROPERTY_OVERRIDES += \
    ro.orangefox.setup=1
