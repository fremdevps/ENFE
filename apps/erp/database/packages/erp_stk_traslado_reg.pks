create or replace package erp_stk_traslado_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_traslado_reg   (capa reg)
-- Desc    : Reglas y máquina de estados de los traslados de stock
--           (docs/requisitos-stk-traslados.md, docs/diseno-stk-inventario.md).
--           El traslado es un solo documento: al despachar sale del origen y
--           entra al depósito de tránsito; al recibir sale del tránsito y entra
--           al destino, siempre al costo con que salió. Nunca hace COMMIT.
--
--   B Borrador -> S Solicitado -> P Aprobado -> T En tránsito -> C Completado
--        rechazar (S, P) -> X      recepción parcial -> R      con faltantes -> D
--        anular (B, S, P, T sin recepciones) -> A
--
--   Comportamiento opcional por parámetro de la empresa (erp_gen_parametro):
--     ERP_STK_TRASLADO_APROBACION    S = requiere aprobar; N = se aprueba al solicitar
--     ERP_STK_TRASLADO_SEGREGAR      S = quien despacha no recibe
--     ERP_STK_TRASLADO_UN_PASO       S = admite internos de un paso
--     ERP_STK_TRASLADO_TOLERANCIA    % de faltante que se da de baja solo, como merma
--     ERP_STK_TRASLADO_PERDIDA_RESP  S = la pérdida exige responsable
-- =============================================================================

    -- Estados del traslado
    c_est_borrador     constant varchar2(1) := 'B';
    c_est_solicitado   constant varchar2(1) := 'S';
    c_est_aprobado     constant varchar2(1) := 'P';
    c_est_transito     constant varchar2(1) := 'T';
    c_est_parcial      constant varchar2(1) := 'R';
    c_est_diferencias  constant varchar2(1) := 'D';
    c_est_completado   constant varchar2(1) := 'C';
    c_est_rechazado    constant varchar2(1) := 'X';
    c_est_anulado      constant varchar2(1) := 'A';

    -- Tipos de traslado
    c_tipo_interno   constant varchar2(1) := 'I';
    c_tipo_remision  constant varchar2(1) := 'R';
    c_tipo_tercero   constant varchar2(1) := 'T';

    -- Resolución de un faltante
    c_res_perdida     constant varchar2(1) := 'P';
    c_res_devolucion  constant varchar2(1) := 'D';
    c_res_posterior   constant varchar2(1) := 'R';
    c_res_merma       constant varchar2(1) := 'M';

    -- Modo de la devolución enlazada
    c_dev_transito  constant varchar2(1) := 'T';   -- rechazo del destino: vuelve lo que sigue en tránsito
    c_dev_recibido  constant varchar2(1) := 'R';   -- devuelve mercadería ya recibida

    -- Estado de la nota de remisión
    c_rem_no_aplica  constant varchar2(1) := 'N';
    c_rem_pendiente  constant varchar2(1) := 'P';
    c_rem_generada   constant varchar2(1) := 'G';
    c_rem_cancelada  constant varchar2(1) := 'C';

    c_err_depositos     constant pls_integer := -20170;
    c_err_estado        constant pls_integer := -20171;
    c_err_cantidad      constant pls_integer := -20172;
    c_err_transporte    constant pls_integer := -20173;
    c_err_acceso        constant pls_integer := -20174;
    c_err_no_anulable   constant pls_integer := -20175;
    c_err_inmutable     constant pls_integer := -20176;

    procedure generar (
        i_empresa_id              in  number,
        i_deposito_id_origen      in  number,
        i_deposito_id_destino     in  number,
        i_items                   in  erp_stk_tras_item_tab,
        i_motivo                  in  varchar2 default null,
        i_tipo                    in  varchar2 default null,
        i_es_un_paso              in  varchar2 default 'N',
        i_fecha_emision           in  date     default null,
        i_fecha_requerida         in  date     default null,
        i_fecha_salida_estimada   in  timestamp with local time zone default null,
        i_persona_id_destino      in  number   default null,
        i_monto_flete             in  number   default 0,
        i_es_flete_capitalizable  in  varchar2 default 'N',
        i_observacion             in  varchar2 default null,
        o_traslado_id             out number
    );

    procedure aplicar_modificacion (
        i_traslado_id             in number,
        i_fecha_requerida         in date,
        i_fecha_salida_estimada   in timestamp with local time zone,
        i_monto_flete             in number,
        i_es_flete_capitalizable  in varchar2,
        i_observacion             in varchar2
    );

    procedure aplicar_item (
        i_traslado_id       in  number,
        i_item              in  erp_stk_tras_item_typ,
        o_traslado_item_id  out number
    );

    procedure aplicar_quita_item (
        i_traslado_item_id  in number
    );

    procedure aplicar_transporte (
        i_traslado_id               in number,
        i_vehiculo_id               in number,
        i_persona_id_conductor      in number,
        i_persona_id_transportista  in number,
        i_vehiculo_chapa            in varchar2,
        i_tipo_transporte           in varchar2,
        i_modalidad_transporte      in varchar2,
        i_responsable_emision       in number,
        i_punto_expedicion_id       in number,
        i_kilometros                in number
    );

    procedure aplicar_solicitud (
        i_traslado_id  in number
    );

    procedure aplicar_aprobacion (
        i_traslado_id  in number,
        i_items        in erp_stk_tras_item_tab default null
    );

    procedure aplicar_rechazo (
        i_traslado_id  in number,
        i_motivo       in varchar2
    );

    procedure aplicar_despacho (
        i_traslado_id              in  number,
        i_items                    in  erp_stk_tras_item_tab default null,
        i_fecha                    in  timestamp with local time zone default null,
        i_debe_crear_complemento   in  varchar2 default 'N',
        o_traslado_id_complemento  out number
    );

    procedure aplicar_recepcion (
        i_traslado_id        in  number,
        i_items              in  erp_stk_tras_item_tab default null,
        i_fecha              in  timestamp with local time zone default null,
        i_observacion        in  varchar2 default null,
        o_traslado_recep_id  out number
    );

    procedure aplicar_resolucion (
        i_traslado_recep_det_id   in number,
        i_resolucion              in varchar2,
        i_persona_id_responsable  in number   default null,
        i_observacion             in varchar2 default null,
        i_fecha                   in timestamp with local time zone default null
    );

    procedure aplicar_anulacion (
        i_traslado_id  in number,
        i_motivo       in varchar2,
        i_fecha        in timestamp with local time zone default null
    );

    procedure generar_devolucion (
        i_traslado_id  in  number,
        i_modo         in  varchar2 default null,
        i_items        in  erp_stk_tras_item_tab default null,
        o_traslado_id  out number
    );

    -- Punto de integración con el módulo de documentos (nota de remisión electrónica).
    procedure aplicar_remision (
        i_traslado_id            in number,
        i_remision_documento_id  in number,
        i_remision_numero        in varchar2,
        i_remision_cdc           in varchar2
    );

    procedure aplicar_cancelacion_remision (
        i_traslado_id  in number
    );

    -- Empresa del traslado (para verificar permisos en la capa api).
    function calcular_empresa (
        i_traslado_id  in number
    ) return number;

end erp_stk_traslado_reg;
/
