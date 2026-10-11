create or replace package body erp_stk_traslado_api
as

    c_per_crear      constant varchar2(40) := 'ERP_STK_TRASLADO_CREAR';
    c_per_aprobar    constant varchar2(40) := 'ERP_STK_TRASLADO_APROBAR';
    c_per_despachar  constant varchar2(40) := 'ERP_STK_TRASLADO_DESPACHAR';
    c_per_recibir    constant varchar2(40) := 'ERP_STK_TRASLADO_RECIBIR';
    c_per_resolver   constant varchar2(40) := 'ERP_STK_TRASLADO_RESOLVER';
    c_per_anular     constant varchar2(40) := 'ERP_STK_TRASLADO_ANULAR';

    procedure validar_permiso (
        i_permiso      in varchar2,
        i_traslado_id  in number
    ) is
    begin
        erp_stk_comun_utl.validar_permiso(
            i_permiso    => i_permiso,
            i_empresa_id => erp_stk_traslado_reg.calcular_empresa(i_traslado_id => i_traslado_id));
    end validar_permiso;

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
    ) is
    begin
        erp_stk_comun_utl.validar_permiso(i_permiso => c_per_crear, i_empresa_id => i_empresa_id);
        erp_stk_traslado_reg.generar(
            i_empresa_id             => i_empresa_id,
            i_deposito_id_origen     => i_deposito_id_origen,
            i_deposito_id_destino    => i_deposito_id_destino,
            i_items                  => i_items,
            i_motivo                 => i_motivo,
            i_tipo                   => i_tipo,
            i_es_un_paso             => i_es_un_paso,
            i_fecha_emision          => i_fecha_emision,
            i_fecha_requerida        => i_fecha_requerida,
            i_fecha_salida_estimada  => i_fecha_salida_estimada,
            i_persona_id_destino     => i_persona_id_destino,
            i_monto_flete            => i_monto_flete,
            i_es_flete_capitalizable => i_es_flete_capitalizable,
            i_observacion            => i_observacion,
            o_traslado_id            => o_traslado_id);
    end crear;

    procedure modificar (
        i_traslado_id             in number,
        i_fecha_requerida         in date,
        i_fecha_salida_estimada   in timestamp with local time zone,
        i_monto_flete             in number,
        i_es_flete_capitalizable  in varchar2,
        i_observacion             in varchar2
    ) is
    begin
        validar_permiso(i_permiso => c_per_crear, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_modificacion(
            i_traslado_id            => i_traslado_id,
            i_fecha_requerida        => i_fecha_requerida,
            i_fecha_salida_estimada  => i_fecha_salida_estimada,
            i_monto_flete            => i_monto_flete,
            i_es_flete_capitalizable => i_es_flete_capitalizable,
            i_observacion            => i_observacion);
    end modificar;

    procedure asignar_item (
        i_traslado_id       in  number,
        i_item              in  erp_stk_tras_item_typ,
        o_traslado_item_id  out number
    ) is
    begin
        validar_permiso(i_permiso => c_per_crear, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_item(i_traslado_id => i_traslado_id, i_item => i_item,
                                          o_traslado_item_id => o_traslado_item_id);
    end asignar_item;

    procedure quitar_item (
        i_traslado_item_id  in number
    ) is
        v_traslado_id  number;
    begin
        select max(traslado_id) into v_traslado_id from erp_stk_traslado_item where traslado_item_id = i_traslado_item_id;
        if v_traslado_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'El ítem de traslado indicado no existe.');
        end if;
        validar_permiso(i_permiso => c_per_crear, i_traslado_id => v_traslado_id);
        erp_stk_traslado_reg.aplicar_quita_item(i_traslado_item_id => i_traslado_item_id);
    end quitar_item;

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
    ) is
    begin
        validar_permiso(i_permiso => c_per_crear, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_transporte(
            i_traslado_id              => i_traslado_id,
            i_vehiculo_id              => i_vehiculo_id,
            i_persona_id_conductor     => i_persona_id_conductor,
            i_persona_id_transportista => i_persona_id_transportista,
            i_vehiculo_chapa           => i_vehiculo_chapa,
            i_tipo_transporte          => i_tipo_transporte,
            i_modalidad_transporte     => i_modalidad_transporte,
            i_responsable_emision      => i_responsable_emision,
            i_punto_expedicion_id      => i_punto_expedicion_id,
            i_kilometros               => i_kilometros);
    end asignar_transporte;

    procedure solicitar (
        i_traslado_id  in number
    ) is
    begin
        validar_permiso(i_permiso => c_per_crear, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_solicitud(i_traslado_id => i_traslado_id);
    end solicitar;

    procedure aprobar (
        i_traslado_id  in number,
        i_items        in erp_stk_tras_item_tab default null
    ) is
    begin
        validar_permiso(i_permiso => c_per_aprobar, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_aprobacion(i_traslado_id => i_traslado_id, i_items => i_items);
    end aprobar;

    procedure rechazar (
        i_traslado_id  in number,
        i_motivo       in varchar2
    ) is
    begin
        validar_permiso(i_permiso => c_per_aprobar, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_rechazo(i_traslado_id => i_traslado_id, i_motivo => i_motivo);
    end rechazar;

    procedure despachar (
        i_traslado_id              in  number,
        i_items                    in  erp_stk_tras_item_tab default null,
        i_fecha                    in  timestamp with local time zone default null,
        i_debe_crear_complemento   in  varchar2 default 'N',
        o_traslado_id_complemento  out number
    ) is
    begin
        validar_permiso(i_permiso => c_per_despachar, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_despacho(
            i_traslado_id             => i_traslado_id,
            i_items                   => i_items,
            i_fecha                   => i_fecha,
            i_debe_crear_complemento  => i_debe_crear_complemento,
            o_traslado_id_complemento => o_traslado_id_complemento);
    end despachar;

    procedure recibir (
        i_traslado_id        in  number,
        i_items              in  erp_stk_tras_item_tab default null,
        i_fecha              in  timestamp with local time zone default null,
        i_observacion        in  varchar2 default null,
        o_traslado_recep_id  out number
    ) is
    begin
        validar_permiso(i_permiso => c_per_recibir, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_recepcion(
            i_traslado_id       => i_traslado_id,
            i_items             => i_items,
            i_fecha             => i_fecha,
            i_observacion       => i_observacion,
            o_traslado_recep_id => o_traslado_recep_id);
    end recibir;

    procedure resolver_diferencia (
        i_traslado_recep_det_id   in number,
        i_resolucion              in varchar2,
        i_persona_id_responsable  in number   default null,
        i_observacion             in varchar2 default null,
        i_fecha                   in timestamp with local time zone default null
    ) is
        v_traslado_id  number;
    begin
        select max(i.traslado_id)
          into v_traslado_id
          from erp_stk_traslado_recep_det d
          join erp_stk_traslado_item i on i.traslado_item_id = d.traslado_item_id
         where d.traslado_recep_det_id = i_traslado_recep_det_id;
        if v_traslado_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'La línea de recepción indicada no existe.');
        end if;
        validar_permiso(i_permiso => c_per_resolver, i_traslado_id => v_traslado_id);
        erp_stk_traslado_reg.aplicar_resolucion(
            i_traslado_recep_det_id  => i_traslado_recep_det_id,
            i_resolucion             => i_resolucion,
            i_persona_id_responsable => i_persona_id_responsable,
            i_observacion            => i_observacion,
            i_fecha                  => i_fecha);
    end resolver_diferencia;

    procedure anular (
        i_traslado_id  in number,
        i_motivo       in varchar2,
        i_fecha        in timestamp with local time zone default null
    ) is
    begin
        validar_permiso(i_permiso => c_per_anular, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_anulacion(i_traslado_id => i_traslado_id, i_motivo => i_motivo, i_fecha => i_fecha);
    end anular;

    procedure crear_devolucion (
        i_traslado_id  in  number,
        i_modo         in  varchar2 default null,
        i_items        in  erp_stk_tras_item_tab default null,
        o_traslado_id  out number
    ) is
    begin
        validar_permiso(i_permiso => c_per_recibir, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.generar_devolucion(i_traslado_id => i_traslado_id, i_modo => i_modo,
                                                i_items => i_items, o_traslado_id => o_traslado_id);
    end crear_devolucion;

    procedure asignar_remision (
        i_traslado_id            in number,
        i_remision_documento_id  in number,
        i_remision_numero        in varchar2,
        i_remision_cdc           in varchar2 default null
    ) is
    begin
        validar_permiso(i_permiso => c_per_despachar, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_remision(
            i_traslado_id           => i_traslado_id,
            i_remision_documento_id => i_remision_documento_id,
            i_remision_numero       => i_remision_numero,
            i_remision_cdc          => i_remision_cdc);
    end asignar_remision;

    procedure quitar_remision (
        i_traslado_id  in number
    ) is
    begin
        validar_permiso(i_permiso => c_per_despachar, i_traslado_id => i_traslado_id);
        erp_stk_traslado_reg.aplicar_cancelacion_remision(i_traslado_id => i_traslado_id);
    end quitar_remision;

end erp_stk_traslado_api;
/
