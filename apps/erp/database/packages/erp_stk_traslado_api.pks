create or replace package erp_stk_traslado_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_traslado_api   (capa api)
-- Desc    : Traslados de stock para APEX / REST / jobs. Verifica el permiso
--           ERP_STK_TRASLADO_* de cada acción (si hay usuario de sesión) y
--           delega en erp_stk_traslado_reg. Reglas, estados y ejemplos:
--           docs/diseno-stk-inventario.md.
-- =============================================================================

    -- Crea el traslado en borrador. i_tipo null = se deduce (I misma sucursal y
    -- dirección, R entre locales, T si se indica la persona que recibe).
    -- i_motivo: código de erp_stk_motivo_traslado (por defecto INTERNO / ENTRE_LOCALES).
    procedure crear (
        i_empresa_id              in  number,
        i_deposito_id_origen      in  number,
        i_deposito_id_destino     in  number,
        i_items                   in  erp_stk_tras_item_tab default null,
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

    -- Solo en borrador.
    procedure modificar (
        i_traslado_id             in number,
        i_fecha_requerida         in date,
        i_fecha_salida_estimada   in timestamp with local time zone,
        i_monto_flete             in number,
        i_es_flete_capitalizable  in varchar2,
        i_observacion             in varchar2
    );

    -- Agrega un ítem (solo en borrador). Usa producto_id, lote_id, cantidad,
    -- deposito_ubicacion_id (de retiro) y observacion.
    procedure asignar_item (
        i_traslado_id       in  number,
        i_item              in  erp_stk_tras_item_typ,
        o_traslado_item_id  out number
    );

    procedure quitar_item (
        i_traslado_item_id  in number
    );

    -- Vehículo, conductor y datos de la remisión (hasta antes del despacho).
    -- Con un vehículo genérico la chapa real va en i_vehiculo_chapa.
    procedure asignar_transporte (
        i_traslado_id               in number,
        i_vehiculo_id               in number   default null,
        i_persona_id_conductor      in number   default null,
        i_persona_id_transportista  in number   default null,
        i_vehiculo_chapa            in varchar2 default null,
        i_tipo_transporte           in varchar2 default 'P',
        i_modalidad_transporte      in varchar2 default 'T',
        i_responsable_emision       in number   default null,
        i_punto_expedicion_id       in number   default null,
        i_kilometros                in number   default null
    );

    procedure solicitar (
        i_traslado_id  in number
    );

    -- i_items (traslado_item_id, cantidad) para aprobar menos de lo solicitado;
    -- null = todo. Reserva el stock en el origen.
    procedure aprobar (
        i_traslado_id  in number,
        i_items        in erp_stk_tras_item_tab default null
    );

    procedure rechazar (
        i_traslado_id  in number,
        i_motivo       in varchar2
    );

    -- i_items (traslado_item_id, cantidad) para despachar menos de lo aprobado;
    -- null = todo. Lo no despachado se cancela o, con i_debe_crear_complemento = 'S',
    -- pasa a un traslado complementario en borrador.
    procedure despachar (
        i_traslado_id              in  number,
        i_items                    in  erp_stk_tras_item_tab default null,
        i_fecha                    in  timestamp with local time zone default null,
        i_debe_crear_complemento   in  varchar2 default 'N',
        o_traslado_id_complemento  out number
    );

    -- i_items (traslado_item_id, cantidad conforme, cantidad_averiada,
    -- cantidad_faltante, cantidad_sobrante, deposito_ubicacion_id); null = recibe
    -- conforme todo lo pendiente.
    procedure recibir (
        i_traslado_id        in  number,
        i_items              in  erp_stk_tras_item_tab default null,
        i_fecha              in  timestamp with local time zone default null,
        i_observacion        in  varchar2 default null,
        o_traslado_recep_id  out number
    );

    -- i_resolucion: P pérdida, D devolución al origen, R recepción posterior.
    procedure resolver_diferencia (
        i_traslado_recep_det_id   in number,
        i_resolucion              in varchar2,
        i_persona_id_responsable  in number   default null,
        i_observacion             in varchar2 default null,
        i_fecha                   in timestamp with local time zone default null
    );

    procedure anular (
        i_traslado_id  in number,
        i_motivo       in varchar2,
        i_fecha        in timestamp with local time zone default null
    );

    -- Traslado de devolución enlazado. i_modo: T = el destino rechaza lo que sigue
    -- en tránsito (nace en tránsito hacia el origen), R = devuelve lo ya recibido
    -- (nace en borrador). null = T si queda algo en tránsito, si no R.
    procedure crear_devolucion (
        i_traslado_id  in  number,
        i_modo         in  varchar2 default null,
        i_items        in  erp_stk_tras_item_tab default null,
        o_traslado_id  out number
    );

    -- Punto de integración con el módulo de documentos: informa la nota de
    -- remisión electrónica emitida para el traslado (una sola vigente).
    procedure asignar_remision (
        i_traslado_id            in number,
        i_remision_documento_id  in number,
        i_remision_numero        in varchar2,
        i_remision_cdc           in varchar2 default null
    );

    -- La remisión fue cancelada: el traslado admite una nueva.
    procedure quitar_remision (
        i_traslado_id  in number
    );

end erp_stk_traslado_api;
/
