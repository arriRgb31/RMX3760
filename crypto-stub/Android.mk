LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := boot_control_stub
LOCAL_MODULE_TAGS := optional
LOCAL_SRC_FILES := BootControlStub.c
LOCAL_SHARED_LIBRARIES := libbinder_ndk liblog
LOCAL_CFLAGS := -Wall -std=gnu11
include $(BUILD_EXECUTABLE)
