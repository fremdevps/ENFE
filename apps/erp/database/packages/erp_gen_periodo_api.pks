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
