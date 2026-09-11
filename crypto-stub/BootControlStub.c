/*
 * BootControlStub - pengganti HAL boot A15 di ramdisk recovery (fix #267).
 * vold A15 memanggil cp_needsCheckpoint() -> BootControlClient::
 * WaitForService("android.hardware.boot.IBootControl/default") TANPA syarat
 * di mountFstab, jadi service harus ADA atau mountFstab (dan /data) macet
 * selamanya. Cukup TERDAFTAR saja sudah membuka blokir: panggilan yang gagal
 * ditoleransi vold lewat value_or(true). Menggantikan HAL stock yang mati
 * dengan CANNOT LINK Tokenize (libbase ramdisk A12.1, simbol butuh A13+).
 */

#include <uchar.h>

#include <android/binder_manager.h>
#include <android/binder_ibinder.h>
#include <android/binder_parcel.h>
#include <android/binder_status.h>
#include <android/log.h>
#include <stdio.h>
#include <unistd.h>

/* AIBinder_Class callbacks: no user data to keep, nothing to destroy. */
static void *BootControl_onCreate(void *args) { return NULL; }
static void BootControl_onDestroy(void *userData) {}

/*
 * Wire methods of android.hardware.boot.IBootControl (AIDL v5,
 * android-15.0.0_r1). Transaction code = 1-based declaration order in the
 * .aidl (append-only across versions, so this matches any client <= v5).
 * Register-only is the goal: vold tolerates failing calls (value_or(true)),
 * so correct reply payloads below are a bonus.
 */
static binder_status_t BootControl_onTransact(AIBinder *binder,
                                              transaction_code_t code,
                                              const AParcel *in,
                                              AParcel *out) {
    int32_t slot = 0;

    switch (code) {
        /* Transaction code 0: no-op, report success. */
        case 0:
            return STATUS_OK;
        /* 1: int getActiveBootSlot() */
        case 1:
            return AParcel_writeInt32(out, 0);
        /* 2: int getCurrentSlot() */
        case 2:
            return AParcel_writeInt32(out, 0);
        /* 3: int getNumberSlots() - A/B device: two slots */
        case 3:
            return AParcel_writeInt32(out, 2);
        /* 4: MergeStatus getSnapshotMergeStatus() (enum + int32 on wire) */
        case 4:
            return AParcel_writeInt32(out, 0);
        /* 5: String getSuffix(in int slot) - slot 0 -> "_a", else "_b" */
        case 5:
            if (AParcel_readInt32(in, &slot) != STATUS_OK)
                return STATUS_UNKNOWN_TRANSACTION;
            return AParcel_writeString(out, slot == 0 ? "_a" : "_b", -1);
        /* 6: boolean isSlotBootable(in int slot) - both slots bootable */
        case 6:
            if (AParcel_readInt32(in, &slot) != STATUS_OK)
                return STATUS_UNKNOWN_TRANSACTION;
            return AParcel_writeBool(out, true);
        /* 7: boolean isSlotMarkedSuccessful(in int slot) - vold unblocks */
        case 7:
            if (AParcel_readInt32(in, &slot) != STATUS_OK)
                return STATUS_UNKNOWN_TRANSACTION;
            return AParcel_writeBool(out, true);
        /* 8: void markBootSuccessful() */
        case 8:
            return STATUS_OK;
        /* 9: void setActiveBootSlot(in int slot) */
        case 9:
            if (AParcel_readInt32(in, &slot) != STATUS_OK)
                return STATUS_UNKNOWN_TRANSACTION;
            return STATUS_OK;
        /* 10: void setSlotAsUnbootable(in int slot) */
        case 10:
            if (AParcel_readInt32(in, &slot) != STATUS_OK)
                return STATUS_UNKNOWN_TRANSACTION;
            return STATUS_OK;
        /* 11: void setSnapshotMergeStatus(in MergeStatus status) */
        case 11:
            if (AParcel_readInt32(in, &slot) != STATUS_OK)
                return STATUS_UNKNOWN_TRANSACTION;
            return STATUS_OK;
        default:
            /* Unknown / out-of-range code. vold tolerates failures. */
            return STATUS_UNKNOWN_TRANSACTION;
    }
}

int main(void) {
    AIBinder_Class *cls;
    AIBinder *binder;
    binder_status_t st;

    if (getuid() != 0)
        return 1;

    cls = AIBinder_Class_define("android.hardware.boot.IBootControl",
                                BootControl_onCreate, BootControl_onDestroy,
                                BootControl_onTransact);
    if (cls == NULL)
        return 1;

    binder = AIBinder_new(cls, NULL);
    if (binder == NULL)
        return 1;

    st = AServiceManager_addService(binder,
                                    "android.hardware.boot.IBootControl/default");
    __android_log_print(ANDROID_LOG_INFO, "boot_ctl_stub",
                        "addService status %d", (int)st);

    /* Never exit: keep the registration alive for vold's binder wait.
     * (thread-pool serving was tried in #268 and SIGSEGV'd on this
     * device; #269 disables vold checkpointing instead, so the stub is
     * only a registration placeholder.) */
    while (1)
        sleep(3600);

    return 0;
}
