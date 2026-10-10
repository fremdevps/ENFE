-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/erp/database)

-- >>> apps/erp/database/packages/erp_gen_parametro_ctr.pks
create or replace package erp_gen_parametro_ctr
    authid definer
    accessible by (package erp_gen_parametro_api, package erp_gen_moneda_reg, package erp_gen_periodo_reg)
as
-- =============================================================================
-- Paquete : erp_gen_parametro_ctr   (capa ctr)
-- Tabla   : erp_gen_parametro
-- =============================================================================

    -- Fila del parámetro para la empresa; si no existe, la general (empresa_id null).
    -- Si no hay ninguna, devuelve un registro vacío (parametro_id null).
    function obtener (
        i_codigo      in erp_gen_parametro.codigo%type,
        i_empresa_id  in erp_gen_parametro.empresa_id%type default null
    ) return erp_gen_parametro%rowtype;

end erp_gen_parametro_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_periodo_ctr.pks
create or replace package erp_gen_periodo_ctr
    authid definer
    accessible by (package erp_gen_periodo_reg, package erp_gen_periodo_api)
as
-- =============================================================================
-- Paquete : erp_gen_periodo_ctr   (capa ctr)
-- Tabla   : erp_gen_periodo
-- =============================================================================

    -- Registro vacío (periodo_id null) si no existe.
    function obtener (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type
    ) return erp_gen_periodo%rowtype;

    -- Inserta el período si no existe (idempotente).
    procedure insertar (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type,
        i_estado      in erp_gen_periodo.estado%type
    );

    procedure actualizar (
        i_periodo_id    in erp_gen_periodo.periodo_id%type,
        i_estado        in erp_gen_periodo.estado%type,
        i_fecha_cierre  in erp_gen_periodo.fecha_cierre%type,
        i_cerrado_por   in erp_gen_periodo.cerrado_por%type
    );

end erp_gen_periodo_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_persona_ctr.pks
create or replace package erp_gen_persona_ctr
    authid definer
    accessible by (package erp_gen_persona_api)
as
-- =============================================================================
-- Paquete : erp_gen_persona_ctr   (capa ctr)
-- Tabla   : erp_gen_persona
-- =============================================================================

    procedure insertar (
        i_persona  in  erp_gen_persona%rowtype,
        o_persona_id out erp_gen_persona.persona_id%type
    );

    procedure actualizar (
        i_persona  in erp_gen_persona%rowtype
    );

end erp_gen_persona_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_empresa_func_ctr.pks
create or replace package erp_gen_empresa_func_ctr
    authid definer
    accessible by (package erp_gen_funcionalidad_api)
as
-- =============================================================================
-- Paquete : erp_gen_empresa_func_ctr   (capa ctr)
-- Tabla   : erp_gen_empresa_func
-- =============================================================================

    -- Activa la funcionalidad en la empresa (la crea si no existe). Idempotente.
    procedure insertar (
        i_empresa_id        in erp_gen_empresa_func.empresa_id%type,
        i_funcionalidad_id  in erp_gen_empresa_func.funcionalidad_id%type
    );

end erp_gen_empresa_func_ctr;
/

