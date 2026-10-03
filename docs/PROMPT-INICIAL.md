# Prompt inicial para tu asistente de IA

Copia y pega esto al empezar una sesión con tu LLM (Claude, ChatGPT/Codex, Cursor, etc.)
dentro del repo. Después, pide tu tarea con la plantilla de abajo.

---

```text
Estás trabajando en el repositorio ENFE: plataforma multi-app en Oracle APEX 26.1 (APEXlang)
con seguridad centralizada en la app ADM (ID 100). Antes de hacer nada:

1. Lee AGENTS.md (flujo, definición de terminado y errores a evitar).
2. Lee docs/ESTANDAR.md y aplícalo SIEMPRE (nombres, capas de paquetes, comentarios, APEX).
3. Lee .claude/skills/git-flujo/SKILL.md y .claude/skills/playwright-e2e/SKILL.md.
4. Mira CHANGELOG.md y `git log --oneline -15` para saber el estado actual.

Reglas:
- Crea una rama feature/<app>-<tema> desde develop antes de cambiar algo.
- Micro commits en español (Conventional Commits) y push frecuente.
- No des nada por terminado sin cumplir la "Definición de terminado" de AGENTS.md
  (apex validate, import en DEV, verificar_consultas.sql, pruebas Playwright).
- Si una pantalla cambia, actualiza sus pruebas en el mismo cambio.
- Nunca subas credenciales ni wallets. No escribas contraseñas en sitios remotos.
- Si hay una decisión de diseño que no cubre el estándar, pregúntame antes.
- Al terminar, dime qué hiciste, qué verificaste (con resultados) y qué quedó pendiente.

Confírmame que leíste todo y espera mi tarea.
```

---

## Plantilla para pedir una tarea

```text
App: <adm | erp | ...>        Módulo: <seg | fin | stk | ...>
Quiero: <qué necesitas, en lenguaje de negocio>
Usuarios: <quién lo usa y con qué permiso/rol>
Datos: <tablas/campos nuevos o existentes, reglas de negocio>
Pantallas: <listado + formulario | reporte | tablero | ...>
Criterios de aceptación:
  - <cuando hago X, debe pasar Y>
  - <mensaje de error esperado si Z>
Fuera de alcance: <lo que NO hay que tocar>
```

### Ejemplo

```text
App: erp   Módulo: ven
Quiero: mantenimiento de clientes.
Usuarios: rol ERP_VENTAS con permiso ERP_VEN_CLIENTE_GESTIONAR.
Datos: tabla erp_ven_cliente (código, razón social, RUC único, email, estado, empresa).
       Regla: el RUC no se puede repetir dentro de la misma empresa.
Pantallas: listado + formulario en panel lateral, en el menú de Ventas.
Criterios de aceptación:
  - Crear un cliente con RUC repetido muestra "Ya existe un cliente con ese RUC".
  - Un usuario sin el permiso no ve la opción del menú ni puede abrir la página.
Fuera de alcance: facturación.
```

## Qué esperar del asistente

1. Te confirma el plan (tablas, paquetes, páginas, permisos) antes de construir si hay dudas.
2. Crea la rama, construye por partes con micro commits.
3. Corre la verificación y te reporta resultados reales (no "debería funcionar").
4. Te pide que lances la suite con login (`cd tests/e2e && npm run test:live`) si trabaja contra
   un ambiente remoto, y corrige lo que falle.
5. Hace merge a `develop` cuando todo está en verde.
