create or replace package body erp_stk_movimiento_api
as

    procedure registrar (
        i_empresa_id       in  number,
        i_tipo_movimiento  in  varchar2,
        i_fecha            in  date,
        i_items            in  erp_stk_mov_item_tab,
        i_origen_modulo    in  varchar2 default 'STK',
        i_origen_tabla     in  varchar2 default null,
        i_origen_id        in  number   default null,
        i_motivo           in  varchar2 default null,
        i_observacion      in  varchar2 default null,
        o_movimiento_id    out number
    ) is
    begin
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_MOVIMIENTO_REGISTRAR', i_empresa_id => i_empresa_id);
        erp_stk_movimiento_reg.generar(
            i_empresa_id      => i_empresa_id,
            i_tipo_movimiento => i_tipo_movimiento,
            i_fecha           => i_fecha,
            i_items           => i_items,
            i_origen_modulo   => i_origen_modulo,
            i_origen_tabla    => i_origen_tabla,
            i_origen_id       => i_origen_id,
            i_motivo          => i_motivo,
            i_observacion     => i_observacion,
            o_movimiento_id   => o_movimiento_id);
    end registrar;

    procedure crear_ajuste_entrada (
        i_empresa_id              in  number,
        i_deposito_id             in  number,
        i_producto_id             in  number,
        i_cantidad                in  number,
        i_motivo                  in  varchar2,
        i_costo_unitario          in  number   default null,
        i_costo_unitario_reporte  in  number   default null,
        i_lote_id                 in  number   default null,
        i_deposito_ubicacion_id   in  number   default null,
        i_fecha                   in  date     default trunc(current_date),
        i_observacion             in  varchar2 default null,
        o_movimiento_id           out number
    ) is
    begin
        if i_cantidad is null or i_cantidad <= 0 then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'La cantidad del ajuste debe ser mayor que cero.');
        end if;
        registrar(
            i_empresa_id      => i_empresa_id,
            i_tipo_movimiento => 'AJUSTE_ENT',
            i_fecha           => i_fecha,
            i_items           => erp_stk_mov_item_tab(
                                     erp_stk_mov_item_typ(
                                         deposito_id            => i_deposito_id,
                                         producto_id            => i_producto_id,
                                         cantidad               => i_cantidad,
                                         lote_id                => i_lote_id,
                                         deposito_ubicacion_id  => i_deposito_ubicacion_id,
                                         costo_unitario         => i_costo_unitario,
                                         costo_unitario_reporte => i_costo_unitario_reporte)),
            i_motivo          => i_motivo,
            i_observacion     => i_observacion,
            o_movimiento_id   => o_movimiento_id);
    end crear_ajuste_entrada;

    procedure crear_ajuste_salida (
        i_empresa_id             in  number,
        i_deposito_id            in  number,
        i_producto_id            in  number,
        i_cantidad               in  number,
        i_motivo                 in  varchar2,
        i_lote_id                in  number   default null,
        i_deposito_ubicacion_id  in  number   default null,
        i_fecha                  in  date     default trunc(current_date),
        i_observacion            in  varchar2 default null,
        o_movimiento_id          out number
    ) is
    begin
        if i_cantidad is null or i_cantidad <= 0 then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'La cantidad del ajuste debe ser mayor que cero.');
        end if;
        registrar(
            i_empresa_id      => i_empresa_id,
            i_tipo_movimiento => 'AJUSTE_SAL',
            i_fecha           => i_fecha,
            i_items           => erp_stk_mov_item_tab(
                                     erp_stk_mov_item_typ(
                                         deposito_id           => i_deposito_id,
                                         producto_id           => i_producto_id,
                                         cantidad              => -i_cantidad,
                                         lote_id               => i_lote_id,
                                         deposito_ubicacion_id => i_deposito_ubicacion_id)),
            i_motivo          => i_motivo,
            i_observacion     => i_observacion,
            o_movimiento_id   => o_movimiento_id);
    end crear_ajuste_salida;

    procedure anular (
        i_movimiento_id  in  number,
        i_motivo         in  varchar2,
        i_fecha          in  date default trunc(current_date),
        o_movimiento_id  out number
    ) is
        v_empresa_id    erp_stk_movimiento.empresa_id%type;
        v_origen_tabla  erp_stk_movimiento.origen_tabla%type;
    begin
        begin
            select empresa_id, origen_tabla
              into v_empresa_id, v_origen_tabla
              from erp_stk_movimiento
             where movimiento_id = i_movimiento_id;
        exception
            when no_data_found then
                raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'El movimiento indicado no existe.');
        end;
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_MOVIMIENTO_ANULAR', i_empresa_id => v_empresa_id);
        if v_origen_tabla is not null then
            raise_application_error(erp_stk_movimiento_reg.c_err_no_reversable,
                'El movimiento fue generado por un documento: se anula desde ese documento.');
        end if;
        erp_stk_movimiento_reg.generar_reverso(
            i_movimiento_id => i_movimiento_id,
            i_fecha         => i_fecha,
            i_motivo        => i_motivo,
            o_movimiento_id => o_movimiento_id);
    end anular;

    procedure aplicar_reserva (
        i_empresa_id             in number,
        i_deposito_id            in number,
        i_producto_id            in number,
        i_cantidad               in number,
        i_signo                  in number,
        i_lote_id                in number,
        i_deposito_ubicacion_id  in number
    ) is
    begin
        erp_stk_comun_utl.validar_permiso(i_permiso => 'ERP_STK_RESERVA_GESTIONAR', i_empresa_id => i_empresa_id);
        if i_cantidad is null or i_cantidad <= 0 then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'La cantidad debe ser mayor que cero.');
        end if;
        erp_stk_movimiento_reg.aplicar_reserva(
            i_empresa_id => i_empresa_id,
            i_items      => erp_stk_mov_item_tab(
                                erp_stk_mov_item_typ(
                                    deposito_id           => i_deposito_id,
                                    producto_id           => i_producto_id,
                                    cantidad              => 0,
                                    lote_id               => i_lote_id,
                                    deposito_ubicacion_id => i_deposito_ubicacion_id,
                                    reserva               => i_signo * i_cantidad)));
    end aplicar_reserva;

    procedure reservar (
        i_empresa_id             in number,
        i_deposito_id            in number,
        i_producto_id            in number,
        i_cantidad               in number,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    ) is
    begin
        aplicar_reserva(i_empresa_id => i_empresa_id, i_deposito_id => i_deposito_id, i_producto_id => i_producto_id,
                        i_cantidad => i_cantidad, i_signo => 1, i_lote_id => i_lote_id,
                        i_deposito_ubicacion_id => i_deposito_ubicacion_id);
    end reservar;

    procedure liberar_reserva (
        i_empresa_id             in number,
        i_deposito_id            in number,
        i_producto_id            in number,
        i_cantidad               in number,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    ) is
    begin
        aplicar_reserva(i_empresa_id => i_empresa_id, i_deposito_id => i_deposito_id, i_producto_id => i_producto_id,
                        i_cantidad => i_cantidad, i_signo => -1, i_lote_id => i_lote_id,
                        i_deposito_ubicacion_id => i_deposito_ubicacion_id);
    end liberar_reserva;

    function obtener_disponible (
        i_empresa_id             in number,
        i_deposito_id            in number,
        i_producto_id            in number,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    ) return number is
    begin
        return erp_stk_movimiento_reg.calcular_disponible(
                   i_empresa_id            => i_empresa_id,
                   i_deposito_id           => i_deposito_id,
                   i_producto_id           => i_producto_id,
                   i_lote_id               => i_lote_id,
                   i_deposito_ubicacion_id => i_deposito_ubicacion_id);
    end obtener_disponible;

    function obtener_saldo (
        i_empresa_id             in number,
        i_producto_id            in number,
        i_deposito_id            in number default null,
        i_lote_id                in number default null,
        i_deposito_ubicacion_id  in number default null
    ) return number is
        v_saldo  number;
    begin
        select coalesce(sum(cantidad), 0)
          into v_saldo
          from erp_stk_saldo
         where empresa_id  = i_empresa_id
           and producto_id = i_producto_id
           and (i_deposito_id is null or deposito_id = i_deposito_id)
           and (i_lote_id is null or lote_id = i_lote_id)
           and (i_deposito_ubicacion_id is null or deposito_ubicacion_id = i_deposito_ubicacion_id);
        return v_saldo;
    end obtener_saldo;

    function obtener_costo (
        i_empresa_id   in number,
        i_producto_id  in number,
        i_deposito_id  in number   default null,
        i_lote_id      in number   default null,
        i_es_reporte   in varchar2 default 'N'
    ) return number is
        v_costo  number;
    begin
        -- Ponderado por existencia; sin existencia, el último costo conocido.
        select case when sum(greatest(cantidad, 0)) > 0
                    then round(sum(greatest(cantidad, 0) * case when i_es_reporte = 'S' then costo_promedio_reporte else costo_promedio end)
                               / sum(greatest(cantidad, 0)), 6)
                    else max(case when i_es_reporte = 'S' then costo_promedio_reporte else costo_promedio end)
                           keep (dense_rank last order by fecha_ultimo_movimiento nulls first, saldo_id)
               end
          into v_costo
          from erp_stk_saldo
         where empresa_id  = i_empresa_id
           and producto_id = i_producto_id
           and (i_deposito_id is null or deposito_id = i_deposito_id)
           and (i_lote_id is null or lote_id = i_lote_id);
        return coalesce(v_costo, 0);
    end obtener_costo;

end erp_stk_movimiento_api;
/
