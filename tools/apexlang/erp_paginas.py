"""
Generador de la app 200 "ERP · Configuración" (APEXlang): app maestra del ERP modular.

Reutiliza el patrón de ADM (tools/apexlang/adm_paginas.py):
  - Listado: Interactive Report + botón Crear + lápiz por fila.
  - Alta/edición: formulario en panel lateral (drawer).
Además genera los componentes compartidos que las apps de módulo (210, 220…) suscribirán:
authorization schemes, LOVs, app items (empresa activa) y procesos de aplicación.

Uso:  python tools/apexlang/erp_paginas.py
Luego: apex validate -input apps/erp/apexlang
"""
import os

import adm_paginas as base

RAIZ = base.RAIZ
APP = os.path.join(RAIZ, 'apps', 'erp', 'apexlang')
SC = os.path.join(APP, 'shared-components')
base.PAGINAS = os.path.join(APP, 'pages')
code, ml, cabecera, guardar = base.code, base.ml, base.cabecera, base.guardar


def escribir(ruta, lineas):
    with open(ruta, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lineas) + '\n')


EMP = ':APP_EMPRESA_ID'

# ----------------------------------------------------------------------------- authorization schemes
PERMISOS = [
    ('erp-gen-catalogo-gestionar', 'ERP_GEN_CATALOGO_GESTIONAR'),
    ('erp-gen-empresa-configurar', 'ERP_GEN_EMPRESA_CONFIGURAR'),
    ('erp-gen-cotizacion-gestionar', 'ERP_GEN_COTIZACION_GESTIONAR'),
    ('erp-gen-persona-ver', 'ERP_GEN_PERSONA_VER'),
    ('erp-gen-persona-gestionar', 'ERP_GEN_PERSONA_GESTIONAR'),
    ('erp-gen-periodo-cerrar', 'ERP_GEN_PERIODO_CERRAR'),
]


def escribir_autorizaciones():
    o = []
    for aid, nombre, cuerpo, msg in [
            ('acceso-app', 'ACCESO_APP', 'return adm_seg_seguridad_reg.tiene_acceso_app(:APP_USER, :APP_ID);',
             'No tiene acceso a esta aplicación. Solicítelo al administrador.'),
            ('es-superadmin', 'ES_SUPERADMIN', 'return adm_seg_seguridad_reg.es_superadmin(:APP_USER);',
             'No tiene permiso para realizar esta acción.')] + [
            (aid, cod, f"return adm_seg_seguridad_reg.tiene_permiso(:APP_USER, '{cod}', {EMP});",
             'No tiene permiso para realizar esta acción en la empresa activa.') for aid, cod in PERMISOS]:
        o += [f"authorization {aid} (", f"    name: {nombre}", "    type: plSqlFunctionBody", "    settings {",
              f"        plsqlFunctionBody: {cuerpo}", "    }", "    error {", f"        errorMessage: {msg}", "    }", ")", ""]
    escribir(os.path.join(SC, 'authorizations.apx'), o[:-1])


