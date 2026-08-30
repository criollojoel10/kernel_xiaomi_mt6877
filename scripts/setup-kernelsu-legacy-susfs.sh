#!/bin/sh
# Setup KernelSU-Next @ v3.2.0-legacy-susfs-v2 (00cb93e0) for Aeron v15 susfs tree
# Compatible con KernelSU-Next manager v3.2.0-spoofed (33110+): UAPI legacy + non_su_procs.
set -eu

GKI_ROOT=$(pwd)
REPO_URL="https://github.com/DXRN-MoonWake/KernelSU-Next"
TAG="v3.2.0-legacy-susfs-v2"

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

echo "[+] Setting up KernelSU-Next ($TAG)..."
if test ! -d "$GKI_ROOT/KernelSU-Next"; then
     git clone "$REPO_URL" KernelSU-Next
fi

cd "$GKI_ROOT/KernelSU-Next"
git fetch --tags origin
git checkout "$TAG"

cd "$DRIVER_DIR"
ln -sf "$(realpath --relative-to=$DRIVER_DIR $GKI_ROOT/KernelSU-Next/kernel)" kernelsu
echo "[+] Symlink created."

grep -q "kernelsu" $DRIVER_MAKEFILE || printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> $DRIVER_MAKEFILE
grep -q 'source "drivers/kernelsu/Kconfig"' $DRIVER_KCONFIG || printf 'source "drivers/kernelsu/Kconfig"\n' >> $DRIVER_KCONFIG
echo '[+] Done.'