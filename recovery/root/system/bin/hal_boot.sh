#!/system/bin/sh
# hal_boot.sh - prepare & start Trusty keymint/gatekeeper chain in TWRP
# Order matters: mount vendor -> wait -> HARVEST VNDK -> fix VINTF -> restart
# servicemanagers -> start HALs -> restart keystore2.

MOUNTED=$(mount | grep ' /vendor ')
# keystore2 (on late-init) starts before VINTF is fixed and crashes in a loop;
# hold it until hal_boot has installed the fixed manifests (restarted at end).
stop keystore2 2>/dev/null
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

# ---- ODM mount (VINTF neutralization for ODM manifests) --------------------
mkdir -p /odm
if ! mount | grep -q ' /odm '; then
    mount -t erofs -o ro /dev/block/mapper/odm_a /odm 2>/dev/null \
      || mount -t erofs -o ro /dev/block/by-name/odm_a /odm 2>/dev/null \
      || mount -t erofs -o ro /dev/block/by-name/odm /odm 2>/dev/null \
      || true
fi
[ -f /odm/etc/vintf/manifest.xml ] && echo "hal_boot: /odm mounted (vintf visible)"

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

# ---- ICE/FDE provisioning HAL (vendor.sprd.boot-hal-1-2) -------------------
# Stock A15 vendor HAL android.hardware.boot@1.2-impl needs libbase with the
# Tokenize symbol (post-A13). Ramdisk libbase (A13) lacks it -> CANNOT LINK on
# boot-hal-1-2 -> stock never provisions ICE keys -> /data stays encrypted.
# Harvest real A15 libbase from the stock system partition.
mkdir -p /tmp/harvest/libbase64
if [ ! -f /tmp/harvest/libbase64/libbase.so ]; then
    # Stock A15 libbase (with Tokenize, needs by post-A13 HALs like
    # boot-hal-1-2). Ramdisk libbase (A13) lacks it. Harvest from the stock
    # system of the CURRENT slot: dynamic_partition only exposes the active
    # slot (system_a when booted on _a; system_b on _b) under /system_root.
    if [ -f /system_root/system/lib64/libbase.so ]; then
        cp /system_root/system/lib64/libbase.so /tmp/harvest/libbase64/ \
            && echo "hal_boot: libbase A15 harvested from system_root (ICE/FDE)"
    else
        mkdir -p /mnt/sys_stock
        if ! mount | grep -q ' /mnt/sys_stock '; then
            mount -t erofs -o ro /dev/block/mapper/system_b /mnt/sys_stock 2>/dev/null \
              || mount -t erofs -o ro /dev/block/by-name/system_b /mnt/sys_stock 2>/dev/null
        fi
        if [ -f /mnt/sys_stock/system/lib64/libbase.so ]; then
            cp /mnt/sys_stock/system/lib64/libbase.so /tmp/harvest/libbase64/ \
                && echo "hal_boot: libbase A15 harvested from system_b (ICE/FDE)"
        fi
    fi
fi

# ---- Fix VINTF (libvintf@4.0 cannot parse A15 manifests v5.0/v8.0) ----------
mkdir -p /tmp/fakeman

