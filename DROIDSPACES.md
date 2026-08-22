# Droidspaces en Aeron Kernel — Xiaomi Ruby (MT6877, kernel 4.19)

> **Estado:** ✅ Compilado y **probado en dispositivo físico** (agosto 2026).
> Build de referencia: [run #2](https://github.com/criollojoel10/kernel_xiaomi_mt6877/actions/runs/32587806944) — artifacts `Aeron-Phoenix-KSU-DroidSpaces` y `Aeron-Phoenix-KSU-SuSFS-DroidSpaces`.

Kernel [Aeron-Phoenix](https://github.com/DXRN-MoonWake/aeron_kernel_xiaomi_ruby) (4.19.325, non-GKI)
con soporte completo de [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) añadido.

---

## Rama de trabajo

| Rama | Contenido |
|---|---|
| `ksu_susfs` | Kernel Aeron + soporte Droidspaces (rama que se compila). Base: commit `746bb6a90` de DXRN-MoonWake/aeron_kernel_xiaomi_ruby (el mismo del build #152 de KernelAction). |
| `lineage-23.2` | Fork original. Solo aloja el workflow y los configs de CI (requerido por GitHub, ver [Notas de CI](#notas-de-ci)). |

Variantes generadas por el CI:

- **Aeron-Phoenix-KSU-DroidSpaces** — KernelSU-Next (`legacy-susfs-v2`)
- **Aeron-Phoenix-KSU-SuSFS-DroidSpaces** — KernelSU-Next + SuSFS

## Cambios respecto al upstream

### 1. `arch/arm64/configs/ruby_defconfig`

Bloque Droidspaces (non-GKI) añadido al final del defconfig:

- **IPC:** `CONFIG_SYSVIPC=y`, `CONFIG_POSIX_MQUEUE=y`
- **Namespaces:** `NAMESPACES`, `PID_NS`, `UTS_NS`, `IPC_NS`, `USER_NS`, `NET_NS`
- **Seccomp:** `SECCOMP`, `SECCOMP_FILTER`
- **Cgroups:** `CGROUPS`, `CGROUP_DEVICE`, `CGROUP_PIDS`, `MEMCG`, `CGROUP_SCHED`, `FAIR_GROUP_SCHED`, `CGROUP_FREEZER`, `CGROUP_NET_PRIO`
- **Filesystems:** `DEVTMPFS`, `OVERLAY_FS` (modo volátil), `TMPFS_XATTR`, `TMPFS_POSIX_ACL` (soporte NixOS)
- **Red (modos NAT/none):** `VETH`, `BRIDGE`, `BRIDGE_NETFILTER`, `NF_CONNTRACK`, `IP_NF_IPTABLES`, `IP_NF_FILTER`, `NF_NAT`, `NF_TABLES`, `IP_NF_TARGET_MASQUERADE`, `NETFILTER_XT_MATCH_ADDRTYPE`, `NF_CT_NETLINK`, `NF_NAT_REDIRECT`, `IP_ADVANCED_ROUTER`, `IP_MULTIPLE_TABLES`

**Adaptación a 4.19** (los nombres del doc upstream son para kernels más nuevos):

| Doc Droidspaces | Este árbol 4.19 |
|---|---|
| `CONFIG_NF_CONNTRACK_NETLINK` | `CONFIG_NF_CT_NETLINK` |
| `CONFIG_NETFILTER_XT_TARGET_MASQUERADE` | `CONFIG_IP_NF_TARGET_MASQUERADE` |
| `CONFIG_FW_LOADER_COMPRESS` | no existe en 4.19 (omitido) |
| `CONFIG_ANDROID_PARANOID_NETWORK=n` | el símbolo no existe en este árbol (nada que deshabilitar) |

### 2. Patches non-GKI de Droidspaces

| Patch | Estado |
|---|---|
| `02.fix_restore cgroup file prefix handling` | ✅ Aplicado (`kernel/cgroup/cgroup.c`) |
| `01.fix_kernel_panic_in_xt_qtaguid` | ⛔ N/A: `xt_qtaguid.c` no existe en este árbol MTK |

### 3. CI (GitHub Actions)

Workflow adaptado de [DXRN-MoonWake/KernelAction](https://github.com/DXRN-MoonWake/KernelAction):

- `.github/workflows/build.yml` — sin Telegram por defecto, con fallback de versión
- `configs/release/ruby-droidspaces.json` — construye desde esta rama con
  `ruby_defconfig` + fragments `vendor/kernelsu.config` (+ `vendor/susfs.config` en la variante SuSFS)
- Toolchain: clang r563880 (DR-KernelArchive), AnyKernel3 branch `aeron`

## Relanzar un build

```bash
gh api -X POST repos/criollojoel10/kernel_xiaomi_mt6877/actions/workflows/build.yml/dispatches \
  -f ref=lineage-23.2 \
  -f 'inputs[config_type]=release' \
  -f 'inputs[config_file]=ruby-droidspaces.json' \
  -f 'inputs[full_dump]=true' \
  -f 'inputs[send_to_telegram]=false'
```

El workflow clona el kernel desde `ksu_susfs` (definido en el JSON); el checkout de la
rama default solo se usa para leer los configs.

### Notas de CI

GitHub exige que el archivo del workflow exista en la **rama default**
([docs](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#workflow_dispatch),
confirmado en [cli/cli#9781](https://github.com/cli/cli/issues/9781)). Por eso `build.yml`
y el JSON viven también en `lineage-23.2`, aunque todo lo compilable vive en `ksu_susfs`.
Si cambias el workflow/config, actualiza **ambas ramas**.

## Verificación en dispositivo

```bash
su -c droidspaces check
```

o en la app Droidspaces: **Settings → Requirements → Check Requirements**.

## Instalación

Flashear el zip AnyKernel3 correspondiente vía recovery custom.
En HyperOS/MIUI y AOSP, ver las guías de flasheo del wiki de MoonWake.

## Créditos

- [DXRN-MoonWake/aeron_kernel_xiaomi_ruby](https://github.com/DXRN-MoonWake/aeron_kernel_xiaomi_ruby) — kernel base Aeron-Phoenix
- [DXRN-MoonWake/KernelAction](https://github.com/DXRN-MoonWake/KernelAction) — workflow de build (RainyXeon)
- [ravindu644/Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS) — guía de configuración de kernel y patches
