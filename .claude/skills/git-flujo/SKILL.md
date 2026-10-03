---
name: git-flujo
description: Flujo de trabajo con git del proyecto (ramas, micro commits, push, merge y versiones). Usar SIEMPRE antes de empezar cualquier feature, corrección, documento o cambio de APEX/BD; al terminar una tarea; cuando el dev pida "commit", "subir", "push", "rama", "versión", "release", "merge" o "pasar a main".
---

# Flujo de git

Objetivo: que todo cambio quede **versionado, en GitHub y recuperable**, y que varios devs
trabajen en paralelo sin pisarse.

## Ramas

```
main      ← producción / versiones estables (solo merges con tag vX.Y.Z)
  └─ develop   ← integración: de aquí salen y aquí vuelven las ramas de trabajo
       ├─ feature/<tema>   funcionalidad nueva      feature/adm-reporte-formulario
       ├─ fix/<tema>       corrección               fix/adm-busqueda-grid
       ├─ docs/<tema>      documentación            docs/estandar-v3
       └─ test/<tema>      solo pruebas             test/e2e-catalogos
```

Nombres en minúsculas, con guiones, empezando por el código de app cuando aplica (`adm-`, `erp-`).

## Al EMPEZAR cualquier tarea (obligatorio, también para Claude)

```bash
git checkout develop
git pull
git checkout -b feature/<tema>
git push -u origin feature/<tema>
```

Nunca trabajar directo en `main` ni en `develop`. Si hay cambios sin commit de otra tarea,
primero commitearlos en su rama.

## Mientras se trabaja

- **Micro commits**: un commit por cambio lógico (una tabla, un paquete, una página, un spec).
  Cada commit debe validar (`apex validate`) / compilar.
- Mensajes **Conventional Commits en español**:
  `feat(adm): …` · `fix(erp): …` · `refactor: …` · `docs: …` · `test(e2e): …` · `build: …` · `chore: …`
- Pie obligatorio cuando el commit lo hace Claude:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- **Push después de cada grupo de commits** (`git push`): el código no vive solo en una PC.
- Antes de commitear, revisar el diff: **nunca** wallets, contraseñas, `.env*`, `.secrets/`.
- Cambios de otro dev en el working tree: revisarlos y commitearlos aparte con su propio mensaje.

## Al TERMINAR la tarea

1. Cumplir la **Definición de terminado** de `AGENTS.md`: `apex validate`, import en DEV,
   `tools/apex/verificar_consultas.sql` sin errores, pruebas Playwright (ver skill `playwright-e2e`).
   Supporting Objects regenerados (`tools/build-supporting-objects.ps1 -App <app>`).
2. Si algún paso no se pudo correr, decirlo explícitamente en el reporte y en el merge.
3. Merge a develop (sin fast-forward, para que quede la historia de la rama):
   ```bash
   git checkout develop && git pull
   git merge --no-ff feature/<tema> -m "Merge feature/<tema>: <resumen>"
   git push
   ```
4. Opcional: abrir Pull Request en GitHub en lugar del merge local cuando haya revisión de otro dev.

## Versiones (release a main)

SemVer: `MAJOR.MINOR.PATCH` — MAJOR cambio incompatible, MINOR funcionalidad, PATCH corrección.

```bash
git checkout main && git pull
git merge --no-ff develop -m "Release vX.Y.Z: <resumen>"
git tag -a vX.Y.Z -m "vX.Y.Z - <qué incluye>"
git push origin main --tags
git checkout develop
```

Registrar el cambio en `CHANGELOG.md` (sección de la versión) antes del tag.

## Empezar a trabajar como dev nuevo

```bash
git clone https://github.com/fremdevps/ENFE
cd ENFE
git checkout develop
git checkout -b feature/<tema>
```
