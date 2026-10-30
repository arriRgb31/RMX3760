#!/system/bin/sh
# 274: byte-identical /metadata key protection for TWRP (RMX3760/UMS9230).
# TWRP's A15 vold triggers "Upgrading key" on every boot: the RAMDISK keymint
# (different KM version than stock) re-wraps keymaster_key_blob and writes it
# back to /metadata/vold/metadata_encryption/key/. Stock keymint on the next
# system boot then cannot read the blob -> "Rescue Party: init user0 failed".
# Design (#274):
#   - This service snapshots the 4 key files into RAM (/crypto/keyguard)
#     right after /metadata is mounted in late-init, BEFORE vold runs.
#   - init gates the vold/keystore2 trigger on sys.crypto.keysnapshot=1
#     (fail-closed: vold only runs once the snapshot exists).
#   - vdc_mount_all.sh restores this snapshot after EVERY mountFstab attempt,
#     so the on-disk keys are byte-identical no matter what vold rewrote.
#     (/data is dm-crypt'd with the DEK derived from encrypted_key which vold
#     never changes; restoring keymaster_key_blob only affects the wrap.)
# #276 (generic anti-cascade - NO hardcoded hashes, repo is PUBLIC):
#   Per-device key material differs (and changes after factory reset / first
#   boot / RMA), so we must NOT verify against baked-in md5s - that would
#   block vold forever on any other device (keys differ) or after a factory
#   reset (new keys). Instead the protection is self-referential and airtight:
#   - The snapshot preserves whatever key state the STOCK system left on disk
#     (the only state where keymaster_key_blob is valid for stock keymint).
#   - restore (in vdc_mount_all.sh) runs after every vold op AND a final
#     delayed pass after the mount loop so an async "Upgrading key" write can
#     never be left behind -> recovery always exits with the boot-time keys.
#   First boot / format / factory reset: key dir missing -> nothing to protect,
#     prop is set so vold provisions fresh keys (valid for that fresh state).
SRC=/metadata/vold/metadata_encryption/key
DST=/crypto/keyguard
MAN=/crypto/keys.manifest
if [ -d "$SRC" ]; then
    rm -rf "$DST"
    mkdir -p "$DST"
    if cp -a "$SRC/." "$DST/"; then
        sync
        # telemetry only: runtime hashes written for forensics, NEVER compared.
        ( cd "$SRC" && md5sum * > "$MAN" 2>/dev/null || true )
        chmod 600 "$DST"/* 2>/dev/null
    else
        # Snapshot copy failed: still arm vold (blocking would only leave
        # /data unmounted). restore_keys() refuses to clobber with an
        # incomplete/empty keyguard, so disk keys stay untouched.
        rm -rf "$DST"
        mkdir -p "$DST"
    fi
fi
setprop sys.crypto.keysnapshot 1
exit 0