-- >>> apps/erp/database/packages/erp_gen_moneda_reg.pks
create or replace package erp_gen_moneda_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_moneda_reg   (capa reg)
-- Desc    : Redondeo por moneda, búsqueda de cotización y conversión de montos.
-- =============================================================================

    c_err_moneda_no_existe       constant pls_integer := -20100;
    c_err_cotizacion_no_existe   constant pls_integer := -20101;
    c_err_cotizacion_vencida     constant pls_integer := -20102;

    -- Redondea a los decimales de la moneda (de importe o de precio).
    function aplicar_redondeo (
        i_monto      in number,
        i_moneda_id  in erp_gen_moneda.moneda_id%type,
        i_es_precio  in varchar2 default 'N'
    ) return number;

    -- Cuántas unidades de la moneda destino vale 1 unidad de la moneda origen.
    -- Busca la última cotización <= i_fecha (a igual fecha prefiere la de la
    -- empresa sobre la general); si no hay par directo, usa 1 / par inverso.
    -- i_tipo C=compra, V=venta; null = el configurado en la empresa (o V).
    -- Parámetro ERP_GEN_COTIZACION_DIAS_MAX: antigüedad máxima admitida.
    function calcular_cotizacion (
        i_moneda_id_origen   in erp_gen_moneda.moneda_id%type,
        i_moneda_id_destino  in erp_gen_moneda.moneda_id%type,
        i_fecha              in date,
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

    -- Convierte y redondea a la moneda destino.
    function calcular_conversion (
        i_monto              in number,
        i_moneda_id_origen   in erp_gen_moneda.moneda_id%type,
        i_moneda_id_destino  in erp_gen_moneda.moneda_id%type,
        i_fecha              in date,
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

end erp_gen_moneda_reg;
/

-- >>> apps/erp/database/packages/erp_gen_impuesto_reg.pks
create or replace package erp_gen_impuesto_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_impuesto_reg   (capa reg)
-- Desc    : Motor de impuestos. Nada fijo en código: tasas, vigencias y
--           categorías fiscales son datos (ver docs/arquitectura-erp.md §3.2).
-- =============================================================================

    c_err_tasa_sin_vigencia   constant pls_integer := -20103;
    c_err_categoria_invalida  constant pls_integer := -20104;
    c_err_base_excedida       constant pls_integer := -20105;

    -- Porcentaje de la tasa vigente a la fecha (última vigencia con fecha_desde <= i_fecha).
    function calcular_porcentaje (
        i_impuesto_tasa_id  in erp_gen_impuesto_tasa.impuesto_tasa_id%type,
        i_fecha             in date
    ) return number;

    -- Desglosa un monto según la categoría fiscal.
    --   i_incluye_impuesto  S = i_monto ya incluye los impuestos (precio final)
    --                       N = i_monto es la base; el impuesto se suma
    --   i_decimales         null = decimales de la moneda
    -- Devuelve una línea por tasa y, si una parte del monto no está gravada por
    -- un impuesto, una línea con impuesto_tasa_id null (exento). Categoría sin
    -- tasas: una sola línea exenta con impuesto_id null.
    function calcular_impuestos (
        i_categoria_fiscal_id  in erp_gen_categoria_fiscal.categoria_fiscal_id%type,
        i_fecha                in date,
        i_monto                in number,
        i_incluye_impuesto     in varchar2,
        i_moneda_id            in erp_gen_moneda.moneda_id%type,
        i_decimales            in pls_integer default null
    ) return erp_impuesto_calc_tab;

end erp_gen_impuesto_reg;
/

-- >>> apps/erp/database/packages/erp_gen_periodo_reg.pks
create or replace package erp_gen_periodo_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_periodo_reg   (capa reg)
-- Desc    : Control de períodos abiertos/cerrados por empresa y módulo.
--           Período sin registro = abierto, salvo que el parámetro
--           ERP_GEN_PERIODO_ESTRICTO = 'S' (entonces debe existir y estar abierto).
-- =============================================================================

    c_err_periodo_cerrado     constant pls_integer := -20106;
    c_err_periodo_no_existe   constant pls_integer := -20107;

    function es_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    ) return boolean;

    procedure validar_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    );

end erp_gen_periodo_reg;
/

