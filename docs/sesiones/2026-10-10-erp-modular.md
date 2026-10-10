# 2026-10-10 — ERP modular: fase 1 (módulo general y app 200)

Rama: `feature/erp-gen` (desde `develop`). Estado al cierre: ver `docs/ESTADO.md`.

## Pedidos del dueño (en orden)

1. ERP **multimoneda, multiempresa, todo configurable** (impuestos sin columnas fijas) y
   **escalable en volumen**, en facturación y en finanzas; con mejoras propias.
2. **No monolítico**: una app APEX por módulo. 200 ERP Configuración es la app maestra (componentes
   compartidos por suscripción y sesión compartida); 210 Inventario, 220 Compras, 230 Ventas,
   240 Finanzas, 250 Contabilidad, 260+ verticales por rubro.
3. Estructura organizativa: empresa → sucursal → departamento (opcional, unidad de negocio) →
   punto de expedición, más depósito.
4. Adaptable a **cualquier rubro**: funcionalidades activables, perfiles de rubro y roles de persona
   configurables; nunca código por cliente.
5. Usar material de referencia solo para tomar ideas y **no mencionar el origen** en ningún
   documento, código ni commit. El material vive fuera del repositorio en
   `C:\Users\Francisco\Documents\ENFE-referencias` (no versionar ni copiar al repo).
6. Nombres sin prefijos `f_`/`p_` (estándar: `verbo_objeto`).
7. **Nativo primero**: todo en Oracle (hasta 26ai) + APEX; solo lo imposible queda para una API
   futura. Facturación electrónica **SIFEN nativa**.
8. **Historial de cambios** en JSON.
9. Probar y verificar siempre en **DEV ENFE OCI**, sin especular.
10. Usar agentes en paralelo cuando convenga.
11. Documentar el estado para que cualquier sesión nueva retome fácil (este archivo y `docs/ESTADO.md`).

## Decisiones y por qué

| Decisión | Por qué |
|---|---|
| Una app APEX por módulo, con sesión compartida y suscripción a la app 200 | Despliegue, versión y pruebas por separado; el cliente instala solo lo que usa; varios devs en paralelo. La lógica vive en un solo esquema (`erp_*_api`), las apps son solo interfaz. |
| Impuestos como datos: impuesto → tasa con vigencia → categoría fiscal (% de base); foto del cálculo por ítem | Ninguna tasa fija en columnas; cambiar una tasa no altera documentos emitidos; soporta gravado parcial. |
| Persona global única, roles por empresa (`erp_gen_tipo_rol` configurable) | Un grupo de empresas comparte el padrón sin duplicar; cliente, proveedor, empleado, etc. son roles. |
| Departamento opcional como dimensión de análisis | Unidades de negocio sin forzarlas a todas las empresas. |
| Depósito creado ya en la fase 1 (`erp_stk_deposito`) | Es parte de la estructura organizativa aunque pertenezca al módulo `stk`. |
| Adaptación por datos (funcionalidades, rubros, parámetros, apps verticales) | Evita tablas o triggers por cliente. |
| Facturación electrónica SIFEN **nativa**; se decidió no reutilizar una API de facturación externa analizada | Principio "nativo primero"; solo un paso imposible en alguna plataforma (p. ej. firma) quedaría como API futura. |
| Historial: tabla genérica `adm_aud_cambio` (JSON con antes/después) + trigger compound generado por tabla | Igual en Autonomous, SE2 y EE; captura todo DML; no autónomo (si hay rollback, el historial también). Flashback y Unified Auditing quedan como complementos. Diseño en `docs/arquitectura-erp.md` §9.2; **no implementado**. |
| Ambiente de pruebas único: DEV ENFE OCI | Pedido del dueño; se descartó montar Oracle/APEX locales. |
| Se retiró del repo el análisis comparativo de referencia y se reescribieron las decisiones como "principios de modelado" | Regla de no mencionar el origen de las ideas. |

## Qué se construyó (commits de la rama)

