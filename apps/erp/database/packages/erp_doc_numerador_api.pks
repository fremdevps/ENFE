create or replace package erp_doc_numerador_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_numerador_api   (capa api)
-- Desc    : Numeración de comprobantes para los módulos del ERP, APEX y REST.
--           tomar_siguiente NO confirma: el número queda dentro de la transacción del
--           documento que lo pide (si el documento no se graba, el número no se pierde).
--           Inutilizar requiere el permiso ERP_DOC_NUMERO_INUTILIZAR; fuera de una sesión
--           APEX (jobs, scripts) no se verifica: el llamador es el propio esquema.
-- =============================================================================

    c_err_sin_permiso  constant pls_integer := -20137;

    c_permiso_inutilizar  constant varchar2(30) := 'ERP_DOC_NUMERO_INUTILIZAR';

    function obtener_numerador (
        i_punto_expedicion_id  in number,
        i_tipo_documento_id    in number,
        i_fecha                in date default current_date
    ) return number;

    procedure tomar_siguiente (
        i_numerador_id       in  number,
        i_fecha              in  date     default current_date,
        i_usuario            in  varchar2 default null,
        i_espera_segundos    in  number   default null,
        o_numero             out number,
        o_numero_formateado  out varchar2
    );

    function formatear_numero (
        i_establecimiento   in varchar2,
        i_punto_expedicion  in varchar2,
        i_numero            in number
    ) return varchar2;

    -- 'S' si el texto tiene el formato 001-001-0000001.
    function es_formato_valido_sn (
        i_numero_formateado  in varchar2
    ) return varchar2;

    procedure validar_formato (
        i_numero_formateado  in  varchar2,
        o_establecimiento    out varchar2,
        o_punto_expedicion   out varchar2,
        o_numero             out number
    );

    function obtener_aviso (
        i_numerador_id  in number,
        i_fecha         in date default current_date
    ) return varchar2;

    procedure inutilizar (
        i_numerador_id           in  number,
        i_numero_desde           in  number,
        i_numero_hasta           in  number   default null,
        i_tipo                   in  varchar2,
        i_motivo                 in  varchar2,
        i_motivo_id              in  number   default null,
        i_fecha                  in  date     default current_date,
        o_numero_inutilizado_id  out number
    );

end erp_doc_numerador_api;
/
