create or replace package erp_doc_fe_cola_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_cola_reg   (capa reg)
-- Desc    : Cola de envío de documentos electrónicos y máquina de estados.
--           El estado de ENVÍO (qué pasó con la transmisión) está separado del
--           resultado en SIFEN (qué decidió la administración tributaria).
--
--           Envío:  P pendiente -> E enviado (síncrono) | L en lote -> E -> C concluido
--                   E -> S sin respuesta (consultar por CDC) -> C | P
--                   P/L/E/S -> T error técnico (reintento con espera creciente) -> X detenido
--                   T/S/X -> P (reencolar)
--           SIFEN:  N sin resultado -> A aprobado | O aprobado con observación | R rechazado
--                   A/O -> C cancelado (evento) ; N/R -> I inutilizado (evento)
--
--           Los consumidores toman documentos con select … for update skip locked
--           (erp_doc_fe_documento_ctr.bloquear_pendientes). Ningún procedimiento confirma:
--           el job o el servicio que consume hace commit después de cada paso.
--           Lotes: Manual Técnico SIFEN v150 §9.2 (pág. 47): hasta 50 DE del mismo tipo.
-- =============================================================================

    c_err_transicion     constant pls_integer := -20146;
    c_err_no_encontrado  constant pls_integer := -20147;
    c_err_lote           constant pls_integer := -20149;

    -- estado de envío
    c_envio_pendiente      constant varchar2(1) := 'P';
    c_envio_en_lote        constant varchar2(1) := 'L';
    c_envio_enviado        constant varchar2(1) := 'E';
    c_envio_sin_respuesta  constant varchar2(1) := 'S';
    c_envio_error          constant varchar2(1) := 'T';
    c_envio_detenido       constant varchar2(1) := 'X';
    c_envio_concluido      constant varchar2(1) := 'C';

    -- resultado en SIFEN (los tres primeros coinciden con el efecto del catálogo de códigos)
    c_sifen_sin_resultado  constant varchar2(1) := 'N';
    c_sifen_aprobado       constant varchar2(1) := 'A';
    c_sifen_observado      constant varchar2(1) := 'O';
    c_sifen_rechazado      constant varchar2(1) := 'R';
    c_sifen_cancelado      constant varchar2(1) := 'C';
    c_sifen_inutilizado    constant varchar2(1) := 'I';

    -- estado del lote
    c_lote_pendiente       constant varchar2(1) := 'P';
    c_lote_enviado         constant varchar2(1) := 'E';
    c_lote_concluido       constant varchar2(1) := 'C';
    c_lote_rechazado       constant varchar2(1) := 'R';
    c_lote_detenido        constant varchar2(1) := 'X';

    -- códigos de respuesta que el flujo necesita reconocer (Manual Técnico SIFEN v150 cap. 12)
    c_cod_lote_recibido    constant varchar2(4) := '0300';

    -- valores por defecto cuando la empresa no tiene configuración
    c_max_documentos_lote  constant pls_integer := 50;
    c_max_intentos         constant pls_integer := 10;
    c_minutos_reintento    constant pls_integer := 5;
    c_minutos_espera_max   constant pls_integer := 1440;
    c_horas_consulta_lote  constant pls_integer := 48;

    function es_transicion_valida (
        i_estado_desde  in varchar2,
        i_estado_hasta  in varchar2
    ) return boolean;

    -- Minutos de espera antes del intento siguiente: base * 2^(intentos - 1), con tope.
    function calcular_espera (
        i_intentos       in number,
        i_minutos_base   in number
    ) return number;

    -- Vuelve a dejar el documento pendiente de envío (desde error, sin respuesta o detenido).
    procedure encolar (
        i_fe_documento_id  in number
    );

    -- Envío síncrono: toma hasta i_cantidad documentos y los deja en "enviado".
    function tomar_pendientes (
        i_empresa_id  in number,
        i_tipo_de     in number,
        i_cantidad    in number
    ) return sys.odcinumberlist;

    -- Envío asíncrono: arma un lote con los pendientes de un mismo tipo de DE.
    -- o_fe_lote_id queda nulo si no había nada para enviar.
    procedure armar_lote (
        i_empresa_id  in  number,
        i_tipo_de     in  number,
        o_fe_lote_id  out number,
        o_cantidad    out number
    );

    -- <rLoteDE> con los rDE firmados del lote (lo que después se comprime y se envía).
    function generar_xml_lote (
        i_fe_lote_id  in number
    ) return clob;

    -- Respuesta de la recepción del lote (siRecepLoteDE).
    procedure registrar_envio_lote (
        i_fe_lote_id         in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_numero_lote        in varchar2,
        i_tiempo_proceso     in number
    );

    -- Resultado del documento. El efecto sale del catálogo de códigos; si el código no
    -- está catalogado se usa i_estado_resultado (A, O o R).
    procedure registrar_resultado (
        i_fe_documento_id    in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_protocolo          in varchar2 default null,
        i_estado_resultado   in varchar2 default null
    );

    -- Error técnico (sin respuesta válida): programa el reintento o detiene el documento.
    procedure registrar_error (
        i_fe_documento_id  in number,
        i_error            in varchar2
    );

    -- Se envió pero no llegó respuesta: queda para consultar por CDC.
    procedure registrar_sin_respuesta (
        i_fe_documento_id  in number
    );

    -- Cambio del resultado por un evento aprobado: cancelación o inutilización.
    procedure registrar_evento (
        i_fe_documento_id  in number,
        i_estado_sifen     in varchar2
    );

end erp_doc_fe_cola_reg;
/
