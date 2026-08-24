#!/bin/sh
# Setup KernelSU-Next driver from Constantq/xiaomi_fog_caf-kernel_ksun_susfs
# (proven working on msm-4.19 non-GKI with full pre-5.x compat layer:
#  TWA_RESUME define, fsnotify ops macro, seccomp_cache >=5.10 guard,
#  MODULE_IMPORT_NS guards, app_profile filter_count guards).
# Paired with the in-tree susfs v2.0.0 all_procs variant (proven on ruby).
set -eu

GKI_ROOT=$(pwd)
REPO_URL="https://github.com/Constantq/xiaomi_fog_caf-kernel_ksun_susfs"
PIN_SHA="dcd534ae759a3333b55febbd53347de1174963bb"

if test -d "$GKI_ROOT/common/drivers"; then
     DRIVER_DIR="$GKI_ROOT/common/drivers"
elif test -d "$GKI_ROOT/drivers"; then
     DRIVER_DIR="$GKI_ROOT/drivers"
else
     echo '[ERROR] "drivers/" directory not found.'
     exit 127
fi

DRIVER_MAKEFILE=$DRIVER_DIR/Makefile
DRIVER_KCONFIG=$DRIVER_DIR/Kconfig

echo "[+] Setting up KernelSU-Next ($PIN_SHA)..."
if ! test -d "$GKI_ROOT/KernelSU-Next-src"; then
    git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" KernelSU-Next-src
fi
cd "$GKI_ROOT/KernelSU-Next-src"
CUR=$(git rev-parse HEAD)
if [ "$CUR" != "$PIN_SHA" ]; then
    echo "[!] main moved ($CUR), fetching pinned $PIN_SHA"
    git fetch --depth 1 --filter=blob:none origin "$PIN_SHA"
    git checkout --detach "$PIN_SHA"
fi
git sparse-checkout set KernelSU-Next
test -f KernelSU-Next/kernel/Kbuild || { echo '[ERROR] KernelSU-Next/kernel missing'; exit 127; }

# --- ruby-specific adaptation ---
# Our in-tree susfs exports the ALL-procs variant of the hide-sus-mounts cmd
# (CMD number 0x55561 identical on both sides); align the driver call name.
if grep -q "susfs_set_hide_sus_mnts_for_non_su_procs" KernelSU-Next/kernel/supercalls.c 2>/dev/null; then
    sed -i 's/susfs_set_hide_sus_mnts_for_non_su_procs/susfs_set_hide_sus_mnts_for_all_procs/g' KernelSU-Next/kernel/supercalls.c
    echo "[+] Patched supercalls.c: non_su_procs -> all_procs"
fi

cd "$DRIVER_DIR"
ln -sf "$(realpath --relative-to=$DRIVER_DIR $GKI_ROOT/KernelSU-Next-src/KernelSU-Next/kernel)" kernelsu
echo "[+] Symlink created."
grep -q "kernelsu" $DRIVER_MAKEFILE || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> $DRIVER_MAKEFILE
grep -q 'source "drivers/kernelsu/Kconfig"' $DRIVER_KCONFIG || printf 'source "drivers/kernelsu/Kconfig"\n' >> $DRIVER_KCONFIG
echo '[+] Done.'
