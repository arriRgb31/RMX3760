# OrangeFox RMX3760 — Log Analysis Notes (from /storage/sdcard1/OFOX)

Analyzed on boot after OF build success (orangefox e105bcb).

## Status OK
- Recovery boots, swipe gesture works, battery/charging displayed.
- logcat.log / dmesg.log / logcat.txt captured to external SD /storage/sdcard1/OFOX.

## CRITICAL: servicemanager crash-loop (blocks /data decrypt & mount)
- Repeated every ~5s for the whole session:
  `F linker: CANNOT LINK EXECUTABLE "/system/bin/servicemanager":
   cannot locate symbol "_ZTVN7android2os14ConnectionInfoE" referenced by "/system/bin/servicemanager"`
- Same root cause as TWRP main: servicemanager loads the A12.1 libbinder
  (lacks ConnectionInfo vtable) instead of the A15 /system/lib64/a15/libbinder.so.
- Effect: vold never gets its addService, so /data + internal storage cannot
  mount (shows 0 MB). Once TWRP main finalises the fix, port the SAME patches
  to OrangeFox (OFox = main + thin OF layer).

## Flashlight — NOT a sysfs-led device
- Kernel loads `flash_ic_sgm3785.ko` (SGM3785 flash IC, back flash, GPIO 203).
  Also `sprd_flash_drv.ko`, `flash_ic_ocp8137*`, `flash_ic_ocp81375*`.
- NONE of these drivers export a writable `/sys/class/leds/*/brightness`.
  SGM3785/SPRD flash is driven through kernel media / V4L2 subdev calls
  (`flash_open_torch` / `flash_cfg_value_torch`, `SPRD_FLASH_LED0/1/2/ALL`,
  `torch_led_index`, `isHulk`) - NOT via sysfs class leds.
- So `TW_DEFAULT_TORCH_PATH=/sys/class/leds/flashlight/brightness` is wrong for
  this device. Before enabling, must verify at runtime in recovery:
      ls /sys/class/leds
      ls /dev/v4l-subdev*  ;  ls /dev/media*
  Then pick the correct TORCH path (or V4L2 approach) accordingly.
- Back-flash only (no torch on front/secondary).

## Touch delay / erratic
- dmesg shows `omnivision_tcm_spi spi3.0` reporting corrupted coords
  (e.g. `y_width:199474248`) and repeated FW download attempts
  (`omnivision_tcm_spi: zeroflash_*` with garbage sizes like `-802415686`).
  Likely firmware download failing on cold boot -> touch latency. Confirm with
  TWRP main before porting any touch workaround.

## Magisk addon
- OFox "Install Magisk" addon appears but reports Magisk not detected (red text).
- OFox must READ the already-patched boot button (virtual A/B vendor_boot) and
  needs /data mounted to scan modules. Since /data does not mount yet,
  "not detected" is expected. Root via Magisk app patch of vendor_boot.img,
  then the addon can detect it once /data is decrypted.

## Plan
- Do NOT commit any of these to orangefox yet.
- Wait for TWRP main to finalise all fixes (servicemanager/libbinder decrypt,
  internal storage, touch). Then port every main fix to orangefox, final build,
  commit. OFox is more feature-complete but shares main as its base, so main
  must be settled first.