# 1) Device manifest: v1.0 with the 4 keymint AIDL entries that hwservicemanager
#    must know about (proven on-device). Bind over the real v5.0 vendor manifest.
printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<manifest version="1.0" type="device">' \
'    <hal format="aidl">' \
'        <name>android.hardware.security.keymint</name>' \
'        <version>2</version>' \
'        <fqname>IKeyMintDevice/default</fqname>' \
'    </hal>' \
'    <hal format="aidl">' \
'        <name>android.hardware.security.secureclock</name>' \
'        <fqname>ISecureClock/default</fqname>' \
'    </hal>' \
'    <hal format="aidl">' \
'        <name>android.hardware.security.sharedsecret</name>' \
'        <fqname>ISharedSecret/default</fqname>' \
'    </hal>' \
'    <hal format="aidl">' \
'        <name>android.hardware.security.keymint</name>' \
'        <version>2</version>' \
'        <fqname>IRemotelyProvisionedComponent/default</fqname>' \
'    </hal>' \
'    <hal format="hidl">' \
'        <name>android.hardware.boot</name>' \
'        <transport>hwbinder</transport>' \
'        <version>1.2</version>' \
'        <interface>' \
'            <name>IBootControl</name>' \
'            <instance>default</instance>' \
'        </interface>' \
'    </hal>' \
'</manifest>' > /tmp/fakeman/manifest.xml
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
printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<manifest version="1.0" type="framework">' \
'    <hal format="aidl">' \
'        <name>android.system.keystore2</name>' \
'        <fqname>IKeystoreService/default</fqname>' \
'    </hal>' \
'</manifest>' > /system/etc/vintf/manifest.xml
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
# 6) ICE/FDE provisioning HAL: with A15 libbase harvested above, start the
#    stock binary via vendor.sprd.boot-hal-ice (which carries LD_LIBRARY_PATH
#    with the harvested libbase; the stock init service vendor.sprd.boot-hal-1-2
#    would CANNOT LINK again). Provisions ICE keys -> /data readable f2fs.
if [ -f /tmp/harvest/libbase64/libbase.so ]; then
    start vendor.sprd.boot-hal-ice 2>/dev/null
    setprop ctl.restart vendor.sprd.boot-hal-ice 2>/dev/null
    sleep 3
fi
setprop ctl.restart keystore2 2>/dev/null
sleep 6

# ---- Harvest vold dependencies (stock A15 vold), then start it --------------
# A15 libc/libm are BUNDLED at /system/lib64/a15 (ramdisk, from stock
# com.android.runtime APEX) -> no on-device apex extraction needed.
# The 2 NDK/system libs below are only on stock partitions, harvest into
# /tmp/harvest/voldlibs (volatile; re-done every boot).
mkdir -p /tmp/harvest/voldlibs
VOLD_LIBS="android.system.keystore2-V4-ndk.so libphoenix_native.so"
for lib in $VOLD_LIBS; do
    if [ ! -f /tmp/harvest/voldlibs/$lib ]; then
        for d in /system_ext/lib64 /system_root/system_ext/lib64 /system_root/system/lib64 /system_root/system/system_ext/lib64; do
            if [ -f "$d/$lib" ]; then
                cp "$d/$lib" /tmp/harvest/voldlibs/ 2>/dev/null \
                    && echo "hal_boot: vold lib $lib <- $d" && break
            fi
        done
    fi
done
# vold expects these bundled A15 bionic libs in the harvest dir as well.
for lib in libc.so libm.so; do
    [ -f /tmp/harvest/voldlibs/$lib ] || \
        cp /system/lib64/a15/$lib /tmp/harvest/voldlibs/ 2>/dev/null
done
echo "hal_boot: voldlibs:"; ls /tmp/harvest/voldlibs 2>/dev/null

setprop servicemanager.ready true
sleep 1
setprop twrp.voldstart 1
sleep 5
echo "hal_boot: vold status"
getprop init.svc.vold
ps -A | grep -E '[v]old' | grep -v grep

# ---- try to actually mount /data through the freshly registered vold --------
if ps -A | grep -q '[v]old'; then
    echo "hal_boot: vold alive; attempting vdc mount_all"
    LD_LIBRARY_PATH=/tmp/harvest/voldlibs:/tmp/harvest/vndk:/system/lib64/a15:/system_root/system/lib64:/vendor/lib64:/system/lib64 \
        /system_root/system/bin/vdc mount_all 2>&1 | head -5
    sleep 3
    mount | grep ' /data ' || echo "hal_boot: /data not mounted yet (see logs)"
else
    echo "hal_boot: WARN vold NOT running"
fi

echo "hal_boot: status"
getprop init.svc.vendor.keymint-unisoc
getprop init.svc.vendor.gatekeeper-trusty
getprop init.svc.keystore2
getprop init.svc.vold
ps -A | grep -E 'keymint|gatekeeper|keystore|boot-hal|vold' | grep -v grep