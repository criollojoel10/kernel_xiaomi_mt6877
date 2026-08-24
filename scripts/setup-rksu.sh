#!/bin/sh
# Setup RKSU (rsuntk/KernelSU) pinned to a Feb-2026 commit (constantq-era,
# with LSM hook for non-GKI 4.19) + externally provided susfs 1.5.x (already
# in tree from ksu_susfs-v15). SUS_MOUNT enabled via vendor fragments.
set -eu

GKI_ROOT=$(pwd)
REPO_URL="https://github.com/rsuntk/KernelSU"
BRANCH="main"
COMMIT="9f68f239f62c242964311aeec3080ced9cda4d29"

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

echo "[+] Setting up RKSU ($COMMIT)..."
test -d "$GKI_ROOT/KernelSU" || git clone --branch "$BRANCH" "$REPO_URL" KernelSU
cd "$GKI_ROOT/KernelSU"
git fetch origin "$COMMIT"
git checkout "$COMMIT"
cd "$DRIVER_DIR"
ln -sf "$(realpath --relative-to=$DRIVER_DIR $GKI_ROOT/KernelSU/kernel)" kernelsu
echo "[+] Symlink created."
grep -q "kernelsu" $DRIVER_MAKEFILE || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> $DRIVER_MAKEFILE
grep -q 'source "drivers/kernelsu/Kconfig"' $DRIVER_KCONFIG || printf 'source "drivers/kernelsu/Kconfig"\n' >> $DRIVER_KCONFIG
echo '[+] Done.'