# ----------------------------------------------------------------------------- LOVs
ESTATICAS = {
    'boolean': [('true', 'Yes', 'TRUE'), ('false', 'No', 'FALSE')],
    'estado-ai': [('activo', 'Activo', 'A'), ('inactivo', 'Inactivo', 'I')],
    'si-no': [('si', 'Sí', 'S'), ('no', 'No', 'N')],
    'tipo-impuesto': [('impuesto', 'Impuesto', 'I'), ('retencion', 'Retención', 'R'), ('percepcion', 'Percepción', 'P')],
    'tipo-ubicacion': [('departamento', 'Departamento / estado', 'DEP'), ('distrito', 'Distrito / municipio', 'DIS'), ('ciudad', 'Ciudad / localidad', 'CIU')],
    'fuente-cotizacion': [('bcp', 'Banco Central', 'BCP'), ('set', 'DNIT / SET', 'SET'), ('api', 'Servicio externo', 'API'), ('manual', 'Manual', 'MAN')],
    'tipo-cotizacion': [('compra', 'Compra', 'C'), ('venta', 'Venta', 'V')],
    'tipo-contribuyente': [('fisica', 'Persona física', 'F'), ('juridica', 'Persona jurídica', 'J')],
    'tipo-persona': [('fisica', 'Física', 'F'), ('juridica', 'Jurídica', 'J')],
    'tipo-dato-parametro': [('texto', 'Texto', 'T'), ('numero', 'Número', 'N'), ('fecha', 'Fecha (AAAA-MM-DD)', 'F'), ('si-no', 'Sí / No', 'S')],
    'tipo-deposito': [('propio', 'Propio', 'P'), ('terceros', 'De terceros / consignación', 'C'), ('transito', 'En tránsito', 'T')],
    'afectacion-iva': [('gravado', 'Gravado', '1'), ('exonerado', 'Exonerado', '2'), ('exento', 'Exento', '3'), ('parcial', 'Gravado parcial', '4')],
    'meses': [(f'm{i:02d}', n, str(i)) for i, n in enumerate(
        ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'], 1)],
}

DINAMICAS = {
    'monedas': "select codigo || ' - ' || nombre d, moneda_id r\n  from erp_gen_moneda\n where estado = 'A'\n order by codigo",
    'paises': "select nombre d, pais_id r\n  from erp_gen_pais\n where estado = 'A'\n order by nombre",
    'ubicaciones': ("select u.nombre || ' (' || decode(u.tipo, 'DEP', 'Dpto.', 'DIS', 'Distrito', 'Ciudad')\n"
                    "       || nvl2(p.nombre, ' - ' || p.nombre, null) || ')' d, u.ubicacion_id r\n"
                    "  from erp_gen_ubicacion u\n  left join erp_gen_ubicacion p on p.ubicacion_id = u.ubicacion_id_padre\n"
                    " where u.estado = 'A'\n order by u.nombre"),
    'impuestos': "select i.codigo || ' - ' || i.nombre || ' (' || p.codigo || ')' d, i.impuesto_id r\n  from erp_gen_impuesto i\n  join erp_gen_pais p on p.pais_id = i.pais_id\n order by p.codigo, i.codigo",
    'impuesto-tasas': "select i.codigo || ' / ' || t.codigo || ' - ' || t.nombre d, t.impuesto_tasa_id r\n  from erp_gen_impuesto_tasa t\n  join erp_gen_impuesto i on i.impuesto_id = t.impuesto_id\n order by i.codigo, t.codigo",
    'categorias-fiscales': "select c.codigo || ' - ' || c.nombre || ' (' || p.codigo || ')' d, c.categoria_fiscal_id r\n  from erp_gen_categoria_fiscal c\n  join erp_gen_pais p on p.pais_id = c.pais_id\n where c.estado = 'A'\n order by p.codigo, c.codigo",
    'empresas': "select codigo || ' - ' || razon_social d, empresa_id r\n  from adm_gen_empresa\n order by codigo",
    'empresa-activa': f"select codigo || ' - ' || razon_social d, empresa_id r\n  from adm_gen_empresa\n where empresa_id = {EMP}",
    'mis-empresas': "select codigo || ' - ' || razon_social d, empresa_id r\n  from erp_gen_usuario_empresa_v\n where upper(username) = upper(:APP_USER)\n order by codigo",
    'tipos-doc-identidad': "select t.codigo || ' - ' || t.nombre || ' (' || p.codigo || ')' d, t.tipo_doc_identidad_id r\n  from erp_gen_tipo_doc_identidad t\n  join erp_gen_pais p on p.pais_id = t.pais_id\n where t.estado = 'A'\n order by p.codigo, t.codigo",
    'modulos-erp': "select m.codigo || ' - ' || m.nombre d, m.codigo r\n  from adm_seg_modulo m\n  join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id\n where a.codigo = 'ERP'\n   and m.estado = 'A'\n order by m.orden",
    'rubros': "select nombre d, rubro_id r\n  from erp_gen_rubro\n where estado = 'A'\n order by nombre",
    'funcionalidades': "select nombre || ' (' || codigo || ')' d, funcionalidad_id r\n  from erp_gen_funcionalidad\n where estado = 'A'\n order by nombre",
    'tipos-rol': "select nombre d, tipo_rol_id r\n  from erp_gen_tipo_rol\n where estado = 'A'\n order by nombre",
    'sucursales': f"select establecimiento || ' - ' || nombre d, sucursal_id r\n  from erp_gen_sucursal\n where empresa_id = {EMP}\n   and estado = 'A'\n order by establecimiento",
    'departamentos': f"select codigo || ' - ' || nombre d, departamento_id r\n  from erp_gen_departamento\n where empresa_id = {EMP}\n   and estado = 'A'\n order by codigo",
    'puntos-expedicion': (f"select s.establecimiento || '-' || p.codigo || ' ' || p.nombre d, p.punto_expedicion_id r\n"
                          "  from erp_gen_punto_expedicion p\n  join erp_gen_sucursal s on s.sucursal_id = p.sucursal_id\n"
                          f" where s.empresa_id = {EMP}\n   and p.estado = 'A'\n order by s.establecimiento, p.codigo"),
    'periodos-cerrados': (f"select modulo || ' ' || lpad(mes, 2, '0') || '/' || anio d, periodo_id r\n  from erp_gen_periodo\n"
                          f" where empresa_id = {EMP}\n   and estado = 'C'\n order by anio desc, mes desc, modulo"),
    'usuarios': "select username || ' - ' || nombres || ' ' || apellidos d, usuario_id r\n  from adm_seg_usuario\n where estado = 'A'\n order by username",
    'personas': ("select p.razon_social || ' (' || p.nro_documento || nvl2(p.dv, '-' || p.dv, null) || ')' d, p.persona_id r\n"
                 "  from erp_gen_persona p\n where p.estado = 'A'\n order by p.razon_social"),
}


def escribir_lovs():
    o = []
    for lid in sorted(set(ESTATICAS) | set(DINAMICAS)):
        nombre = lid.upper().replace('-', '_')
        o += [f"lov {lid} (", f"    name: {nombre}"]
        if lid in ESTATICAS:
            o += ["    source {", "        location: staticValues", "    }"]
            for i, (eid, disp, ret) in enumerate(ESTATICAS[lid]):
                o += ["", f"    entry {eid} (", f"        sequence: {(i + 1) * 10}", f"        display: {disp}", f"        return: {ret}", "    )"]
            o += ["", ")", ""]
        else:
            o += ["    source {", "        type: sqlQuery", "        sqlQuery:" + code('sql', DINAMICAS[lid], 12), "    }",
                  "    columnMapping {", "        return: R", "        display: D", "    }", ")", ""]
    escribir(os.path.join(SC, 'lovs.apx'), o[:-1])


# ----------------------------------------------------------------------------- empresa activa
def escribir_app_items_y_procesos():
    o = []
    for item in ('APP_EMPRESA_ID', 'APP_EMPRESA_NOMBRE'):
        o += [f"appItem {item} (", "    security {", "        sessionStateProtection: checksumRequiredSessionLevel", "    }", ")", ""]
    escribir(os.path.join(SC, 'app-items.apx'), o[:-1])

    forzar = """-- Usuarios con debe_cambiar_password = 'S' (nuevos, reseteados, ADMIN inicial)
-- van a la página 91 de ADM (diseño de login, sin menú) hasta cambiar su contraseña.
if not (:APP_ID = 100 and :APP_PAGE_ID in (91, 9999))
   and adm_seg_seguridad_reg.debe_cambiar_password(:APP_USER)
then
    apex_util.redirect_url(
        p_url => apex_page.get_url(p_application => '100', p_page => '91'));
end if;"""
    empresa = """-- Empresa activa de la sesión: la empresa por defecto del usuario o la primera
-- habilitada (erp_gen_usuario_empresa_v). Se cambia en la página 95.
if :APP_EMPRESA_ID is null and :APP_USER is not null and :APP_USER <> 'nobody' then
    for r in (select empresa_id, razon_social
                from erp_gen_usuario_empresa_v
               where upper(username) = upper(:APP_USER)
               order by case es_defecto when 'S' then 0 else 1 end, codigo
               fetch first 1 row only) loop
        :APP_EMPRESA_ID     := r.empresa_id;
        :APP_EMPRESA_NOMBRE := r.razon_social;
    end loop;
end if;"""
    o = []
    for pid, nombre, plsql, seq in [('forzar-cambio-password', 'Forzar cambio de contraseña', forzar, 10),
                                    ('inicializar-empresa', 'Inicializar empresa activa', empresa, 20)]:
        o += [f"appProcess {pid} (", f"    name: {nombre}", "    type: executeCode", "    source {",
              "        plsqlCode:" + code('plsql', plsql, 12), "    }", "    execution {", f"        sequence: {seq}",
              "        point: beforeHeader", "    }", ")", ""]
    escribir(os.path.join(SC, 'app-processes.apx'), o[:-1])


# ----------------------------------------------------------------------------- menú, tarjetas, breadcrumb
GRUPOS = [
    # (id, etiqueta, ícono, [(id, etiqueta, ícono, página, descripción, auth)])
    ('empresa', 'Empresa', 'fa-building-o', [
        ('cfg-empresa', 'Datos de la empresa', 'fa-id-card-o', 10, 'País, monedas, rubro y datos fiscales de cada empresa.', 'erp-gen-empresa-configurar'),
        ('sucursales', 'Sucursales', 'fa-map-marker', 12, 'Establecimientos de la empresa activa.', 'erp-gen-empresa-configurar'),
        ('departamentos', 'Departamentos', 'fa-sitemap', 14, 'Unidades de negocio o áreas (opcional).', 'erp-gen-empresa-configurar'),
        ('puntos', 'Puntos de expedición', 'fa-print', 16, 'Puntos de emisión de comprobantes por sucursal.', 'erp-gen-empresa-configurar'),
        ('depositos', 'Depósitos', 'fa-archive', 18, 'Depósitos de stock por sucursal.', 'erp-gen-empresa-configurar'),
        ('usuarios-sucursal', 'Usuarios por sucursal', 'fa-users', 20, 'Qué sucursales opera cada usuario.', 'erp-gen-empresa-configurar'),
        ('func-empresa', 'Funcionalidades activas', 'fa-toggle-on', 22, 'Lo que usa la empresa según su rubro.', 'erp-gen-empresa-configurar'),
        ('parametros', 'Parámetros', 'fa-sliders', 80, 'Ajustes del comportamiento del ERP.', 'erp-gen-empresa-configurar'),
        ('periodos', 'Períodos', 'fa-calendar', 82, 'Apertura y cierre de meses por módulo.', 'erp-gen-periodo-cerrar'),
        ('habilitaciones', 'Habilitaciones de período', 'fa-unlock', 86, 'Permite a un usuario registrar en un mes cerrado.', 'erp-gen-periodo-cerrar')]),
    ('monedas-grp', 'Monedas', 'fa-money', [
        ('monedas', 'Monedas', 'fa-money', 30, 'Monedas y sus decimales.', 'erp-gen-catalogo-gestionar'),
        ('cotizaciones', 'Cotizaciones', 'fa-line-chart', 32, 'Tipos de cambio por fecha.', 'erp-gen-cotizacion-gestionar')]),
    ('impuestos-grp', 'Impuestos', 'fa-percent', [
        ('impuestos', 'Impuestos', 'fa-bank', 40, 'IVA, ISC, retenciones… por país.', 'erp-gen-catalogo-gestionar'),
        ('tasas', 'Tasas', 'fa-percent', 42, 'Tasas de cada impuesto.', 'erp-gen-catalogo-gestionar'),
        ('vigencias', 'Vigencias de tasas', 'fa-calendar-check-o', 44, 'Porcentaje de cada tasa desde una fecha.', 'erp-gen-catalogo-gestionar'),
        ('categorias', 'Categorías fiscales', 'fa-tags', 46, 'Cómo tributa cada producto.', 'erp-gen-catalogo-gestionar'),
        ('categoria-tasas', 'Tasas por categoría', 'fa-th-list', 48, 'Composición de cada categoría fiscal.', 'erp-gen-catalogo-gestionar'),
        ('probar-impuestos', 'Probar cálculo', 'fa-calculator', 50, 'Verifique cómo se calcula un monto.', 'erp-gen-catalogo-gestionar')]),
    ('personas-grp', 'Personas', 'fa-address-book-o', [
        ('personas', 'Personas', 'fa-address-book-o', 60, 'Padrón único de personas físicas y jurídicas.', 'erp-gen-persona-ver'),
        ('roles-persona', 'Roles por empresa', 'fa-user-circle-o', 62, 'Clientes, proveedores, empleados… de la empresa activa.', 'erp-gen-persona-ver'),
        ('tipos-rol', 'Tipos de rol', 'fa-tag', 64, 'Roles de persona disponibles.', 'erp-gen-catalogo-gestionar'),
        ('tipos-documento', 'Tipos de documento', 'fa-id-badge', 66, 'RUC, cédula, pasaporte…', 'erp-gen-catalogo-gestionar'),
        ('documentos-persona', 'Documentos adicionales', 'fa-files-o', 68, 'Otros documentos de cada persona.', 'erp-gen-persona-ver')]),
    ('catalogos', 'Catálogos', 'fa-book', [
        ('paises', 'Países', 'fa-globe', 70, 'Países y su moneda.', 'erp-gen-catalogo-gestionar'),
        ('ubicaciones', 'Ubicaciones', 'fa-map-o', 72, 'Departamentos, distritos y ciudades.', 'erp-gen-catalogo-gestionar'),
        ('feriados', 'Feriados', 'fa-calendar-times-o', 84, 'Feriados por país para vencimientos.', 'erp-gen-catalogo-gestionar'),
        ('funcionalidades', 'Funcionalidades', 'fa-puzzle-piece', 74, 'Catálogo de funcionalidades activables.', 'erp-gen-catalogo-gestionar'),
        ('rubros', 'Rubros', 'fa-industry', 76, 'Perfiles de rubro.', 'erp-gen-catalogo-gestionar'),
        ('rubro-func', 'Funcionalidades por rubro', 'fa-th', 78, 'Qué activa cada rubro.', 'erp-gen-catalogo-gestionar')]),
]
ACCESOS = [a for _, _, _, hijos in GRUPOS for a in hijos]


def entrada(eid, etiqueta, icono, seq, pagina=None, padre=None, auth=None, desc=None, url='#', cond_auth=False):
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
    if cond_auth:
        e += ["        serverSideCondition {", "            type: userIsAuthenticated", "        }"]
    e.append("    )")
    return e


def escribir_listas():
    o = ["list navigation-bar (", "    name: Navigation Bar"]
    o += entrada('empresa-activa', '&APP_EMPRESA_NOMBRE.', 'fa-building-o', 5, 95, cond_auth=True)
    o += entrada('app-user', '&APP_USER.', 'fa-user', 10)
    o[-1:-1] = ["        userDefinedAttributes {", "            2: has-username", "        }"]
    o += ["", "    entry --- (", "        label: ---", "        layout {", "            sequence: 20", "            parentEntry: @app-user",
          "        }", "        link {", "            target: {", "                type: url", "                url: separator",
          "            }", "        }", "    )"]
    o += entrada('sign-out', 'Cerrar sesión', 'fa-sign-out', 30, None, 'app-user', url='&LOGOUT_URL.', cond_auth=True)
    o += ["", ")", "", "list navigation-menu (", "    name: Navigation Menu"]
    o += entrada('inicio', 'Inicio', 'fa-home', 10, 1)
    seq = 20
    for gid, gnombre, gicono, hijos in GRUPOS:
        o += entrada(gid, gnombre, gicono, seq)
        for eid, et, ic, pag, desc, auth in hijos:
            seq += 1
            o += entrada(eid, et, ic, seq, pag, gid, auth)
        seq += 10
    o += ["", ")", "", "list accesos (", "    name: Accesos"]
    for i, (eid, et, ic, pag, desc, auth) in enumerate(ACCESOS):
        o += entrada('acc-' + eid, et, ic, (i + 1) * 10, pag, None, auth, desc)
    o += ["", ")"]
    escribir(os.path.join(SC, 'lists.apx'), o)


def escribir_breadcrumbs():
    entradas = [('home', 'Inicio', 1, None)] + [(a[0], a[1], a[3], 'home') for a in ACCESOS] + \
               [('cambiar-empresa', 'Cambiar empresa', 95, 'home')]
    o = ["breadcrumb breadcrumb (", "    name: Breadcrumb", ""]
    for i, (eid, nombre, pagina, padre) in enumerate(entradas):
        o += [f"    entry {eid} (", f"        name: {nombre}", f"        pageNumber: {pagina}"]
        if padre:
            o += ["        appearance {", f"            parentEntry: @{padre}", "        }"]
        o += ["        execution {", f"            sequence: {(i + 1) * 10}", "        }", "        link {", "            target: {",
              f"                page: {pagina}", "            }", "        }", "    )", ""]
    o.append(")")
    escribir(os.path.join(SC, 'breadcrumbs.apx'), o)


# ----------------------------------------------------------------------------- páginas especiales
def region_reporte(rid, titulo, sql, columnas, seq, cond=None, plantilla='standard'):
    o = ["", f"    region {rid} (", f"        name: {titulo}", "        type: classicReport", "        source {",
         "            location: localDatabase", "            type: sqlQuery", "            sqlQuery:" + code('sql', sql, 16), "        }",
         "        layout {", f"            sequence: {seq}", "            slot: BODY", "        }", "        appearance {",
         f"            template: @/{plantilla}", "            templateOptions: #DEFAULT#", "        }", "        componentAppearance {",
         "            template: @/standard", "            templateOptions: #DEFAULT#", "        }"]
    if cond:
        o += ["        serverSideCondition {", "            type: expression", "            language: plsql",
              "            plsqlExpression:" + code('plsql', cond, 16), "        }"]
    for i, (c, h) in enumerate(columnas):
        o += ["", f"        column {c} (", f"            reportColumnQueryId: {i + 1}", "            derivedColumn: N",
              "            heading {", f"                heading: {h}", "                alignment: start", "            }",
              "            layout {", f"                sequence: {(i + 1) * 10}", "                columnAlignment: start", "            }", "        )"]
    o.append("    )")
    return o


def pagina_inicio():
    o = cabecera(1, 'Inicio', 'HOME', None,
                 "Configuración general del ERP para la empresa activa.\n"
                 "Siga los pasos de Puesta en marcha y use las tarjetas para ir a cada configuración. "
                 "La empresa activa se cambia desde la barra superior.")
    pasos = f"""select 1 orden, 'Datos de la empresa (país, monedas, rubro)' paso,
       case when exists (select 1 from erp_gen_empresa_config where empresa_id = {EMP})
            then 'Listo' else 'Pendiente' end estado
  from dual
union all
select 2, 'Al menos una sucursal (establecimiento)',
       case when exists (select 1 from erp_gen_sucursal where empresa_id = {EMP} and estado = 'A')
            then 'Listo' else 'Pendiente' end
  from dual
union all
select 3, 'Punto de expedición por sucursal',
       case when exists (select 1 from erp_gen_punto_expedicion p join erp_gen_sucursal s on s.sucursal_id = p.sucursal_id
                          where s.empresa_id = {EMP} and p.estado = 'A')
            then 'Listo' else 'Pendiente' end
  from dual
union all
select 4, 'Depósito principal',
       case when exists (select 1 from erp_stk_deposito d join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
                          where s.empresa_id = {EMP} and d.estado = 'A')
            then 'Listo' else 'Pendiente' end
  from dual
union all
select 5, 'Funcionalidades del rubro activadas',
       case when exists (select 1 from erp_gen_empresa_func where empresa_id = {EMP} and estado = 'A')
            then 'Listo' else 'Pendiente' end
  from dual
union all
select 6, 'Cotización del día cargada',
       case when exists (select 1 from erp_gen_cotizacion
                          where fecha = trunc(current_date) and (empresa_id is null or empresa_id = {EMP}))
            then 'Listo' else 'Pendiente' end
  from dual
union all
select 7, 'Períodos del año creados',
       case when exists (select 1 from erp_gen_periodo where empresa_id = {EMP} and anio = extract(year from current_date))
            then 'Listo' else 'Pendiente' end
  from dual
 order by 1"""
    o += region_reporte('puesta-en-marcha', 'Puesta en marcha', pasos, [('ORDEN', 'Paso'), ('PASO', 'Qué configurar'), ('ESTADO', 'Estado')], 20)
    o += ["", "    region accesos (", "        name: Configuración", "        type: list", "        source {", "            list: @accesos",
          "        }", "        layout {", "            sequence: 30", "            slot: BODY", "        }", "        appearance {",
          "            template: @/standard", "            templateOptions: #DEFAULT#", "        }", "        componentAppearance {",
          "            listTemplate: @/cards", "            templateOptions: [", "                #DEFAULT#",
          "                t-Cards--featured force-fa-lg", "                t-Cards--displayIcons", "                t-Cards--3cols", "                t-Cards--desc-2ln",
          "                t-Cards--animColorFill", "            ]", "        }", "    )", ")"]
    guardar('p00001-home.apx', o)


def pagina_cambiar_empresa():
    o = cabecera(95, 'Cambiar empresa', 'CAMBIAR-EMPRESA', None,
                 "Elija la empresa con la que va a trabajar.\nSolo se listan las empresas donde tiene algún rol del ERP.")
    o += ["", "    region datos (", "        name: Empresa activa", "        type: staticContent", "        layout {", "            sequence: 20",
          "            slot: BODY", "            column: 4", "            columnSpan: 6", "        }", "        appearance {",
          "            template: @/standard", "            templateOptions: #DEFAULT#", "        }", "    )",
          "", "    pageItem P95_EMPRESA_ID (", "        type: selectList", "        label {", "            label: Empresa", "        }",
          "        layout {", "            sequence: 10", "            region: @datos", "            slot: regionBody", "        }",
          "        appearance {", "            template: @/required-floating", "            templateOptions: #DEFAULT#", "        }",
          "        validation {", "            valueRequired: true", "        }", "        lov {", "            type: sharedComponent",
          "            lov: @mis-empresas", "        }", "        default {", "            type: item", "            item: APP_EMPRESA_ID", "        }",
          "        help {", "            inlineHelpText: Empresas donde tiene acceso", "            helpText: Los datos y permisos de las pantallas se aplican a la empresa elegida.", "        }", "    )",
          "", "    button cambiar (", "        buttonName: CAMBIAR", "        label: Usar esta empresa", "        layout {", "            sequence: 10",
          "            region: @datos", "            slot: NEXT", "        }", "        appearance {", "            buttonTemplate: @/text", "            hot: true",
          "            templateOptions: #DEFAULT#", "        }", "    )"]
    cambio = """begin
    select empresa_id, razon_social
      into :APP_EMPRESA_ID, :APP_EMPRESA_NOMBRE
      from erp_gen_usuario_empresa_v
     where upper(username) = upper(:APP_USER)
       and empresa_id = :P95_EMPRESA_ID;
exception
    when no_data_found then
        raise_application_error(-20112, 'No tiene acceso a la empresa elegida.');
end;"""
    o += ["", "    process cambiar-empresa (", "        name: Cambiar empresa activa", "        type: executeCode", "        source {",
          "            plsqlCode:" + code('plsql', cambio, 16), "        }", "        execution {", "            sequence: 10", "        }",
          "        serverSideCondition {", "            whenButtonPressed: @cambiar", "        }", "        successMessage {",
          "            successMessage: Empresa activa: &APP_EMPRESA_NOMBRE.", "        }", "    )",
          "", "    branch ir-a-inicio (", "        name: Ir al inicio", "        execution {", "            sequence: 10",
          "            point: afterProcessing", "        }", "        behavior {", "            type: pageOrUrl", "            target: {",
          "                page: 1", "            }", "        }", "    )", ")"]
    guardar('p00095-cambiar-empresa.apx', o)


def pagina_probar_impuestos():
    o = cabecera(50, 'Probar cálculo', 'PROBAR-IMPUESTOS', 'erp-gen-catalogo-gestionar',
                 "Verifique cómo el motor de impuestos desglosa un monto.\n"
                 "Elija la categoría fiscal, el monto, si incluye impuestos y la moneda, y presione Calcular.")
    o += ["", "    region datos (", "        name: Datos del cálculo", "        type: staticContent", "        layout {", "            sequence: 20",
          "            slot: BODY", "        }", "        appearance {", "            template: @/standard", "            templateOptions: #DEFAULT#", "        }", "    )"]
    items = [('CATEGORIA_FISCAL_ID', 'selectList', 'Categoría fiscal', 'categorias-fiscales', None, 'Cómo tributa el producto', 'Define las tasas y la parte de la base que grava cada una.'),
             ('MONTO', 'numberField', 'Monto', None, None, 'Importe a desglosar', 'Precio total si incluye impuestos; base si no los incluye.'),
             ('INCLUYE_IMPUESTO', 'selectList', 'Incluye impuestos', 'si-no', 'S', 'Sí = precio final', 'Sí: el monto ya incluye los impuestos. No: se suman sobre el monto.'),
             ('MONEDA_ID', 'selectList', 'Moneda', 'monedas', None, 'Define el redondeo', 'Los importes se redondean a los decimales de la moneda.'),
             ('FECHA', 'datePicker', 'Fecha', None, None, 'Vacío = hoy', 'Se usa la tasa vigente a esta fecha.')]
    for i, (n, tipo, et, lov, defecto, inline, ayuda) in enumerate(items):
        o += ["", f"    pageItem P50_{n} (", f"        type: {tipo}", "        label {", f"            label: {et}", "        }", "        layout {",
              f"            sequence: {(i + 1) * 10}", "            region: @datos", "            slot: regionBody"]
        if i % 3:
            o.append("            startNewRow: false")
        o += ["        }", "        appearance {", f"            template: @/{'optional-floating' if n == 'FECHA' else 'required-floating'}",
              "            templateOptions: #DEFAULT#", "        }"]
        if n != 'FECHA':
            o += ["        validation {", "            valueRequired: true", "        }"]
        if lov:
            o += ["        lov {", "            type: sharedComponent", f"            lov: @{lov}", "        }"]
        if defecto:
            o += ["        default {", "            type: static", f"            staticValue: {defecto}", "        }"]
        o += ["        help {", f"            inlineHelpText: {inline}", f"            helpText: {ayuda}", "        }", "    )"]
    o += ["", "    button calcular (", "        buttonName: CALCULAR", "        label: Calcular", "        layout {", "            sequence: 10",
          "            region: @datos", "            slot: NEXT", "        }", "        appearance {", "            buttonTemplate: @/text", "            hot: true",
          "            templateOptions: #DEFAULT#", "        }", "    )"]
    sql = """select coalesce(i.codigo, '-') impuesto,
       c.codigo_tasa tasa,
       c.porcentaje,
       c.porcentaje_base,
       c.monto,
       c.monto_base,
       c.monto_impuesto
  from table(erp_gen_impuesto_api.obtener_calculo(
             i_categoria_fiscal_id => :P50_CATEGORIA_FISCAL_ID,
             i_fecha               => coalesce(to_date(:P50_FECHA), trunc(current_date)),
             i_monto               => to_number(:P50_MONTO),
             i_incluye_impuesto    => :P50_INCLUYE_IMPUESTO,
             i_moneda_id           => :P50_MONEDA_ID)) c
  left join erp_gen_impuesto i on i.impuesto_id = c.impuesto_id"""
    o += region_reporte('resultado', 'Resultado', sql,
                        [('IMPUESTO', 'Impuesto'), ('TASA', 'Tasa'), ('PORCENTAJE', '% tasa'), ('PORCENTAJE_BASE', '% de la base'),
                         ('MONTO', 'Parte del monto'), ('MONTO_BASE', 'Base imponible'), ('MONTO_IMPUESTO', 'Impuesto')], 30,
                        cond=":P50_CATEGORIA_FISCAL_ID is not null and :P50_MONTO is not null and :P50_MONEDA_ID is not null")
    o.append(")")
    guardar('p00050-probar-impuestos.apx', o)


# ----------------------------------------------------------------------------- items de formulario
def i(n, tipo, etiqueta, inline, ayuda, req=False, lov=None, nulo=None, dt=None, defecto=None, **kw):
    d = dict(n=n, tipo=tipo, etiqueta=etiqueta, inline=inline, ayuda=ayuda, req=req)
    if lov:
        d['lov'] = lov
    if nulo:
        d['nulo'] = nulo
    if dt:
        d['dt'] = dt
    if defecto:
        d['defecto'] = defecto
    d.update(kw)
    return d


def oculto_empresa():
    return dict(n='EMPRESA_ID', tipo='hidden', dt='number', defecto=('item', 'APP_EMPRESA_ID'))


ESTADO = i('ESTADO', 'selectList', 'Estado', 'Activo o inactivo', 'Los registros inactivos no se ofrecen en las listas.', True, 'estado-ai', defecto=('static', 'A'))


def sn(n, etiqueta, inline, ayuda, defecto='N'):
    return i(n, 'selectList', etiqueta, inline, ayuda, True, 'si-no', defecto=('static', defecto))


def sel(n, etiqueta, lov, inline, ayuda, req=True, nulo=None, popup=False, **kw):
    return i(n, 'popupLov' if popup else 'selectList', etiqueta, inline, ayuda, req, lov, nulo, dt='number', **kw)


def txt(n, etiqueta, inline, ayuda, req=False):
    return i(n, 'textField', etiqueta, inline, ayuda, req)


def num(n, etiqueta, inline, ayuda, req=False, defecto=None):
    return i(n, 'numberField', etiqueta, inline, ayuda, req, dt='number', defecto=('static', defecto) if defecto else None)


def area(n, etiqueta, inline, ayuda):
    return i(n, 'textarea', etiqueta, inline, ayuda)


def fecha(n, etiqueta, inline, ayuda, req=False):
    return i(n, 'datePicker', etiqueta, inline, ayuda, req, dt='date')


EST_SQL = "decode({p}estado, 'A', 'Activo', 'Inactivo') estado"


def catalogo(n_lista, alias, titulo, region, pk, tabla, n_form, alias_f, titulo_f, auth, sql, cols, items, ayuda, crear,
             permite_eliminar=True):
    base.pagina_listado(f'p{n_lista:05d}-{region}.apx', n_lista, alias, titulo, auth, region, sql, pk, n_form, cols,
                        ayuda + "\nUse " + crear + " para agregar o el lápiz de cada fila para editar.",
                        f"Listado de {tabla}. Alta/edición en la página {n_form} (guardado automático: catálogo).", crear)
    base.pagina_formulario(f'p{n_form:05d}-{alias_f.lower()}.apx', n_form, alias_f, titulo_f, auth, tabla, pk, items,
                           f"Alta y edición: {titulo_f.lower()}.\nLos campos marcados son obligatorios.", permite_eliminar=permite_eliminar)


def S(n, h, r=None):
    return (n, h, 'STRING', r)


def N(n, h, r=None):
    return (n, h, 'NUMBER', r)


def D(n, h, r=None):
    return (n, h, 'DATE', r)


# ----------------------------------------------------------------------------- generación
if __name__ == '__main__':
    conservar = {'p00000-global-page.apx', 'p09999-login.apx'}
    for f in os.listdir(base.PAGINAS):
        if f not in conservar:
            os.remove(os.path.join(base.PAGINAS, f))

    CFG = 'erp-gen-empresa-configurar'
    CAT = 'erp-gen-catalogo-gestionar'

    # ------------------------------------------------------------------ EMPRESA
    catalogo(10, 'EMPRESAS-CONFIG', 'Datos de la empresa', 'empresas-config', 'EMPRESA_CONFIG_ID', 'erp_gen_empresa_config', 11,
             'EMPRESA-CONFIG', 'Datos de la empresa', CFG,
             "select c.empresa_config_id, e.codigo, e.razon_social, p.nombre pais, mf.codigo moneda_funcional,\n"
             "       mr.codigo moneda_reporte, r.nombre rubro,\n"
             "       decode(c.precio_incluye_impuesto, 'S', 'Sí', 'No') precio_con_impuesto\n"
             "  from erp_gen_empresa_config c\n  join adm_gen_empresa e on e.empresa_id = c.empresa_id\n"
             "  join erp_gen_pais p on p.pais_id = c.pais_id\n  join erp_gen_moneda mf on mf.moneda_id = c.moneda_id_funcional\n"
             "  left join erp_gen_moneda mr on mr.moneda_id = c.moneda_id_reporte\n  left join erp_gen_rubro r on r.rubro_id = c.rubro_id",
             [S('CODIGO', 'Empresa'), S('RAZON_SOCIAL', 'Razón social'), S('PAIS', 'País'), S('MONEDA_FUNCIONAL', 'Moneda funcional'),
              S('MONEDA_REPORTE', 'Moneda de reporte'), S('RUBRO', 'Rubro'), S('PRECIO_CON_IMPUESTO', 'Precio con impuesto')],
             [sel('EMPRESA_ID', 'Empresa', 'empresas', 'Empresa de la Administración Central', 'Las empresas se crean en ADM; aquí se completa su configuración del ERP.', solo_alta=True),
              sel('PAIS_ID', 'País', 'paises', 'País fiscal', 'Define los impuestos, documentos de identidad y ubicaciones disponibles.'),
              sel('MONEDA_ID_FUNCIONAL', 'Moneda funcional', 'monedas', 'Moneda contable', 'Moneda en la que se lleva la contabilidad y se valoriza el stock (PYG en Paraguay).'),
              sel('MONEDA_ID_REPORTE', 'Moneda de reporte', 'monedas', 'Opcional, ej. USD', 'Segunda moneda para reportes gerenciales y de grupo.', req=False, nulo='- Ninguna -'),
              sel('RUBRO_ID', 'Rubro', 'rubros', 'Perfil de la empresa', 'Sugiere las funcionalidades a activar (ver Funcionalidades activas).', req=False, nulo='- Sin rubro -'),
              sn('PRECIO_INCLUYE_IMPUESTO', 'Precios con impuesto incluido', 'Habitual en Paraguay', 'Sí: los precios de venta se cargan con IVA incluido.', 'S'),
              i('TIPO_COTIZACION', 'selectList', 'Cotización por defecto', 'Compra o venta', 'Qué tasa se usa por defecto al convertir monedas.', True, 'tipo-cotizacion', defecto=('static', 'V')),
              i('TIPO_CONTRIBUYENTE', 'selectList', 'Tipo de contribuyente', 'Física o jurídica', 'Requerido por la facturación electrónica (SIFEN).', True, 'tipo-contribuyente', defecto=('static', 'J')),
              txt('DV_RUC', 'DV del RUC', '1 dígito', 'Dígito verificador del RUC cargado en la empresa (ADM).'),
              sn('ES_AGENTE_RETENCION', 'Agente de retención', 'Sí / No', 'Sí si la empresa fue designada agente de retención.'),
              sn('ES_EXPORTADOR', 'Exportador', 'Sí / No', 'Sí si la empresa realiza exportaciones.'),
              area('DIRECCION', 'Dirección fiscal', 'Calle y número', 'Dirección que figura en los comprobantes.'),
              sel('UBICACION_ID', 'Ciudad', 'ubicaciones', 'Ciudad fiscal', 'Ciudad de la dirección fiscal.', req=False, popup=True),
              txt('TELEFONO', 'Teléfono', 'Opcional', 'Teléfono de contacto.'),
              txt('EMAIL', 'Email', 'Opcional', 'Correo de la empresa (respuestas de SIFEN, avisos).')],
             "Configuración del ERP de cada empresa registrada en la Administración Central.", 'Configurar empresa', permite_eliminar=False)

    catalogo(12, 'SUCURSALES', 'Sucursales', 'sucursales', 'SUCURSAL_ID', 'erp_gen_sucursal', 13, 'SUCURSAL', 'Sucursal', CFG,
             "select s.sucursal_id, s.establecimiento, s.codigo, s.nombre, u.nombre ciudad,\n"
             "       decode(s.es_casa_matriz, 'S', 'Sí', 'No') casa_matriz, " + EST_SQL.format(p='s.') + "\n"
             "  from erp_gen_sucursal s\n  left join erp_gen_ubicacion u on u.ubicacion_id = s.ubicacion_id\n"
             f" where s.empresa_id = {EMP}",
             [S('ESTABLECIMIENTO', 'Establecimiento'), S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('CIUDAD', 'Ciudad'),
              S('CASA_MATRIZ', 'Casa matriz'), S('ESTADO', 'Estado')],
             [oculto_empresa(),
              txt('CODIGO', 'Código', 'Código interno corto', 'Identificador de la sucursal dentro de la empresa.', True),
              txt('NOMBRE', 'Nombre', 'Nombre visible', 'Nombre de la sucursal.', True),
              txt('ESTABLECIMIENTO', 'Establecimiento', '3 dígitos, ej. 001', 'Código de establecimiento de los comprobantes (SIFEN/timbrado).', True),
              area('DIRECCION', 'Dirección', 'Calle', 'Dirección de la sucursal.'),
              txt('NUMERO_CASA', 'Número de casa', 'Opcional', 'Número de casa (lo pide SIFEN).'),
              sel('UBICACION_ID', 'Ciudad', 'ubicaciones', 'Ciudad', 'Ciudad de la sucursal.', req=False, popup=True),
              txt('TELEFONO', 'Teléfono', 'Opcional', 'Teléfono de la sucursal.'),
              txt('EMAIL', 'Email', 'Opcional', 'Correo de la sucursal.'),
              sn('ES_CASA_MATRIZ', 'Casa matriz', 'Sí / No', 'Marque la sucursal principal.'),
              ESTADO],
             "Sucursales (establecimientos) de la empresa activa.", 'Crear sucursal')

    catalogo(14, 'DEPARTAMENTOS', 'Departamentos', 'departamentos', 'DEPARTAMENTO_ID', 'erp_gen_departamento', 15, 'DEPARTAMENTO', 'Departamento', CFG,
             "select d.departamento_id, d.codigo, d.nombre, coalesce(s.nombre, 'Toda la empresa') sucursal, " + EST_SQL.format(p='d.') + "\n"
             "  from erp_gen_departamento d\n  left join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id\n"
             f" where d.empresa_id = {EMP}",
             [S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('SUCURSAL', 'Sucursal'), S('ESTADO', 'Estado')],
             [oculto_empresa(),
              txt('CODIGO', 'Código', 'Código corto', 'Identificador del departamento en la empresa.', True),
              txt('NOMBRE', 'Nombre', 'Ventas, Administración, Taller…', 'Nombre de la unidad de negocio o área.', True),
              sel('SUCURSAL_ID', 'Sucursal', 'sucursales', 'Vacío = toda la empresa', 'Sucursal a la que pertenece; vacío si es de toda la empresa.', req=False, nulo='Toda la empresa'),
              ESTADO],
             "Departamentos o unidades de negocio (opcional). Sirven para analizar ventas, stock y gastos por área.", 'Crear departamento')

    catalogo(16, 'PUNTOS-EXPEDICION', 'Puntos de expedición', 'puntos-expedicion', 'PUNTO_EXPEDICION_ID', 'erp_gen_punto_expedicion', 17,
             'PUNTO-EXPEDICION', 'Punto de expedición', CFG,
             "select p.punto_expedicion_id, s.establecimiento || '-' || p.codigo numero, p.nombre, s.nombre sucursal,\n"
             "       d.nombre departamento, " + EST_SQL.format(p='p.') + "\n"
             "  from erp_gen_punto_expedicion p\n  join erp_gen_sucursal s on s.sucursal_id = p.sucursal_id\n"
             "  left join erp_gen_departamento d on d.departamento_id = p.departamento_id\n"
             f" where s.empresa_id = {EMP}",
             [S('NUMERO', 'Número', 'Establecimiento-punto, como en el comprobante.'), S('NOMBRE', 'Nombre'), S('SUCURSAL', 'Sucursal'),
              S('DEPARTAMENTO', 'Departamento'), S('ESTADO', 'Estado')],
             [sel('SUCURSAL_ID', 'Sucursal', 'sucursales', 'Establecimiento', 'Sucursal donde se emiten los comprobantes.'),
              txt('CODIGO', 'Código', '3 dígitos, ej. 001', 'Punto de expedición que figura en el número del comprobante (001-001-0000001).', True),
              txt('NOMBRE', 'Nombre', 'Caja 1, Mostrador…', 'Descripción del punto de emisión.', True),
              sel('DEPARTAMENTO_ID', 'Departamento', 'departamentos', 'Opcional', 'Departamento al que pertenece el punto.', req=False, nulo='- Ninguno -'),
              ESTADO],
             "Puntos de expedición de comprobantes por sucursal.", 'Crear punto de expedición')

    catalogo(18, 'DEPOSITOS', 'Depósitos', 'depositos', 'DEPOSITO_ID', 'erp_stk_deposito', 19, 'DEPOSITO', 'Depósito', CFG,
             "select d.deposito_id, d.codigo, d.nombre, s.nombre sucursal,\n"
             "       decode(d.tipo, 'P', 'Propio', 'C', 'De terceros', 'T', 'En tránsito') tipo,\n"
             "       decode(d.es_principal, 'S', 'Sí', 'No') principal,\n"
             "       decode(d.debe_controlar_stock, 'S', 'Sí', 'No') controla_stock, " + EST_SQL.format(p='d.') + "\n"
             "  from erp_stk_deposito d\n  join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id\n"
             f" where s.empresa_id = {EMP}",
             [S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('SUCURSAL', 'Sucursal'), S('TIPO', 'Tipo'), S('PRINCIPAL', 'Principal'),
              S('CONTROLA_STOCK', 'Controla stock', 'Sí = no admite saldo negativo.'), S('ESTADO', 'Estado')],
             [sel('SUCURSAL_ID', 'Sucursal', 'sucursales', 'Sucursal del depósito', 'Sucursal a la que pertenece el depósito.'),
              txt('CODIGO', 'Código', 'Código corto', 'Identificador del depósito en la sucursal.', True),
              txt('NOMBRE', 'Nombre', 'Nombre visible', 'Nombre del depósito.', True),
              i('TIPO', 'selectList', 'Tipo', 'Propio, terceros o tránsito', 'Propio: stock de la empresa. De terceros: consignación. En tránsito: mercadería viajando.', True, 'tipo-deposito', defecto=('static', 'P')),
              sel('DEPARTAMENTO_ID', 'Departamento', 'departamentos', 'Opcional', 'Departamento dueño del stock.', req=False, nulo='- Ninguno -'),
              sn('DEBE_CONTROLAR_STOCK', 'Controla stock', 'Sí = sin negativos', 'Sí: no permite salidas que dejen saldo negativo.', 'S'),
              sn('ES_PRINCIPAL', 'Principal', 'Depósito por defecto', 'Se propone por defecto en los documentos de la sucursal.'),
              area('DIRECCION', 'Dirección', 'Si es distinta de la sucursal', 'Dirección física del depósito.'),
              sel('UBICACION_ID', 'Ciudad', 'ubicaciones', 'Opcional', 'Ciudad del depósito.', req=False, popup=True),
              ESTADO],
             "Depósitos de stock de las sucursales de la empresa activa.", 'Crear depósito')

    catalogo(20, 'USUARIOS-SUCURSAL', 'Usuarios por sucursal', 'usuarios-sucursal', 'USUARIO_SUCURSAL_ID', 'erp_gen_usuario_sucursal', 21,
             'USUARIO-SUCURSAL', 'Usuario por sucursal', CFG,
             "select us.usuario_sucursal_id, u.username usuario, u.nombres || ' ' || u.apellidos nombre, s.nombre sucursal,\n"
             "       coalesce(d.nombre, 'Todos') departamento, se.establecimiento || '-' || p.codigo punto,\n"
             "       decode(us.es_defecto, 'S', 'Sí', 'No') por_defecto, " + EST_SQL.format(p='us.') + "\n"
             "  from erp_gen_usuario_sucursal us\n  join adm_seg_usuario u on u.usuario_id = us.usuario_id\n"
             "  join erp_gen_sucursal s on s.sucursal_id = us.sucursal_id\n"
             "  left join erp_gen_departamento d on d.departamento_id = us.departamento_id\n"
             "  left join erp_gen_punto_expedicion p on p.punto_expedicion_id = us.punto_expedicion_id\n"
             "  left join erp_gen_sucursal se on se.sucursal_id = p.sucursal_id\n"
             f" where s.empresa_id = {EMP}",
             [S('USUARIO', 'Usuario'), S('NOMBRE', 'Nombre'), S('SUCURSAL', 'Sucursal'), S('DEPARTAMENTO', 'Departamento'),
              S('PUNTO', 'Punto por defecto'), S('POR_DEFECTO', 'Sucursal por defecto'), S('ESTADO', 'Estado')],
             [sel('USUARIO_ID', 'Usuario', 'usuarios', 'Usuario de ADM', 'Usuario que podrá operar la sucursal.', popup=True),
              sel('SUCURSAL_ID', 'Sucursal', 'sucursales', 'Sucursal habilitada', 'Sucursal que podrá operar el usuario.'),
              sel('DEPARTAMENTO_ID', 'Departamento', 'departamentos', 'Vacío = todos', 'Limita al usuario a un departamento.', req=False, nulo='Todos'),
              sel('PUNTO_EXPEDICION_ID', 'Punto de expedición', 'puntos-expedicion', 'Opcional', 'Punto que se propone al emitir comprobantes.', req=False, nulo='- Ninguno -'),
              sn('ES_DEFECTO', 'Sucursal por defecto', 'Sí / No', 'Sucursal con la que inicia el usuario.'),
              ESTADO],
             "Sucursales y departamentos que puede operar cada usuario en la empresa activa.\n"
             "Si un usuario no tiene ninguna, opera todas (salvo el parámetro ERP_GEN_ACCESO_SUCURSAL_ESTRICTO).", 'Asignar sucursal')

    catalogo(22, 'FUNCIONALIDADES-EMPRESA', 'Funcionalidades activas', 'funcionalidades-empresa', 'EMPRESA_FUNC_ID', 'erp_gen_empresa_func', 23,
             'FUNCIONALIDAD-EMPRESA', 'Funcionalidad de la empresa', CFG,
             "select ef.empresa_func_id, f.nombre funcionalidad, f.codigo, f.modulo, f.descripcion, " + EST_SQL.format(p='ef.') + "\n"
             "  from erp_gen_empresa_func ef\n  join erp_gen_funcionalidad f on f.funcionalidad_id = ef.funcionalidad_id\n"
             f" where ef.empresa_id = {EMP}",
             [S('FUNCIONALIDAD', 'Funcionalidad'), S('CODIGO', 'Código'), S('MODULO', 'Módulo'), S('DESCRIPCION', 'Qué habilita'), S('ESTADO', 'Estado')],
             [oculto_empresa(),
              sel('FUNCIONALIDAD_ID', 'Funcionalidad', 'funcionalidades', 'Qué activar', 'Funcionalidad a activar o desactivar en la empresa.'),
              ESTADO],
             "Funcionalidades que usa la empresa activa (lotes, vendedores, safra…).\n"
             "Use Activar las del rubro para cargar las sugeridas por el rubro de la empresa.", 'Agregar funcionalidad')

    base.pagina_accion('p00024-aplicar-rubro.apx', 24, 'APLICAR-RUBRO', 'Activar funcionalidades del rubro', CFG,
                       "Activa en la empresa activa las funcionalidades sugeridas por su rubro.\nNo desactiva las que ya tenga.",
                       [], [('activar', 'ACTIVAR', 'Activar', True, None)],
                       [('activar', f"erp_gen_funcionalidad_api.crear_desde_rubro(i_empresa_id => {EMP});", 'Funcionalidades del rubro activadas.')])

    # ------------------------------------------------------------------ MONEDAS
    catalogo(30, 'MONEDAS', 'Monedas', 'monedas', 'MONEDA_ID', 'erp_gen_moneda', 31, 'MONEDA', 'Moneda', CAT,
             "select moneda_id, codigo, nombre, simbolo, decimales, decimales_precio, " + EST_SQL.format(p='') + "\n  from erp_gen_moneda",
             [S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('SIMBOLO', 'Símbolo'), N('DECIMALES', 'Decimales'),
              N('DECIMALES_PRECIO', 'Decimales de precio'), S('ESTADO', 'Estado')],
             [txt('CODIGO', 'Código', 'ISO 4217, ej. PYG', 'Código internacional de 3 letras en mayúsculas.', True),
              txt('NOMBRE', 'Nombre', 'Nombre visible', 'Nombre de la moneda.', True),
              txt('SIMBOLO', 'Símbolo', 'Ej. ₲, US$', 'Símbolo que se muestra junto a los importes.', True),
              num('DECIMALES', 'Decimales', '0 a 4', 'Decimales de los importes (Guaraní 0, Dólar 2).', True, '2'),
              num('DECIMALES_PRECIO', 'Decimales de precio', '0 a 6', 'Decimales de los precios unitarios.', True, '4'),
              ESTADO],
             "Monedas que maneja el ERP.", 'Crear moneda')

    catalogo(32, 'COTIZACIONES', 'Cotizaciones', 'cotizaciones', 'COTIZACION_ID', 'erp_gen_cotizacion', 33, 'COTIZACION', 'Cotización',
             'erp-gen-cotizacion-gestionar',
             "select c.cotizacion_id, c.fecha, mo.codigo origen, md.codigo destino, c.tasa_compra, c.tasa_venta,\n"
             "       decode(c.fuente, 'BCP', 'Banco Central', 'SET', 'DNIT', 'API', 'Servicio externo', 'Manual') fuente,\n"
             "       coalesce(e.razon_social, 'General') ambito\n"
             "  from erp_gen_cotizacion c\n  join erp_gen_moneda mo on mo.moneda_id = c.moneda_id_origen\n"
             "  join erp_gen_moneda md on md.moneda_id = c.moneda_id_destino\n  left join adm_gen_empresa e on e.empresa_id = c.empresa_id\n"
             f" where c.empresa_id is null or c.empresa_id = {EMP}",
             [D('FECHA', 'Fecha'), S('ORIGEN', 'Moneda'), S('DESTINO', 'En moneda'), N('TASA_COMPRA', 'Compra'), N('TASA_VENTA', 'Venta'),
              S('FUENTE', 'Fuente'), S('AMBITO', 'Ámbito', 'General = vale para todas las empresas.')],
             [fecha('FECHA', 'Fecha', 'Día de la cotización', 'Rige desde esta fecha hasta la próxima cotización cargada.', True),
              sel('MONEDA_ID_ORIGEN', 'Moneda', 'monedas', 'Ej. USD', '1 unidad de esta moneda…'),
              sel('MONEDA_ID_DESTINO', 'En moneda', 'monedas', 'Ej. PYG', '…equivale a la tasa en esta moneda.'),
              num('TASA_COMPRA', 'Tasa compra', 'Comprador', 'Cotización comprador.', True),
              num('TASA_VENTA', 'Tasa venta', 'Vendedor', 'Cotización vendedor.', True),
              i('FUENTE', 'selectList', 'Fuente', 'Origen del dato', 'De dónde se obtuvo la cotización.', True, 'fuente-cotizacion', defecto=('static', 'MAN')),
              sel('EMPRESA_ID', 'Ámbito', 'empresa-activa', 'Vacío = general', 'General: vale para todas las empresas. Elija la empresa si usa una cotización propia.', req=False, nulo='General (todas las empresas)')],
             "Cotizaciones de monedas. Se usa la última cargada a la fecha del documento.", 'Cargar cotización')

    # ------------------------------------------------------------------ IMPUESTOS
    catalogo(40, 'IMPUESTOS', 'Impuestos', 'impuestos', 'IMPUESTO_ID', 'erp_gen_impuesto', 41, 'IMPUESTO', 'Impuesto', CAT,
             "select i.impuesto_id, p.nombre pais, i.codigo, i.nombre,\n       decode(i.tipo, 'I', 'Impuesto', 'R', 'Retención', 'Percepción') tipo,\n"
             "       i.codigo_oficial, " + EST_SQL.format(p='i.') + "\n  from erp_gen_impuesto i\n  join erp_gen_pais p on p.pais_id = i.pais_id",
             [S('PAIS', 'País'), S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('TIPO', 'Tipo'), S('CODIGO_OFICIAL', 'Código SIFEN'), S('ESTADO', 'Estado')],
             [sel('PAIS_ID', 'País', 'paises', 'País del impuesto', 'Cada país define sus impuestos.'),
              txt('CODIGO', 'Código', 'Ej. IVA', 'Código corto en mayúsculas.', True),
              txt('NOMBRE', 'Nombre', 'Nombre completo', 'Nombre del impuesto.', True),
              i('TIPO', 'selectList', 'Tipo', 'Impuesto, retención o percepción', 'Tipo de tributo.', True, 'tipo-impuesto', defecto=('static', 'I')),
              txt('CODIGO_OFICIAL', 'Código oficial', 'SIFEN iTImp', '1=IVA, 2=ISC, 3=Renta, 4=Ninguno, 5=IVA-Renta.'),
              ESTADO],
             "Impuestos, retenciones y percepciones por país.", 'Crear impuesto')

    catalogo(42, 'TASAS', 'Tasas', 'tasas', 'IMPUESTO_TASA_ID', 'erp_gen_impuesto_tasa', 43, 'TASA', 'Tasa', CAT,
             "select t.impuesto_tasa_id, i.codigo impuesto, t.codigo, t.nombre,\n"
             "       (select v.porcentaje from erp_gen_impuesto_tasa_vig v\n"
             "         where v.impuesto_tasa_id = t.impuesto_tasa_id and v.fecha_desde <= trunc(current_date)\n"
             "         order by v.fecha_desde desc fetch first 1 row only) porcentaje_vigente,\n"
             "       t.codigo_oficial, " + EST_SQL.format(p='t.') + "\n"
             "  from erp_gen_impuesto_tasa t\n  join erp_gen_impuesto i on i.impuesto_id = t.impuesto_id",
             [S('IMPUESTO', 'Impuesto'), S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), N('PORCENTAJE_VIGENTE', '% vigente hoy'),
              S('CODIGO_OFICIAL', 'Código SIFEN'), S('ESTADO', 'Estado')],
             [sel('IMPUESTO_ID', 'Impuesto', 'impuestos', 'Impuesto de la tasa', 'Impuesto al que pertenece la tasa.'),
              txt('CODIGO', 'Código', 'Ej. IVA10', 'Código corto en mayúsculas.', True),
              txt('NOMBRE', 'Nombre', 'Ej. IVA 10 %', 'Nombre visible.', True),
              txt('CODIGO_OFICIAL', 'Código oficial', 'SIFEN dTasaIVA', 'Tasa informada a SIFEN (10, 5, 0).'),
              ESTADO],
             "Tasas de cada impuesto. El porcentaje se carga en Vigencias de tasas, con fecha desde.", 'Crear tasa')

    catalogo(44, 'VIGENCIAS', 'Vigencias de tasas', 'vigencias', 'IMPUESTO_TASA_VIG_ID', 'erp_gen_impuesto_tasa_vig', 45, 'VIGENCIA', 'Vigencia de tasa', CAT,
             "select v.impuesto_tasa_vig_id, i.codigo || ' / ' || t.codigo tasa, v.fecha_desde, v.porcentaje,\n"
             "       v.monto_minimo, m.codigo moneda_minimo, v.observacion\n"
             "  from erp_gen_impuesto_tasa_vig v\n  join erp_gen_impuesto_tasa t on t.impuesto_tasa_id = v.impuesto_tasa_id\n"
             "  join erp_gen_impuesto i on i.impuesto_id = t.impuesto_id\n  left join erp_gen_moneda m on m.moneda_id = v.moneda_id",
             [S('TASA', 'Tasa'), D('FECHA_DESDE', 'Rige desde'), N('PORCENTAJE', 'Porcentaje'), N('MONTO_MINIMO', 'Monto mínimo', 'Retenciones: se aplican desde este monto.'),
              S('MONEDA_MINIMO', 'Moneda'), S('OBSERVACION', 'Norma / observación')],
             [sel('IMPUESTO_TASA_ID', 'Tasa', 'impuesto-tasas', 'Tasa a la que aplica', 'Tasa cuyo porcentaje cambia.'),
              fecha('FECHA_DESDE', 'Rige desde', 'Fecha de inicio', 'El porcentaje rige desde esta fecha hasta la siguiente vigencia.', True),
              num('PORCENTAJE', 'Porcentaje', '10 = 10 %', 'Porcentaje del impuesto.', True),
              num('MONTO_MINIMO', 'Monto mínimo', 'Vacío = siempre', 'Para retenciones: monto de la operación desde el cual se aplica la tasa.'),
              sel('MONEDA_ID', 'Moneda del mínimo', 'monedas', 'Si hay mínimo', 'Moneda en la que está expresado el monto mínimo.', req=False, nulo='- Ninguna -'),
              area('OBSERVACION', 'Norma / observación', 'Opcional', 'Ley o resolución que fija el porcentaje.')],
             "Porcentaje de cada tasa a lo largo del tiempo. Un cambio de tasa no altera documentos ya emitidos.", 'Crear vigencia')

    catalogo(46, 'CATEGORIAS-FISCALES', 'Categorías fiscales', 'categorias-fiscales', 'CATEGORIA_FISCAL_ID', 'erp_gen_categoria_fiscal', 47,
             'CATEGORIA-FISCAL', 'Categoría fiscal', CAT,
             "select c.categoria_fiscal_id, p.nombre pais, c.codigo, c.nombre,\n"
             "       (select listagg(t.codigo || ' sobre ' || ct.porcentaje_base || '%', ', ') within group (order by ct.orden)\n"
             "          from erp_gen_categoria_tasa ct join erp_gen_impuesto_tasa t on t.impuesto_tasa_id = ct.impuesto_tasa_id\n"
             "         where ct.categoria_fiscal_id = c.categoria_fiscal_id) composicion,\n"
             "       " + EST_SQL.format(p='c.') + "\n  from erp_gen_categoria_fiscal c\n  join erp_gen_pais p on p.pais_id = c.pais_id",
             [S('PAIS', 'País'), S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('COMPOSICION', 'Tasas', 'Vacío = exento.'), S('ESTADO', 'Estado')],
             [sel('PAIS_ID', 'País', 'paises', 'País', 'País de la categoría.'),
              txt('CODIGO', 'Código', 'Ej. GRAV10', 'Código corto en mayúsculas.', True),
              txt('NOMBRE', 'Nombre', 'Ej. Gravado 10 %', 'Nombre visible.', True),
              i('CODIGO_OFICIAL', 'selectList', 'Afectación (SIFEN)', 'iAfecIVA', 'Cómo se informa a SIFEN: gravado, exonerado, exento o gravado parcial.', False, 'afectacion-iva', '- Sin indicar -'),
              area('DESCRIPCION', 'Descripción', 'Opcional', 'A qué productos o servicios aplica.'),
              ESTADO],
             "Categorías fiscales: definen cómo tributa cada producto. Sus tasas se cargan en Tasas por categoría.", 'Crear categoría')

    catalogo(48, 'CATEGORIA-TASAS', 'Tasas por categoría', 'categoria-tasas', 'CATEGORIA_TASA_ID', 'erp_gen_categoria_tasa', 49,
             'CATEGORIA-TASA', 'Tasa de la categoría', CAT,
             "select ct.categoria_tasa_id, c.codigo categoria, i.codigo || ' / ' || t.codigo tasa, ct.porcentaje_base, ct.orden\n"
             "  from erp_gen_categoria_tasa ct\n  join erp_gen_categoria_fiscal c on c.categoria_fiscal_id = ct.categoria_fiscal_id\n"
             "  join erp_gen_impuesto_tasa t on t.impuesto_tasa_id = ct.impuesto_tasa_id\n  join erp_gen_impuesto i on i.impuesto_id = t.impuesto_id",
             [S('CATEGORIA', 'Categoría'), S('TASA', 'Tasa'), N('PORCENTAJE_BASE', '% de la base'), N('ORDEN', 'Orden')],
             [sel('CATEGORIA_FISCAL_ID', 'Categoría fiscal', 'categorias-fiscales', 'Categoría', 'Categoría que se compone.'),
              sel('IMPUESTO_TASA_ID', 'Tasa', 'impuesto-tasas', 'Tasa aplicada', 'Tasa que grava la categoría.'),
              num('PORCENTAJE_BASE', '% de la base', '100 = toda la base', 'Parte del monto gravada por esta tasa. Por impuesto, la suma no puede superar 100; el resto es exento.', True, '100'),
              num('ORDEN', 'Orden', 'Orden de cálculo', 'Orden en que se aplican las tasas.', True, '1')],
             "Composición de cada categoría fiscal: qué tasas aplican y sobre qué parte de la base.", 'Agregar tasa')

    pagina_probar_impuestos()

    # ------------------------------------------------------------------ PERSONAS
    base.pagina_listado('p00060-personas.apx', 60, 'PERSONAS', 'Personas', 'erp-gen-persona-ver', 'personas',
        "select p.persona_id, p.nro_documento || nvl2(p.dv, '-' || p.dv, null) documento, td.codigo tipo_documento,\n"
        "       p.razon_social, p.nombre_fantasia, decode(p.tipo_persona, 'F', 'Física', 'Jurídica') tipo,\n"
        "       (select listagg(tr.nombre, ', ') within group (order by tr.nombre)\n"
        "          from erp_gen_persona_rol pr join erp_gen_tipo_rol tr on tr.tipo_rol_id = pr.tipo_rol_id\n"
        f"         where pr.persona_id = p.persona_id and pr.empresa_id = {EMP} and pr.estado = 'A') roles,\n"
        "       p.email, p.telefono, " + EST_SQL.format(p='p.') + "\n"
        "  from erp_gen_persona p\n  join erp_gen_tipo_doc_identidad td on td.tipo_doc_identidad_id = p.tipo_doc_identidad_id",
        'PERSONA_ID', 61,
        [S('DOCUMENTO', 'Documento'), S('TIPO_DOCUMENTO', 'Tipo doc.'), S('RAZON_SOCIAL', 'Razón social / nombre'), S('NOMBRE_FANTASIA', 'Nombre de fantasía'),
         S('TIPO', 'Persona'), S('ROLES', 'Roles en la empresa activa'), S('EMAIL', 'Email'), S('TELEFONO', 'Teléfono'), S('ESTADO', 'Estado')],
        "Padrón único de personas físicas y jurídicas, compartido por todas las empresas.\n"
        "Los roles (cliente, proveedor…) se asignan por empresa en Roles por empresa.",
        "Listado de erp_gen_persona. Alta/edición en la página 61 vía erp_gen_persona_api.", 'Crear persona', 'erp-gen-persona-gestionar')

    campos = ['TIPO_PERSONA', 'TIPO_DOC_IDENTIDAD_ID', 'NRO_DOCUMENTO', 'DV', 'RAZON_SOCIAL', 'NOMBRES', 'APELLIDOS', 'NOMBRE_FANTASIA',
              'ES_CONTRIBUYENTE', 'PAIS_ID', 'FECHA_NACIMIENTO', 'EMAIL', 'TELEFONO', 'OBSERVACION', 'ESTADO']

    def llamada(proc, con_id):
        args = ([f"    i_persona_id            => :P61_PERSONA_ID"] if con_id else [])
        args += [f"    i_{c.lower():<22}=> " + (f"to_date(:P61_{c})" if c == 'FECHA_NACIMIENTO' else f":P61_{c}") for c in campos]
        if not con_id:
            args.append("    o_persona_id            => :P61_PERSONA_ID")
        return f"erp_gen_persona_api.{proc}(\n" + ",\n".join(args) + ");"

    base.pagina_formulario('p00061-persona.apx', 61, 'PERSONA', 'Persona', 'erp-gen-persona-gestionar', 'erp_gen_persona', 'PERSONA_ID',
        [i('TIPO_PERSONA', 'selectList', 'Tipo de persona', 'Física o jurídica', 'Persona física (individuo) o jurídica (empresa, institución).', True, 'tipo-persona', defecto=('static', 'J')),
         sel('TIPO_DOC_IDENTIDAD_ID', 'Tipo de documento', 'tipos-doc-identidad', 'RUC, cédula…', 'Tipo de documento de identidad.'),
         txt('NRO_DOCUMENTO', 'Número de documento', 'Sin puntos; puede incluir -DV', 'Si escribe 80012345-6 se separa el dígito verificador automáticamente.', True),
         txt('DV', 'Dígito verificador', 'Solo RUC', 'Se valida con el algoritmo de la SET; si no coincide, no se guarda.'),
         txt('RAZON_SOCIAL', 'Razón social', 'Jurídica, o vacío para física', 'Para personas físicas puede dejarlo vacío: se arma con nombres y apellidos.'),
         txt('NOMBRES', 'Nombres', 'Persona física', 'Nombres de la persona física.'),
         txt('APELLIDOS', 'Apellidos', 'Persona física', 'Apellidos de la persona física.'),
         txt('NOMBRE_FANTASIA', 'Nombre de fantasía', 'Opcional', 'Nombre comercial.'),
         sn('ES_CONTRIBUYENTE', 'Contribuyente de IVA', 'Sí / No', 'Define cómo se informa al receptor en la factura electrónica.'),
         sel('PAIS_ID', 'País', 'paises', 'País de la persona', 'País de residencia o constitución.'),
         fecha('FECHA_NACIMIENTO', 'Fecha de nacimiento / constitución', 'Opcional', 'Fecha de nacimiento (física) o de constitución (jurídica).'),
         txt('EMAIL', 'Email', 'Para comprobantes', 'Correo al que se envían los comprobantes electrónicos.'),
         txt('TELEFONO', 'Teléfono', 'Opcional', 'Teléfono principal.'),
         area('OBSERVACION', 'Observaciones', 'Opcional', 'Notas internas.'),
         ESTADO],
        "Alta y edición de personas.\nEl documento se normaliza y se valida (formato y dígito verificador del RUC) antes de guardar.",
        permite_eliminar=False,
        procesamiento={'CREAR': llamada('crear', False), 'GUARDAR': llamada('modificar', True)})

    catalogo(62, 'ROLES-PERSONA', 'Roles por empresa', 'roles-persona', 'PERSONA_ROL_ID', 'erp_gen_persona_rol', 63, 'ROL-PERSONA', 'Rol de persona',
             'erp-gen-persona-gestionar',
             "select pr.persona_rol_id, p.razon_social persona, p.nro_documento || nvl2(p.dv, '-' || p.dv, null) documento,\n"
             "       tr.nombre rol, pr.codigo_interno, pr.fecha_desde, " + EST_SQL.format(p='pr.') + "\n"
             "  from erp_gen_persona_rol pr\n  join erp_gen_persona p on p.persona_id = pr.persona_id\n"
             "  join erp_gen_tipo_rol tr on tr.tipo_rol_id = pr.tipo_rol_id\n"
             f" where pr.empresa_id = {EMP}",
             [S('PERSONA', 'Persona'), S('DOCUMENTO', 'Documento'), S('ROL', 'Rol'), S('CODIGO_INTERNO', 'Código interno'),
              D('FECHA_DESDE', 'Desde'), S('ESTADO', 'Estado')],
             [oculto_empresa(),
              sel('PERSONA_ID', 'Persona', 'personas', 'Busque por nombre o documento', 'Persona del padrón.', popup=True),
              sel('TIPO_ROL_ID', 'Rol', 'tipos-rol', 'Cliente, proveedor…', 'Rol que cumple la persona en la empresa activa.'),
              txt('CODIGO_INTERNO', 'Código interno', 'Opcional', 'Código de cliente o proveedor en la empresa.'),
              fecha('FECHA_DESDE', 'Desde', 'Vacío = hoy', 'Desde cuándo tiene el rol.'),
              ESTADO],
             "Clientes, proveedores, empleados y demás roles de las personas en la empresa activa.", 'Asignar rol')

    catalogo(64, 'TIPOS-ROL', 'Tipos de rol', 'tipos-rol', 'TIPO_ROL_ID', 'erp_gen_tipo_rol', 65, 'TIPO-ROL', 'Tipo de rol', CAT,
             "select tipo_rol_id, codigo, nombre, decode(es_ventas, 'S', 'Sí', 'No') ventas, decode(es_compras, 'S', 'Sí', 'No') compras,\n"
             "       decode(es_cobrar, 'S', 'Sí', 'No') a_cobrar, decode(es_pagar, 'S', 'Sí', 'No') a_pagar,\n"
             "       decode(es_stock, 'S', 'Sí', 'No') stock, " + EST_SQL.format(p='') + "\n"
             "  from erp_gen_tipo_rol",
             [S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('VENTAS', 'Ventas'), S('COMPRAS', 'Compras'), S('A_COBRAR', 'A cobrar'),
              S('A_PAGAR', 'A pagar'), S('STOCK', 'Inventario'), S('ESTADO', 'Estado')],
             [txt('CODIGO', 'Código', 'Ej. CLIENTE', 'Código corto en mayúsculas.', True),
              txt('NOMBRE', 'Nombre', 'Nombre visible', 'Nombre del rol.', True),
              sn('ES_VENTAS', 'Se usa en Ventas', 'Sí / No', 'Se ofrece en pedidos y facturas de venta.'),
              sn('ES_COMPRAS', 'Se usa en Compras', 'Sí / No', 'Se ofrece en órdenes y facturas de compra.'),
              sn('ES_COBRAR', 'Genera cuentas a cobrar', 'Sí / No', 'La persona con este rol puede tener deudas con la empresa (clientes, socios).'),
              sn('ES_PAGAR', 'Genera cuentas a pagar', 'Sí / No', 'La empresa puede deberle a la persona con este rol (proveedores, empleados).'),
              sn('ES_STOCK', 'Se usa en Inventario', 'Sí / No', 'Se ofrece en remisiones y movimientos (ej. transportistas).'),
              ESTADO],
             "Roles que puede tener una persona. Agregue los que necesite su rubro (socio, productor, paciente…).", 'Crear tipo de rol')

    catalogo(66, 'TIPOS-DOCUMENTO', 'Tipos de documento', 'tipos-documento', 'TIPO_DOC_IDENTIDAD_ID', 'erp_gen_tipo_doc_identidad', 67,
             'TIPO-DOCUMENTO', 'Tipo de documento', CAT,
             "select t.tipo_doc_identidad_id, p.nombre pais, t.codigo, t.nombre, decode(t.es_tributario, 'S', 'Sí', 'No') tributario,\n"
             "       decode(t.tiene_dv, 'S', 'Sí', 'No') con_dv, t.codigo_oficial, " + EST_SQL.format(p='t.') + "\n"
             "  from erp_gen_tipo_doc_identidad t\n  join erp_gen_pais p on p.pais_id = t.pais_id",
             [S('PAIS', 'País'), S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('TRIBUTARIO', 'Tributario'), S('CON_DV', 'Con DV'),
              S('CODIGO_OFICIAL', 'Código SIFEN'), S('ESTADO', 'Estado')],
             [sel('PAIS_ID', 'País', 'paises', 'País emisor', 'País que emite el documento.'),
              txt('CODIGO', 'Código', 'Ej. RUC, CI', 'Código corto en mayúsculas.', True),
              txt('NOMBRE', 'Nombre', 'Nombre visible', 'Nombre del documento.', True),
              sn('ES_TRIBUTARIO', 'Identificación tributaria', 'Sí = RUC', 'Indica el documento tributario del país.'),
              sn('TIENE_DV', 'Tiene dígito verificador', 'Sí / No', 'Si es Sí, se valida el DV al guardar personas.'),
              txt('FORMATO_REGEXP', 'Formato (expresión regular)', 'Opcional', 'Valida el número, ej. ^[0-9]{1,8}$.'),
              txt('CODIGO_OFICIAL', 'Código oficial', 'SIFEN iTipIDRec', '1=Cédula, 2=Pasaporte, 3=Cédula extranjera, 4=Carnet de residencia, 5=Innominado, 6=Diplomática, 9=Otro.'),
              ESTADO],
             "Tipos de documento de identidad por país.", 'Crear tipo de documento')

    validar_doc = ["", "    process validar-documento (", "        name: Validar documento", "        type: executeCode", "        source {",
                   "            plsqlCode:" + code('plsql', "erp_gen_persona_api.validar_documento(\n    i_tipo_doc_identidad_id => :P69_TIPO_DOC_IDENTIDAD_ID,\n"
                                                      "    i_nro_documento         => :P69_NRO_DOCUMENTO,\n    i_dv                    => :P69_DV);", 16),
                   "        }", "        execution {", "            sequence: 5", "        }", "        serverSideCondition {",
                   "            type: requestIsContainedInValue", "            value: CREAR,GUARDAR", "        }", "    )"]
    base.pagina_listado('p00068-documentos-persona.apx', 68, 'DOCUMENTOS-PERSONA', 'Documentos adicionales', 'erp-gen-persona-ver', 'documentos-persona',
        "select d.persona_documento_id, p.razon_social persona, td.codigo tipo, d.nro_documento || nvl2(d.dv, '-' || d.dv, null) documento,\n"
        "       d.fecha_desde, d.fecha_hasta\n"
        "  from erp_gen_persona_documento d\n  join erp_gen_persona p on p.persona_id = d.persona_id\n"
        "  join erp_gen_tipo_doc_identidad td on td.tipo_doc_identidad_id = d.tipo_doc_identidad_id",
        'PERSONA_DOCUMENTO_ID', 69,
        [S('PERSONA', 'Persona'), S('TIPO', 'Tipo'), S('DOCUMENTO', 'Documento'), D('FECHA_DESDE', 'Desde'), D('FECHA_HASTA', 'Vence')],
        "Documentos de identidad adicionales de las personas (por ejemplo cédula y RUC, o pasaporte y RUC).\n"
        "El documento principal se carga en la persona.",
        "Listado de erp_gen_persona_documento. Alta/edición en la página 69 con validación vía erp_gen_persona_api.", 'Agregar documento', 'erp-gen-persona-gestionar')
    base.pagina_formulario('p00069-documento-persona.apx', 69, 'DOCUMENTO-PERSONA', 'Documento adicional', 'erp-gen-persona-gestionar',
        'erp_gen_persona_documento', 'PERSONA_DOCUMENTO_ID',
        [sel('PERSONA_ID', 'Persona', 'personas', 'Busque por nombre o documento', 'Persona a la que pertenece el documento.', popup=True),
         sel('TIPO_DOC_IDENTIDAD_ID', 'Tipo de documento', 'tipos-doc-identidad', 'RUC, cédula…', 'Tipo del documento adicional.'),
         txt('NRO_DOCUMENTO', 'Número', 'Sin puntos', 'Número del documento, sin dígito verificador.', True),
         txt('DV', 'Dígito verificador', 'Solo RUC', 'Se valida con el algoritmo de la SET.'),
         fecha('FECHA_DESDE', 'Desde', 'Vacío = hoy', 'Desde cuándo es válido.'),
         fecha('FECHA_HASTA', 'Vence', 'Opcional', 'Fecha de vencimiento del documento.')],
        "Alta y edición de documentos adicionales.\nEl número se valida (formato y dígito verificador) antes de guardar.",
        extras=validar_doc)

    # ------------------------------------------------------------------ CATÁLOGOS
    catalogo(70, 'PAISES', 'Países', 'paises', 'PAIS_ID', 'erp_gen_pais', 71, 'PAIS', 'País', CAT,
             "select p.pais_id, p.codigo, p.codigo_iso3, p.nombre, m.codigo moneda, p.prefijo_telefono, " + EST_SQL.format(p='p.') + "\n"
             "  from erp_gen_pais p\n  left join erp_gen_moneda m on m.moneda_id = p.moneda_id",
             [S('CODIGO', 'Código'), S('CODIGO_ISO3', 'ISO 3'), S('NOMBRE', 'Nombre'), S('MONEDA', 'Moneda'), S('PREFIJO_TELEFONO', 'Prefijo'), S('ESTADO', 'Estado')],
             [txt('CODIGO', 'Código', 'ISO 3166, 2 letras', 'Código de país de 2 letras (PY).', True),
              txt('CODIGO_ISO3', 'Código ISO 3', '3 letras (PRY)', 'Código de 3 letras; lo usa SIFEN.', True),
              txt('NOMBRE', 'Nombre', 'Nombre del país', 'Nombre visible.', True),
              sel('MONEDA_ID', 'Moneda', 'monedas', 'Moneda local', 'Moneda por defecto del país.', req=False, nulo='- Ninguna -'),
              txt('PREFIJO_TELEFONO', 'Prefijo telefónico', 'Ej. +595', 'Prefijo internacional.'),
              ESTADO],
             "Países.", 'Crear país')

    catalogo(72, 'UBICACIONES', 'Ubicaciones', 'ubicaciones', 'UBICACION_ID', 'erp_gen_ubicacion', 73, 'UBICACION', 'Ubicación', CAT,
             "select u.ubicacion_id, p.nombre pais, decode(u.tipo, 'DEP', 'Departamento', 'DIS', 'Distrito', 'Ciudad') tipo,\n"
             "       u.codigo_oficial, u.nombre, s.nombre superior, " + EST_SQL.format(p='u.') + "\n"
             "  from erp_gen_ubicacion u\n  join erp_gen_pais p on p.pais_id = u.pais_id\n"
             "  left join erp_gen_ubicacion s on s.ubicacion_id = u.ubicacion_id_padre",
             [S('PAIS', 'País'), S('TIPO', 'Tipo'), S('CODIGO_OFICIAL', 'Código oficial'), S('NOMBRE', 'Nombre'), S('SUPERIOR', 'Pertenece a'), S('ESTADO', 'Estado')],
             [sel('PAIS_ID', 'País', 'paises', 'País', 'País de la ubicación.'),
              i('TIPO', 'selectList', 'Tipo', 'Departamento, distrito o ciudad', 'Nivel de la ubicación.', True, 'tipo-ubicacion'),
              txt('CODIGO_OFICIAL', 'Código oficial', 'Tabla de SIFEN', 'Código oficial de la ubicación (tabla geográfica de la DNIT).', True),
              txt('NOMBRE', 'Nombre', 'Nombre', 'Nombre de la ubicación.', True),
              sel('UBICACION_ID_PADRE', 'Pertenece a', 'ubicaciones', 'Nivel superior', 'Departamento del distrito, distrito de la ciudad…', req=False, popup=True),
              ESTADO],
             "Ubicaciones geográficas (departamento, distrito, ciudad) con su código oficial.", 'Crear ubicación')

    catalogo(74, 'FUNCIONALIDADES', 'Funcionalidades', 'funcionalidades', 'FUNCIONALIDAD_ID', 'erp_gen_funcionalidad', 75, 'FUNCIONALIDAD', 'Funcionalidad', CAT,
             "select funcionalidad_id, codigo, nombre, modulo, descripcion, " + EST_SQL.format(p='') + "\n  from erp_gen_funcionalidad",
             [S('CODIGO', 'Código', 'Lo usan las condiciones de las pantallas.'), S('NOMBRE', 'Nombre'), S('MODULO', 'Módulo'), S('DESCRIPCION', 'Qué habilita'), S('ESTADO', 'Estado')],
             [txt('CODIGO', 'Código', 'Mayúsculas, ej. LOTE', 'Código que usan las pantallas para mostrar u ocultar funciones.', True),
              txt('NOMBRE', 'Nombre', 'Nombre visible', 'Nombre de la funcionalidad.', True),
              i('MODULO', 'selectList', 'Módulo', 'Módulo principal', 'Módulo al que afecta principalmente.', False, 'modulos-erp', '- General -'),
              area('DESCRIPCION', 'Descripción', 'Qué habilita', 'Explique qué campos o pantallas habilita.'),
              ESTADO],
             "Catálogo de funcionalidades que cada empresa puede activar según su rubro.", 'Crear funcionalidad')

    catalogo(76, 'RUBROS', 'Rubros', 'rubros', 'RUBRO_ID', 'erp_gen_rubro', 77, 'RUBRO', 'Rubro', CAT,
             "select r.rubro_id, r.codigo, r.nombre, r.descripcion,\n"
             "       (select count(*) from erp_gen_rubro_func rf where rf.rubro_id = r.rubro_id) funcionalidades,\n"
             "       " + EST_SQL.format(p='r.') + "\n  from erp_gen_rubro r",
             [S('CODIGO', 'Código'), S('NOMBRE', 'Nombre'), S('DESCRIPCION', 'Descripción'), N('FUNCIONALIDADES', 'Funcionalidades'), S('ESTADO', 'Estado')],
             [txt('CODIGO', 'Código', 'Mayúsculas', 'Código del rubro.', True),
              txt('NOMBRE', 'Nombre', 'Nombre visible', 'Nombre del rubro.', True),
              area('DESCRIPCION', 'Descripción', 'Para qué empresas', 'Tipo de empresa para la que sirve el perfil.'),
              ESTADO],
             "Perfiles de rubro. Cada uno sugiere funcionalidades al configurar una empresa.", 'Crear rubro')

    catalogo(78, 'RUBRO-FUNCIONALIDADES', 'Funcionalidades por rubro', 'rubro-funcionalidades', 'RUBRO_FUNC_ID', 'erp_gen_rubro_func', 79,
             'RUBRO-FUNCIONALIDAD', 'Funcionalidad del rubro', CAT,
             "select rf.rubro_func_id, r.nombre rubro, f.nombre funcionalidad, f.codigo\n"
             "  from erp_gen_rubro_func rf\n  join erp_gen_rubro r on r.rubro_id = rf.rubro_id\n"
             "  join erp_gen_funcionalidad f on f.funcionalidad_id = rf.funcionalidad_id",
             [S('RUBRO', 'Rubro'), S('FUNCIONALIDAD', 'Funcionalidad'), S('CODIGO', 'Código')],
             [sel('RUBRO_ID', 'Rubro', 'rubros', 'Rubro', 'Perfil de rubro.'),
              sel('FUNCIONALIDAD_ID', 'Funcionalidad', 'funcionalidades', 'Qué activa', 'Funcionalidad que el rubro sugiere activar.')],
             "Qué funcionalidades sugiere cada rubro.", 'Agregar funcionalidad')

    catalogo(84, 'FERIADOS', 'Feriados', 'feriados', 'FERIADO_ID', 'erp_gen_feriado', 85, 'FERIADO', 'Feriado', CAT,
             "select f.feriado_id, p.nombre pais, f.fecha, to_char(f.fecha, 'Day', 'nls_date_language=spanish') dia, f.nombre\n"
             "  from erp_gen_feriado f\n  join erp_gen_pais p on p.pais_id = f.pais_id",
             [S('PAIS', 'País'), D('FECHA', 'Fecha'), S('DIA', 'Día'), S('NOMBRE', 'Motivo')],
             [sel('PAIS_ID', 'País', 'paises', 'País', 'País donde rige el feriado.'),
              fecha('FECHA', 'Fecha', 'Día del feriado', 'Cargue los feriados de cada año (incluidos los trasladables).', True),
              txt('NOMBRE', 'Motivo', 'Ej. Independencia', 'Nombre del feriado.', True)],
             "Feriados por país. Se usan para calcular vencimientos, plazos e intereses en días hábiles.", 'Crear feriado')

    # ------------------------------------------------------------------ PARÁMETROS Y PERÍODOS
    catalogo(80, 'PARAMETROS', 'Parámetros', 'parametros', 'PARAMETRO_ID', 'erp_gen_parametro', 81, 'PARAMETRO', 'Parámetro', CFG,
             "select pa.parametro_id, pa.codigo, pa.valor,\n"
             "       decode(pa.tipo_dato, 'T', 'Texto', 'N', 'Número', 'F', 'Fecha', 'Sí/No') tipo_dato,\n"
             "       coalesce(e.razon_social, 'General') ambito, pa.descripcion\n"
             "  from erp_gen_parametro pa\n  left join adm_gen_empresa e on e.empresa_id = pa.empresa_id\n"
             f" where pa.empresa_id is null or pa.empresa_id = {EMP}",
             [S('CODIGO', 'Código'), S('VALOR', 'Valor'), S('TIPO_DATO', 'Tipo'), S('AMBITO', 'Ámbito', 'El valor de la empresa reemplaza al general.'),
              S('DESCRIPCION', 'Para qué sirve')],
             [txt('CODIGO', 'Código', 'Mayúsculas, ej. ERP_GEN_…', 'Código del parámetro. Para cambiar un valor general solo en esta empresa, cree el mismo código con ámbito empresa.', True),
              sel('EMPRESA_ID', 'Ámbito', 'empresa-activa', 'Vacío = general', 'General: vale para todas las empresas. Empresa: solo para la empresa activa.', req=False, nulo='General (todas las empresas)'),
              i('TIPO_DATO', 'selectList', 'Tipo de dato', 'Formato del valor', 'Fechas como AAAA-MM-DD; Sí/No como S o N; números con punto decimal.', True, 'tipo-dato-parametro', defecto=('static', 'T')),
              area('VALOR', 'Valor', 'Valor del parámetro', 'Valor que toma el parámetro.'),
              area('DESCRIPCION', 'Descripción', 'Para qué sirve', 'Explicación del parámetro.')],
             "Parámetros que ajustan el comportamiento del ERP.", 'Crear parámetro')

    base.pagina_listado('p00082-periodos.apx', 82, 'PERIODOS', 'Períodos', 'erp-gen-periodo-cerrar', 'periodos',
        "select pe.periodo_id, pe.modulo, pe.anio, pe.mes, to_char(to_date(pe.mes, 'MM'), 'Month', 'nls_date_language=spanish') nombre_mes,\n"
        "       decode(pe.estado, 'A', 'Abierto', 'Cerrado') estado, pe.fecha_cierre, pe.cerrado_por\n"
        "  from erp_gen_periodo pe\n"
        f" where pe.empresa_id = {EMP}",
        'PERIODO_ID', 83,
        [S('MODULO', 'Módulo'), N('ANIO', 'Año'), N('MES', 'Mes'), S('NOMBRE_MES', 'Nombre'), S('ESTADO', 'Estado'),
         D('FECHA_CIERRE', 'Último cierre'), S('CERRADO_POR', 'Cerrado por')],
        "Períodos (meses) por módulo de la empresa activa.\nUn período cerrado no admite documentos con fecha en ese mes.",
        "Listado de erp_gen_periodo. Gestión en la página 83 vía erp_gen_periodo_api.", 'Gestionar períodos')

    base.pagina_accion('p00083-gestionar-periodo.apx', 83, 'GESTIONAR-PERIODO', 'Gestionar período', 'erp-gen-periodo-cerrar',
        "Cree los meses de un año, cierre un mes o reábralo.\nReabrir requiere el permiso ERP_GEN_PERIODO_REABRIR.",
        [dict(n='PERIODO_ID', tipo='hidden'),
         dict(n='MODULO', tipo='selectList', etiqueta='Módulo', req=True, lov='modulos-erp', inline='Módulo del período', ayuda='Cada módulo abre y cierra sus períodos por separado.'),
         dict(n='ANIO', tipo='numberField', etiqueta='Año', req=True, inline='Ej. 2026', ayuda='Año del período.'),
         dict(n='MES', tipo='selectList', etiqueta='Mes', lov='meses', nulo='- Todo el año (solo crear) -', inline='Para cerrar o reabrir', ayuda='Mes a cerrar o reabrir. Para crear el año completo, déjelo vacío.')],
        [('crear', 'CREAR_ANIO', 'Crear los 12 meses', False, None),
         ('reabrir', 'REABRIR', 'Reabrir', False, '¿Reabrir el período? Se podrán registrar documentos con fecha en ese mes.'),
         ('cerrar', 'CERRAR', 'Cerrar período', True, '¿Cerrar el período? No se podrán registrar documentos con fecha en ese mes.')],
        [('crear', f"erp_gen_periodo_api.crear_anio(i_empresa_id => {EMP}, i_modulo => :P83_MODULO, i_anio => :P83_ANIO);", 'Meses creados.'),
         ('reabrir', f"erp_gen_periodo_api.reabrir(i_empresa_id => {EMP}, i_modulo => :P83_MODULO, i_anio => :P83_ANIO, i_mes => :P83_MES);", 'Período reabierto.'),
         ('cerrar', f"erp_gen_periodo_api.cerrar(i_empresa_id => {EMP}, i_modulo => :P83_MODULO, i_anio => :P83_ANIO, i_mes => :P83_MES);", 'Período cerrado.')],
        extras=["", "    process cargar-periodo (", "        name: Cargar período", "        type: executeCode", "        source {",
                "            plsqlCode:" + code('plsql', "for r in (select modulo, anio, mes from erp_gen_periodo\n"
                                                      f"           where periodo_id = :P83_PERIODO_ID and empresa_id = {EMP}) loop\n"
                                                      "    :P83_MODULO := r.modulo;\n    :P83_ANIO   := r.anio;\n    :P83_MES    := r.mes;\nend loop;", 16),
                "        }", "        execution {", "            sequence: 10", "            point: beforeHeader", "        }",
                "        serverSideCondition {", "            type: itemIsNotNull", "            item: P83_PERIODO_ID", "        }", "    )"])

    catalogo(86, 'HABILITACIONES', 'Habilitaciones de período', 'habilitaciones', 'PERIODO_HABILITA_ID', 'erp_gen_periodo_habilita', 87,
             'HABILITACION', 'Habilitación de período', 'erp-gen-periodo-cerrar',
             "select h.periodo_habilita_id, pe.modulo, pe.anio, pe.mes, u.username usuario, h.fecha_hasta, h.motivo\n"
             "  from erp_gen_periodo_habilita h\n  join erp_gen_periodo pe on pe.periodo_id = h.periodo_id\n"
             "  join adm_seg_usuario u on u.usuario_id = h.usuario_id\n"
             f" where pe.empresa_id = {EMP}",
             [S('MODULO', 'Módulo'), N('ANIO', 'Año'), N('MES', 'Mes'), S('USUARIO', 'Usuario'), D('FECHA_HASTA', 'Hasta'), S('MOTIVO', 'Motivo')],
             [sel('PERIODO_ID', 'Período', 'periodos-cerrados', 'Mes cerrado', 'Período cerrado en el que podrá registrar el usuario.'),
              sel('USUARIO_ID', 'Usuario', 'usuarios', 'Usuario habilitado', 'Solo este usuario podrá registrar en el período.', popup=True),
              fecha('FECHA_HASTA', 'Hasta', 'Último día', 'Después de esta fecha la habilitación deja de valer.', True),
              area('MOTIVO', 'Motivo', 'Obligatorio', 'Por qué se habilita; queda registrado para auditoría.')],
             "Habilitaciones puntuales: permiten a un usuario registrar documentos en un período cerrado hasta una fecha, sin reabrirlo para todos.",
             'Crear habilitación')

    pagina_inicio()
    pagina_cambiar_empresa()
    escribir_autorizaciones()
    escribir_lovs()
    escribir_app_items_y_procesos()
    escribir_listas()
    escribir_breadcrumbs()
    print('ok')
