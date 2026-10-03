"""
Generador de las pantallas de mantenimiento de ADM (APEXlang).

Patrón (recomendado por APEX para usuarios no técnicos):
  - Listado: Interactive Report de solo lectura + botón "Crear" + link de edición por fila.
  - Alta/edición: formulario en panel lateral (drawer modal) con ayuda por campo.
  - Al cerrar el panel, el listado se refresca solo.

Uso:  python tools/apexlang/adm_paginas.py
Luego: apex validate -input apps/adm/apexlang
"""
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PAGINAS = os.path.join(RAIZ, 'apps', 'adm', 'apexlang', 'pages')


# ----------------------------------------------------------------------------- utilidades
def ml(texto, ind):
    pad = ' ' * ind
    cuerpo = '\n'.join(pad + l for l in texto.strip().split('\n'))
    return f"\n{pad}```\n{cuerpo}\n{pad}```"


def code(lang, texto, ind):
    pad = ' ' * ind
    cuerpo = '\n'.join(pad + l for l in texto.strip().split('\n'))
    return f"\n{pad}```{lang}\n{cuerpo}\n{pad}```"


def guardar(nombre, lineas):
    with open(os.path.join(PAGINAS, nombre), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lineas) + '\n')


def cabecera(num, titulo, alias, auth, ayuda, modal=False):
    o = [f"page {num} (", f"    name: {titulo}", f"    alias: {alias}", f"    title: {titulo}", "    appearance {"]
    if modal:
        o += ["        pageMode: modalDialog", "        dialogTemplate: @/drawer",
              "        templateOptions: [", "            #DEFAULT#", "            js-dialog-class-t-Drawer--pullOutEnd", "        ]"]
    else:
        o += ["        pageTemplate: @/standard", "        templateOptions: #DEFAULT#"]
    o += ["    }"]
    if modal:
        o += ["    dialog {", "        chained: false", "    }"]
    o += ["    security {"]
    if auth:
        o.append(f"        authorizationScheme: @{auth}")
    o += ["        pageAccessProtection: argumentsMustHaveChecksum", "        formAutoComplete: false", "    }",
          "    help {", "        helpText:" + ml(ayuda, 12), "    }"]
    if not modal:
        # Title Bar con el breadcrumb: muestra la ruta y el nombre de la página actual
        o += ["", "    region breadcrumb (", f"        name: {titulo}", "        type: breadcrumb",
              "        source {", "            breadcrumb: @breadcrumb", "        }",
              "        layout {", "            sequence: 10", "            slot: REGION_POSITION_01", "        }",
              "        appearance {", "            template: @/title-bar",
              "            templateOptions: [", "                #DEFAULT#",
              "                t-BreadcrumbRegion--useBreadcrumbTitle", "            ]", "        }",
              "        componentAppearance {", "            breadcrumbTemplate: @/breadcrumb",
              "            templateOptions: #DEFAULT#", "        }", "    )"]
    return o


def comentario_columna(etiqueta, resumen=None):
    s = (f"Display Label: {etiqueta}. Display in Report: true. Display in Form: true. Format Mask: none. "
         f"Value Required: false. Read Only: true. Primary Display Column: false. Authorization Scheme: none.")
    return f"Summary: {resumen} {s}" if resumen else s


# ----------------------------------------------------------------------------- listado
def pagina_listado(archivo, num, alias, titulo, auth, region, sql, pk, pagina_form, columnas, ayuda,
                   comentario_region, texto_crear=None, auth_crear=None):
    """columnas: (NOMBRE, encabezado, tipo NUMBER|STRING|DATE, resumen|None)"""
    o = cabecera(num, titulo, alias, auth, ayuda)
    o += ["", f"    region {region} (", f"        name: {titulo}", "        type: interactiveReport",
          "        source {", "            location: localDatabase", "            type: sqlQuery",
          "            sqlQuery:" + code('sql', sql, 16), "        }",
          "        layout {", "            sequence: 20", "            slot: BODY", "        }",
          "        appearance {", "            template: @/interactive-report", "            templateOptions: #DEFAULT#", "        }",
          "        advanced {", f"            htmlDomId: {region}", "        }"]
    if pagina_form:
        o += ["        link {", "            linkColumn: customTarget", "            target: {",
              f"                page: {pagina_form}", "                items: {",
              f"                    P{pagina_form}_{pk}: #{pk}#", "                }",
              f"                clearCache: {pagina_form}", "            }",
              '            linkIcon: <span role="img" aria-label="Editar" class="fa fa-edit" title="Editar"></span>',
              "        }"]
    o += ["        componentAppearance {", "            showNullValuesAs: -", "        }",
          "        pagination {", "            type: rowRangesXToY", "        }",
          "        messages {", "            whenNoDataFound: No hay registros.",
          "            whenMoreDataFound: Hay más de #MAX_ROW_COUNT# registros; use la búsqueda o los filtros.", "        }",
          "        download {", "            formats: [", "                csv", "                html", "            ]", "        }",
          "        comments {", "            comments:" + ml(comentario_region, 16), "        }",
          "", f"        column {pk} (", "            type: hidden", "            heading {", "                heading: ID",
          "            }", "            layout {", "                sequence: 10", "            }",
          "            source {", "                dataType: NUMBER", "            }", "        )"]
    for i, (nombre, encabezado, tipo, resumen) in enumerate(columnas):
        o += ["", f"        column {nombre} (", "            type: plainText", "            heading {",
              f"                heading: {encabezado}", "            }", "            layout {",
              f"                sequence: {(i + 2) * 10}", "            }", "            source {",
              f"                dataType: {tipo}", "            }", "            comments {",
              "                comments: " + comentario_columna(encabezado, resumen), "            }", "        )"]
    o.append("    )")
    if pagina_form:
        o += ["", "    button crear (", "        buttonName: CREAR", f"        label: {texto_crear or 'Crear'}",
              "        layout {", "            sequence: 10", f"            region: @{region}",
              "            slot: RIGHT_OF_IR_SEARCH_BAR", "        }", "        appearance {",
              "            buttonTemplate: @/text-with-icon", "            hot: true", "            templateOptions: #DEFAULT#",
              "            icon: fa-plus", "        }", "        behavior {", "            action: redirectThisApp",
              "            target: {", f"                page: {pagina_form}", f"                clearCache: {pagina_form}",
              "            }", "        }"]
        if auth_crear:
            o += ["        security {", f"            authorizationScheme: @{auth_crear}", "        }"]
        o += ["    )",
              "", "    dynamicAction refrescar-al-cerrar (", "        name: Refrescar al cerrar el formulario",
              "        execution {", "            sequence: 10", "        }", "        when {",
              "            event: apexafterclosedialog", "            selectionType: region", f"            region: @{region}",
              "        }", "", "        action refrescar (", "            action: refresh", "            affectedElements {",
              "                selectionType: region", f"                region: @{region}", "            }",
              "            execution {", "                sequence: 10",
              "                fireOnInit: false", "            }", "        )", "    )"]
    o.append(")")
    guardar(archivo, o)


