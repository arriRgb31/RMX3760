#!/system/bin/sh
# 274: byte-identical /metadata key protection for TWRP (RMX3760/UMS9230).
# TWRP's A15 vold triggers "Upgrading key" on every boot: the RAMDISK keymint
# (different KM version than stock) re-wraps keymaster_key_blob and writes it
# back to /metadata/vold/metadata_encryption/key/. Stock keymint on the next
# system boot then cannot read the blob -> "Rescue Party: init user0 failed" /
# reported data corruption (proven 3x by blob md5 change 6143b46d -> ...).
# Design (#274):
#   - This service snapshots the 4 key files into RAM (/crypto/keyguard)
#     right after /metadata is mounted in late-init, BEFORE vold runs.
#   - init gates the vold/keystore2 trigger on sys.crypto.keysnapshot=1
#     (fail-closed: vold only runs once the snapshot exists).
#   - vdc_mount_all.sh restores this snapshot after EVERY mountFstab attempt,
#     so the on-disk keys are byte-identical no matter what vold rewrote.
#     (/data is dm-crypt'd with the DEK derived from encrypted_key which vold
#     never changes; restoring keymaster_key_blob only affects the wrap.)
# Fail-open note: if the key dir does not exist yet (first boot / factory /
# RMA), there is nothing to protect - set the prop anyway so vold can create
# fresh keys. A manifest of md5s is written for post-session verification.
SRC=/metadata/vold/metadata_encryption/key
DST=/crypto/keyguard
if [ -d "$SRC" ]; then
    rm -rf "$DST"
    mkdir -p "$DST"
    cp -a "$SRC/." "$DST/" || exit 1
    sync
fi
setprop sys.crypto.keysnapshot 1
exit 0