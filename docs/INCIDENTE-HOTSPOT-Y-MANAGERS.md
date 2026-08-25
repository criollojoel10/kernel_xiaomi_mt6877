# Incidente Hotspot + Matriz de Managers — Aeron Ruby (kernel 4.19, DroidSpaces)

Fecha: 2026-08-24 · Dispositivo: Xiaomi ruby (MT6781/G99) · ROM Android 16 QPR2
Kernel instalado al inicio: `4.19.325-Aeron-Phoenix-1.0.3` variante KSU-SuSFS
Repo de trabajo: `criollojoel10/kernel_xiaomi_mt6877`

## 1. Síntoma

El hotspot se enciende y se apaga a los ~2 segundos. Logcat:

```
E/netd    : Failed to send update command to dnsmasq (Broken pipe)
E/Tethering: ERROR setting DNS forwarders failed ... (code 121)
E/Tethering: Error in setDnsForwarders      -> teardown del SoftAP
```

## 2. Cadena de evidencia (diagnóstico en dispositivo)

| Prueba | Resultado |
|---|---|
| dnsmasq manual como root (`--listen-mark`, `--dhcp-range`) | funciona y bindea :53 OK |
| exec dentro del mnt-ns de netd (nsenter) | OK |
| Contexto SELinux / avc | Enforcing, CERO denegaciones para el spawn |
| strace del hijo de netd | `exit_group(127)` ×5, sin execve visible |
| ftrace raw_syscalls (hijo vfork) | prctl(PR_SET_NAME) y muerte ANTES del exec |
| Conclusión | el exec falla silenciosamente bajo el hook inline KSU/SuSFS de `__do_execve_file()` |

## 3. Qué NO era

- No era conflicto de puerto :53 (verificado con scans TCP+UDP durante toggles).
- No eran los servicios del stack Termux (aislamiento total probado: sin boot hook,
  flags down, hotspot seguía fallando).
- No era la política SELinux del ROM (idéntica en builds que funcionan).
- El fix "hotspot android 16 QPR2" de upstream 1.0.2 (serie completa close_range +
  epoll_pwait2 + NL80211_WPA_VERSION_3 + `110beacdf` anti-duplicados de syscalls)
  YA estaba completo en el tag 1.0.3 (verificado tabla + kallsyms + fs/file.c).

## 4. Causa raíz (diferencia entre builds)

Con `CONFIG_KSU_SUSFS=y` + hook inline, TODO exec del sistema pasa por
`ksu_handle_execveat()`. Cuando el estado kernel↔ksud está desalineado
(p.ej. kernel compilado con KSU 3.2.0 vs ksud 3.0.1), la sustitución de
`filename` falla silenciosamente para spawns legítimos de daemons root
(netd→dnsmasq) → exit 127 → EPIPE → teardown.

## 5. Fix aplicado (en ambas ramas)

`fs/exec.c`: los procesos **uid==0** se saltan el hook (la reescritura de
ruta `/system/bin/su` solo aplica a callers no-root) + fail-safe que restaura
`filename` si el hook lo deja NULL/ERR_PTR.
- rama `ksu_susfs`: commit `10df8108bd`
- rama `ksu_rksu`: commit `808e34fb2e`
- referencia local: repo stack-termux `kernel-patches/` (commit `267eed1`)

## 6. Resultados de builds

| Build | Config | Resultado |
|---|---|---|
| 26/32-era (`ruby-rksu-susmount`) | RKSU pineado Feb-2026 | compila PERO falla empaquetado: `pkg_observer.c` usa `handle_inode_event`, fsnotify 4.19 solo tiene `handle_event` |
| 28 (`ruby-test-susmount`) | ReSukiSU main | ✅ compila y empaqueta. **Hotspot OK.** PERO firma embebida = ReSukiSU: el manager KSU-Next 3.0.1-spoofed NO lo reconoce; el manager RKSU sí detecta root pero no gestiona módulos ni concede root (falta su ksud userspace; los módulos existentes los monta el ksud de Next) |
| estable v2 (`ruby-test-susmount` + fix + fragmentos vendor/) | ReSukiSU main | ✅ zip completo (artifact `b07da82`) |
| next301 (`ruby-next301-stable`) | **KernelSU-Next v3.0.1-legacy** pineado | en curso |

## 7. Matriz de managers (hallazgo clave)

KernelSU-Next quitó soporte non-GKI de la línea principal después de v3.0.x;
el soporte vive en tags `-legacy` (v3.0.1-legacy, v3.1.0-legacy, v3.2.0-legacy,
con `lsm_hooks.c`). El dispositivo usa manager **Next 3.0.1-spoofed** ⇒ el
kernel DEBE compilarse con fuente KernelSU-Next de esa generación para que la
firma del manager embebida coincida y ksud/userspace gestione módulos y root.

| Kernel compilado con | Manager que lo reconoce |
|---|---|
| ReSukiSU/RKSU | solo manager RKSU |
| KernelSU-Next legacy 3.0.x | manager Next 3.0.1 (+ spoofed) |

## 8. Estado actual del dispositivo

Kernel original reinstalado (SUS_MOUNT ON): BYD app pasa ✓, módulos cargan ✓,
manager Next 3.0.1-spoofed vale ✓ — hotspot sigue roto (esperando build next301).

## 9. Pendientes

- [ ] Validar build `ruby-next301-stable`: hotspot + manager Next + módulos + BYD
- [ ] Investigar por qué RKSU manager no detecta root en build 32
      (hipótesis: guard uid==0 interactúa con la máquina de estados
      `susfs_is_boot_completed_triggered` de la variante v15)
- [ ] Fix `pkg_observer.c` fsnotify 4.19 si se retoma la línea RKSU
      (añadir fix #6 a scripts/setup-rksu.sh)
- [ ] Si next301 estabiliza todo: proponer serie aguas arriba al maintainer