# ----------------------------------------------------------------------------- formulario (drawer)
def pagina_formulario(archivo, num, alias, titulo, auth, tabla, pk, items, ayuda, permite_eliminar=True,
                      procesamiento=None, extras=None):
    """items: dict(n=COLUMNA, tipo, etiqueta, req, lov, inline, ayuda, solo_alta, sin_fuente, ancho)
       procesamiento: None = guardado automático de APEX (catálogo simple);
                      dict(CREAR=plsql, GUARDAR=plsql, ELIMINAR=plsql) = vía paquetes api."""
    o = cabecera(num, titulo, alias, auth, ayuda, modal=True)
    o += ["", "    region botones (", "        name: Botones", "        type: staticContent",
          "        layout {", "            sequence: 20", "            slot: REGION_POSITION_03", "        }",
          "        appearance {", "            template: @/buttons-container", "            templateOptions: #DEFAULT#", "        }", "    )",
          "", "    region formulario (", f"        name: {titulo}", "        type: form",
          "        source {", "            location: localDatabase", f"            tableName: {tabla.upper()}", "        }",
          "        layout {", "            sequence: 10", "            slot: contentBody", "        }",
          "        appearance {", "            template: @/blank-with-attributes", "            templateOptions: #DEFAULT#", "        }",
          "        edit {", "            enabled: true", "        }", "    )",
          "", f"    pageItem P{num}_{pk} (", "        type: hidden", "        layout {", "            sequence: 10",
          "            region: @formulario", "            slot: regionBody", "        }", "        source {",
          "            formRegion: @formulario", f"            column: {pk}", "            dataType: number",
          "            queryOnly: true", "            primaryKey: true", "        }", "        security {",
          "            sessionStateProtection: checksumRequiredSessionLevel", "        }", "    )"]
    for i, it in enumerate(items):
        nombre = f"P{num}_{it['n']}"
        o += ["", f"    pageItem {nombre} (", f"        type: {it['tipo']}", "        label {",
              f"            label: {it['etiqueta']}", "        }", "        layout {", f"            sequence: {(i + 2) * 10}",
              "            region: @formulario", "            slot: regionBody", "        }", "        appearance {",
              f"            template: @/{'required-floating' if it.get('req') else 'optional-floating'}",
              "            templateOptions: #DEFAULT#", "        }"]
        if it.get('req'):
            o += ["        validation {", "            valueRequired: true", "        }"]
        if it.get('lov'):
            o += ["        lov {", "            type: sharedComponent", f"            lov: @{it['lov']}"]
            if it.get('nulo'):
                o += ["            displayNullValue: true", f"            nullDisplayValue: {it['nulo']}"]
            o += ["        }"]
        if not it.get('sin_fuente'):
            dt = it.get('dt', 'varchar2')
            o += ["        source {", "            formRegion: @formulario", f"            column: {it['n']}",
                  f"            dataType: {dt}", "        }"]
        if it.get('solo_alta'):
            o += ["        serverSideCondition {", "            type: itemIsNull", f"            item: P{num}_{pk}", "        }"]
        if it.get('solo_edicion'):
            o += ["        serverSideCondition {", "            type: itemIsNotNull", f"            item: P{num}_{pk}", "        }"]
        o += ["        help {", f"            inlineHelpText: {it['inline']}", f"            helpText: {it['ayuda']}", "        }", "    )"]

    def boton(id_, nombre, etiqueta, seq, slot, accion_bd=None, cond=None, hot=False, confirmar=False, plantilla='text'):
        b = ["", f"    button {id_} (", f"        buttonName: {nombre}", f"        label: {etiqueta}", "        layout {",
             f"            sequence: {seq}", "            region: @botones", f"            slot: {slot}", "        }",
             "        appearance {", f"            buttonTemplate: @/{plantilla}"]
        if hot:
            b.append("            hot: true")
        b += ["            templateOptions: #DEFAULT#", "        }", "        behavior {"]
        if accion_bd:
            b += ["            warnOnUnsavedChanges: doNotCheck", f"            databaseAction: {accion_bd}"]
            if confirmar:
                b += ["            executeValidations: false", "            requiresConfirmation: true"]
        else:
            b += ["            action: definedByDynamicAction"]
        b += ["        }"]
        if confirmar:
            b += ["        confirmation {", "            message: ¿Seguro que desea eliminar este registro?", "            style: danger", "        }"]
        if cond:
            b += ["        serverSideCondition {", f"            type: {cond}", f"            item: P{num}_{pk}", "        }"]
        b.append("    )")
        return b

    o += boton('cancelar', 'CANCELAR', 'Cancelar', 10, 'CLOSE')
    if permite_eliminar:
        o += boton('eliminar', 'ELIMINAR', 'Eliminar', 20, 'DELETE', 'delete', 'itemIsNotNull', confirmar=True)
    o += boton('guardar', 'GUARDAR', 'Guardar cambios', 30, 'NEXT', 'update', 'itemIsNotNull', hot=True)
    o += boton('crear', 'CREAR', 'Crear', 40, 'NEXT', 'insert', 'itemIsNull', hot=True)
    o += ["", "    dynamicAction cerrar-panel (", "        name: Cancelar", "        execution {", "            sequence: 10",
          "        }", "        when {", "            event: click", "            selectionType: button", "            button: @cancelar",
          "        }", "", "        action cancelar-dialogo (", "            action: cancelDialog", "            execution {",
          "                sequence: 10", "                fireOnInit: false",
          "            }", "        )", "    )"]
    o += ["", "    process inicializar (", f"        name: Inicializar {titulo}", "        type: formInitialization",
          "        formRegion: @formulario", "        execution {", "            sequence: 10", "            point: beforeHeader",
          "        }", "    )"]
    if extras:
        o += extras
    if procesamiento is None:
        o += ["", "    process guardar-datos (", f"        name: Guardar {titulo}", "        type: formAutoRowProcessing",
              "        formRegion: @formulario", "        execution {", "            sequence: 10", "        }",
              "        successMessage {", "            successMessage: Cambios guardados.", "        }", "    )"]
    else:
        for i, (req, plsql) in enumerate(procesamiento.items()):
            o += ["", f"    process {req.lower()}-api (", f"        name: {req.capitalize()} (api)", "        type: executeCode",
                  "        source {", "            plsqlCode:" + code('plsql', plsql, 16), "        }",
                  "        execution {", f"            sequence: {(i + 1) * 10}", "        }",
                  "        serverSideCondition {", f"            whenButtonPressed: @{req.lower()}", "        }",
                  "        successMessage {", "            successMessage: Cambios guardados.", "        }", "    )"]
    o += ["", "    process cerrar (", "        name: Cerrar panel", "        type: closeDialog", "        execution {",
          "            sequence: 50", "        }", "        serverSideCondition {", "            type: requestIsContainedInValue",
          "            value: CREAR,GUARDAR,ELIMINAR", "        }", "    )", ")"]
    guardar(archivo, o)


def pagina_accion(archivo, num, alias, titulo, auth, ayuda, items, botones, procesos):
    """Modal (drawer) para una acción puntual, sin tabla asociada.
       items: dict(n, tipo, etiqueta, req, lov, nulo, inline, ayuda) — tipo 'hidden' para parámetros.
       botones: (id, NOMBRE, etiqueta, hot, mensaje_confirmacion|None)   procesos: (id_boton, plsql, mensaje)"""
    o = cabecera(num, titulo, alias, auth, ayuda, modal=True)
    o += ["", "    region botones (", "        name: Botones", "        type: staticContent",
          "        layout {", "            sequence: 20", "            slot: REGION_POSITION_03", "        }",
          "        appearance {", "            template: @/buttons-container", "            templateOptions: #DEFAULT#", "        }", "    )",
          "", "    region datos (", f"        name: {titulo}", "        type: staticContent",
          "        layout {", "            sequence: 10", "            slot: contentBody", "        }",
          "        appearance {", "            template: @/blank-with-attributes", "            templateOptions: #DEFAULT#", "        }", "    )"]
    for i, it in enumerate(items):
        oculto = it['tipo'] == 'hidden'
        o += ["", f"    pageItem P{num}_{it['n']} (", f"        type: {it['tipo']}"]
        if not oculto:
            o += ["        label {", f"            label: {it['etiqueta']}", "        }"]
        o += ["        layout {", f"            sequence: {(i + 1) * 10}", "            region: @datos", "            slot: regionBody", "        }"]
        if not oculto:
            o += ["        appearance {", f"            template: @/{'required-floating' if it.get('req') else 'optional-floating'}",
                  "            templateOptions: #DEFAULT#", "        }"]
        if it.get('req'):
            o += ["        validation {", "            valueRequired: true", "        }"]
        if it.get('lov'):
            o += ["        lov {", "            type: sharedComponent", f"            lov: @{it['lov']}"]
            if it.get('nulo'):
                o += ["            displayNullValue: true", f"            nullDisplayValue: {it['nulo']}"]
            o += ["        }"]
        if oculto:
            o += ["        security {", "            sessionStateProtection: checksumRequiredSessionLevel", "        }"]
        else:
            o += ["        help {", f"            inlineHelpText: {it['inline']}", f"            helpText: {it['ayuda']}", "        }"]
        o.append("    )")
    o += ["", "    button cancelar (", "        buttonName: CANCELAR", "        label: Cancelar", "        layout {",
          "            sequence: 5", "            region: @botones", "            slot: CLOSE", "        }",
          "        appearance {", "            buttonTemplate: @/text", "            templateOptions: #DEFAULT#", "        }",
          "        behavior {", "            action: definedByDynamicAction", "        }", "    )"]
    for i, (bid, nombre, etiqueta, hot, confirmar) in enumerate(botones):
        o += ["", f"    button {bid} (", f"        buttonName: {nombre}", f"        label: {etiqueta}", "        layout {",
              f"            sequence: {(i + 1) * 10}", "            region: @botones", "            slot: NEXT", "        }",
              "        appearance {", "            buttonTemplate: @/text"]
        if hot:
            o.append("            hot: true")
        o += ["            templateOptions: #DEFAULT#", "        }", "        behavior {", "            warnOnUnsavedChanges: doNotCheck"]
        if confirmar:
            o.append("            requiresConfirmation: true")
        o.append("        }")
        if confirmar:
            o += ["        confirmation {", f"            message: {confirmar}", "            style: danger", "        }"]
        o.append("    )")
    o += ["", "    dynamicAction cerrar-panel (", "        name: Cancelar", "        execution {", "            sequence: 10",
          "        }", "        when {", "            event: click", "            selectionType: button", "            button: @cancelar",
          "        }", "", "        action cancelar-dialogo (", "            action: cancelDialog", "            execution {",
          "                sequence: 10", "                fireOnInit: false", "            }", "        )", "    )"]
    for i, (bid, plsql, mensaje) in enumerate(procesos):
        o += ["", f"    process {bid}-proceso (", f"        name: {bid.capitalize()}", "        type: executeCode",
              "        source {", "            plsqlCode:" + code('plsql', plsql, 16), "        }",
              "        execution {", f"            sequence: {(i + 1) * 10}", "        }",
              "        serverSideCondition {", f"            whenButtonPressed: @{bid}", "        }",
              "        successMessage {", f"            successMessage: {mensaje}", "        }", "    )"]
    o += ["", "    process cerrar (", "        name: Cerrar panel", "        type: closeDialog", "        execution {",
          "            sequence: 50", "        }", "        serverSideCondition {", "            type: requestIsContainedInValue",
          "            value: " + ",".join(b[1] for b in botones), "        }", "    )", ")"]
    guardar(archivo, o)