-- >>> apps/erp/database/packages/erp_gen_persona_reg.pks
create or replace package erp_gen_persona_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_persona_reg   (capa reg)
-- Desc    : Reglas de personas: normalización y validación del documento,
--           dígito verificador del RUC (algoritmo módulo 11 de la SET/DNIT).
-- =============================================================================

    c_err_documento_formato  constant pls_integer := -20109;
    c_err_dv_invalido        constant pls_integer := -20110;
    c_err_tipo_doc_invalido  constant pls_integer := -20111;

    -- Dígito verificador módulo 11 (base máxima 11). Las letras se reemplazan por
    -- su código ASCII, igual que el algoritmo publicado por la SET.
    function calcular_dv_ruc (
        i_numero  in varchar2
    ) return varchar2;

    -- Quita puntos y espacios, pasa a mayúsculas y, si viene "80012345-6" sin dv,
    -- separa número y dígito verificador.
    procedure aplicar_formato_documento (
        io_nro_documento  in out nocopy varchar2,
        io_dv             in out nocopy varchar2
    );

    procedure validar_documento (
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type
    );

end erp_gen_persona_reg;
/

-- >>> apps/erp/database/packages/erp_gen_parametro_api.pks
create or replace package erp_gen_parametro_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_parametro_api   (capa api)
-- Desc    : Lectura tipada de parámetros. Valor de la empresa o, si no hay,
--           el general. Si no existe ninguno devuelve i_defecto.
-- =============================================================================

    function obtener_texto (
        i_codigo      in varchar2,
        i_empresa_id  in number   default null,
        i_defecto     in varchar2 default null
    ) return varchar2;

    -- Números guardados con punto decimal (ej. 0.5).
    function obtener_numero (
        i_codigo      in varchar2,
        i_empresa_id  in number default null,
        i_defecto     in number default null
    ) return number;

    -- Fechas guardadas como AAAA-MM-DD.
    function obtener_fecha (
        i_codigo      in varchar2,
        i_empresa_id  in number default null,
        i_defecto     in date   default null
    ) return date;

    -- 'S' / 'N'.
    function obtener_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number      default null,
        i_defecto     in varchar2    default 'N'
    ) return varchar2;

end erp_gen_parametro_api;
/

