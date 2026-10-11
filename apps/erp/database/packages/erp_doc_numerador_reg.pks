create or replace package erp_doc_numerador_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_numerador_reg   (capa reg)
-- Desc    : Numeración de comprobantes. El número legal se toma bloqueando el
--           numerador (select … for update) EN LA TRANSACCIÓN DEL LLAMADOR: si el
--           documento se deshace, el número vuelve a quedar disponible (sin huecos);
--           dos sesiones nunca obtienen el mismo número. Nunca transacción autónoma.
--           Formato visible: establecimiento-punto-número (001-001-0000001).
-- =============================================================================

    c_err_numerador_invalido   constant pls_integer := -20130;
    c_err_timbrado_no_vigente  constant pls_integer := -20131;
    c_err_rango_agotado        constant pls_integer := -20132;
    c_err_usuario_no_autoriz   constant pls_integer := -20133;
    c_err_formato_numero       constant pls_integer := -20134;
    c_err_inutilizacion        constant pls_integer := -20135;
    c_err_numerador_ocupado    constant pls_integer := -20136;

    c_estado_activo            constant varchar2(1) := 'A';
    c_si                       constant varchar2(1) := 'S';
    c_timbrado_electronico     constant varchar2(1) := 'E';
    c_tipo_anulado             constant varchar2(1) := 'A';
    c_tipo_inutilizado         constant varchar2(1) := 'I';
    c_tipo_extraviado          constant varchar2(1) := 'E';
    c_espera_segundos          constant pls_integer := 10;     -- espera por defecto del bloqueo
    c_max_rango_electronico    constant pls_integer := 1000;   -- Manual Técnico SIFEN v150 §11.1.1 (pág. 113)
    c_largo_minimo_motivo      constant pls_integer := 5;

    -- 001-001-0000001
    function formatear_numero (
        i_establecimiento   in varchar2,
        i_punto_expedicion  in varchar2,
        i_numero            in number
    ) return varchar2;

    -- Valida el formato 001-001-0000001 y devuelve sus partes.
    procedure validar_formato (
        i_numero_formateado  in  varchar2,
        o_establecimiento    out varchar2,
        o_punto_expedicion   out varchar2,
        o_numero             out number
    );

    -- Numerador activo con timbrado vigente para el punto, el tipo de documento y la fecha.
    function obtener_numerador (
        i_punto_expedicion_id  in erp_doc_numerador.punto_expedicion_id%type,
        i_tipo_documento_id    in erp_doc_numerador.tipo_documento_id%type,
        i_fecha                in date
    ) return erp_doc_numerador.numerador_id%type;

    -- Toma el siguiente número (saltando los inutilizados) y deja bloqueado el numerador
    -- hasta el commit o rollback del llamador.
    procedure tomar_siguiente (
        i_numerador_id       in  erp_doc_numerador.numerador_id%type,
        i_fecha              in  date,
        i_usuario            in  varchar2,
        i_espera_segundos    in  pls_integer,
        o_numero             out erp_doc_numerador.numero_actual%type,
        o_numero_formateado  out varchar2
    );

    -- Texto del aviso (vencimiento del timbrado o rango por agotarse); null si no hay.
    function obtener_aviso (
        i_numerador_id  in erp_doc_numerador.numerador_id%type,
        i_fecha         in date
    ) return varchar2;

    -- Registra números anulados, inutilizados o extraviados.
    procedure inutilizar (
        i_numerador_id           in  erp_doc_numerador.numerador_id%type,
        i_numero_desde           in  number,
        i_numero_hasta           in  number,
        i_tipo                   in  varchar2,
        i_motivo_id              in  number,
        i_motivo                 in  varchar2,
        i_fecha                  in  date,
        o_numero_inutilizado_id  out erp_doc_numero_inutilizado.numero_inutilizado_id%type
    );

end erp_doc_numerador_reg;
/