def region_roles_usuario(num):
    """Roles asignados dentro del formulario de usuario + botones que abren modales de acción."""
    sql = ("select r.codigo || ' - ' || r.nombre rol,\n"
           "       coalesce(e.razon_social, 'Todas') empresa,\n"
           "       to_char(ur.fecha_desde, 'DD/MM/YYYY') desde,\n"
           "       coalesce(to_char(ur.fecha_hasta, 'DD/MM/YYYY'), 'Sin vencimiento') hasta\n"
           "  from adm_seg_usuario_rol ur\n"
           "  join adm_seg_rol r on r.rol_id = ur.rol_id\n"
           "  left join adm_gen_empresa e on e.empresa_id = ur.empresa_id\n"
           f" where ur.usuario_id = :P{num}_USUARIO_ID\n"
           " order by r.codigo")
    o = ["", "    region roles-asignados (", "        name: Roles asignados", "        type: classicReport",
         "        source {", "            location: localDatabase", "            type: sqlQuery",
         "            sqlQuery:" + code('sql', sql, 16), "        }",
         "        layout {", "            sequence: 30", "            slot: contentBody", "        }",
         "        appearance {", "            template: @/standard", "            templateOptions: #DEFAULT#", "        }",
         "        componentAppearance {", "            template: @/standard", "            templateOptions: #DEFAULT#", "        }",
         "        serverSideCondition {", "            type: itemIsNotNull", f"            item: P{num}_USUARIO_ID", "        }",
         "        comments {", "            comments: Roles del usuario. Se gestionan con el modal Asignar o quitar rol (página 34).", "        }"]
    for i, (c, h) in enumerate([('ROL', 'Rol'), ('EMPRESA', 'Empresa'), ('DESDE', 'Desde'), ('HASTA', 'Hasta')]):
        o += ["", f"        column {c} (", f"            reportColumnQueryId: {i + 1}", "            derivedColumn: N",
              "            heading {", f"                heading: {h}", "                alignment: start", "            }",
              "            layout {", f"                sequence: {(i + 1) * 10}", "                columnAlignment: start", "            }", "        )"]
    o.append("    )")
    for bid, nombre, etiqueta, icono, destino, auth in [
            ('asignar-rol', 'ASIGNAR_ROL', 'Asignar o quitar rol', 'fa-user-plus', 34, 'adm-seg-usuario-gestionar'),
            ('resetear', 'RESETEAR', 'Resetear contraseña', 'fa-key', 32, 'adm-seg-usuario-reset-password')]:
        o += ["", f"    button {bid} (", f"        buttonName: {nombre}", f"        label: {etiqueta}", "        layout {",
              "            sequence: 10", "            region: @roles-asignados", "            slot: RIGHT_OF_TITLE", "        }",
              "        appearance {", "            buttonTemplate: @/text-with-icon", "            templateOptions: #DEFAULT#",
              f"            icon: {icono}", "        }", "        behavior {", "            action: redirectThisApp",
              "            target: {", f"                page: {destino}", "                items: {",
              f"                    P{destino}_USUARIO_ID: &P{num}_USUARIO_ID.", "                }",
              f"                clearCache: {destino}", "            }", "        }",
              "        security {", f"            authorizationScheme: @{auth}", "        }", "    )"]
    return o


# ----------------------------------------------------------------------------- inicio: hub + tablero
ACCESOS = [
    # (id, etiqueta, ícono, página, descripción, authorization scheme)
    ('usuarios', 'Usuarios', 'fa-users', 30, 'Alta, edición, roles y contraseñas de los usuarios.', 'adm-seg-usuario-ver'),
    ('roles', 'Roles y permisos', 'fa-key', 20, 'Qué puede hacer cada rol en cada aplicación.', 'adm-seg-rol-gestionar'),
    ('aplicaciones', 'Aplicaciones', 'fa-apps', 40, 'Catálogo de aplicaciones de la plataforma.', 'adm-seg-aplicacion-gestionar'),
    ('modulos', 'Módulos', 'fa-folder-o', 42, 'Módulos funcionales de cada aplicación.', 'adm-seg-aplicacion-gestionar'),
    ('permisos', 'Permisos', 'fa-check-square-o', 44, 'Permisos atómicos por módulo.', 'adm-seg-aplicacion-gestionar'),
    ('empresas', 'Empresas', 'fa-building-o', 50, 'Empresas y unidades de negocio.', 'adm-gen-empresa-gestionar'),
    ('mensajes-error', 'Mensajes de error', 'fa-comment-o', 52, 'Textos claros para los errores de datos.', 'adm-gen-mensaje-gestionar'),
    ('bitacora-login', 'Bitácora de accesos', 'fa-history', 60, 'Quién ingresó, cuándo y con qué resultado.', 'adm-aud-login-ver'),
    ('bitacora-errores', 'Bitácora de errores', 'fa-bug', 61, 'Incidentes inesperados para soporte.', 'adm-aud-error-ver'),
]