-- >>> apps/erp/database/packages/erp_gen_moneda_api.pks
create or replace package erp_gen_moneda_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_moneda_api   (capa api)
-- Desc    : Cotización, conversión y redondeo para APEX / REST / otros módulos.
--           Ver erp_gen_moneda_reg para el detalle de la búsqueda.
-- =============================================================================

    function obtener_cotizacion (
        i_moneda_id_origen   in number,
        i_moneda_id_destino  in number,
        i_fecha              in date     default trunc(current_date),
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

    function obtener_monto_convertido (
        i_monto              in number,
        i_moneda_id_origen   in number,
        i_moneda_id_destino  in number,
        i_fecha              in date     default trunc(current_date),
        i_empresa_id         in number   default null,
        i_tipo               in varchar2 default null
    ) return number;

    function obtener_monto_redondeado (
        i_monto      in number,
        i_moneda_id  in number,
        i_es_precio  in varchar2 default 'N'
    ) return number;

end erp_gen_moneda_api;
/

-- >>> apps/erp/database/packages/erp_gen_impuesto_api.pks
create or replace package erp_gen_impuesto_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_impuesto_api   (capa api)
-- Desc    : Cálculo de impuestos para APEX / REST / documentos.
--   select * from table(erp_gen_impuesto_api.obtener_calculo(:categoria, sysdate, 110000, 'S', :pyg));
-- =============================================================================

    function obtener_porcentaje (
        i_impuesto_tasa_id  in number,
        i_fecha             in date default trunc(current_date)
    ) return number;

    function obtener_calculo (
        i_categoria_fiscal_id  in number,
        i_fecha                in date,
        i_monto                in number,
        i_incluye_impuesto     in varchar2,
        i_moneda_id            in number,
        i_decimales            in pls_integer default null
    ) return erp_impuesto_calc_tab;

end erp_gen_impuesto_api;
/

-- >>> apps/erp/database/packages/erp_gen_periodo_api.pks
create or replace package erp_gen_periodo_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_periodo_api   (capa api)
-- Desc    : Apertura, cierre y validación de períodos para APEX / REST / jobs.
--           Cerrar requiere ERP_GEN_PERIODO_CERRAR y reabrir ERP_GEN_PERIODO_REABRIR
--           (permisos de ADM). Fuera de una sesión APEX (jobs, scripts) no se
--           verifica el permiso: el llamador es el propio esquema.
-- =============================================================================

    c_err_sin_permiso  constant pls_integer := -20108;
    c_err_mes_invalido constant pls_integer := -20113;

    procedure validar_abierto (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    );

    -- 'S' / 'N' (para usar en SQL y condiciones de APEX).
    function es_abierto_sn (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_fecha       in date
    ) return varchar2;

    -- Crea los 12 meses del año (abiertos) para el módulo; no toca los existentes.
    procedure crear_anio (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_anio        in number
    );

    procedure cerrar (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_anio        in number,
        i_mes         in number
    );

    procedure reabrir (
        i_empresa_id  in number,
        i_modulo      in varchar2,
        i_anio        in number,
        i_mes         in number
    );

end erp_gen_periodo_api;
/

-- >>> apps/erp/database/packages/erp_gen_persona_api.pks
create or replace package erp_gen_persona_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_persona_api   (capa api)
-- Desc    : Alta y modificación de personas para APEX / REST. Normaliza y valida
--           el documento (formato y dígito verificador) antes de guardar.
-- =============================================================================

    procedure crear (
        i_tipo_persona           in  erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in  erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in  erp_gen_persona.nro_documento%type,
        i_dv                     in  erp_gen_persona.dv%type,
        i_razon_social           in  erp_gen_persona.razon_social%type,
        i_nombres                in  erp_gen_persona.nombres%type,
        i_apellidos              in  erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in  erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in  erp_gen_persona.es_contribuyente%type,
        i_pais_id                in  erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in  erp_gen_persona.fecha_nacimiento%type,
        i_email                  in  erp_gen_persona.email%type,
        i_telefono               in  erp_gen_persona.telefono%type,
        i_observacion            in  erp_gen_persona.observacion%type,
        i_estado                 in  erp_gen_persona.estado%type,
        o_persona_id             out erp_gen_persona.persona_id%type
    );

    procedure modificar (
        i_persona_id             in erp_gen_persona.persona_id%type,
        i_tipo_persona           in erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type,
        i_razon_social           in erp_gen_persona.razon_social%type,
        i_nombres                in erp_gen_persona.nombres%type,
        i_apellidos              in erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in erp_gen_persona.es_contribuyente%type,
        i_pais_id                in erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in erp_gen_persona.fecha_nacimiento%type,
        i_email                  in erp_gen_persona.email%type,
        i_telefono               in erp_gen_persona.telefono%type,
        i_observacion            in erp_gen_persona.observacion%type,
        i_estado                 in erp_gen_persona.estado%type
    );

    -- Para mostrar el DV sugerido en pantalla.
    function obtener_dv_ruc (
        i_numero  in varchar2
    ) return varchar2;

end erp_gen_persona_api;
/

-- >>> apps/erp/database/packages/erp_gen_funcionalidad_api.pks
create or replace package erp_gen_funcionalidad_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_funcionalidad_api   (capa api)
-- Desc    : Funcionalidades activables por empresa: adaptan el ERP al rubro sin
--           tocar código (docs/arquitectura-erp.md §3.5).
--   Condición APEX: erp_gen_funcionalidad_api.es_activa_sn('LOTE', :APP_EMPRESA_ID) = 'S'
-- =============================================================================

    -- 'S' si la funcionalidad está activa (catálogo y empresa) para la empresa.
    function es_activa_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number
    ) return varchar2;

    -- Activa en la empresa las funcionalidades de su rubro (erp_gen_empresa_config.rubro_id).
    -- No desactiva las que ya tenga: solo agrega.
    procedure crear_desde_rubro (
        i_empresa_id  in number
    );

end erp_gen_funcionalidad_api;
/
