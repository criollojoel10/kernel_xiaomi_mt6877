# SuSFS sus-mount en Aeron Kernel — Xiaomi Ruby (MT6877, kernel 4.19)

> **Estado:** ✅ Fix aplicado y compilado (agosto 2026).
> Build de referencia: [run #4](https://github.com/criollojoel10/kernel_xiaomi_mt6877/actions/runs/32656223784) — artifact `Aeron-Phoenix-KSU-SuSFS-DroidSpaces-rubyx-ds-10-4-2b891c2-release`.

Documento que deja constancia de por qué la app **BYD** no abría con
LSPosed/JingMatrix/Vector instalados en la ROM con kernel Aeron (sí abría al
desinstalarlos), mientras que en HyperOS + kernel **HyperMoon** funcionaba
perfectamente, y del fix aplicado.

---

## Síntomas

| ROM / Kernel | Módulo Susfs | App BYD |
|---|---|---|
| HyperOS + HyperMoon 1.0.x | "sus mount support" activo, oculta 2 sus mounts | ✅ Abre |
| AOSP + Aeron (DroidSpaces) | "sus mount support" deshabilitado | ❌ No abre |

Al desinstalar LSPosed/JingMatrix/Vector, BYD abre sin problema → el disparador
son los **mounts** de esos módulos visibles para las apps.

## Investigación

### 1. El código susfs es idéntico en ambos árboles

`fs/susfs.c` y `fs/namespace.c` de [DXRN-MoonWake/hypermoon_kernel_xiaomi_ruby@main](https://github.com/DXRN-MoonWake/hypermoon_kernel_xiaomi_ruby)
y de este fork (`ksu_susfs`) son **idénticos byte por byte** (`diff` vacío).
La diferencia NO estaba en el código sino en la **configuración**.

### 2. La config heredada tenía sus-mount apagado

`arch/arm64/configs/vendor/susfs.config` traía:

```
CONFIG_KSU_SUSFS_SUS_MOUNT=n     # ← ocultamiento de mounts NO compilado
CONFIG_KSU_SUSFS_TRY_UMOUNT=n
```

Todo el mecanismo de ocultar montajes está tras `#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT`
en `fs/namespace.c`: los mounts creados por ksud (módulos incluidos) reciben un
`mnt_id` falso ≥ `DEFAULT_KSU_MNT_ID` (500000) y se ocultan de `/proc/*/mounts`
para procesos sin root cuando el módulo Susfs envía
`CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS` en post-fs-data.
Con `=n` eso **no se compila nada**: aunque el módulo quiera ocultar, el kernel
no puede → LSPosed/JingMatrix/Vector quedan visibles y BYD detecta root.

### 3. Git log de hypermoon explica todo

Commits sobre `arch/arm64/configs/vendor/susfs.config`:

| Commit | Fecha | Cambio |
|---|---|---|
| `f3b19973` | 2025-07-22 | import: susfs 1.5.9 |
| `fa3eb1e8` | 2025-10-19 | enable sus map features |
| `beba7f1c` | 2026-01-22 07:37 | `TRY_UMOUNT` y→n |
| `2cfcefd3` | 2026-05-07 | **`SUS_MOUNT` y→n** ("disable sus mount for bootable") |

Releases de HyperMoon: **1.0.0** (2025-12-06), **1.0.1** (2026-01-15),
**1.0.2** (2026-01-22 06:39) — todos anteriores a esos dos últimos commits,
o sea compilados con `SUS_MOUNT=y` + `TRY_UMOUNT=y`. Por eso ahí el módulo
reporta soporte, oculta los 2 sus mounts y BYD funciona.

Este fork se creó después del `2cfcefd3`, heredando el estado deshabilitado.

## Fix aplicado

| Commit | Cambio | Build |
|---|---|---|
| [`b61787738b`](https://github.com/criollojoel10/kernel_xiaomi_mt6877/commit/b61787738b8287e5846de66c0109137976264fd4) | `SUS_MOUNT=n→y`, `TRY_UMOUNT=n→y` | ❌ [run 32655122818](https://github.com/criollojoel10/kernel_xiaomi_mt6877/actions/runs/32655122818): falla |
| [`2b891c21c9`](https://github.com/criollojoel10/kernel_xiaomi_mt6877/commit/2b891c21c9) | `TRY_UMOUNT=y→n` (se mantiene `SUS_MOUNT=y`) | ✅ [run 32656223784](https://github.com/criollojoel10/kernel_xiaomi_mt6877/actions/runs/32656223784) |

### Por qué `TRY_UMOUNT` debe quedar en `=n`

El primer intento activó también `CONFIG_KSU_SUSFS_TRY_UMOUNT=y` (como los
releases HyperMoon) y el build falló con:

```
drivers/kernelsu/supercall/supercall.c:122: error: implicit declaration of
function 'susfs_add_try_umount' [-Werror]
```

Motivo: el driver [KernelSU-Next `legacy-susfs-v2`](https://github.com/DXRN-MoonWake/KernelSU-Next/tree/legacy-susfs-v2)
llama a `susfs_add_try_umount()` bajo ese `#ifdef`, pero esa función fue
eliminada del árbol con la reimplementación de susfs
(`4abaf4d2` remove + `90a9396b` reimplement susfs 2.1.0). Los releases
HyperMoon se compilaron contra susfs **1.5.9**, que sí la tenía.
Con susfs 2.x, `TRY_UMOUNT=n` es obligatorio; el ocultamiento lo provee
`SUS_MOUNT=y` por sí solo.

## Estado final de `vendor/susfs.config`

Igual que antes del fix salvo `CONFIG_KSU_SUSFS_SUS_MOUNT=y`:

```
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=n          # ← sin API en susfs 2.x, no tocar
CONFIG_KSU_SUSFS_SUS_MOUNT=y           # ← FIX: oculta mounts de módulos/KSU
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
# (AUTO_ADD_*, HAS_MAGIC_MOUNT, SUS_OVERLAYFS, SUS_SU: símbolos que este
#  Kconfig legacy-susfs-v2 no define; Kconfig los ignora)
```

## Verificación post-flash

1. Flashear `Aeron-Phoenix-KSU-SuSFS-DroidSpaces-*-release.zip` (variante SuSFS).
2. En el módulo Susfs (sidex15): *sus mount support* debe aparecer como
   **soportado**; el módulo activa el ocultamiento solo en post-fs-data.
3. Comprobar desde una app sin root que no aparecen mounts de `/data/adb/*`.
4. Abrir BYD **sin desinstalar** LSPosed/JingMatrix/Vector → debe funcionar
   igual que en HyperMoon.

## Relanzar un build

Ver [DROIDSPACES.md](DROIDSPACES.md#relanzar-un-build) — mismo workflow
(`build.yml`), misma rama de kernel (`ksu_susfs`).

## Créditos

- [DXRN-MoonWake/hypermoon_kernel_xiaomi_ruby](https://github.com/DXRN-MoonWake/hypermoon_kernel_xiaomi_ruby) — referencia del comportamiento correcto
- [DXRN-MoonWake/aeron_kernel_xiaomi_ruby](https://github.com/DXRN-MoonWake/aeron_kernel_xiaomi_ruby) — kernel base Aeron-Phoenix
- [DXRN-MoonWake/KernelSU-Next](https://github.com/DXRN-MoonWake/KernelSU-Next) (`legacy-susfs-v2`) — driver KSU usado en el build
- [sidex15/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) — SuSFS
