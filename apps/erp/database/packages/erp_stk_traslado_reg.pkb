create or replace package body erp_stk_traslado_reg
as

    -- Tipos de movimiento de stock que generan los traslados (erp_stk_tipo_movimiento.codigo)
    c_mov_despacho       constant varchar2(20) := 'TRAS_DESPACHO';
    c_mov_despacho_dev   constant varchar2(20) := 'TRAS_DESP_DEV';
    c_mov_interno        constant varchar2(20) := 'TRAS_INTERNO';
    c_mov_recepcion      constant varchar2(20) := 'TRAS_RECEPCION';
    c_mov_perdida        constant varchar2(20) := 'TRAS_PERDIDA';
    c_mov_devolucion     constant varchar2(20) := 'TRAS_DEVOLUCION';

    -- Eventos del historial
    c_evt_crear      constant varchar2(20) := 'CREAR';
    c_evt_solicitar  constant varchar2(20) := 'SOLICITAR';
    c_evt_aprobar    constant varchar2(20) := 'APROBAR';
    c_evt_rechazar   constant varchar2(20) := 'RECHAZAR';
    c_evt_despachar  constant varchar2(20) := 'DESPACHAR';
    c_evt_recibir    constant varchar2(20) := 'RECIBIR';
    c_evt_resolver   constant varchar2(20) := 'RESOLVER';
    c_evt_anular     constant varchar2(20) := 'ANULAR';
    c_evt_devolver   constant varchar2(20) := 'DEVOLVER';
    c_evt_remision   constant varchar2(20) := 'REMISION';

    c_modulo            constant varchar2(3)  := 'STK';
    c_tabla_origen      constant varchar2(30) := 'erp_stk_traslado';
    c_numerador         constant varchar2(20) := 'TRASLADO';
    c_dep_transito      constant varchar2(1)  := 'T';
    c_accion_despachar  constant varchar2(1)  := 'D';
    c_accion_recibir    constant varchar2(1)  := 'R';
    c_ubi_cuarentena    constant varchar2(20) := 'CUARENTENA';
    c_si                constant varchar2(1)  := 'S';
    c_no                constant varchar2(1)  := 'N';
    c_activo            constant varchar2(1)  := 'A';
    c_rel_devolucion    constant varchar2(1)  := 'D';
    c_rel_complemento   constant varchar2(1)  := 'C';

    type t_deposito is record (
        deposito_id  erp_stk_deposito.deposito_id%type,
        sucursal_id  erp_stk_deposito.sucursal_id%type,
        empresa_id   erp_gen_sucursal.empresa_id%type,
        codigo       erp_stk_deposito.codigo%type,
        tipo         erp_stk_deposito.tipo%type,
        estado       erp_stk_deposito.estado%type,
        direccion    varchar2(400)
    );

    -- ------------------------------------------------------------------ utilitarios

    procedure lanzar (
        i_codigo   in pls_integer,
        i_mensaje  in varchar2
    ) is
    begin
        raise_application_error(i_codigo, i_mensaje);
    end lanzar;

    function obtener_parametro_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number,
        i_defecto     in varchar2
    ) return varchar2 is
    begin
        return erp_gen_parametro_api.obtener_sn(i_codigo => i_codigo, i_empresa_id => i_empresa_id, i_defecto => i_defecto);
    end obtener_parametro_sn;

    function obtener_deposito (
        i_deposito_id  in number
    ) return t_deposito is
        r  t_deposito;
    begin
        select d.deposito_id, d.sucursal_id, s.empresa_id, d.codigo, d.tipo, d.estado, coalesce(d.direccion, s.direccion)
          into r
          from erp_stk_deposito d
          join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
         where d.deposito_id = i_deposito_id;
        return r;
    exception
        when no_data_found then
            lanzar(i_codigo => c_err_depositos, i_mensaje => 'El depósito indicado no existe.');
    end obtener_deposito;

    function bloquear_traslado (
        i_traslado_id  in number
    ) return erp_stk_traslado%rowtype is
    begin
        return erp_stk_traslado_ctr.bloquear(i_traslado_id => i_traslado_id);
    exception
        when no_data_found then
            lanzar(i_codigo => erp_stk_comun_utl.c_err_no_existe, i_mensaje => 'El traslado indicado no existe.');
    end bloquear_traslado;

    function obtener_item (
        i_traslado_item_id  in number
    ) return erp_stk_traslado_item%rowtype is
        r_item  erp_stk_traslado_item%rowtype;
    begin
        select * into r_item from erp_stk_traslado_item where traslado_item_id = i_traslado_item_id;
        return r_item;
    exception
        when no_data_found then
            lanzar(i_codigo => erp_stk_comun_utl.c_err_no_existe, i_mensaje => 'El ítem de traslado indicado no existe.');
    end obtener_item;

    function describir_estado (
        i_estado  in varchar2
    ) return varchar2 is
    begin
        return case i_estado
                   when c_est_borrador    then 'borrador'
                   when c_est_solicitado  then 'solicitado'
                   when c_est_aprobado    then 'aprobado'
                   when c_est_transito    then 'en tránsito'
                   when c_est_parcial     then 'recibido parcialmente'
                   when c_est_diferencias then 'con diferencias'
                   when c_est_completado  then 'completado'
                   when c_est_rechazado   then 'rechazado'
                   when c_est_anulado     then 'anulado'
               end;
    end describir_estado;

    -- i_permitidos: estados admitidos concatenados (ej. 'BSP').
    procedure validar_estado (
        i_traslado    in erp_stk_traslado%rowtype,
        i_permitidos  in varchar2,
        i_accion      in varchar2
    ) is
    begin
        if instr(i_permitidos, i_traslado.estado) = 0 then
            lanzar(i_codigo  => c_err_estado,
                   i_mensaje => 'No se puede ' || i_accion || ' un traslado ' || describir_estado(i_estado => i_traslado.estado) || '.');
        end if;
    end validar_estado;

    -- El traslado solo se edita en borrador (RN-16).
    procedure validar_editable (
        i_traslado  in erp_stk_traslado%rowtype
    ) is
    begin
        if i_traslado.estado <> c_est_borrador then
            lanzar(i_codigo  => c_err_inmutable,
                   i_mensaje => 'El traslado está ' || describir_estado(i_estado => i_traslado.estado)
                                || ': ya no se pueden modificar sus datos ni sus ítems.');
        end if;
    end validar_editable;

    procedure registrar_evento (
        i_traslado_id      in number,
        i_evento           in varchar2,
        i_estado_anterior  in varchar2,
        i_estado_nuevo     in varchar2,
        i_movimiento_id    in number   default null,
        i_detalle          in varchar2 default null
    ) is
        r_evento  erp_stk_traslado_evento%rowtype;
        v_id      number;
    begin
        r_evento.traslado_id     := i_traslado_id;
        r_evento.evento          := i_evento;
        r_evento.estado_anterior := i_estado_anterior;
        r_evento.estado_nuevo    := i_estado_nuevo;
        r_evento.usuario         := erp_stk_comun_utl.obtener_usuario_auditoria;
        r_evento.movimiento_id   := i_movimiento_id;
        r_evento.detalle         := i_detalle;
        erp_stk_traslado_evento_ctr.insertar(i_evento => r_evento, o_traslado_evento_id => v_id);
    end registrar_evento;

    function armar_detalle (
        i_clave  in varchar2,
        i_valor  in varchar2
    ) return varchar2 is
        v_objeto  json_object_t := json_object_t();
    begin
        v_objeto.put(i_clave, i_valor);
        return v_objeto.to_string;
    end armar_detalle;

    -- ------------------------------------------------------------------ acceso (RN-12)

    function tiene_acceso (
        i_deposito  in t_deposito,
        i_accion    in varchar2
    ) return boolean is
        v_usuario     varchar2(255) := erp_stk_comun_utl.obtener_usuario;
        v_usuario_id  number;
        v_filas       pls_integer;
        v_coincide    pls_integer;
    begin
        if v_usuario is null or adm_seg_seguridad_reg.es_superadmin(i_username => v_usuario) then
            return true;
        end if;
        begin
            select usuario_id into v_usuario_id from adm_seg_usuario where username = upper(v_usuario);
        exception
            when no_data_found then
                return false;
        end;

        -- 1) Restricción fina por depósito, si el usuario tiene alguna en la empresa
        select count(*),
               count(case when ud.deposito_id = i_deposito.deposito_id
                           and ((i_accion = c_accion_despachar and ud.es_despachador = c_si)
                             or (i_accion = c_accion_recibir   and ud.es_receptor    = c_si)) then 1 end)
          into v_filas, v_coincide
          from erp_stk_usuario_deposito ud
          join erp_stk_deposito d on d.deposito_id = ud.deposito_id
          join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
         where ud.usuario_id = v_usuario_id
           and ud.estado     = c_activo
           and s.empresa_id  = i_deposito.empresa_id;
        if v_filas > 0 then
            return v_coincide > 0;
        end if;

        -- 2) Sucursales asignadas al usuario
        select count(*), count(case when us.sucursal_id = i_deposito.sucursal_id then 1 end)
          into v_filas, v_coincide
          from erp_gen_usuario_sucursal us
          join erp_gen_sucursal s on s.sucursal_id = us.sucursal_id
         where us.usuario_id = v_usuario_id
           and us.estado     = c_activo
           and s.empresa_id  = i_deposito.empresa_id;
        if v_filas > 0 then
            return v_coincide > 0;
        end if;

        -- 3) Sin asignaciones: opera todas, salvo acceso estricto
        return obtener_parametro_sn(i_codigo => 'ERP_GEN_ACCESO_SUCURSAL_ESTRICTO',
                                    i_empresa_id => i_deposito.empresa_id, i_defecto => c_no) = c_no;
    end tiene_acceso;

    procedure validar_acceso (
        i_deposito_id  in number,
        i_accion       in varchar2
    ) is
        r_deposito  t_deposito := obtener_deposito(i_deposito_id => i_deposito_id);
    begin
        if not tiene_acceso(i_deposito => r_deposito, i_accion => i_accion) then
            lanzar(i_codigo  => c_err_acceso,
                   i_mensaje => 'No tiene acceso para ' || case i_accion when c_accion_despachar then 'despachar desde' else 'recibir en' end
                                || ' el depósito ' || r_deposito.codigo || '.');
        end if;
    end validar_acceso;

    -- ------------------------------------------------------------------ ítems

    function buscar_item (
        i_items             in erp_stk_tras_item_tab,
        i_traslado_item_id  in number
    ) return erp_stk_tras_item_typ is
    begin
        if i_items is not null then
            for i in 1 .. i_items.count loop
                if i_items(i).traslado_item_id = i_traslado_item_id then
                    return i_items(i);
                end if;
            end loop;
        end if;
        return null;
    end buscar_item;

    -- Todos los ítems recibidos deben ser del traslado.
    procedure validar_items_del_traslado (
        i_traslado_id  in number,
        i_items        in erp_stk_tras_item_tab
    ) is
        v_cantidad  pls_integer;
    begin
        if i_items is null then
            return;
        end if;
        for i in 1 .. i_items.count loop
            select count(*) into v_cantidad
              from erp_stk_traslado_item
             where traslado_item_id = i_items(i).traslado_item_id
               and traslado_id      = i_traslado_id;
            if v_cantidad = 0 then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Una de las líneas indicadas no pertenece al traslado.');
            end if;
        end loop;
    end validar_items_del_traslado;

    procedure insertar_item (
        i_traslado          in  erp_stk_traslado%rowtype,
        i_item              in  erp_stk_tras_item_typ,
        o_traslado_item_id  out number
    ) is
        r_item        erp_stk_traslado_item%rowtype;
        v_empresa_id  number;
        v_estado      varchar2(1);
        v_tipo        varchar2(1);
        v_codigo      erp_stk_producto.codigo%type;
        v_lote_ok     pls_integer;
    begin
        begin
            select empresa_id, estado, tipo, codigo
              into v_empresa_id, v_estado, v_tipo, v_codigo
              from erp_stk_producto
             where producto_id = i_item.producto_id;
        exception
            when no_data_found then
                lanzar(i_codigo => erp_stk_movimiento_reg.c_err_producto_invalido, i_mensaje => 'El producto indicado no existe.');
        end;
        if v_empresa_id <> i_traslado.empresa_id or v_estado <> c_activo or v_tipo not in ('B', 'P') then
            lanzar(i_codigo  => erp_stk_movimiento_reg.c_err_producto_invalido,
                   i_mensaje => 'El producto ' || v_codigo || ' no se puede trasladar (inactivo, de otra empresa o sin stock).');
        end if;
        if i_item.cantidad is null or i_item.cantidad <= 0 then
            lanzar(i_codigo => c_err_cantidad, i_mensaje => 'La cantidad del producto ' || v_codigo || ' debe ser mayor que cero.');
        end if;
        if i_item.lote_id is not null then
            select count(*) into v_lote_ok
              from erp_stk_lote
             where lote_id = i_item.lote_id and producto_id = i_item.producto_id;
            if v_lote_ok = 0 then
                lanzar(i_codigo  => erp_stk_movimiento_reg.c_err_lote_invalido,
                       i_mensaje => 'El lote indicado no corresponde al producto ' || v_codigo || '.');
            end if;
        end if;

        select coalesce(max(linea), 0) + 1 into r_item.linea
          from erp_stk_traslado_item
         where traslado_id = i_traslado.traslado_id;
        r_item.traslado_id                  := i_traslado.traslado_id;
        r_item.producto_id                  := i_item.producto_id;
        r_item.lote_id                      := i_item.lote_id;
        r_item.deposito_ubicacion_id_origen := i_item.deposito_ubicacion_id;
        r_item.cantidad_solicitada          := i_item.cantidad;
        r_item.observacion                  := i_item.observacion;
        erp_stk_traslado_item_ctr.insertar(i_item => r_item, o_traslado_item_id => o_traslado_item_id);
    end insertar_item;

    -- Numera, inserta la cabecera y registra el evento de creación.
    procedure insertar_cabecera (
        io_traslado  in out nocopy erp_stk_traslado%rowtype
    ) is
    begin
        erp_stk_numerador_ctr.actualizar_siguiente(
            i_empresa_id  => io_traslado.empresa_id,
            i_sucursal_id => io_traslado.sucursal_id,
            i_codigo      => c_numerador,
            o_numero      => io_traslado.numero);
        erp_stk_traslado_ctr.insertar(i_traslado => io_traslado, o_traslado_id => io_traslado.traslado_id);
        registrar_evento(i_traslado_id => io_traslado.traslado_id, i_evento => c_evt_crear,
                         i_estado_anterior => null, i_estado_nuevo => io_traslado.estado);
    end insertar_cabecera;

    function obtener_deposito_transito (
        i_sucursal_id  in number
    ) return number is
        v_deposito_id  number;
    begin
        select min(deposito_id)
          into v_deposito_id
          from erp_stk_deposito
         where sucursal_id = i_sucursal_id
           and tipo        = c_dep_transito
           and estado      = c_activo;
        if v_deposito_id is null then
            lanzar(i_codigo => c_err_depositos, i_mensaje => 'La sucursal de origen no tiene un depósito de tránsito activo.');
        end if;
        return v_deposito_id;
    end obtener_deposito_transito;

    -- Estado de un traslado despachado según lo pendiente y los faltantes declarados.
    function calcular_estado (
        i_traslado_id  in number
    ) return varchar2 is
        v_pendiente  number;
        v_faltante   number;
        v_avance     number;
    begin
        select coalesce(sum(cantidad_despachada - cantidad_recibida - cantidad_averiada - cantidad_perdida - cantidad_devuelta), 0),
               coalesce(sum(cantidad_faltante), 0),
               coalesce(sum(cantidad_recibida + cantidad_averiada + cantidad_perdida + cantidad_devuelta), 0)
          into v_pendiente, v_faltante, v_avance
          from erp_stk_traslado_item
         where traslado_id = i_traslado_id;
        return case
                   when v_pendiente = 0 then c_est_completado
                   when v_faltante > 0 and v_faltante = v_pendiente then c_est_diferencias
                   when v_avance > 0 or v_faltante > 0 then c_est_parcial
                   else c_est_transito
               end;
    end calcular_estado;

    procedure liberar_reservas (
        i_traslado  in erp_stk_traslado%rowtype
    ) is
        t_items  erp_stk_mov_item_tab := erp_stk_mov_item_tab();
    begin
        for r in (select producto_id, lote_id, deposito_ubicacion_id_origen, cantidad_aprobada
                    from erp_stk_traslado_item
                   where traslado_id = i_traslado.traslado_id
                     and cantidad_aprobada > 0) loop
            t_items.extend;
            t_items(t_items.count) := erp_stk_mov_item_typ(
                                          deposito_id           => i_traslado.deposito_id_origen,
                                          producto_id           => r.producto_id,
                                          cantidad              => 0,
                                          lote_id               => r.lote_id,
                                          deposito_ubicacion_id => r.deposito_ubicacion_id_origen,
                                          reserva               => -r.cantidad_aprobada);
        end loop;
        erp_stk_movimiento_reg.aplicar_reserva(i_empresa_id => i_traslado.empresa_id, i_items => t_items);
    end liberar_reservas;

    -- ------------------------------------------------------------------ creación y edición

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
    ) is
        r_origen    t_deposito;
        r_destino   t_deposito;
        r_traslado  erp_stk_traslado%rowtype;
        r_motivo    erp_stk_motivo_traslado%rowtype;
        v_item_id   number;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            -- RN-01
            if i_deposito_id_origen = i_deposito_id_destino then
                lanzar(i_codigo => c_err_depositos, i_mensaje => 'El depósito de origen y el de destino deben ser distintos.');
            end if;
            r_origen  := obtener_deposito(i_deposito_id => i_deposito_id_origen);
            r_destino := obtener_deposito(i_deposito_id => i_deposito_id_destino);
            if r_origen.empresa_id <> i_empresa_id or r_destino.empresa_id <> i_empresa_id then
                lanzar(i_codigo => c_err_depositos, i_mensaje => 'Los depósitos de origen y destino deben ser de la empresa.');
            end if;
            if r_origen.estado <> c_activo or r_destino.estado <> c_activo then
                lanzar(i_codigo => c_err_depositos, i_mensaje => 'Los depósitos de origen y destino deben estar activos.');
            end if;
            if r_origen.tipo = c_dep_transito or r_destino.tipo = c_dep_transito then
                lanzar(i_codigo => c_err_depositos, i_mensaje => 'Un depósito de tránsito no puede ser origen ni destino de un traslado.');
            end if;
            if not tiene_acceso(i_deposito => r_origen, i_accion => c_accion_despachar)
               and not tiene_acceso(i_deposito => r_destino, i_accion => c_accion_recibir) then
                lanzar(i_codigo => c_err_acceso, i_mensaje => 'No tiene acceso al depósito de origen ni al de destino.');
            end if;

            -- RN-02: tipo de traslado
            r_traslado.tipo := upper(i_tipo);
            if r_traslado.tipo is null then
                r_traslado.tipo := case
                                       when i_persona_id_destino is not null then c_tipo_tercero
                                       when r_origen.sucursal_id = r_destino.sucursal_id
                                            and coalesce(r_origen.direccion, '-') = coalesce(r_destino.direccion, '-') then c_tipo_interno
                                       else c_tipo_remision
                                   end;
            end if;
            if r_traslado.tipo not in (c_tipo_interno, c_tipo_remision, c_tipo_tercero) then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'El tipo de traslado debe ser I, R o T.');
            end if;
            if r_traslado.tipo = c_tipo_interno and r_origen.sucursal_id <> r_destino.sucursal_id then
                lanzar(i_codigo => c_err_depositos, i_mensaje => 'Un traslado interno es entre depósitos de la misma sucursal; entre sucursales lleva remisión.');
            end if;
            if r_traslado.tipo = c_tipo_tercero and i_persona_id_destino is null then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Un traslado a terceros necesita la persona que recibe.');
            end if;

            -- Motivo
            begin
                select *
                  into r_motivo
                  from erp_stk_motivo_traslado
                 where codigo = upper(coalesce(i_motivo, case r_traslado.tipo
                                                             when c_tipo_interno  then 'INTERNO'
                                                             when c_tipo_remision then 'ENTRE_LOCALES'
                                                         end))
                   and estado = c_activo;
            exception
                when no_data_found then
                    lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Indique un motivo de traslado válido.');
            end;
            if (r_traslado.tipo = c_tipo_interno and r_motivo.es_tipo_interno = c_no)
               or (r_traslado.tipo = c_tipo_remision and r_motivo.es_tipo_remision = c_no)
               or (r_traslado.tipo = c_tipo_tercero and r_motivo.es_tipo_tercero = c_no) then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido,
                       i_mensaje => 'El motivo "' || r_motivo.nombre || '" no corresponde a este tipo de traslado.');
            end if;

            -- Un paso (solo internos y si el parámetro lo permite)
            r_traslado.es_un_paso := coalesce(upper(i_es_un_paso), c_no);
            if r_traslado.es_un_paso = c_si then
                if r_traslado.tipo <> c_tipo_interno then
                    lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Solo los traslados internos pueden ser de un paso.');
                end if;
                if obtener_parametro_sn(i_codigo => 'ERP_STK_TRASLADO_UN_PASO', i_empresa_id => i_empresa_id, i_defecto => c_si) = c_no then
                    lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'La empresa no permite traslados internos de un paso.');
                end if;
            else
                r_traslado.deposito_id_transito := obtener_deposito_transito(i_sucursal_id => r_origen.sucursal_id);
            end if;

            -- Flete (funcionalidad FLETE)
            if coalesce(i_monto_flete, 0) < 0 then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'El flete no puede ser negativo.');
            end if;
            if coalesce(i_monto_flete, 0) > 0
               and erp_gen_funcionalidad_api.es_activa_sn(i_codigo => 'FLETE', i_empresa_id => i_empresa_id) = c_no then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'La empresa no tiene activa la funcionalidad de fletes.');
            end if;

            -- Fechas (RN-10) y ruta sugerida
            r_traslado.fecha_emision         := trunc(coalesce(i_fecha_emision, current_date));
            r_traslado.fecha_requerida       := trunc(i_fecha_requerida);
            r_traslado.fecha_salida_estimada := i_fecha_salida_estimada;
            if r_traslado.fecha_salida_estimada < r_traslado.fecha_emision then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'La salida estimada no puede ser anterior a la fecha del traslado.');
            end if;
            if r_origen.sucursal_id <> r_destino.sucursal_id then
                begin
                    select kilometros, horas_estimadas
                      into r_traslado.kilometros, r_traslado.horas_estimadas
                      from erp_stk_ruta_traslado
                     where empresa_id          = i_empresa_id
                       and sucursal_id_origen  = r_origen.sucursal_id
                       and sucursal_id_destino = r_destino.sucursal_id
                       and estado              = c_activo;
                exception
                    when no_data_found then
                        null;
                end;
            end if;
            if r_traslado.fecha_salida_estimada is not null then
                r_traslado.fecha_llegada_estimada := r_traslado.fecha_salida_estimada
                                                     + numtodsinterval(coalesce(r_traslado.horas_estimadas, 0), 'HOUR');
            end if;

            r_traslado.empresa_id             := i_empresa_id;
            r_traslado.sucursal_id            := r_origen.sucursal_id;
            r_traslado.motivo_traslado_id     := r_motivo.motivo_traslado_id;
            r_traslado.deposito_id_origen     := i_deposito_id_origen;
            r_traslado.deposito_id_destino    := i_deposito_id_destino;
            r_traslado.persona_id_destino     := i_persona_id_destino;
            r_traslado.monto_flete            := coalesce(i_monto_flete, 0);
            r_traslado.es_flete_capitalizable := coalesce(upper(i_es_flete_capitalizable), c_no);
            r_traslado.remision_estado        := c_rem_no_aplica;
            r_traslado.observacion            := i_observacion;
            r_traslado.estado                 := c_est_borrador;
            r_traslado.creado_por             := erp_stk_comun_utl.obtener_usuario_auditoria;
            insertar_cabecera(io_traslado => r_traslado);
            o_traslado_id := r_traslado.traslado_id;

            if i_items is not null then
                for i in 1 .. i_items.count loop
                    insertar_item(i_traslado => r_traslado, i_item => i_items(i), o_traslado_item_id => v_item_id);
                end loop;
            end if;
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end generar;

    procedure aplicar_modificacion (
        i_traslado_id             in number,
        i_fecha_requerida         in date,
        i_fecha_salida_estimada   in timestamp with local time zone,
        i_monto_flete             in number,
        i_es_flete_capitalizable  in varchar2,
        i_observacion             in varchar2
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_editable(i_traslado => r_traslado);
            if i_fecha_salida_estimada < r_traslado.fecha_emision then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'La salida estimada no puede ser anterior a la fecha del traslado.');
            end if;
            if coalesce(i_monto_flete, 0) > 0
               and erp_gen_funcionalidad_api.es_activa_sn(i_codigo => 'FLETE', i_empresa_id => r_traslado.empresa_id) = c_no then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'La empresa no tiene activa la funcionalidad de fletes.');
            end if;
            r_traslado.fecha_requerida        := trunc(i_fecha_requerida);
            r_traslado.fecha_salida_estimada  := i_fecha_salida_estimada;
            r_traslado.fecha_llegada_estimada := i_fecha_salida_estimada + numtodsinterval(coalesce(r_traslado.horas_estimadas, 0), 'HOUR');
            r_traslado.monto_flete            := coalesce(i_monto_flete, 0);
            r_traslado.es_flete_capitalizable := coalesce(upper(i_es_flete_capitalizable), c_no);
            r_traslado.observacion            := i_observacion;
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_modificacion;

    procedure aplicar_item (
        i_traslado_id       in  number,
        i_item              in  erp_stk_tras_item_typ,
        o_traslado_item_id  out number
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_editable(i_traslado => r_traslado);
            insertar_item(i_traslado => r_traslado, i_item => i_item, o_traslado_item_id => o_traslado_item_id);
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_item;

    procedure aplicar_quita_item (
        i_traslado_item_id  in number
    ) is
        r_item      erp_stk_traslado_item%rowtype := obtener_item(i_traslado_item_id => i_traslado_item_id);
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => r_item.traslado_id);
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_editable(i_traslado => r_traslado);
            erp_stk_traslado_item_ctr.eliminar(i_traslado_item_id => i_traslado_item_id);
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_quita_item;

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
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
        r_vehiculo  erp_stk_vehiculo%rowtype;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            if r_traslado.estado not in (c_est_borrador, c_est_solicitado, c_est_aprobado) then
                validar_editable(i_traslado => r_traslado);
            end if;
            if i_vehiculo_id is not null then
                begin
                    select * into r_vehiculo from erp_stk_vehiculo where vehiculo_id = i_vehiculo_id;
                exception
                    when no_data_found then
                        lanzar(i_codigo => c_err_transporte, i_mensaje => 'El vehículo indicado no existe.');
                end;
                if r_vehiculo.empresa_id <> r_traslado.empresa_id or r_vehiculo.estado <> c_activo then
                    lanzar(i_codigo => c_err_transporte, i_mensaje => 'El vehículo ' || r_vehiculo.chapa || ' está inactivo o es de otra empresa.');
                end if;
            end if;
            r_traslado.vehiculo_id              := i_vehiculo_id;
            r_traslado.persona_id_conductor     := coalesce(i_persona_id_conductor, r_vehiculo.persona_id_conductor);
            r_traslado.persona_id_transportista := coalesce(i_persona_id_transportista, r_vehiculo.persona_id_transportista);
            -- El vehículo genérico no tiene chapa propia: se carga la real en cada traslado.
            r_traslado.vehiculo_chapa           := upper(trim(case when r_vehiculo.es_generico = c_no then r_vehiculo.chapa else i_vehiculo_chapa end));
            r_traslado.vehiculo_marca           := r_vehiculo.marca;
            r_traslado.vehiculo_tipo            := r_vehiculo.tipo;
            r_traslado.tipo_transporte          := upper(i_tipo_transporte);
            r_traslado.modalidad_transporte     := coalesce(upper(i_modalidad_transporte), r_traslado.modalidad_transporte);
            r_traslado.responsable_emision      := i_responsable_emision;
            r_traslado.punto_expedicion_id      := i_punto_expedicion_id;
            r_traslado.kilometros               := coalesce(i_kilometros, r_traslado.kilometros);
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_transporte;

    -- ------------------------------------------------------------------ solicitud y aprobación

    procedure aprobar_interno (
        io_traslado    in out nocopy erp_stk_traslado%rowtype,
        i_items        in erp_stk_tras_item_tab,
        i_automatica   in boolean
    ) is
        t_reservas   erp_stk_mov_item_tab := erp_stk_mov_item_tab();
        r_item       erp_stk_traslado_item%rowtype;
        r_indicado   erp_stk_tras_item_typ;
        v_anterior   varchar2(1) := io_traslado.estado;
        v_total      number := 0;
    begin
        validar_items_del_traslado(i_traslado_id => io_traslado.traslado_id, i_items => i_items);
        for r in (select traslado_item_id from erp_stk_traslado_item where traslado_id = io_traslado.traslado_id order by linea) loop
            r_item     := obtener_item(i_traslado_item_id => r.traslado_item_id);
            r_indicado := buscar_item(i_items => i_items, i_traslado_item_id => r.traslado_item_id);
            r_item.cantidad_aprobada := case when r_indicado is null then r_item.cantidad_solicitada else coalesce(r_indicado.cantidad, 0) end;
            if r_item.cantidad_aprobada < 0 or r_item.cantidad_aprobada > r_item.cantidad_solicitada then
                lanzar(i_codigo => c_err_cantidad, i_mensaje => 'La cantidad aprobada de la línea ' || r_item.linea || ' debe estar entre 0 y lo solicitado.');
            end if;
            v_total := v_total + r_item.cantidad_aprobada;
            erp_stk_traslado_item_ctr.actualizar(i_item => r_item);
            if r_item.cantidad_aprobada > 0 then
                t_reservas.extend;
                t_reservas(t_reservas.count) := erp_stk_mov_item_typ(
                                                    deposito_id           => io_traslado.deposito_id_origen,
                                                    producto_id           => r_item.producto_id,
                                                    cantidad              => 0,
                                                    lote_id               => r_item.lote_id,
                                                    deposito_ubicacion_id => r_item.deposito_ubicacion_id_origen,
                                                    reserva               => r_item.cantidad_aprobada);
            end if;
        end loop;
        if v_total = 0 then
            lanzar(i_codigo => c_err_cantidad, i_mensaje => 'No hay cantidades para aprobar.');
        end if;

        -- RN-03: la reserva falla si el depósito controla stock y no alcanza el disponible
        erp_stk_movimiento_reg.aplicar_reserva(i_empresa_id => io_traslado.empresa_id, i_items => t_reservas);

        io_traslado.estado           := c_est_aprobado;
        io_traslado.usuario_aprueba  := erp_stk_comun_utl.obtener_usuario_auditoria;
        io_traslado.fecha_aprobacion := systimestamp;
        erp_stk_traslado_ctr.actualizar(i_traslado => io_traslado);
        registrar_evento(i_traslado_id => io_traslado.traslado_id, i_evento => c_evt_aprobar,
                         i_estado_anterior => v_anterior, i_estado_nuevo => io_traslado.estado,
                         i_detalle => armar_detalle(i_clave => 'automatica', i_valor => case when i_automatica then c_si else c_no end));
    end aprobar_interno;

    procedure aplicar_solicitud (
        i_traslado_id  in number
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
        v_cantidad  pls_integer;
        v_codigo    erp_stk_producto.codigo%type;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_estado(i_traslado => r_traslado, i_permitidos => c_est_borrador, i_accion => 'solicitar');
            select count(*), min(case when (p.tiene_lote = c_si or p.tiene_serie = c_si) and i.lote_id is null then p.codigo end)
              into v_cantidad, v_codigo
              from erp_stk_traslado_item i
              join erp_stk_producto p on p.producto_id = i.producto_id
             where i.traslado_id = i_traslado_id;
            if v_cantidad = 0 then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'El traslado no tiene ítems.');
            end if;
            if v_codigo is not null then
                lanzar(i_codigo => erp_stk_movimiento_reg.c_err_lote_invalido,
                       i_mensaje => 'El producto ' || v_codigo || ' exige indicar el lote o la serie a trasladar.');
            end if;

            r_traslado.estado           := c_est_solicitado;
            r_traslado.usuario_solicita := erp_stk_comun_utl.obtener_usuario_auditoria;
            r_traslado.fecha_solicitud  := systimestamp;
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_solicitar,
                             i_estado_anterior => c_est_borrador, i_estado_nuevo => c_est_solicitado);

            if obtener_parametro_sn(i_codigo => 'ERP_STK_TRASLADO_APROBACION', i_empresa_id => r_traslado.empresa_id, i_defecto => c_si) = c_no then
                aprobar_interno(io_traslado => r_traslado, i_items => null, i_automatica => true);
            end if;
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_solicitud;

    procedure aplicar_aprobacion (
        i_traslado_id  in number,
        i_items        in erp_stk_tras_item_tab default null
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_estado(i_traslado => r_traslado, i_permitidos => c_est_solicitado, i_accion => 'aprobar');
            aprobar_interno(io_traslado => r_traslado, i_items => i_items, i_automatica => false);
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_aprobacion;

    procedure aplicar_rechazo (
        i_traslado_id  in number,
        i_motivo       in varchar2
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
        v_anterior  varchar2(1) := r_traslado.estado;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_estado(i_traslado => r_traslado, i_permitidos => c_est_solicitado || c_est_aprobado, i_accion => 'rechazar');
            if trim(i_motivo) is null then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Indique el motivo del rechazo.');
            end if;
            if r_traslado.estado = c_est_aprobado then
                liberar_reservas(i_traslado => r_traslado);
            end if;
            r_traslado.estado           := c_est_rechazado;
            r_traslado.motivo_rechazo   := trim(i_motivo);
            r_traslado.usuario_aprueba  := erp_stk_comun_utl.obtener_usuario_auditoria;
            r_traslado.fecha_aprobacion := systimestamp;
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_rechazar,
                             i_estado_anterior => v_anterior, i_estado_nuevo => c_est_rechazado,
                             i_detalle => armar_detalle(i_clave => 'motivo', i_valor => trim(i_motivo)));
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_rechazo;

    -- ------------------------------------------------------------------ despacho

    procedure aplicar_despacho (
        i_traslado_id              in  number,
        i_items                    in  erp_stk_tras_item_tab default null,
        i_fecha                    in  timestamp with local time zone default null,
        i_debe_crear_complemento   in  varchar2 default 'N',
        o_traslado_id_complemento  out number
    ) is
        r_traslado     erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
        r_item         erp_stk_traslado_item%rowtype;
        r_indicado     erp_stk_tras_item_typ;
        r_hijo         erp_stk_traslado%rowtype;
        t_lineas       erp_stk_mov_item_tab := erp_stk_mov_item_tab();
        v_fecha        timestamp with local time zone := coalesce(i_fecha, systimestamp);
        v_cantidad     number;
        v_total        number := 0;
        v_valor_total  number := 0;
        v_movimiento   number;
        v_es_dev       boolean := coalesce(r_traslado.relacion, '-') = c_rel_devolucion;
        v_item_id      number;
        v_destino_dep  number := case when r_traslado.es_un_paso = c_si then r_traslado.deposito_id_destino
                                      else r_traslado.deposito_id_transito end;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_estado(i_traslado => r_traslado, i_permitidos => c_est_aprobado, i_accion => 'despachar');
            validar_acceso(i_deposito_id => r_traslado.deposito_id_origen, i_accion => c_accion_despachar);
            validar_items_del_traslado(i_traslado_id => i_traslado_id, i_items => i_items);

            -- RN-09: datos mínimos de transporte cuando lleva remisión
            if r_traslado.tipo in (c_tipo_remision, c_tipo_tercero) then
                if r_traslado.vehiculo_id is not null and r_traslado.vehiculo_chapa is null then
                    select max(case when es_generico = c_no then chapa end), max(marca), max(tipo)
                      into r_traslado.vehiculo_chapa, r_traslado.vehiculo_marca, r_traslado.vehiculo_tipo
                      from erp_stk_vehiculo
                     where vehiculo_id = r_traslado.vehiculo_id;
                end if;
                if r_traslado.persona_id_conductor is null or r_traslado.vehiculo_chapa is null then
                    lanzar(i_codigo => c_err_transporte,
                           i_mensaje => 'Para despachar con nota de remisión indique el conductor y la chapa del vehículo.');
                end if;
                select max(razon_social), max(nro_documento)
                  into r_traslado.conductor_nombre, r_traslado.conductor_documento
                  from erp_gen_persona
                 where persona_id = r_traslado.persona_id_conductor;
            end if;

            -- Líneas del movimiento: sale del origen (libera la reserva) y entra al tránsito al mismo costo
            for r in (select traslado_item_id from erp_stk_traslado_item where traslado_id = i_traslado_id order by linea) loop
                r_item     := obtener_item(i_traslado_item_id => r.traslado_item_id);
                r_indicado := buscar_item(i_items => i_items, i_traslado_item_id => r.traslado_item_id);
                v_cantidad := case when r_indicado is null then r_item.cantidad_aprobada else coalesce(r_indicado.cantidad, 0) end;
                if v_cantidad < 0 or v_cantidad > r_item.cantidad_aprobada then
                    lanzar(i_codigo => c_err_cantidad,
                           i_mensaje => 'La cantidad despachada de la línea ' || r_item.linea || ' no puede superar lo aprobado.');
                end if;
                v_total := v_total + v_cantidad;
                if v_cantidad > 0 or r_item.cantidad_aprobada > 0 then
                    t_lineas.extend;
                    t_lineas(t_lineas.count) := erp_stk_mov_item_typ(
                                                    deposito_id           => r_traslado.deposito_id_origen,
                                                    producto_id           => r_item.producto_id,
                                                    cantidad              => -v_cantidad,
                                                    lote_id               => r_item.lote_id,
                                                    deposito_ubicacion_id => r_item.deposito_ubicacion_id_origen,
                                                    reserva               => -r_item.cantidad_aprobada,
                                                    origen_linea_id       => r_item.traslado_item_id);
                end if;
                if v_cantidad > 0 then
                    t_lineas.extend;
                    t_lineas(t_lineas.count) := erp_stk_mov_item_typ(
                                                    deposito_id           => v_destino_dep,
                                                    producto_id           => r_item.producto_id,
                                                    cantidad              => v_cantidad,
                                                    lote_id               => r_item.lote_id,
                                                    deposito_ubicacion_id => case when r_traslado.es_un_paso = c_si
                                                                                  then r_item.deposito_ubicacion_id_destino end,
                                                    linea_costo           => t_lineas.count - 1,
                                                    origen_linea_id       => r_item.traslado_item_id);
                end if;
                r_item.cantidad_despachada := v_cantidad;
                if r_traslado.es_un_paso = c_si then
                    r_item.cantidad_recibida := v_cantidad;
                end if;
                erp_stk_traslado_item_ctr.actualizar(i_item => r_item);
            end loop;
            if v_total = 0 then
                lanzar(i_codigo => c_err_cantidad, i_mensaje => 'No hay cantidades para despachar.');
            end if;

            erp_stk_movimiento_reg.generar(
                i_empresa_id      => r_traslado.empresa_id,
                i_tipo_movimiento => case when r_traslado.es_un_paso = c_si then c_mov_interno
                                          when v_es_dev then c_mov_despacho_dev
                                          else c_mov_despacho end,
                i_fecha           => cast(v_fecha as date),
                i_items           => t_lineas,
                i_origen_modulo   => c_modulo,
                i_origen_tabla    => c_tabla_origen,
                i_origen_id       => i_traslado_id,
                o_movimiento_id   => v_movimiento);

            -- Costo con que salió cada ítem (RN-07) y prorrateo del flete capitalizable (RN-08)
            for r in (select origen_linea_id, costo_unitario, costo_unitario_reporte, -cantidad cantidad
                        from erp_stk_movimiento_item
                       where movimiento_id = v_movimiento
                         and cantidad < 0) loop
                r_item := obtener_item(i_traslado_item_id => r.origen_linea_id);
                r_item.costo_unitario         := r.costo_unitario;
                r_item.costo_unitario_reporte := r.costo_unitario_reporte;
                erp_stk_traslado_item_ctr.actualizar(i_item => r_item);
                v_valor_total := v_valor_total + r.cantidad * r.costo_unitario;
            end loop;
            if r_traslado.es_flete_capitalizable = c_si and r_traslado.monto_flete > 0 and r_traslado.es_un_paso = c_no then
                for r in (select traslado_item_id from erp_stk_traslado_item
                           where traslado_id = i_traslado_id and cantidad_despachada > 0) loop
                    r_item := obtener_item(i_traslado_item_id => r.traslado_item_id);
                    -- Por valor; si la mercadería no tiene costo, por cantidad
                    r_item.flete_unitario := round(case when v_valor_total > 0
                                                        then r_traslado.monto_flete * r_item.costo_unitario / v_valor_total
                                                        else r_traslado.monto_flete / v_total end, 6);
                    r_item.flete_unitario_reporte := round(case when r_item.costo_unitario > 0
                                                                then r_item.flete_unitario * r_item.costo_unitario_reporte / r_item.costo_unitario
                                                                else 0 end, 6);
                    erp_stk_traslado_item_ctr.actualizar(i_item => r_item);
                end loop;
            end if;

            r_traslado.movimiento_id_despacho := v_movimiento;
            r_traslado.usuario_despacha       := erp_stk_comun_utl.obtener_usuario_auditoria;
            r_traslado.fecha_salida_real      := v_fecha;
            r_traslado.fecha_llegada_estimada := greatest(coalesce(r_traslado.fecha_llegada_estimada, v_fecha),
                                                          v_fecha + numtodsinterval(coalesce(r_traslado.horas_estimadas, 0), 'HOUR'));
            if r_traslado.es_un_paso = c_si then
                r_traslado.estado             := c_est_completado;
                r_traslado.fecha_llegada_real := v_fecha;
            else
                r_traslado.estado := c_est_transito;
            end if;
            -- Punto de integración: el módulo de documentos emite la nota de remisión de los
            -- traslados con remision_estado = P y la informa con erp_stk_traslado_api.asignar_remision.
            if r_traslado.tipo in (c_tipo_remision, c_tipo_tercero) then
                r_traslado.remision_estado := c_rem_pendiente;
            end if;
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_despachar,
                             i_estado_anterior => c_est_aprobado, i_estado_nuevo => r_traslado.estado,
                             i_movimiento_id => v_movimiento);

            -- RF-04: lo no despachado pasa a un traslado complementario en borrador
            if upper(i_debe_crear_complemento) = c_si then
                for r in (select producto_id, lote_id, deposito_ubicacion_id_origen, cantidad_aprobada - cantidad_despachada cantidad
                            from erp_stk_traslado_item
                           where traslado_id = i_traslado_id
                             and cantidad_aprobada > cantidad_despachada
                           order by linea) loop
                    if r_hijo.traslado_id is null then
                        r_hijo                        := r_traslado;
                        r_hijo.traslado_id            := null;
                        r_hijo.traslado_id_origen     := i_traslado_id;
                        r_hijo.relacion               := c_rel_complemento;
                        r_hijo.estado                 := c_est_borrador;
                        r_hijo.fecha_emision          := trunc(cast(v_fecha as date));
                        r_hijo.movimiento_id_despacho := null;
                        r_hijo.usuario_solicita       := null;
                        r_hijo.fecha_solicitud        := null;
                        r_hijo.usuario_aprueba        := null;
                        r_hijo.fecha_aprobacion       := null;
                        r_hijo.usuario_despacha       := null;
                        r_hijo.fecha_salida_estimada  := null;
                        r_hijo.fecha_llegada_estimada := null;
                        r_hijo.fecha_salida_real      := null;
                        r_hijo.fecha_llegada_real     := null;
                        r_hijo.remision_estado        := c_rem_no_aplica;
                        r_hijo.monto_flete            := 0;
                        r_hijo.creado_por             := erp_stk_comun_utl.obtener_usuario_auditoria;
                        r_hijo.fecha_creacion         := null;
                        r_hijo.modificado_por         := null;
                        r_hijo.fecha_modificacion     := null;
                        insertar_cabecera(io_traslado => r_hijo);
                    end if;
                    insertar_item(i_traslado => r_hijo,
                                  i_item     => erp_stk_tras_item_typ(cantidad => r.cantidad, producto_id => r.producto_id,
                                                                      lote_id => r.lote_id,
                                                                      deposito_ubicacion_id => r.deposito_ubicacion_id_origen),
                                  o_traslado_item_id => v_item_id);
                end loop;
                o_traslado_id_complemento := r_hijo.traslado_id;
            end if;
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_despacho;

    -- ------------------------------------------------------------------ recepción y diferencias

    function obtener_cuarentena (
        i_deposito_id  in number
    ) return number is
        v_id  number;
    begin
        select min(deposito_ubicacion_id)
          into v_id
          from erp_stk_deposito_ubicacion
         where deposito_id = i_deposito_id
           and tipo        = 'C'
           and estado      = c_activo;
        if v_id is null then
            erp_stk_deposito_ubicacion_ctr.insertar(
                i_deposito_id           => i_deposito_id,
                i_codigo                => c_ubi_cuarentena,
                i_nombre                => 'Cuarentena',
                i_tipo                  => 'C',
                i_es_disponible         => c_no,
                o_deposito_ubicacion_id => v_id);
        end if;
        return v_id;
    end obtener_cuarentena;

    -- Resuelve el faltante de un detalle de recepción (el traslado ya está bloqueado).
    procedure resolver_interno (
        i_traslado                in erp_stk_traslado%rowtype,
        i_traslado_recep_det_id   in number,
        i_resolucion              in varchar2,
        i_persona_id_responsable  in number,
        i_observacion             in varchar2,
        i_fecha                   in timestamp with local time zone,
        o_movimiento_id           out number
    ) is
        r_detalle  erp_stk_traslado_recep_det%rowtype;
        r_item     erp_stk_traslado_item%rowtype;
        t_lineas   erp_stk_mov_item_tab := erp_stk_mov_item_tab();
        v_cantidad number;
    begin
        begin
            r_detalle := erp_stk_traslado_recep_det_ctr.bloquear(i_traslado_recep_det_id => i_traslado_recep_det_id);
        exception
            when no_data_found then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_no_existe, i_mensaje => 'La línea de recepción indicada no existe.');
        end;
        r_item     := obtener_item(i_traslado_item_id => r_detalle.traslado_item_id);
        v_cantidad := r_detalle.cantidad_faltante;
        if r_item.traslado_id <> i_traslado.traslado_id or v_cantidad <= 0 or r_detalle.resolucion is not null then
            lanzar(i_codigo => c_err_estado, i_mensaje => 'La línea no tiene un faltante pendiente de resolver.');
        end if;
        if i_resolucion not in (c_res_perdida, c_res_devolucion, c_res_posterior, c_res_merma) or i_resolucion is null then
            lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido,
                   i_mensaje => 'La resolución debe ser pérdida (P), devolución al origen (D) o recepción posterior (R).');
        end if;
        if i_resolucion = c_res_perdida and i_persona_id_responsable is null
           and obtener_parametro_sn(i_codigo => 'ERP_STK_TRASLADO_PERDIDA_RESP', i_empresa_id => i_traslado.empresa_id, i_defecto => c_no) = c_si then
            lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Indique la persona responsable de la pérdida.');
        end if;

        if i_resolucion <> c_res_posterior then
            -- Sale del tránsito al costo con que salió del origen
            t_lineas.extend;
            t_lineas(1) := erp_stk_mov_item_typ(
                               deposito_id            => i_traslado.deposito_id_transito,
                               producto_id            => r_item.producto_id,
                               cantidad               => -v_cantidad,
                               lote_id                => r_item.lote_id,
                               costo_unitario         => r_item.costo_unitario,
                               costo_unitario_reporte => r_item.costo_unitario_reporte,
                               origen_linea_id        => r_item.traslado_item_id);
            if i_resolucion = c_res_devolucion then
                t_lineas.extend;
                t_lineas(2) := erp_stk_mov_item_typ(
                                   deposito_id            => i_traslado.deposito_id_origen,
                                   producto_id            => r_item.producto_id,
                                   cantidad               => v_cantidad,
                                   lote_id                => r_item.lote_id,
                                   deposito_ubicacion_id  => r_item.deposito_ubicacion_id_origen,
                                   costo_unitario         => r_item.costo_unitario,
                                   costo_unitario_reporte => r_item.costo_unitario_reporte,
                                   origen_linea_id        => r_item.traslado_item_id);
                r_item.cantidad_devuelta := r_item.cantidad_devuelta + v_cantidad;
            else
                r_item.cantidad_perdida := r_item.cantidad_perdida + v_cantidad;
            end if;
            -- Punto de integración: cuando exista contabilidad, la pérdida genera su asiento
            -- a partir de este movimiento (tipo TRAS_PERDIDA).
            erp_stk_movimiento_reg.generar(
                i_empresa_id      => i_traslado.empresa_id,
                i_tipo_movimiento => case when i_resolucion = c_res_devolucion then c_mov_devolucion else c_mov_perdida end,
                i_fecha           => cast(i_fecha as date),
                i_items           => t_lineas,
                i_origen_modulo   => c_modulo,
                i_origen_tabla    => c_tabla_origen,
                i_origen_id       => i_traslado.traslado_id,
                i_motivo          => i_observacion,
                o_movimiento_id   => o_movimiento_id);
        end if;
        r_item.cantidad_faltante := r_item.cantidad_faltante - v_cantidad;
        erp_stk_traslado_item_ctr.actualizar(i_item => r_item);

        r_detalle.resolucion               := i_resolucion;
        r_detalle.fecha_resolucion         := i_fecha;
        r_detalle.usuario_resuelve         := erp_stk_comun_utl.obtener_usuario_auditoria;
        r_detalle.persona_id_responsable   := i_persona_id_responsable;
        r_detalle.movimiento_id_resolucion := o_movimiento_id;
        r_detalle.observacion              := coalesce(i_observacion, r_detalle.observacion);
        erp_stk_traslado_recep_det_ctr.actualizar(i_detalle => r_detalle);
    end resolver_interno;

    procedure aplicar_recepcion (
        i_traslado_id        in  number,
        i_items              in  erp_stk_tras_item_tab default null,
        i_fecha              in  timestamp with local time zone default null,
        i_observacion        in  varchar2 default null,
        o_traslado_recep_id  out number
    ) is
        type t_id_tab is table of number index by pls_integer;
        type t_detalle_tab is table of erp_stk_traslado_recep_det%rowtype index by pls_integer;
        type t_sn_tab is table of boolean index by pls_integer;
        t_detalles    t_detalle_tab;
        t_es_merma    t_sn_tab;
        r_traslado    erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
        r_item        erp_stk_traslado_item%rowtype;
        r_indicado    erp_stk_tras_item_typ;
        r_recepcion   erp_stk_traslado_recep%rowtype;
        r_detalle     erp_stk_traslado_recep_det%rowtype;
        t_lineas      erp_stk_mov_item_tab := erp_stk_mov_item_tab();
        t_mermas      t_id_tab;
        v_fecha       timestamp with local time zone := coalesce(i_fecha, systimestamp);
        v_anterior    varchar2(1) := r_traslado.estado;
        v_usuario     varchar2(100) := erp_stk_comun_utl.obtener_usuario_auditoria;
        v_tolerancia  number;
        v_cuarentena  number;
        v_recibida    number;
        v_averiada    number;
        v_faltante    number;
        v_sobrante    number;
        v_libre       number;
        v_declarado   number := 0;
        v_detalle_id  number;
        v_mov_merma   number;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_estado(i_traslado => r_traslado, i_permitidos => c_est_transito || c_est_parcial || c_est_diferencias, i_accion => 'recibir');
            validar_acceso(i_deposito_id => r_traslado.deposito_id_destino, i_accion => c_accion_recibir);
            if upper(v_usuario) = upper(r_traslado.usuario_despacha)
               and obtener_parametro_sn(i_codigo => 'ERP_STK_TRASLADO_SEGREGAR', i_empresa_id => r_traslado.empresa_id, i_defecto => c_no) = c_si then
                lanzar(i_codigo => c_err_acceso, i_mensaje => 'El usuario que despachó el traslado no puede recibirlo.');
            end if;
            if v_fecha < r_traslado.fecha_salida_real then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'La recepción no puede ser anterior al despacho.');
            end if;
            erp_gen_periodo_api.validar_abierto(i_empresa_id => r_traslado.empresa_id, i_modulo => c_modulo, i_fecha => cast(v_fecha as date));
            validar_items_del_traslado(i_traslado_id => i_traslado_id, i_items => i_items);
            v_tolerancia := coalesce(erp_gen_parametro_api.obtener_numero(i_codigo => 'ERP_STK_TRASLADO_TOLERANCIA',
                                                                          i_empresa_id => r_traslado.empresa_id, i_defecto => 0), 0);

            select coalesce(max(numero), 0) + 1 into r_recepcion.numero
              from erp_stk_traslado_recep
             where traslado_id = i_traslado_id;
            r_recepcion.traslado_id     := i_traslado_id;
            r_recepcion.fecha_recepcion := v_fecha;
            r_recepcion.usuario_recibe  := v_usuario;
            r_recepcion.observacion     := i_observacion;

            for r in (select traslado_item_id from erp_stk_traslado_item where traslado_id = i_traslado_id order by linea) loop
                r_item     := obtener_item(i_traslado_item_id => r.traslado_item_id);
                r_indicado := buscar_item(i_items => i_items, i_traslado_item_id => r.traslado_item_id);
                -- Lo que sigue en tránsito sin declarar
                v_libre := r_item.cantidad_despachada - r_item.cantidad_recibida - r_item.cantidad_averiada
                           - r_item.cantidad_perdida - r_item.cantidad_devuelta - r_item.cantidad_faltante;
                if i_items is null then
                    v_recibida := v_libre;   -- sin detalle: se recibe conforme todo lo pendiente
                    v_averiada := 0;
                    v_faltante := 0;
                    v_sobrante := 0;
                elsif r_indicado is null then
                    continue;
                else
                    v_recibida := coalesce(r_indicado.cantidad, 0);
                    v_averiada := coalesce(r_indicado.cantidad_averiada, 0);
                    v_faltante := coalesce(r_indicado.cantidad_faltante, 0);
                    v_sobrante := coalesce(r_indicado.cantidad_sobrante, 0);
                end if;
                if v_recibida < 0 or v_averiada < 0 or v_faltante < 0 or v_sobrante < 0 then
                    lanzar(i_codigo => c_err_cantidad, i_mensaje => 'Las cantidades de la recepción no pueden ser negativas.');
                end if;
                -- RN-06
                if v_recibida + v_averiada + v_faltante > v_libre then
                    lanzar(i_codigo => c_err_cantidad,
                           i_mensaje => 'La línea ' || r_item.linea || ' recibe más de lo que queda en tránsito ('
                                        || rtrim(to_char(v_libre, 'fm999999999999990.9999'), '.') || ').');
                end if;
                if v_recibida + v_averiada + v_faltante + v_sobrante = 0 then
                    continue;
                end if;
                v_declarado := v_declarado + v_recibida + v_averiada + v_faltante + v_sobrante;

                if v_recibida + v_averiada > 0 then
                    -- Sale del tránsito al costo de salida; entra al destino al mismo costo más el flete capitalizable
                    t_lineas.extend;
                    t_lineas(t_lineas.count) := erp_stk_mov_item_typ(
                                                    deposito_id            => r_traslado.deposito_id_transito,
                                                    producto_id            => r_item.producto_id,
                                                    cantidad               => -(v_recibida + v_averiada),
                                                    lote_id                => r_item.lote_id,
                                                    costo_unitario         => r_item.costo_unitario,
                                                    costo_unitario_reporte => r_item.costo_unitario_reporte,
                                                    origen_linea_id        => r_item.traslado_item_id);
                end if;
                if v_recibida > 0 then
                    t_lineas.extend;
                    t_lineas(t_lineas.count) := erp_stk_mov_item_typ(
                                                    deposito_id            => r_traslado.deposito_id_destino,
                                                    producto_id            => r_item.producto_id,
                                                    cantidad               => v_recibida,
                                                    lote_id                => r_item.lote_id,
                                                    deposito_ubicacion_id  => coalesce(r_indicado.deposito_ubicacion_id, r_item.deposito_ubicacion_id_destino),
                                                    costo_unitario         => r_item.costo_unitario + r_item.flete_unitario,
                                                    costo_unitario_reporte => r_item.costo_unitario_reporte + r_item.flete_unitario_reporte,
                                                    origen_linea_id        => r_item.traslado_item_id);
                end if;
                if v_averiada > 0 then
                    -- RN-14: lo dañado entra a cuarentena, no disponible
                    if v_cuarentena is null then
                        v_cuarentena := obtener_cuarentena(i_deposito_id => r_traslado.deposito_id_destino);
                    end if;
                    t_lineas.extend;
                    t_lineas(t_lineas.count) := erp_stk_mov_item_typ(
                                                    deposito_id            => r_traslado.deposito_id_destino,
                                                    producto_id            => r_item.producto_id,
                                                    cantidad               => v_averiada,
                                                    lote_id                => r_item.lote_id,
                                                    deposito_ubicacion_id  => v_cuarentena,
                                                    costo_unitario         => r_item.costo_unitario + r_item.flete_unitario,
                                                    costo_unitario_reporte => r_item.costo_unitario_reporte + r_item.flete_unitario_reporte,
                                                    origen_linea_id        => r_item.traslado_item_id);
                end if;

                r_item.cantidad_recibida := r_item.cantidad_recibida + v_recibida;
                r_item.cantidad_averiada := r_item.cantidad_averiada + v_averiada;
                r_item.cantidad_faltante := r_item.cantidad_faltante + v_faltante;
                erp_stk_traslado_item_ctr.actualizar(i_item => r_item);

                r_detalle := null;
                r_detalle.traslado_item_id  := r_item.traslado_item_id;
                r_detalle.cantidad_recibida := v_recibida;
                r_detalle.cantidad_averiada := v_averiada;
                r_detalle.cantidad_faltante := v_faltante;
                r_detalle.cantidad_sobrante := v_sobrante;
                r_detalle.observacion       := r_indicado.observacion;
                t_detalles(t_detalles.count + 1) := r_detalle;
                -- Faltante dentro de la tolerancia de la empresa: se da de baja solo, como merma
                t_es_merma(t_detalles.count) := v_faltante > 0 and v_tolerancia > 0
                                                and r_item.cantidad_perdida + v_faltante <= r_item.cantidad_despachada * v_tolerancia / 100;
            end loop;
            if v_declarado = 0 then
                lanzar(i_codigo => c_err_cantidad, i_mensaje => 'La recepción no tiene cantidades.');
            end if;

            if t_lineas.count > 0 then
                erp_stk_movimiento_reg.generar(
                    i_empresa_id      => r_traslado.empresa_id,
                    i_tipo_movimiento => c_mov_recepcion,
                    i_fecha           => cast(v_fecha as date),
                    i_items           => t_lineas,
                    i_origen_modulo   => c_modulo,
                    i_origen_tabla    => c_tabla_origen,
                    i_origen_id       => i_traslado_id,
                    o_movimiento_id   => r_recepcion.movimiento_id);
            end if;
            erp_stk_traslado_recep_ctr.insertar(i_recepcion => r_recepcion, o_traslado_recep_id => o_traslado_recep_id);
            for i in 1 .. t_detalles.count loop
                t_detalles(i).traslado_recep_id := o_traslado_recep_id;
                erp_stk_traslado_recep_det_ctr.insertar(i_detalle => t_detalles(i), o_traslado_recep_det_id => v_detalle_id);
                if t_es_merma(i) then
                    t_mermas(t_mermas.count + 1) := v_detalle_id;
                end if;
            end loop;
            for i in 1 .. t_mermas.count loop
                resolver_interno(
                    i_traslado               => r_traslado,
                    i_traslado_recep_det_id  => t_mermas(i),
                    i_resolucion             => c_res_merma,
                    i_persona_id_responsable => null,
                    i_observacion            => 'Merma dentro de la tolerancia',
                    i_fecha                  => v_fecha,
                    o_movimiento_id          => v_mov_merma);
            end loop;

            r_traslado.estado             := calcular_estado(i_traslado_id => i_traslado_id);
            r_traslado.fecha_llegada_real := v_fecha;
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_recibir,
                             i_estado_anterior => v_anterior, i_estado_nuevo => r_traslado.estado,
                             i_movimiento_id => r_recepcion.movimiento_id,
                             i_detalle => armar_detalle(i_clave => 'recepcion', i_valor => to_char(r_recepcion.numero)));
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_recepcion;

    procedure aplicar_resolucion (
        i_traslado_recep_det_id   in number,
        i_resolucion              in varchar2,
        i_persona_id_responsable  in number   default null,
        i_observacion             in varchar2 default null,
        i_fecha                   in timestamp with local time zone default null
    ) is
        r_traslado    erp_stk_traslado%rowtype;
        v_traslado    number;
        v_anterior    varchar2(1);
        v_movimiento  number;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            begin
                select i.traslado_id
                  into v_traslado
                  from erp_stk_traslado_recep_det d
                  join erp_stk_traslado_item i on i.traslado_item_id = d.traslado_item_id
                 where d.traslado_recep_det_id = i_traslado_recep_det_id;
            exception
                when no_data_found then
                    lanzar(i_codigo => erp_stk_comun_utl.c_err_no_existe, i_mensaje => 'La línea de recepción indicada no existe.');
            end;
            r_traslado := bloquear_traslado(i_traslado_id => v_traslado);
            v_anterior := r_traslado.estado;
            validar_estado(i_traslado => r_traslado, i_permitidos => c_est_parcial || c_est_diferencias, i_accion => 'resolver diferencias de');
            if upper(i_resolucion) = c_res_merma then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'La merma solo la aplica el sistema según la tolerancia.');
            end if;
            resolver_interno(
                i_traslado               => r_traslado,
                i_traslado_recep_det_id  => i_traslado_recep_det_id,
                i_resolucion             => upper(i_resolucion),
                i_persona_id_responsable => i_persona_id_responsable,
                i_observacion            => i_observacion,
                i_fecha                  => coalesce(i_fecha, systimestamp),
                o_movimiento_id          => v_movimiento);
            r_traslado.estado := calcular_estado(i_traslado_id => v_traslado);
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => v_traslado, i_evento => c_evt_resolver,
                             i_estado_anterior => v_anterior, i_estado_nuevo => r_traslado.estado,
                             i_movimiento_id => v_movimiento,
                             i_detalle => armar_detalle(i_clave => 'resolucion', i_valor => upper(i_resolucion)));
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_resolucion;

    -- ------------------------------------------------------------------ anulación y devolución

    procedure aplicar_anulacion (
        i_traslado_id  in number,
        i_motivo       in varchar2,
        i_fecha        in timestamp with local time zone default null
    ) is
        r_traslado    erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
        v_anterior    varchar2(1) := r_traslado.estado;
        v_movimiento  number;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            if trim(i_motivo) is null then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Indique el motivo de la anulación.');
            end if;
            if r_traslado.estado in (c_est_parcial, c_est_diferencias, c_est_completado) then
                lanzar(i_codigo => c_err_no_anulable,
                       i_mensaje => 'El traslado ya tiene mercadería recibida: no se anula, se devuelve con un traslado de devolución.');
            end if;
            validar_estado(i_traslado => r_traslado,
                           i_permitidos => c_est_borrador || c_est_solicitado || c_est_aprobado || c_est_transito,
                           i_accion => 'anular');
            if r_traslado.estado = c_est_aprobado then
                liberar_reservas(i_traslado => r_traslado);
            elsif r_traslado.estado = c_est_transito then
                if r_traslado.movimiento_id_despacho is null then
                    lanzar(i_codigo => c_err_no_anulable,
                           i_mensaje => 'Una devolución en tránsito no se anula: se recibe en el depósito de origen.');
                end if;
                validar_acceso(i_deposito_id => r_traslado.deposito_id_origen, i_accion => c_accion_despachar);
                erp_stk_movimiento_reg.generar_reverso(
                    i_movimiento_id => r_traslado.movimiento_id_despacho,
                    i_fecha         => cast(coalesce(i_fecha, systimestamp) as date),
                    i_motivo        => trim(i_motivo),
                    o_movimiento_id => v_movimiento);
                -- Punto de integración: si la remisión ya fue emitida, el módulo de documentos
                -- debe enviar su evento de cancelación (los traslados con remision_estado = C).
                if r_traslado.remision_estado in (c_rem_generada, c_rem_pendiente) then
                    r_traslado.remision_estado := case r_traslado.remision_estado when c_rem_generada then c_rem_cancelada else c_rem_no_aplica end;
                end if;
            end if;
            r_traslado.estado           := c_est_anulado;
            r_traslado.motivo_anulacion := trim(i_motivo);
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_anular,
                             i_estado_anterior => v_anterior, i_estado_nuevo => c_est_anulado,
                             i_movimiento_id => v_movimiento,
                             i_detalle => armar_detalle(i_clave => 'motivo', i_valor => trim(i_motivo)));
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_anulacion;

    procedure generar_devolucion (
        i_traslado_id  in  number,
        i_modo         in  varchar2 default null,
        i_items        in  erp_stk_tras_item_tab default null,
        o_traslado_id  out number
    ) is
        r_original   erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
        r_nuevo      erp_stk_traslado%rowtype;
        r_item       erp_stk_traslado_item%rowtype;
        r_hijo       erp_stk_traslado_item%rowtype;
        r_indicado   erp_stk_tras_item_typ;
        r_destino    t_deposito;
        v_modo       varchar2(1) := upper(i_modo);
        v_anterior   varchar2(1) := r_original.estado;
        v_ahora      timestamp with local time zone := systimestamp;
        v_maximo     number;
        v_cantidad   number;
        v_total      number := 0;
        v_linea      pls_integer := 0;
        v_item_id    number;
    begin
        savepoint sp_erp_stk_traslado;
        begin
            validar_estado(i_traslado => r_original,
                           i_permitidos => c_est_transito || c_est_parcial || c_est_diferencias || c_est_completado,
                           i_accion => 'devolver');
            validar_acceso(i_deposito_id => r_original.deposito_id_destino, i_accion => c_accion_recibir);
            validar_items_del_traslado(i_traslado_id => i_traslado_id, i_items => i_items);
            if v_modo is null then
                v_modo := case when r_original.estado = c_est_completado then c_dev_recibido else c_dev_transito end;
            end if;
            if v_modo not in (c_dev_transito, c_dev_recibido) then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'El modo de devolución debe ser T (en tránsito) o R (recibido).');
            end if;
            if v_modo = c_dev_transito and r_original.estado = c_est_completado then
                lanzar(i_codigo => c_err_estado, i_mensaje => 'El traslado no tiene mercadería en tránsito para rechazar.');
            end if;

            -- Cabecera: mismo tipo, sentido inverso, motivo de devolución
            r_destino := obtener_deposito(i_deposito_id => r_original.deposito_id_destino);
            r_nuevo.empresa_id          := r_original.empresa_id;
            r_nuevo.sucursal_id         := r_destino.sucursal_id;
            r_nuevo.tipo                := r_original.tipo;
            r_nuevo.deposito_id_origen  := r_original.deposito_id_destino;
            r_nuevo.deposito_id_destino := r_original.deposito_id_origen;
            r_nuevo.persona_id_destino  := r_original.persona_id_destino;
            r_nuevo.traslado_id_origen  := i_traslado_id;
            r_nuevo.relacion            := c_rel_devolucion;
            r_nuevo.fecha_emision       := trunc(current_date);
            r_nuevo.kilometros          := r_original.kilometros;
            r_nuevo.horas_estimadas     := r_original.horas_estimadas;
            r_nuevo.monto_flete         := 0;
            r_nuevo.es_flete_capitalizable := c_no;
            r_nuevo.remision_estado     := c_rem_no_aplica;
            r_nuevo.creado_por          := erp_stk_comun_utl.obtener_usuario_auditoria;
            select min(motivo_traslado_id)
              into r_nuevo.motivo_traslado_id
              from erp_stk_motivo_traslado
             where es_devolucion = c_si
               and estado        = c_activo;
            if r_nuevo.motivo_traslado_id is null then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_no_existe, i_mensaje => 'No hay un motivo de traslado marcado como devolución.');
            end if;

            if v_modo = c_dev_transito then
                -- La mercadería sigue en el mismo depósito de tránsito: solo cambia de traslado.
                r_nuevo.es_un_paso             := c_no;
                r_nuevo.deposito_id_transito   := r_original.deposito_id_transito;
                r_nuevo.estado                 := c_est_transito;
                r_nuevo.usuario_solicita       := r_nuevo.creado_por;
                r_nuevo.fecha_solicitud        := v_ahora;
                r_nuevo.usuario_despacha       := r_nuevo.creado_por;
                r_nuevo.fecha_salida_real      := v_ahora;
                r_nuevo.fecha_llegada_estimada := v_ahora + numtodsinterval(coalesce(r_nuevo.horas_estimadas, 0), 'HOUR');
                if r_nuevo.tipo in (c_tipo_remision, c_tipo_tercero) then
                    r_nuevo.remision_estado := c_rem_pendiente;
                end if;
            else
                r_nuevo.es_un_paso := r_original.es_un_paso;
                r_nuevo.estado     := c_est_borrador;
                if r_nuevo.es_un_paso = c_no then
                    r_nuevo.deposito_id_transito := obtener_deposito_transito(i_sucursal_id => r_destino.sucursal_id);
                end if;
            end if;
            insertar_cabecera(io_traslado => r_nuevo);
            o_traslado_id := r_nuevo.traslado_id;

            for r in (select traslado_item_id from erp_stk_traslado_item where traslado_id = i_traslado_id order by linea) loop
                r_item     := obtener_item(i_traslado_item_id => r.traslado_item_id);
                r_indicado := buscar_item(i_items => i_items, i_traslado_item_id => r.traslado_item_id);
                v_maximo   := case v_modo
                                  when c_dev_transito then r_item.cantidad_despachada - r_item.cantidad_recibida - r_item.cantidad_averiada
                                                           - r_item.cantidad_perdida - r_item.cantidad_devuelta - r_item.cantidad_faltante
                                  else r_item.cantidad_recibida
                              end;
                v_cantidad := case when i_items is null then v_maximo
                                   when r_indicado is null then 0
                                   else coalesce(r_indicado.cantidad, 0) end;
                if v_cantidad < 0 or v_cantidad > v_maximo then
                    lanzar(i_codigo => c_err_cantidad,
                           i_mensaje => 'La cantidad a devolver de la línea ' || r_item.linea || ' supera lo '
                                        || case v_modo when c_dev_transito then 'que queda en tránsito.' else 'recibido.' end);
                end if;
                if v_cantidad = 0 then
                    continue;
                end if;
                v_total := v_total + v_cantidad;
                v_linea := v_linea + 1;

                r_hijo := null;
                r_hijo.traslado_id                   := r_nuevo.traslado_id;
                r_hijo.linea                         := v_linea;
                r_hijo.producto_id                   := r_item.producto_id;
                r_hijo.lote_id                       := r_item.lote_id;
                r_hijo.deposito_ubicacion_id_origen  := case when v_modo = c_dev_recibido then r_item.deposito_ubicacion_id_destino end;
                r_hijo.deposito_ubicacion_id_destino := r_item.deposito_ubicacion_id_origen;
                r_hijo.cantidad_solicitada           := v_cantidad;
                if v_modo = c_dev_transito then
                    r_hijo.cantidad_aprobada      := v_cantidad;
                    r_hijo.cantidad_despachada    := v_cantidad;
                    r_hijo.costo_unitario         := r_item.costo_unitario;
                    r_hijo.costo_unitario_reporte := r_item.costo_unitario_reporte;
                    -- En el original deja de estar pendiente: vuelve al origen por la devolución
                    r_item.cantidad_devuelta := r_item.cantidad_devuelta + v_cantidad;
                    erp_stk_traslado_item_ctr.actualizar(i_item => r_item);
                end if;
                erp_stk_traslado_item_ctr.insertar(i_item => r_hijo, o_traslado_item_id => v_item_id);
            end loop;
            if v_total = 0 then
                lanzar(i_codigo => c_err_cantidad, i_mensaje => 'No hay cantidades para devolver.');
            end if;

            if v_modo = c_dev_transito then
                r_original.estado := calcular_estado(i_traslado_id => i_traslado_id);
                erp_stk_traslado_ctr.actualizar(i_traslado => r_original);
            end if;
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_devolver,
                             i_estado_anterior => v_anterior, i_estado_nuevo => r_original.estado,
                             i_detalle => armar_detalle(i_clave => 'traslado_devolucion', i_valor => to_char(r_nuevo.traslado_id)));
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end generar_devolucion;

    -- ------------------------------------------------------------------ nota de remisión

    procedure aplicar_remision (
        i_traslado_id            in number,
        i_remision_documento_id  in number,
        i_remision_numero        in varchar2,
        i_remision_cdc           in varchar2
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
    begin
        savepoint sp_erp_stk_traslado;
        begin
            if r_traslado.tipo = c_tipo_interno then
                lanzar(i_codigo => c_err_transporte, i_mensaje => 'Los traslados internos no llevan nota de remisión.');
            end if;
            -- RN-15: como máximo una remisión vigente
            if r_traslado.remision_estado = c_rem_generada then
                lanzar(i_codigo => c_err_transporte, i_mensaje => 'El traslado ya tiene una nota de remisión vigente.');
            end if;
            if r_traslado.remision_estado = c_rem_no_aplica
               or r_traslado.estado not in (c_est_transito, c_est_parcial, c_est_diferencias, c_est_completado) then
                lanzar(i_codigo => c_err_estado, i_mensaje => 'La nota de remisión se emite al despachar el traslado.');
            end if;
            if trim(i_remision_numero) is null then
                lanzar(i_codigo => erp_stk_comun_utl.c_err_dato_invalido, i_mensaje => 'Indique el número de la nota de remisión.');
            end if;
            r_traslado.remision_estado       := c_rem_generada;
            r_traslado.remision_documento_id := i_remision_documento_id;
            r_traslado.remision_numero       := trim(i_remision_numero);
            r_traslado.remision_cdc          := trim(i_remision_cdc);
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_remision,
                             i_estado_anterior => r_traslado.estado, i_estado_nuevo => r_traslado.estado,
                             i_detalle => armar_detalle(i_clave => 'remision', i_valor => trim(i_remision_numero)));
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_remision;

    procedure aplicar_cancelacion_remision (
        i_traslado_id  in number
    ) is
        r_traslado  erp_stk_traslado%rowtype := bloquear_traslado(i_traslado_id => i_traslado_id);
    begin
        savepoint sp_erp_stk_traslado;
        begin
            if r_traslado.remision_estado <> c_rem_generada then
                lanzar(i_codigo => c_err_transporte, i_mensaje => 'El traslado no tiene una nota de remisión vigente.');
            end if;
            r_traslado.remision_estado := c_rem_cancelada;
            erp_stk_traslado_ctr.actualizar(i_traslado => r_traslado);
            registrar_evento(i_traslado_id => i_traslado_id, i_evento => c_evt_remision,
                             i_estado_anterior => r_traslado.estado, i_estado_nuevo => r_traslado.estado,
                             i_detalle => armar_detalle(i_clave => 'cancelada', i_valor => r_traslado.remision_numero));
        exception
            when others then
                rollback to sp_erp_stk_traslado;
                raise;
        end;
    end aplicar_cancelacion_remision;

    function calcular_empresa (
        i_traslado_id  in number
    ) return number is
        v_empresa_id  number;
    begin
        select empresa_id into v_empresa_id from erp_stk_traslado where traslado_id = i_traslado_id;
        return v_empresa_id;
    exception
        when no_data_found then
            lanzar(i_codigo => erp_stk_comun_utl.c_err_no_existe, i_mensaje => 'El traslado indicado no existe.');
    end calcular_empresa;

end erp_stk_traslado_reg;
/
