#!/system/bin/sh
# crypto_diag.sh - capture TWRP boot diag to EXTERNAL SD (/external_sd)
# Each snapshot is flushed to the vfat immediately (user may pull logs early).

R=/dev/block/mmcblk1p1
T=/tmp/diag
mkdir -p $T

# ---- ftrace: trace signal_generate (sender PID -> target PID) ASAP, before
# the first crash. NO "segfault at" and NO "Fatal signal 11" in #253 dmesg,
# so the triple SIGSEGV is likely INJECTED via kill() - kernel's own signal
# view will name the sender.
mount -t tracefs tracefs /sys/kernel/debug/tracing 2>/dev/null ||
  mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null
TR=
for P in /sys/kernel/debug/tracing /sys/kernel/tracing; do
  [ -d $P ] && TR=$P
done
if [ -n "$TR" ]; then
  echo 0 > $TR/tracing_on
  echo > $TR/trace
  echo signal_generate > $TR/set_event
  echo 1 > $TR/tracing_on
else
  echo "no tracefs" > $T/no_tracefs.txt
fi

snapshot() {
  local N=$1
  {
    echo "=== snapshot$N $(date) ==="
    echo "--- getprop ---"
    getprop
    echo "--- /proc/mounts ---"
    cat /proc/mounts
    echo "--- ps ---"
    ps
  } > $T/s$N.txt 2>&1
  dmesg > $T/dmesg$N.log 2>&1
  logcat -d > $T/logcat$N.log 2>&1
  # maps of the crashing crypto services: live capture is the only way to
  # symbolicate the faulting PC from print-fatal-signals (ASLR base unknown).
  # Services restart every ~5s, so grab maps while their pids are up.
  for NAM in vold keystore2 vendor.sprd.hardware.boot; do
    for P in /proc/[0-9]*; do
      if [ -r $P/cmdline ]; then
        C=$(tr '\0' ' ' < $P/cmdline 2>/dev/null)
        case "$C" in
          *"$NAM"*)
            FN=$(echo "$NAM" | tr '.' '_')
            echo "=== $P $C ===" > $T/maps_${FN}_$N.txt 2>/dev/null
            cat $P/maps >> $T/maps_${FN}_$N.txt 2>/dev/null
            echo "=== smaps_rollup ===" >> $T/maps_${FN}_$N.txt 2>/dev/null
            cat $P/smaps_rollup >> $T/maps_${FN}_$N.txt 2>/dev/null
            ;;
        esac
      fi
    done
  done
  cp /tmp/sigcatch.log $T/ 2>/dev/null
  cp /tmp/maps.log $T/ 2>/dev/null
  if [ -n "$TR" ] && [ -r $TR/trace ]; then
    cat $TR/trace > $T/ftrace$N.log 2>/dev/null
  fi
  # flush to FAT immediately (record result for next-boot post-mortem)
  {
    echo "=== snapshot$N flush $(date +%T) ==="
    if ! grep -q " /external_sd " /proc/mounts; then
      echo "external_sd not mounted; attempting mount"
      mkdir -p /external_sd 2>/dev/null
      mount -t vfat -o rw $R /external_sd 2>&1 || echo "mount failed rc=$?"
    fi
    if grep -q " /external_sd " /proc/mounts; then
      mkdir -p /external_sd/crypto_diag
      cp -rf $T/. /external_sd/crypto_diag/ 2>&1 && echo "flush ok" || echo "cp failed rc=$?"
      sync
    else
      echo "still no external_sd mount"
    fi
  } >> $T/flush.log 2>&1
}

# snapshot 0: immediate (services crash within the first ~100ms of boot)
snapshot 0

# snapshot 1: after TWRP super/metadata mounts (~20s)
sleep 20
snapshot 1

# snapshot 2: settled state (~40s)
sleep 20
snapshot 2

# snapshot 3: confirm the crash loop is steady (~60s)
sleep 20
snapshot 3

# #269 per-thread/binder diagnostics (explicit file)
TIDS=$T/tids.txt
exec > "$TIDS" 2>&1
for p in 267 270 326 327 328 329 330 334 434; do
  echo "=== pid $p ==="
  for t in /proc/$p/task/*; do
    echo "-- tid ${t##*/} comm=$(cat $t/comm 2>/dev/null) state=$(awk '{print $3}' $t/stat 2>/dev/null)"
    echo "   wchan=$(cat $t/wchan 2>/dev/null) syscall=$(cat $t/syscall 2>/dev/null)"
    echo "   stack:"; cat $t/stack 2>/dev/null | head -30
  done
done
cat /sys/kernel/debug/binder/state 2>/dev/null | tail -100
dmsetup table 2>/dev/null; dmsetup status 2>/dev/null
cat /sys/kernel/debug/wakeup_sources 2>/dev/null | head
exec >&- 2>&-
sync
# last-chance flush so flush.log (why 1-3 went missing, if they did) survives.
if grep -q " /external_sd " /proc/mounts; then
  cp -rf $T/. /external_sd/crypto_diag/ 2>/dev/null
  sync
fi
exit 0