| Commit | Contenido |
|---|---|
| `ebc5ba5` | `docs/arquitectura-erp.md` inicial (multiempresa, multimoneda, impuestos, SIFEN). |
| `401c51a` | Tablas y triggers del módulo general (moneda, cotización, impuestos, categoría fiscal, sucursal, persona, parámetros, períodos). |
| `eb09ae7` | Paquetes `ctr/reg/api`: motor de impuestos, cotización/conversión, períodos, personas; tipos de cálculo. |
| `8b8d545` | Datos iniciales de Paraguay, mensajes de error, permisos e instalación. |
| `d337337` | Validación del diseño contra las guías de Oracle (§9.1). |
| `640b35c` | Vista de empresas habilitadas por usuario (empresa activa). |
| `a5dae97` | Generador ADM: ítems ocultos y valores por defecto (sin cambios en ADM). |
| `7de7d7b` | ERP modular, estructura organizativa y adaptación por rubro en la arquitectura. |
| `14ba555` | Departamento, punto de expedición, depósito, acceso por sucursal, funcionalidades, rubros, roles de persona. |
| `03a17d7` | Funcionalidades activables por empresa, semilla de rubros y roles. |
| `3e5c93f` | Fix: períodos exigen mes al cerrar o reabrir. |
| `13bc262` | Generador `tools/apexlang/erp_paginas.py`. |
| `522fb39` | App 200 ERP Configuración y supporting objects. |
| `987e820` | Pruebas E2E del ERP (inicio, apertura de pantallas, motor de impuestos). |
| `54d6e6b` | CHANGELOG sin publicar y generador en `AGENTS.md`. |
| `5b2b49e` | Principios de modelado; se retira el análisis comparativo. |
| `7140d23` | Documentos adicionales de persona, feriados, habilitación de período por usuario, monto mínimo en tasas, roles a cobrar/pagar. |
| `96627a0` | Arquitectura: nativo primero, historial JSON, reglas de numeración, SIFEN, stock, ventas, finanzas y contabilidad. |

Resultado: 30 tablas, 30 triggers, 1 vista, 2 tipos, 14 paquetes, 62 páginas en la app 200, 3 specs E2E.

## Investigaciones con agentes

| Tema | Resultado |
|---|---|
| Revisión de material de referencia (2 sistemas) | Hecha; ideas volcadas como principios en `docs/arquitectura-erp.md`. |
| Análisis de una API de facturación electrónica | Hecho; decisión: no reutilizarla, implementar SIFEN nativo (§4.2). |
| Historial de cambios | Hecho; decisión: tabla genérica JSON + trigger compound (§9.2). |
| Coherencia de nombres | En curso. |
| SIFEN 100 % nativo en Oracle | En curso. |
| Contratos de granos con fijaciones parciales de precio y tipo de cambio en cualquier orden | En curso; será app vertical. |

## Problemas encontrados y solución

| Problema | Solución |
|---|---|
| SQLcl `/nolog` y rutas fallan en Git Bash (conversión de rutas) | Ejecutar SQLcl desde PowerShell. |
| Instalar como `ADMIN` en el esquema de la app | `alter session set current_schema = WKSP_DEV` antes de `@install/install.sql`. |
| **ORA-12839** en los `merge` de datos semilla (Autonomous usa DML paralelo por defecto) | `alter session disable parallel dml` al inicio de los scripts de datos. **En curso** (cambios sin commitear en `apps/erp/database/data/`). |
| Menciones del origen de ideas en docs y mensajes de commit | Documento retirado y texto reescrito; queda el historial de git (requiere OK del dueño para force push). |

## Estado del deploy a DEV al cierre

- Hecho: tablas, triggers, vista, tipos y paquetes del ERP; registro en seguridad central.
- Pruebas públicas `npm run test:publico`: 5/5 contra DEV (antes del deploy).
- Falló: datos iniciales (ORA-12839), reinstalándose con la corrección.
- Falta: verificar objetos inválidos, importar la app 200 con supporting objects,
  `@tools/apex/verificar_consultas.sql 200 QA_ADMIN`, `npx playwright test specs/erp`.

## Pendientes

1. Terminar deploy y verificación en DEV; commitear la corrección de DML paralelo.
2. Actualizar `CHANGELOG.md` y mergear `feature/erp-gen` a `develop` (`--no-ff`) cuando pase todo.
3. Implementar el historial (`adm_aud_cambio` + generador de triggers).
4. Fase 2: documentos, timbrado, numerador, SIFEN nativo.
5. Cambio en ADM para reconocer apps por módulo al crear la app 210.
6. Limpiar del historial de git las menciones de origen (pedir OK para force push de `feature/erp-gen`).
7. Cerrar las investigaciones en curso y volcar sus resultados en `docs/arquitectura-erp.md`.
