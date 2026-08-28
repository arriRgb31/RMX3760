#!/system/bin/sh
# hal_boot.sh - prepare & start Trusty keymint/gatekeeper chain in TWRP
# Order matters: mount vendor -> wait -> HARVEST VNDK -> fix VINTF -> restart
# servicemanagers -> start HALs -> restart keystore2.

MOUNTED=$(mount | grep ' /vendor ')
if [ -z "$MOUNTED" ]; then
    mkdir -p /vendor
    mount -t erofs -o ro /dev/block/mapper/vendor_b /vendor 2>/dev/null \
      || mount -t erofs -o ro /dev/block/mapper/vendor /vendor 2>/dev/null \
      || mount -t erofs -o ro /dev/block/by-name/vendor_b /vendor 2>/dev/null \
      || twrp mount vendor >/dev/null 2>&1
fi

for i in $(seq 1 30); do
    if mount | grep -q ' /vendor '; then
        echo "hal_boot: vendor mounted (attempt $i)"
        break
    fi
    sleep 2
done
mount | grep -q ' /vendor ' || { echo "hal_boot: vendor mount FAILED after 60s"; exit 1; }

# ---- VNDK harvest -----------------------------------------------------------
# LD_LIBRARY_PATH of keymint/gatekeeper services:
#   /tmp/harvest/vndk:/vendor/lib64:/system/lib64
# The 3 keymint NDK libs (keymint-V2-ndk, secureclock-V1-ndk,
# sharedsecret-V1-ndk) are bundled at /system/lib64 in the ramdisk because
# they do NOT exist anywhere in vendor/odm/apex of stock A15.
mkdir -p /tmp/harvest/vndk
LIST=/system/etc/hal_boot.vndk.list
[ -f "$LIST" ] || LIST=/etc/hal_boot.vndk.list
N=0
while read -r lib; do
    [ -z "$lib" ] && continue
    for d in /system/lib64 /vendor/lib64 /odm/lib64 /vendor/lib64/vndk-33 \
             /vendor/lib64/vndk-sp-33 /apex/com.android.vndk.v33/lib64 \
             /apex/com.android.vndk.v34/lib64; do
        if [ -f "$d/$lib" ]; then
            cp "$d/$lib" /tmp/harvest/vndk/ && N=$((N+1)) && break
        fi
    done
done < "$LIST"
echo "hal_boot: harvested $N VNDK libs"

KEY=/tmp/harvest/vndk/android.hardware.security.keymint-V2-ndk.so
SCLK=/tmp/harvest/vndk/android.hardware.security.secureclock-V1-ndk.so
SHSEC=/tmp/harvest/vndk/android.hardware.security.sharedsecret-V1-ndk.so
for L in "$KEY" "$SCLK" "$SHSEC"; do
    [ -f "$L" ] || echo "hal_boot: WARN missing $(basename "$L") -> keymint/keystore2 will fail"
done

# ---- Fix VINTF (libvintf@4.0 cannot parse A15 manifests v5.0/v8.0) ----------
mkdir -p /tmp/fakeman

# 1) Device manifest: v1.0 with the 4 keymint AIDL entries that hwservicemanager
#    must know about (proven on-device). Bind over the real v5.0 vendor manifest.
cat > /tmp/fakeman/manifest.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<manifest version="1.0" type="device">
    <hal format="aidl">
        <name>android.hardware.security.keymint</name>
        <version>2</version>
        <fqname>IKeyMintDevice/default</fqname>
    </hal>
    <hal format="aidl">
        <name>android.hardware.security.secureclock</name>
        <fqname>ISecureClock/default</fqname>
    </hal>
    <hal format="aidl">
        <name>android.hardware.security.sharedsecret</name>
        <fqname>ISharedSecret/default</fqname>
    </hal>
    <hal format="aidl">
        <name>android.hardware.security.keymint</name>
        <version>2</version>
        <fqname>IRemotelyProvisionedComponent/default</fqname>
    </hal>
</manifest>
XML
if [ -f /vendor/etc/vintf/manifest.xml ]; then
    mount -o bind /tmp/fakeman/manifest.xml /vendor/etc/vintf/manifest.xml \
        && echo "hal_boot: vendor vintf bind OK (v1.0 keymint)"
fi

# 2) ODM manifests are v5.0 too -> neutralize with empty v1.0 device manifest.
printf '<?xml version="1.0" encoding="UTF-8"?>\n<manifest version="1.0" type="device" />\n' \
    > /tmp/fakeman/empty.xml
for m in /odm/etc/vintf/manifest.xml /odm/etc/vintf/manifest_nfc.xml; do
    if [ -f "$m" ]; then
        mount -o bind /tmp/fakeman/empty.xml "$m" 2>/dev/null \
            && echo "hal_boot: odm vintf bind $m"
    fi
done

# 3) system_ext vintf is v8.0 -> shadow the whole dir with tmpfs.
if [ -d /system_ext/etc/vintf ] && ! mount | grep -q ' /system_ext/etc/vintf '; then
    mount -t tmpfs tmpfs /system_ext/etc/vintf 2>/dev/null \
        && echo "hal_boot: system_ext vintf shadowed (tmpfs)"
fi

# 4) Framework manifest: keystore2 needs to be registered as a framework HAL.
#    Shop the A15 v8.0 fragments from /system/etc/vintf/manifest/ first.
mkdir -p /system/etc/vintf /tmp/vintf_stash
if [ -d /system/etc/vintf/manifest ]; then
    for f in /system/etc/vintf/manifest/*.xml; do
        [ -f "$f" ] && mv "$f" /tmp/vintf_stash/ && echo "hal_boot: stashed $(basename "$f")"
    done
fi
cat > /system/etc/vintf/manifest.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<manifest version="1.0" type="framework">
    <hal format="aidl">
        <name>android.system.keystore2</name>
        <fqname>IKeystoreService/default</fqname>
    </hal>
</manifest>
XML
cp /system/etc/vintf/manifest.xml /system/manifest.xml
echo "hal_boot: framework vintf manifest installed (keystore2)"

# 5) Restart servicemanagers so they consume the fixed VINTF, then start the
#    HALs (keymint registers instances only at startup), then keystore2.
killall servicemanager hwservicemanager 2>/dev/null
sleep 3
setprop twrp.halstart 1
sleep 3
setprop ctl.restart vendor.keymint-unisoc
sleep 3
setprop ctl.restart keystore2 2>/dev/null
sleep 6

echo "hal_boot: status"
getprop init.svc.vendor.keymint-unisoc
getprop init.svc.vendor.gatekeeper-trusty
getprop init.svc.keystore2
ps -A | grep -E 'keymint|gatekeeper|keystore' | grep -v grep