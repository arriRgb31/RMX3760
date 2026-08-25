#!/system/bin/sh
# hal_boot.sh - prepare & start Trusty keymint/gatekeeper chain in TWRP
# Order matters: mount vendor -> HARVEST -> bind fake vintf/odm -> trigger.
# (harvest must run BEFORE empty-odm bind: odm/lib64 may hold needed libs)

MOUNTED=$(mount | grep ' /vendor ')
if [ -z "$MOUNTED" ]; then
    mkdir -p /vendor
    mount -t erofs -o ro /dev/block/mapper/vendor_b /vendor 2>/dev/null \
      || mount -t erofs -o ro /dev/block/by-name/vendor_b /vendor 2>/dev/null \
      || twrp mount vendor >/dev/null 2>&1
fi
mount | grep -q ' /vendor ' || { echo "hal_boot: vendor mount FAILED"; exit 1; }

mkdir -p /tmp/harvest/vndk
LIST=/system/etc/hal_boot.vndk.list
[ -f "$LIST" ] || LIST=/etc/hal_boot.vndk.list
N=0
while read -r lib; do
    [ -z "$lib" ] && continue
    for d in /vendor/lib64 /odm/lib64 /vendor/lib64/vndk-33 /vendor/lib64/vndk-sp-33 \
             /apex/com.android.vndk.v33/lib64 /apex/com.android.vndk.v34/lib64; do
        if [ -f "$d/$lib" ]; then
            cp "$d/$lib" /tmp/harvest/vndk/ && N=$((N+1)) && break
        fi
    done
done < "$LIST"
echo "hal_boot: harvested $N VNDK libs"

KEY=/tmp/harvest/vndk/android.hardware.security.keymint-V2-ndk.so
if [ -f "$KEY" ]; then
    echo "hal_boot: keymint ndk lib OK"
else
    echo "hal_boot: WARN keymint ndk lib NOT harvested, vendor scan:"
    ls /vendor/lib64 2>/dev/null | grep -i "security" 
    find /apex /odm /vendor -name "*keymint-V2-ndk*" 2>/dev/null
fi

mkdir -p /tmp/fakeman /tmp/emptydir
printf '<?xml version="1.0" encoding="UTF-8"?>\n<manifest/>\n' > /tmp/fakeman/manifest.xml
if [ -f /vendor/etc/vintf/manifest.xml ]; then
    mount -o bind /tmp/fakeman/manifest.xml /vendor/etc/vintf/manifest.xml && echo "hal_boot: manifest bind OK"
fi
[ -d /odm ] && mount -o bind /tmp/emptydir /odm 2>/dev/null && echo "hal_boot: odm bind OK"

setprop twrp.halstart 1
sleep 8
echo "hal_boot: status"
getprop init.svc.vendor.keymint-unisoc
getprop init.svc.vendor.gatekeeper-trusty
ps -A | grep -E 'keymint|gatekeeper' | grep -v grep
