#
#	This file is part of the OrangeFox Recovery Project
# 	Copyright (C) 2026 The OrangeFox Recovery Project
#
#	OrangeFox-specific settings for RMX3760.
#	Included by twrp_RMX3760.mk only when building OrangeFox.
#	OrangeFox is distinguished from plain TWRP by the OrangeFox
#	bootable/recovery + vendor/twrp sources, not by PRODUCT_NAME -
#	so do NOT alter PRODUCT_NAME here.
#

# screen settings
OF_SCREEN_H := 2400
OF_STATUS_H := 108
OF_STATUS_INDENT_LEFT := 48
OF_STATUS_INDENT_RIGHT := 48
OF_CLOCK_POS := 1
OF_HIDE_NOTCH := 1

# keep encrypted data mountable / skip unsupported checks
OF_DONT_PATCH_ENCRYPTED_DEVICE := 1
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1

# quick backup list (boot + internal data)
OF_QUICK_BACKUP_LIST := /boot;/data;

# number of list options before scrollbar creation
OF_OPTIONS_LIST_NUM := 11

# build all the partition tools
OF_ENABLE_ALL_PARTITION_TOOLS := 1

# FRP
OF_ENABLE_FRP_ADDON := 1

# add dmctl
OF_USE_DMCTL := 1