def escribir_listas():
    """Menú lateral (agrupado), barra de usuario y lista 'accesos' (tarjetas del inicio)."""
    def entrada(eid, etiqueta, icono, seq, pagina=None, padre=None, auth=None, desc=None, url='#'):
        e = ["", f"    entry {eid} (", f"        label: {etiqueta}", "        icon {", f"            imageIconCssClasses: {icono}",
             "        }", "        layout {", f"            sequence: {seq}"]
        if padre:
            e.append(f"            parentEntry: @{padre}")
        e += ["        }", "        link {", "            target: {"]
        e += ([f"                page: {pagina}"] if pagina else ["                type: url", f"                url: {url}"])
        e += ["            }", "        }"]
        if desc:
            e += ["        userDefinedAttributes {", f"            1: {desc}", "        }"]
        if auth:
            e += ["        security {", f"            authorizationScheme: @{auth}", "        }"]
        e.append("    )")
        return e

    o = ["list navigation-bar (", "    name: Navigation Bar"]
    o += entrada('app-user', '&APP_USER.', 'fa-user', 10)
    o[-1:-1] = ["        userDefinedAttributes {", "            2: has-username", "        }"]
    o += entrada('cambiar-password', 'Cambiar contraseña', 'fa-key', 20, 90, 'app-user')
    o += ["", "    entry --- (", "        label: ---", "        layout {", "            sequence: 25", "            parentEntry: @app-user",
          "        }", "        link {", "            target: {", "                type: url", "                url: separator",
          "            }", "        }", "    )"]
    o += entrada('sign-out', 'Cerrar sesión', 'fa-sign-out', 30, None, 'app-user', url='&LOGOUT_URL.')
    o += ["", ")", "", "list navigation-menu (", "    name: Navigation Menu"]
    o += entrada('inicio', 'Inicio', 'fa-home', 10, 1)
    grupos = [('seguridad', 'Seguridad', 'fa-shield', ['usuarios', 'roles']),
              ('catalogo', 'Catálogo', 'fa-sitemap', ['aplicaciones', 'modulos', 'permisos', 'empresas', 'mensajes-error']),
              ('auditoria', 'Auditoría', 'fa-search', ['bitacora-login', 'bitacora-errores'])]
    seq = 20
    por_id = {a[0]: a for a in ACCESOS}
    for gid, gnombre, gicono, hijos in grupos:
        o += entrada(gid, gnombre, gicono, seq)
        for h in hijos:
            seq += 1
            eid, et, ic, pag, desc, auth = por_id[h]
            o += entrada(eid, et, ic, seq, pag, gid, auth)
        seq += 10
    o += ["", ")", "", "list accesos (", "    name: Accesos"]
    for i, (eid, et, ic, pag, desc, auth) in enumerate(ACCESOS):
        o += entrada('acc-' + eid, et, ic, (i + 1) * 10, pag, None, auth, desc)
    o += ["", ")"]
    with open(os.path.join(RAIZ, 'apps', 'adm', 'apexlang', 'shared-components', 'lists.apx'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(o) + '\n')


def escribir_breadcrumbs():
    entradas = [('home', 'Inicio', 1, None)] + [(a[0], a[1], a[3], 'home') for a in ACCESOS] + \
               [('cambiar-password', 'Cambiar mi contraseña', 90, 'home')]
    o = ["breadcrumb breadcrumb (", "    name: Breadcrumb", ""]
    for i, (eid, nombre, pagina, padre) in enumerate(entradas):
        o += [f"    entry {eid} (", f"        name: {nombre}", f"        pageNumber: {pagina}"]
        if padre:
            o += ["        appearance {", f"            parentEntry: @{padre}", "        }"]
        o += ["        execution {", f"            sequence: {(i + 1) * 10}", "        }", "        link {", "            target: {",
              f"                page: {pagina}", "            }", "        }", "    )", ""]
    o.append(")")
    with open(os.path.join(RAIZ, 'apps', 'adm', 'apexlang', 'shared-components', 'breadcrumbs.apx'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(o) + '\n')


def region_grafico(rid, titulo, tipo, sql, seq, nueva_fila, columnas=6):
    o = ["", f"    region {rid} (", f"        name: {titulo}", "        type: chart", "        layout {", f"            sequence: {seq}",
         "            slot: BODY"]
    if not nueva_fila:
        o.append("            startNewRow: false")
    o += [f"            columnSpan: {columnas}", "        }", "        appearance {", "            template: @/standard",
          "            templateOptions: #DEFAULT#", "        }", "        chart {", f"            type: {tipo}", "        }",
          "        legend {", f"            show: {'true' if tipo in ('pie', 'donut') else 'false'}", "        }",
          "", f"        series {rid} (", f"            name: {titulo}", "            execution {", "                sequence: 10", "            }",
          "            source {", "                type: sqlQuery", "                sqlQuery:" + code('sql', sql, 20), "            }",
          "            columnMapping {", "                label: ETIQUETA", "                value: VALOR", "            }", "        )"]
    if tipo not in ('pie', 'donut'):
        o += ["", "        axis x (", "            name: x", "            value {", "            }", "            majorTicks {",
              "                show: false", "            }", "        )",
              "", "        axis y (", "            name: y", "            value {", "                format: decimal",
              "                decimalPlaces: 0", "                formatScaling: none", "            }", "            majorTicks {",
              "                show: true", "            }", "        )"]
    o.append("    )")
    return o


def pagina_inicio():
    o = cabecera(1, 'Inicio', 'HOME', None,
                 "Punto de partida de la Administración Central.\nElija un área en las tarjetas o revise el estado actual en los indicadores y gráficos.")
    # Cada indicador sale de su propia subconsulta escalar (sin mezclar agregados con columnas sueltas).
    kpis = ("select 1 id, 'Usuarios activos' titulo,\n"
            "       to_char((select count(*) from adm_seg_usuario where estado = 'A')) valor,\n"
            "       'De ' || (select count(*) from adm_seg_usuario) || ' registrados' detalle\n"
            "  from dual\n"
            "union all\n"
            "select 2, 'Usuarios bloqueados', to_char((select count(*) from adm_seg_usuario where estado = 'B')),\n"
            "       'Por intentos fallidos' from dual\n"
            "union all\n"
            "select 3, 'Ingresos hoy',\n"
            "       to_char((select count(*) from adm_aud_login where resultado = 'OK' and fecha >= trunc(current_date))),\n"
            "       'Inicios de sesión exitosos' from dual\n"
            "union all\n"
            "select 4, 'Accesos rechazados hoy',\n"
            "       to_char((select count(*) from adm_aud_login where resultado <> 'OK' and fecha >= trunc(current_date))),\n"
            "       'Contraseña, bloqueo o sin acceso' from dual\n"
            "union all\n"
            "select 5, 'Incidentes (7 días)',\n"
            "       to_char((select count(*) from adm_aud_error where fecha >= trunc(current_date) - 7)),\n"
            "       'Errores inesperados' from dual")
    o += ["", "    region accesos (", "        name: ¿Qué desea hacer?", "        type: list", "        source {", "            list: @accesos",
          "        }", "        layout {", "            sequence: 20", "            slot: BODY", "        }", "        appearance {",
          "            template: @/standard", "            templateOptions: #DEFAULT#", "        }", "        componentAppearance {",
          "            listTemplate: @/cards", "            templateOptions: [", "                #DEFAULT#",
          "                t-Cards--featured force-fa-lg", "                t-Cards--displayIcons", "                t-Cards--3cols", "                t-Cards--desc-2ln",
          "                t-Cards--animColorFill", "            ]", "        }", "    )",
          "", "    region indicadores (", "        name: Estado actual", "        type: themeTemplateComponent/metricCard",
          "        source {", "            location: localDatabase", "            type: sqlQuery", "            sqlQuery:" + code('sql', kpis, 16),
          "        }", "        layout {", "            sequence: 30", "            slot: BODY", "        }", "        appearance {",
          "            template: @/standard", "            templateOptions: #DEFAULT#", "        }", "        componentAppearance {",
          "            display: report", "        }", "        settings {", "            title: &TITULO.", "            metric: &VALOR.",
          "            meta: &DETALLE.", "            layout: 5Columns", "        }"]
    for i, (c, dt, pk) in enumerate([('ID', 'number', True), ('TITULO', 'varchar2', False), ('VALOR', 'varchar2', False), ('DETALLE', 'varchar2', False)]):
        o += ["", f"        column {c} (", "            layout {", f"                sequence: {(i + 1) * 10}", "            }", "            source {",
              f"                databaseColumn: {c}", f"                dataType: {dt}"]
        if pk:
            o.append("                primaryKey: true")
        o += ["            }", "        )"]
    o.append("    )")
    o += region_grafico('accesos-por-dia', 'Ingresos por día (últimos 14 días)', 'bar',
                        "select to_char(trunc(fecha), 'DD/MM') etiqueta, count(*) valor\n  from adm_aud_login\n"
                        " where resultado = 'OK' and fecha >= trunc(current_date) - 13\n group by trunc(fecha)\n order by trunc(fecha)", 40, True, 8)
    o += region_grafico('resultados-acceso', 'Resultados de acceso (30 días)', 'donut',
                        "select initcap(replace(resultado, '_', ' ')) etiqueta, count(*) valor\n  from adm_aud_login\n"
                        " where fecha >= trunc(current_date) - 30\n group by resultado\n order by 2 desc", 50, False, 4)
    o += region_grafico('usuarios-por-estado', 'Usuarios por estado', 'pie',
                        "select decode(estado, 'A', 'Activo', 'I', 'Inactivo', 'B', 'Bloqueado') etiqueta, count(*) valor\n"
                        "  from adm_seg_usuario\n group by estado", 60, True, 4)
    o += region_grafico('usuarios-por-app', 'Usuarios con acceso por aplicación', 'bar',
                        "select a.nombre etiqueta, count(distinct v.usuario_id) valor\n  from adm_seg_aplicacion a\n"
                        "  left join adm_seg_usuario_permiso_v v on v.aplicacion_id = a.aplicacion_id\n group by a.nombre, a.orden\n order by a.orden", 70, False, 4)
    o += region_grafico('incidentes-por-dia', 'Incidentes por día (últimos 14 días)', 'line',
                        "select to_char(trunc(fecha), 'DD/MM') etiqueta, count(*) valor\n  from adm_aud_error\n"
                        " where fecha >= trunc(current_date) - 13\n group by trunc(fecha)\n order by trunc(fecha)", 80, False, 4)
    o.append(")")
    guardar('p00001-home.apx', o)


def pagina_cambiar_password():
    """Formulario angosto y centrado; botones abajo: Cancelar a la izquierda, acción principal a la derecha."""
    o = cabecera(90, 'Cambiar mi contraseña', 'CAMBIAR-PASSWORD', None,
                 "Cambie su contraseña de acceso.\nEs obligatorio en el primer ingreso o después de un reseteo. Use al menos 8 caracteres con letras y números.")
    o += ["", "    region datos (", "        name: Nueva contraseña", "        type: staticContent", "        layout {", "            sequence: 20",
          "            slot: BODY", "            column: 4", "            columnSpan: 6", "        }", "        appearance {",
          "            template: @/standard", "            templateOptions: #DEFAULT#", "        }", "    )",
          "", "    region botones (", "        name: Botones", "        type: staticContent", "        layout {", "            sequence: 30",
          "            slot: BODY", "            column: 4", "            columnSpan: 6", "        }", "        appearance {",
          "            template: @/buttons-container", "            templateOptions: #DEFAULT#", "        }", "    )"]
    for i, (n, et, inline, ayuda) in enumerate([
            ('PASSWORD_ACTUAL', 'Contraseña actual', 'Su contraseña vigente', 'Contraseña con la que ingresó (o la temporal recibida).'),
            ('PASSWORD_NUEVO', 'Nueva contraseña', 'Mín. 8, letras y números', 'Debe ser distinta a la actual.'),
            ('PASSWORD_CONFIRMA', 'Confirmar nueva contraseña', 'Repita la nueva', 'Escriba nuevamente la nueva contraseña.')]):
        o += ["", f"    pageItem P90_{n} (", "        type: password", "        label {", f"            label: {et}", "        }",
              "        layout {", f"            sequence: {(i + 1) * 10}", "            region: @datos", "            slot: regionBody", "        }",
              "        appearance {", "            template: @/required-floating", "            templateOptions: #DEFAULT#", "        }",
              "        validation {", "            valueRequired: true", "        }", "        help {", f"            inlineHelpText: {inline}",
              f"            helpText: {ayuda}", "        }", "    )"]
    obligado = "adm_seg_seguridad_reg.debe_cambiar_password(:APP_USER)"
    # Cambio obligatorio: no puede seguir sin cambiarla -> "Cancelar y salir" cierra la sesión (vuelve al login)
    o += ["", "    button salir (", "        buttonName: SALIR", "        label: Cancelar y salir", "        layout {", "            sequence: 10",
          "            region: @botones", "            slot: PREVIOUS", "        }", "        appearance {", "            buttonTemplate: @/text",
          "            templateOptions: #DEFAULT#", "        }", "        behavior {", "            action: redirectUrl",
          "            targetUrl: &LOGOUT_URL.", "        }", "        serverSideCondition {", "            type: expression",
          "            language: plsql", "            plsqlExpression:" + code('plsql', obligado, 16), "        }", "    )",
          # Cambio voluntario (desde el menú): Cancelar vuelve al inicio
          "", "    button cancelar (", "        buttonName: CANCELAR", "        label: Cancelar", "        layout {", "            sequence: 11",
          "            region: @botones", "            slot: PREVIOUS", "        }", "        appearance {", "            buttonTemplate: @/text",
          "            templateOptions: #DEFAULT#", "        }", "        behavior {", "            action: redirectThisApp", "            target: {",
          "                page: 1", "            }", "        }", "        serverSideCondition {", "            type: expression",
          "            language: plsql", "            plsqlExpression:" + code('plsql', "not " + obligado, 16), "        }", "    )",
          "", "    button cambiar (", "        buttonName: CAMBIAR", "        label: Cambiar contraseña", "        layout {", "            sequence: 20",
          "            region: @botones", "            slot: NEXT", "        }", "        appearance {", "            buttonTemplate: @/text",
          "            hot: true", "            templateOptions: #DEFAULT#", "        }", "    )",
          "", "    process cambiar-password (", "        name: Cambiar contraseña", "        type: executeCode", "        source {",
          "            plsqlCode:" + code('plsql', "adm_seg_usuario_api.cambiar_password(\n    i_username          => :APP_USER,\n"
                                              "    i_password_actual   => :P90_PASSWORD_ACTUAL,\n    i_password_nuevo    => :P90_PASSWORD_NUEVO,\n"
                                              "    i_password_confirma => :P90_PASSWORD_CONFIRMA);", 16),
          "        }", "        execution {", "            sequence: 10", "        }", "        serverSideCondition {",
          "            whenButtonPressed: @cambiar", "        }", "        successMessage {", "            successMessage: Contraseña actualizada.",
          "        }", "    )",
          "", "    branch ir-a-inicio (", "        name: Ir al inicio", "        execution {", "            sequence: 10",
          "            point: afterProcessing", "        }", "        behavior {", "            type: pageOrUrl", "            target: {",
          "                page: 1", "            }", "        }", "    )", ")"]
    guardar('p00090-cambiar-password.apx', o)



def pagina_cambio_obligatorio():
    """Cambio de contraseña obligatorio: mismo diseño que el login (sin menú). Destino del
    proceso 'forzar-cambio-password' de todas las apps."""
    o = ["page 91 (", "    name: Cambio de contraseña obligatorio", "    alias: CAMBIO-OBLIGATORIO",
         "    title: &APP_TITLE. - Cambiar contraseña", "    appearance {", "        pageTemplate: @/login",
         "        templateOptions: #DEFAULT#", "    }", "    navigation {", "        warnOnUnsavedChanges: false", "    }",
         "    security {", "        pageAccessProtection: argumentsMustHaveChecksum", "        formAutoComplete: false", "    }",
         "    help {", "        helpText:" + ml("Por seguridad debe definir una contraseña nueva antes de continuar.\n"
                                           "Use al menos 8 caracteres con letras y números. Si no desea hacerlo ahora, salga del sistema.", 12), "    }",
         "", "    region cambio (", "        name: Cambiar contraseña", "        title: Cambie su contraseña", "        type: staticContent",
         "        source {", "            htmlCode: <p class=\"u-textCenter\">Por seguridad debe definir una contraseña nueva para continuar.</p>",
         "        }", "        layout {", "            sequence: 10", "            slot: contentBody", "        }", "        appearance {",
         "            template: @/login", "            templateOptions: #DEFAULT#", "        }", "        image {",
         "            fileUrl: #APP_FILES#icons/app-icon-512.png", "        }", "    )"]
    for i, (n, ph, icono, auto) in enumerate([
            ('PASSWORD_ACTUAL', 'Contraseña actual o temporal', 'fa-key', 'current-password'),
            ('PASSWORD_NUEVO', 'Nueva contraseña (mín. 8, letras y números)', 'fa-lock', 'new-password'),
            ('PASSWORD_CONFIRMA', 'Repita la nueva contraseña', 'fa-lock', 'new-password')]):
        o += ["", f"    pageItem P91_{n} (", "        type: password", "        label {", f"            label: {ph}", "        }",
              "        layout {", f"            sequence: {(i + 1) * 10}", "            region: @cambio", "            slot: regionBody", "        }",
              "        appearance {", "            template: @/hidden", "            templateOptions: #DEFAULT#", f"            icon: {icono}",
              "            width: 40", f"            valuePlaceholder: {ph}", "        }", "        validation {", "            valueRequired: true",
              "            maxLength: 100", "        }", "        advanced {", f'            customAttributes: autocomplete="{auto}"', "        }",
              "        sessionState {", "            storage: request", "        }", "    )"]
    o += ["", "    button cambiar (", "        buttonName: CAMBIAR", "        label: Cambiar contraseña y continuar", "        layout {",
          "            sequence: 40", "            region: @cambio", "            slot: next", "        }", "        appearance {",
          "            buttonTemplate: @/text", "            hot: true", "            templateOptions: #DEFAULT#", "        }",
          "        behavior {", "            warnOnUnsavedChanges: doNotCheck", "        }", "    )",
          "", "    button salir (", "        buttonName: SALIR", "        label: Salir", "        layout {", "            sequence: 50",
          "            region: @cambio", "            slot: next", "        }", "        appearance {", "            buttonTemplate: @/text",
          "            templateOptions: #DEFAULT#", "        }", "        behavior {", "            action: redirectUrl",
          "            targetUrl: &LOGOUT_URL.", "        }", "    )",
          "", "    process cambiar-password (", "        name: Cambiar contraseña", "        type: executeCode", "        source {",
          "            plsqlCode:" + code('plsql', "adm_seg_usuario_api.cambiar_password(\n    i_username          => :APP_USER,\n"
                                              "    i_password_actual   => :P91_PASSWORD_ACTUAL,\n    i_password_nuevo    => :P91_PASSWORD_NUEVO,\n"
                                              "    i_password_confirma => :P91_PASSWORD_CONFIRMA);", 16),
          "        }", "        execution {", "            sequence: 10", "        }", "        serverSideCondition {",
          "            whenButtonPressed: @cambiar", "        }", "        successMessage {", "            successMessage: Contraseña actualizada. ¡Bienvenido!",
          "        }", "    )",
          "", "    branch ir-a-inicio (", "        name: Ir al inicio", "        execution {", "            sequence: 10",
          "            point: afterProcessing", "        }", "        behavior {", "            type: pageOrUrl", "            target: {",
          "                page: 1", "            }", "        }", "    )", ")"]
    guardar('p00091-cambio-obligatorio.apx', o)


if __name__ == '__main__':
    # Las páginas de mantenimiento se regeneran; 1 (inicio), 90 (cambiar contraseña) y 9999 (login) no.
    conservar = {'p00000-global-page.apx', 'p09999-login.apx'}
    for f in os.listdir(PAGINAS):
        if f not in conservar:
            os.remove(os.path.join(PAGINAS, f))

    EST = "decode(estado, 'A', 'Activo', 'I', 'Inactivo', 'B', 'Bloqueado', estado) estado"

    # ------------------------------------------------------------------ USUARIOS (vía api)
    pagina_listado('p00030-usuarios.apx', 30, 'USUARIOS', 'Usuarios', 'adm-seg-usuario-ver', 'usuarios',
        "select u.usuario_id, u.username, u.nombres || ' ' || u.apellidos nombre, u.email,\n"
        "       decode(u.tipo_autenticacion, 'LOCAL', 'Local', 'SSO') autenticacion,\n"
        "       e.razon_social empresa,\n"
        "       decode(u.estado, 'A', 'Activo', 'I', 'Inactivo', 'B', 'Bloqueado', u.estado) estado,\n"
        "       to_char(u.fecha_ultimo_login, 'DD/MM/YYYY HH24:MI') ultimo_ingreso\n"
        "  from adm_seg_usuario u\n"
        "  left join adm_gen_empresa e on e.empresa_id = u.empresa_id_defecto",
        'USUARIO_ID', 31,
        [('USERNAME', 'Usuario', 'STRING', None), ('NOMBRE', 'Nombre', 'STRING', None), ('EMAIL', 'Email', 'STRING', None),
         ('AUTENTICACION', 'Autenticación', 'STRING', None), ('EMPRESA', 'Empresa por defecto', 'STRING', None),
         ('ESTADO', 'Estado', 'STRING', 'Bloqueado = superó los intentos fallidos.'), ('ULTIMO_INGRESO', 'Último ingreso', 'STRING', None)],
        "Usuarios de todas las aplicaciones.\nUse Crear usuario para dar de alta o el lápiz para editar, asignar roles o resetear la contraseña.",
        "Listado de adm_seg_usuario. Alta/edición en la página 31 vía adm_seg_usuario_api.", 'Crear usuario', 'adm-seg-usuario-gestionar')

    pagina_formulario('p00031-usuario.apx', 31, 'USUARIO', 'Usuario', 'adm-seg-usuario-ver', 'adm_seg_usuario', 'USUARIO_ID',
        [dict(n='USERNAME', tipo='textField', etiqueta='Usuario', req=True, solo_alta=True, inline='Se guarda en mayúsculas', ayuda='Nombre con el que iniciará sesión. Debe ser único y no se puede cambiar después.'),
         dict(n='EMAIL', tipo='textField', etiqueta='Email', req=True, inline='Correo único', ayuda='Correo electrónico de contacto; no puede repetirse.'),
         dict(n='NOMBRES', tipo='textField', etiqueta='Nombres', req=True, inline='Nombres de la persona', ayuda='Nombres tal como se mostrarán en las aplicaciones.'),
         dict(n='APELLIDOS', tipo='textField', etiqueta='Apellidos', inline='Opcional', ayuda='Apellidos de la persona.'),
         dict(n='TIPO_AUTENTICACION', tipo='selectList', etiqueta='Autenticación', req=True, lov='tipo-autenticacion', solo_alta=True, inline='Local o SSO', ayuda='Local: usa contraseña propia. SSO: se autentica con un proveedor externo.'),
         dict(n='PASSWORD', tipo='password', etiqueta='Contraseña inicial', sin_fuente=True, solo_alta=True, inline='Mín. 8, letras y números', ayuda='Solo para usuarios locales. Es temporal: deberá cambiarla en su primer ingreso.'),
         dict(n='EMPRESA_ID_DEFECTO', tipo='selectList', etiqueta='Empresa por defecto', lov='empresas', nulo='- Ninguna -', dt='number', inline='Empresa habitual', ayuda='Empresa con la que el usuario trabaja por defecto.'),
         dict(n='ESTADO', tipo='selectList', etiqueta='Estado', req=True, lov='estado-usuario', solo_edicion=True, inline='Activo, inactivo o bloqueado', ayuda='Pase a Activo para desbloquear; Inactivo impide el ingreso sin borrar al usuario.')],
        "Alta y edición de usuarios.\nAl crear, el usuario recibe una contraseña inicial que deberá cambiar. Al editar, puede asignarle roles y resetear su contraseña desde la sección Roles asignados.",
        permite_eliminar=False,
        procesamiento={
            'CREAR': """adm_seg_usuario_api.crear(
    i_username           => :P31_USERNAME,
    i_email              => :P31_EMAIL,
    i_nombres            => :P31_NOMBRES,
    i_apellidos          => :P31_APELLIDOS,
    i_tipo_autenticacion => :P31_TIPO_AUTENTICACION,
    i_password           => :P31_PASSWORD,
    i_empresa_id_defecto => :P31_EMPRESA_ID_DEFECTO,
    o_usuario_id         => :P31_USUARIO_ID);""",
            'GUARDAR': """adm_seg_usuario_api.modificar(
    i_usuario_id         => :P31_USUARIO_ID,
    i_email              => :P31_EMAIL,
    i_nombres            => :P31_NOMBRES,
    i_apellidos          => :P31_APELLIDOS,
    i_empresa_id_defecto => :P31_EMPRESA_ID_DEFECTO,
    i_estado             => :P31_ESTADO);"""},
        extras=region_roles_usuario(31))

    pagina_accion('p00032-reset-password.apx', 32, 'RESET-PASSWORD', 'Resetear contraseña', 'adm-seg-usuario-reset-password',
        "Asigne una contraseña temporal al usuario.\nQueda desbloqueado y deberá cambiarla en su próximo ingreso.",
        [dict(n='USUARIO_ID', tipo='hidden'),
         dict(n='PASSWORD', tipo='password', etiqueta='Nueva contraseña temporal', req=True, inline='Mín. 8, letras y números', ayuda='Comuníquela al usuario por un canal seguro.')],
        [('resetear', 'RESETEAR', 'Resetear contraseña', True, None)],
        [('resetear', "adm_seg_usuario_api.resetear_password(\n    i_usuario_id     => :P32_USUARIO_ID,\n    i_password_nuevo => :P32_PASSWORD);",
          'Contraseña reseteada y usuario desbloqueado.')])

    pagina_accion('p00034-asignar-rol.apx', 34, 'ASIGNAR-ROL', 'Asignar o quitar rol', 'adm-seg-usuario-gestionar',
        "Asigne un rol al usuario, para una empresa o para todas, con fecha de vigencia.\nPara quitarlo, elija el mismo rol y empresa y presione Quitar rol.",
        [dict(n='USUARIO_ID', tipo='hidden'),
         dict(n='ROL_ID', tipo='selectList', etiqueta='Rol', req=True, lov='roles', inline='Rol a asignar', ayuda='Conjunto de permisos que recibirá el usuario.'),
         dict(n='EMPRESA_ID', tipo='selectList', etiqueta='Empresa', lov='empresas', nulo='Todas las empresas', inline='Vacío = todas', ayuda='Empresa donde aplica el rol. Si no elige ninguna, aplica a todas.'),
         dict(n='FECHA_DESDE', tipo='datePicker', etiqueta='Desde', req=True, inline='Inicio de vigencia', ayuda='Fecha desde la que el rol tiene efecto.'),
         dict(n='FECHA_HASTA', tipo='datePicker', etiqueta='Hasta', inline='Vacío = sin vencimiento', ayuda='Fecha hasta la que el rol tiene efecto.')],
        [('quitar', 'QUITAR', 'Quitar rol', False, '¿Quitar este rol al usuario?'), ('asignar', 'ASIGNAR', 'Asignar rol', True, None)],
        [('asignar', "adm_seg_usuario_api.asignar_rol(\n    i_usuario_id  => :P34_USUARIO_ID,\n    i_rol_id      => :P34_ROL_ID,\n    i_empresa_id  => :P34_EMPRESA_ID,\n    i_fecha_desde => to_date(:P34_FECHA_DESDE),\n    i_fecha_hasta => to_date(:P34_FECHA_HASTA));", 'Rol asignado.'),
         ('quitar', "adm_seg_usuario_api.quitar_rol(\n    i_usuario_id => :P34_USUARIO_ID,\n    i_rol_id     => :P34_ROL_ID,\n    i_empresa_id => :P34_EMPRESA_ID);", 'Rol quitado.')])

    # ------------------------------------------------------------------ ROLES (vía api, permisos en shuttle)
    pagina_listado('p00020-roles.apx', 20, 'ROLES', 'Roles', 'adm-seg-rol-gestionar', 'roles',
        "select r.rol_id, r.codigo, r.nombre, coalesce(a.nombre, 'Global') aplicacion,\n"
        "       decode(r.es_superadmin, 'S', 'Sí', 'No') superadmin,\n"
        "       (select count(*) from adm_seg_rol_permiso rp where rp.rol_id = r.rol_id) permisos,\n"
        "       (select count(*) from adm_seg_usuario_rol ur where ur.rol_id = r.rol_id) usuarios,\n"
        "       decode(r.estado, 'A', 'Activo', 'Inactivo') estado\n"
        "  from adm_seg_rol r\n"
        "  left join adm_seg_aplicacion a on a.aplicacion_id = r.aplicacion_id",
        'ROL_ID', 21,
        [('CODIGO', 'Código', 'STRING', None), ('NOMBRE', 'Nombre', 'STRING', None), ('APLICACION', 'Aplicación', 'STRING', None),
         ('SUPERADMIN', 'Superadmin', 'STRING', None), ('PERMISOS', 'Permisos', 'NUMBER', None), ('USUARIOS', 'Usuarios', 'NUMBER', None),
         ('ESTADO', 'Estado', 'STRING', None)],
        "Roles de cada aplicación o globales.\nUn rol agrupa permisos; ábralo para elegir sus permisos.",
        "Listado de adm_seg_rol. Alta/edición en la página 21 vía adm_seg_rol_api.", 'Crear rol')

    pagina_formulario('p00021-rol.apx', 21, 'ROL', 'Rol', 'adm-seg-rol-gestionar', 'adm_seg_rol', 'ROL_ID',
        [dict(n='CODIGO', tipo='textField', etiqueta='Código', req=True, inline='<APP>_<NOMBRE> en mayúsculas', ayuda='Código único del rol, por ejemplo ERP_CONTADOR.'),
         dict(n='NOMBRE', tipo='textField', etiqueta='Nombre', req=True, inline='Nombre visible', ayuda='Nombre que verán los administradores.'),
         dict(n='APLICACION_ID', tipo='selectList', etiqueta='Aplicación', lov='aplicaciones', nulo='Global (todas)', dt='number', inline='Vacío = rol global', ayuda='Aplicación a la que pertenece el rol. Los roles globales aplican a todas.'),
         dict(n='DESCRIPCION', tipo='textarea', etiqueta='Descripción', inline='Responsabilidades', ayuda='Qué tareas cubre este rol.'),
         dict(n='ES_SUPERADMIN', tipo='selectList', etiqueta='Superadmin', req=True, lov='si-no', inline='Sí = acceso total', ayuda='Un rol superadmin recibe todos los permisos de todas las aplicaciones. Úselo solo para administradores técnicos.'),
         dict(n='ESTADO', tipo='selectList', etiqueta='Estado', req=True, lov='estado-ai', inline='Activo o inactivo', ayuda='Un rol inactivo deja de otorgar permisos.'),
         dict(n='PERMISOS', tipo='shuttle', etiqueta='Permisos', lov='permisos', sin_fuente=True, inline='Pase a la derecha los permisos del rol', ayuda='Elija los permisos que otorga este rol. Se guardan junto con el rol.')],
        "Alta y edición de roles.\nElija los permisos del rol en la lista de la derecha y guarde.",
        procesamiento={
            'CREAR': """adm_seg_rol_api.crear(
    i_aplicacion_id => :P21_APLICACION_ID,
    i_codigo        => :P21_CODIGO,
    i_nombre        => :P21_NOMBRE,
    i_descripcion   => :P21_DESCRIPCION,
    i_es_superadmin => :P21_ES_SUPERADMIN,
    i_estado        => :P21_ESTADO,
    o_rol_id        => :P21_ROL_ID);
adm_seg_rol_api.asignar_permisos(i_rol_id => :P21_ROL_ID, i_permisos => :P21_PERMISOS);""",
            'GUARDAR': """adm_seg_rol_api.modificar(
    i_rol_id        => :P21_ROL_ID,
    i_aplicacion_id => :P21_APLICACION_ID,
    i_codigo        => :P21_CODIGO,
    i_nombre        => :P21_NOMBRE,
    i_descripcion   => :P21_DESCRIPCION,
    i_es_superadmin => :P21_ES_SUPERADMIN,
    i_estado        => :P21_ESTADO);
adm_seg_rol_api.asignar_permisos(i_rol_id => :P21_ROL_ID, i_permisos => :P21_PERMISOS);""",
            'ELIMINAR': "adm_seg_rol_api.eliminar(i_rol_id => :P21_ROL_ID);"},
        extras=["", "    process cargar-permisos (", "        name: Cargar permisos del rol", "        type: executeCode",
                "        source {", "            plsqlCode:" + code('plsql', ":P21_PERMISOS := adm_seg_rol_api.obtener_permisos(i_rol_id => :P21_ROL_ID);", 16), "        }",
                "        execution {", "            sequence: 20", "            point: beforeHeader", "        }",
                "        serverSideCondition {", "            type: itemIsNotNull", "            item: P21_ROL_ID", "        }", "    )"])

    # ------------------------------------------------------------------ CATÁLOGOS (guardado automático de APEX)
    cat = [
        ('40', 'APLICACIONES', 'Aplicaciones', 'aplicaciones', 'APLICACION_ID', 'adm_seg_aplicacion', '41', 'APLICACION', 'Aplicación', 'adm-seg-aplicacion-gestionar',
         "select aplicacion_id, codigo, nombre, apex_app_id, orden,\n       decode(estado, 'A', 'Activo', 'Inactivo') estado\n  from adm_seg_aplicacion",
         [('CODIGO', 'Código', 'STRING', 'Prefijo de los objetos de la app.'), ('NOMBRE', 'Nombre', 'STRING', None), ('APEX_APP_ID', 'ID App APEX', 'NUMBER', None),
          ('ORDEN', 'Orden', 'NUMBER', None), ('ESTADO', 'Estado', 'STRING', None)],
         [dict(n='CODIGO', tipo='textField', etiqueta='Código', req=True, inline='3 letras en mayúsculas', ayuda='Prefijo de todos los objetos de la aplicación (ADM, ERP, CRM).'),
          dict(n='NOMBRE', tipo='textField', etiqueta='Nombre', req=True, inline='Nombre visible', ayuda='Nombre de la aplicación.'),
          dict(n='DESCRIPCION', tipo='textarea', etiqueta='Descripción', inline='Opcional', ayuda='Descripción funcional.'),
          dict(n='APEX_APP_ID', tipo='numberField', etiqueta='ID App APEX', dt='number', inline='Bloques de 100', ayuda='ID fijo de la app APEX: ADM 100, ERP 200, CRM 300.'),
          dict(n='ICONO', tipo='textField', etiqueta='Icono', inline='Ej. fa-cubes', ayuda='Clase de ícono Font APEX.'),
          dict(n='ORDEN', tipo='numberField', etiqueta='Orden', req=True, dt='number', inline='Orden en menús', ayuda='Orden de presentación.'),
          dict(n='ESTADO', tipo='selectList', etiqueta='Estado', req=True, lov='estado-ai', inline='Activo o inactivo', ayuda='Una aplicación inactiva no permite el ingreso.')],
         "Catálogo de aplicaciones controladas por la seguridad central.", 'Crear aplicación'),
        ('42', 'MODULOS', 'Módulos', 'modulos', 'MODULO_ID', 'adm_seg_modulo', '43', 'MODULO', 'Módulo', 'adm-seg-aplicacion-gestionar',
         "select m.modulo_id, a.codigo aplicacion, m.codigo, m.nombre, m.orden,\n       decode(m.estado, 'A', 'Activo', 'Inactivo') estado\n  from adm_seg_modulo m\n  join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id",
         [('APLICACION', 'Aplicación', 'STRING', None), ('CODIGO', 'Código', 'STRING', None), ('NOMBRE', 'Nombre', 'STRING', None),
          ('ORDEN', 'Orden', 'NUMBER', None), ('ESTADO', 'Estado', 'STRING', None)],
         [dict(n='APLICACION_ID', tipo='selectList', etiqueta='Aplicación', req=True, lov='aplicaciones', dt='number', inline='Aplicación dueña', ayuda='Aplicación a la que pertenece el módulo.'),
          dict(n='CODIGO', tipo='textField', etiqueta='Código', req=True, inline='3 letras en mayúsculas', ayuda='Código único dentro de la aplicación (FIN, STK…).'),
          dict(n='NOMBRE', tipo='textField', etiqueta='Nombre', req=True, inline='Nombre visible', ayuda='Nombre del módulo.'),
          dict(n='ICONO', tipo='textField', etiqueta='Icono', inline='Ej. fa-money', ayuda='Clase de ícono Font APEX.'),
          dict(n='ORDEN', tipo='numberField', etiqueta='Orden', req=True, dt='number', inline='Orden en menús', ayuda='Orden de presentación.'),
          dict(n='ESTADO', tipo='selectList', etiqueta='Estado', req=True, lov='estado-ai', inline='Activo o inactivo', ayuda='Un módulo inactivo no otorga permisos.')],
         "Módulos funcionales de cada aplicación.", 'Crear módulo'),
        ('44', 'PERMISOS', 'Permisos', 'permisos', 'PERMISO_ID', 'adm_seg_permiso', '45', 'PERMISO', 'Permiso', 'adm-seg-aplicacion-gestionar',
         "select p.permiso_id, a.codigo || ' / ' || m.codigo modulo, p.codigo, p.nombre,\n       initcap(p.tipo) tipo, p.apex_pagina_id,\n       decode(p.estado, 'A', 'Activo', 'Inactivo') estado\n  from adm_seg_permiso p\n  join adm_seg_modulo m on m.modulo_id = p.modulo_id\n  join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id",
         [('MODULO', 'Módulo', 'STRING', None), ('CODIGO', 'Código', 'STRING', 'Igual al authorization scheme de APEX.'), ('NOMBRE', 'Nombre', 'STRING', None),
          ('TIPO', 'Tipo', 'STRING', None), ('APEX_PAGINA_ID', 'Página APEX', 'NUMBER', None), ('ESTADO', 'Estado', 'STRING', None)],
         [dict(n='MODULO_ID', tipo='selectList', etiqueta='Módulo', req=True, lov='modulos', dt='number', inline='Módulo dueño', ayuda='Módulo al que pertenece el permiso.'),
          dict(n='CODIGO', tipo='textField', etiqueta='Código', req=True, inline='APP_MOD_ENTIDAD_ACCION', ayuda='Debe coincidir con el authorization scheme de la app APEX.'),
          dict(n='NOMBRE', tipo='textField', etiqueta='Nombre', req=True, inline='Qué permite', ayuda='Descripción corta del permiso.'),
          dict(n='TIPO', tipo='selectList', etiqueta='Tipo', req=True, lov='tipo-permiso', inline='Página, acción o reporte', ayuda='Página: acceso a una página APEX. Acción: botón o proceso. Reporte: consultas y descargas.'),
          dict(n='APEX_PAGINA_ID', tipo='numberField', etiqueta='Página APEX', dt='number', inline='Solo tipo Página', ayuda='Número de página protegida cuando el tipo es Página.'),
          dict(n='ESTADO', tipo='selectList', etiqueta='Estado', req=True, lov='estado-ai', inline='Activo o inactivo', ayuda='Un permiso inactivo no se otorga.')],
         "Permisos atómicos de cada módulo.", 'Crear permiso'),
        ('50', 'EMPRESAS', 'Empresas', 'empresas', 'EMPRESA_ID', 'adm_gen_empresa', '51', 'EMPRESA', 'Empresa', 'adm-gen-empresa-gestionar',
         "select empresa_id, codigo, razon_social, nombre_comercial, nro_documento, zona_horaria,\n       decode(estado, 'A', 'Activo', 'Inactivo') estado\n  from adm_gen_empresa",
         [('CODIGO', 'Código', 'STRING', None), ('RAZON_SOCIAL', 'Razón social', 'STRING', None), ('NOMBRE_COMERCIAL', 'Nombre comercial', 'STRING', None),
          ('NRO_DOCUMENTO', 'Nro. documento', 'STRING', None), ('ZONA_HORARIA', 'Zona horaria', 'STRING', None), ('ESTADO', 'Estado', 'STRING', None)],
         [dict(n='CODIGO', tipo='textField', etiqueta='Código', req=True, inline='Código corto único', ayuda='Identificador corto de la empresa; no puede repetirse.'),
          dict(n='RAZON_SOCIAL', tipo='textField', etiqueta='Razón social', req=True, inline='Nombre legal', ayuda='Razón social tal como figura en los documentos legales.'),
          dict(n='NOMBRE_COMERCIAL', tipo='textField', etiqueta='Nombre comercial', inline='Opcional', ayuda='Nombre comercial o de fantasía.'),
          dict(n='NRO_DOCUMENTO', tipo='textField', etiqueta='Nro. documento', inline='RUC / NIT', ayuda='Número de identificación tributaria.'),
          dict(n='ZONA_HORARIA', tipo='textField', etiqueta='Zona horaria', inline='Ej. America/Asuncion', ayuda='Zona horaria IANA usada para las fechas de negocio de la empresa.'),
          dict(n='ESTADO', tipo='selectList', etiqueta='Estado', req=True, lov='estado-ai', inline='Activo o inactivo', ayuda='Las empresas inactivas no se ofrecen en las listas.')],
         "Empresas o unidades de negocio.", 'Crear empresa'),
        ('52', 'MENSAJES-ERROR', 'Mensajes de error', 'mensajes-error', 'MENSAJE_ERROR_ID', 'adm_gen_mensaje_error', '53', 'MENSAJE-ERROR', 'Mensaje de error', 'adm-gen-mensaje-gestionar',
         "select mensaje_error_id, codigo, mensaje\n  from adm_gen_mensaje_error",
         [('CODIGO', 'Constraint', 'STRING', 'Nombre exacto del constraint.'), ('MENSAJE', 'Mensaje para el usuario', 'STRING', None)],
         [dict(n='CODIGO', tipo='textField', etiqueta='Constraint', req=True, inline='En mayúsculas, ej. UK_ADM_USU_USERNAME', ayuda='Nombre exacto del constraint de la base de datos.'),
          dict(n='MENSAJE', tipo='textarea', etiqueta='Mensaje para el usuario', req=True, inline='Claro y sin términos técnicos', ayuda='Texto que verá el usuario cuando un dato viole esa regla.')],
         "Mensajes claros que ve el usuario cuando un dato viola una regla de la base de datos. Aplica a todas las aplicaciones.", 'Crear mensaje'),
    ]
    for (n, alias, titulo, region, pk, tabla, nf, alias_f, titulo_f, auth, sql, cols, items, ayuda, crear) in cat:
        pagina_listado(f'p000{n}-{region}.apx', int(n), alias, titulo, auth, region, sql, pk, int(nf), cols,
                       ayuda + "\nUse " + crear + " para agregar o el lápiz de cada fila para editar.",
                       f"Listado de {tabla}. Alta/edición en la página {nf} (guardado automático: catálogo simple).", crear)
        pagina_formulario(f'p000{nf}-{alias_f.lower()}.apx', int(nf), alias_f, titulo_f, auth, tabla, pk, items,
                          f"Alta y edición: {titulo_f.lower()}.\nLos campos marcados son obligatorios.")

    # ------------------------------------------------------------------ BITÁCORAS (solo lectura)
    pagina_listado('p00060-bitacora-login.apx', 60, 'BITACORA-LOGIN', 'Bitácora de accesos', 'adm-aud-login-ver', 'bitacora-login',
        "select l.login_id, l.fecha, l.username, initcap(replace(l.resultado, '_', ' ')) resultado,\n"
        "       coalesce(a.nombre, to_char(l.apex_app_id)) aplicacion, l.ip_cliente\n"
        "  from adm_aud_login l\n  left join adm_seg_aplicacion a on a.apex_app_id = l.apex_app_id",
        'LOGIN_ID', None,
        [('FECHA', 'Fecha', 'DATE', None), ('USERNAME', 'Usuario', 'STRING', None), ('RESULTADO', 'Resultado', 'STRING', 'Ok, Password Invalido, Bloqueado, Sin Acceso…'),
         ('APLICACION', 'Aplicación', 'STRING', None), ('IP_CLIENTE', 'IP', 'STRING', None)],
        "Historial de inicios de sesión de todas las aplicaciones.\nFiltre por usuario o resultado para investigar bloqueos o accesos denegados.",
        "Consulta de adm_aud_login (solo lectura).")
    pagina_listado('p00061-bitacora-errores.apx', 61, 'BITACORA-ERRORES', 'Bitácora de errores', 'adm-aud-error-ver', 'bitacora-errores',
        "select e.error_id, e.error_id incidente, e.fecha, coalesce(a.nombre, to_char(e.apex_app_id)) aplicacion,\n"
        "       e.apex_pagina_id pagina, e.username, e.componente, e.mensaje, e.ora_sqlerrm\n"
        "  from adm_aud_error e\n  left join adm_seg_aplicacion a on a.apex_app_id = e.apex_app_id",
        'ERROR_ID', None,
        [('INCIDENTE', 'Incidente', 'NUMBER', 'Número que ve el usuario en el mensaje de error.'), ('FECHA', 'Fecha', 'DATE', None),
         ('APLICACION', 'Aplicación', 'STRING', None), ('PAGINA', 'Página', 'NUMBER', None), ('USERNAME', 'Usuario', 'STRING', None),
         ('COMPONENTE', 'Componente', 'STRING', None), ('MENSAJE', 'Mensaje', 'STRING', None), ('ORA_SQLERRM', 'Detalle técnico', 'STRING', None)],
        "Incidentes inesperados registrados por el manejador de errores.\nBusque por el número de incidente que le informó el usuario.",
        "Consulta de adm_aud_error (solo lectura). Incidente = error_id.")
    pagina_inicio()
    pagina_cambiar_password()
    pagina_cambio_obligatorio()
    escribir_listas()
    escribir_breadcrumbs()
    print('ok')
