#!/system/bin/sh
# Hold /odm (erofs dm-4 logical partition) mounted + busy for the whole
# session. Sesi #261: TWRP mounts /odm erofs right after boot, then
# "Unmounting main partitions..." drops it again (only /vendor stayed,
# because it was busy). With /odm gone, servicemanager resolves the
# ramdisk symlink /odm/etc -> /vendor/odm/etc onto the LIVE vendor mount
# (which itself contains odm -> /vendor/odm) => ELOOP => NULL VINTF
# MANIFEST => android.hardware.security.keymint-service.trusty
# "Check failed: status == STATUS_OK" SIGABRT loop => keystore2 panics.
# Fix: mount the real erofs /odm and keep it busy (cwd) so TWRP's unmount
# fails EBUSY exactly like /vendor. Non-blocking poll pattern (#253).
i=0
while [ ! -e /dev/block/dm-4 ]; do
    i=$((i + 1))
    if [ "$i" -ge 300 ]; then
        break
    fi
    sleep 0.2
done
if [ ! -e /dev/block/dm-4 ]; then
    # Fallback: some boots map odm as by-name without the TWRP dm symlink.
    if [ ! -e /dev/block/by-name/odm ]; then
        exit 1
    fi
fi
mount -t erofs -o ro /dev/block/dm-4 /odm || mount -t erofs -o ro /dev/block/by-name/odm /odm
cd /odm || exit 1
# Hold it forever so no later unmount can drop it.
while :; do
    sleep 3600
done