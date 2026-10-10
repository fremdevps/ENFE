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
