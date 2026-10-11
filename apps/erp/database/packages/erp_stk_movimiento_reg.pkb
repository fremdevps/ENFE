create or replace package body erp_stk_movimiento_reg
as

    type t_deposito is record (
        deposito_id           erp_stk_deposito.deposito_id%type,
        empresa_id            erp_gen_sucursal.empresa_id%type,
        codigo                erp_stk_deposito.codigo%type,
        tipo                  erp_stk_deposito.tipo%type,
        debe_controlar_stock  erp_stk_deposito.debe_controlar_stock%type,
        estado                erp_stk_deposito.estado%type
    );

    type t_producto is record (
        producto_id        erp_stk_producto.producto_id%type,
        empresa_id         erp_stk_producto.empresa_id%type,
        codigo             erp_stk_producto.codigo%type,
        tipo               erp_stk_producto.tipo%type,
        tiene_lote         erp_stk_producto.tiene_lote%type,
        tiene_serie        erp_stk_producto.tiene_serie%type,
        tiene_vencimiento  erp_stk_producto.tiene_vencimiento%type,
        metodo_costo       erp_stk_producto.metodo_costo%type,
        estado             erp_stk_producto.estado%type,
        decimales          erp_stk_unidad.decimales%type
    );

    type t_deposito_mapa  is table of t_deposito index by varchar2(40);
    type t_producto_mapa  is table of t_producto index by varchar2(40);
    type t_lote_mapa      is table of erp_stk_lote%rowtype index by varchar2(40);
    type t_ubicacion_mapa is table of erp_stk_deposito_ubicacion%rowtype index by varchar2(40);
    type t_numero_tab     is table of number index by pls_integer;

    -- Datos de la operación en curso. Se reinician al empezar cada operación.
    type t_contexto is record (
        empresa_id           number,
        fecha                date,
        moneda_id_funcional  number,
        moneda_id_reporte    number,
        decimales            number,
        decimales_reporte    number,
        cotizacion_reporte   number,
        metodo_defecto       varchar2(1),
        es_ubicacion_activa  varchar2(1),
        es_reverso           boolean,
        tipo                 erp_stk_tipo_movimiento%rowtype
    );

    g_ctx          t_contexto;
    g_depositos    t_deposito_mapa;
    g_productos    t_producto_mapa;
    g_lotes        t_lote_mapa;
    g_ubicaciones  t_ubicacion_mapa;

    -- ------------------------------------------------------------------ utilitarios

    function formatear_cantidad (
        i_cantidad  in number
    ) return varchar2 is
    begin
        return rtrim(to_char(i_cantidad, 'fm999999999999990D9999', 'nls_numeric_characters='',.'''), ',');
    end formatear_cantidad;

    procedure iniciar_contexto (
        i_empresa_id  in number,
        i_fecha       in date
    ) is
        v_vacio  t_contexto;
    begin
        g_ctx := v_vacio;
        g_depositos.delete;
        g_productos.delete;
        g_lotes.delete;
        g_ubicaciones.delete;
        g_ctx.empresa_id := i_empresa_id;
        g_ctx.fecha      := trunc(i_fecha);
        g_ctx.es_reverso := false;
        begin
            select c.moneda_id_funcional, c.moneda_id_reporte, f.decimales, r.decimales
              into g_ctx.moneda_id_funcional, g_ctx.moneda_id_reporte, g_ctx.decimales, g_ctx.decimales_reporte
              from erp_gen_empresa_config c
              join erp_gen_moneda f on f.moneda_id = c.moneda_id_funcional
              left join erp_gen_moneda r on r.moneda_id = c.moneda_id_reporte
             where c.empresa_id = i_empresa_id;
        exception
            when no_data_found then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                    'La empresa no tiene configurada su moneda funcional en el ERP.');
        end;
        g_ctx.metodo_defecto := calcular_metodo_costo(i_empresa_id => i_empresa_id, i_metodo_costo => null);
    end iniciar_contexto;

    -- Cuántas unidades de la moneda de reporte vale una de la funcional en la fecha.
    function obtener_cotizacion_reporte return number is
    begin
        if g_ctx.moneda_id_reporte is null then
            return 0;
        end if;
        if g_ctx.moneda_id_reporte = g_ctx.moneda_id_funcional then
            return 1;
        end if;
        if g_ctx.cotizacion_reporte is null then
            g_ctx.cotizacion_reporte := erp_gen_moneda_api.obtener_cotizacion(
                                            i_moneda_id_origen  => g_ctx.moneda_id_funcional,
                                            i_moneda_id_destino => g_ctx.moneda_id_reporte,
                                            i_fecha             => g_ctx.fecha,
                                            i_empresa_id        => g_ctx.empresa_id);
        end if;
        return g_ctx.cotizacion_reporte;
    end obtener_cotizacion_reporte;

    function obtener_deposito (
        i_deposito_id  in number
    ) return t_deposito is
        v_clave  varchar2(40) := to_char(i_deposito_id);
        r        t_deposito;
    begin
        if i_deposito_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'Falta el depósito en una línea.');
        end if;
        if not g_depositos.exists(v_clave) then
            begin
                select d.deposito_id, s.empresa_id, d.codigo, d.tipo, d.debe_controlar_stock, d.estado
                  into r
                  from erp_stk_deposito d
                  join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
                 where d.deposito_id = i_deposito_id;
            exception
                when no_data_found then
                    raise_application_error(c_err_deposito_invalido, 'El depósito indicado no existe.');
            end;
            g_depositos(v_clave) := r;
        end if;
        return g_depositos(v_clave);
    end obtener_deposito;

    function obtener_producto (
        i_producto_id  in number
    ) return t_producto is
        v_clave  varchar2(40) := to_char(i_producto_id);
        r        t_producto;
    begin
        if i_producto_id is null then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'Falta el producto en una línea.');
        end if;
        if not g_productos.exists(v_clave) then
            begin
                select p.producto_id, p.empresa_id, p.codigo, p.tipo, p.tiene_lote, p.tiene_serie,
                       p.tiene_vencimiento, p.metodo_costo, p.estado, u.decimales
                  into r
                  from erp_stk_producto p
                  join erp_stk_unidad u on u.unidad_id = p.unidad_id
                 where p.producto_id = i_producto_id;
            exception
                when no_data_found then
                    raise_application_error(c_err_producto_invalido, 'El producto indicado no existe.');
            end;
            g_productos(v_clave) := r;
        end if;
        return g_productos(v_clave);
    end obtener_producto;

    function obtener_lote (
        i_lote_id  in number
    ) return erp_stk_lote%rowtype is
        v_clave  varchar2(40) := to_char(i_lote_id);
        r        erp_stk_lote%rowtype;
    begin
        if not g_lotes.exists(v_clave) then
            begin
                select * into r from erp_stk_lote where lote_id = i_lote_id;
            exception
                when no_data_found then
                    raise_application_error(c_err_lote_invalido, 'El lote indicado no existe.');
            end;
            g_lotes(v_clave) := r;
        end if;
        return g_lotes(v_clave);
    end obtener_lote;

    function obtener_ubicacion (
        i_deposito_ubicacion_id  in number
    ) return erp_stk_deposito_ubicacion%rowtype is
        v_clave  varchar2(40) := to_char(i_deposito_ubicacion_id);
        r        erp_stk_deposito_ubicacion%rowtype;
    begin
        if not g_ubicaciones.exists(v_clave) then
            begin
                select * into r from erp_stk_deposito_ubicacion where deposito_ubicacion_id = i_deposito_ubicacion_id;
            exception
                when no_data_found then
                    raise_application_error(c_err_ubicacion_invalida, 'La ubicación indicada no existe.');
            end;
            g_ubicaciones(v_clave) := r;
        end if;
        return g_ubicaciones(v_clave);
    end obtener_ubicacion;

    -- ------------------------------------------------------------------ validaciones

    -- Valida depósito, producto, lote y ubicación de una línea.
    -- i_es_reserva: la línea solo mueve la reserva (no hay tipo de movimiento).
    procedure validar_item (
        i_item        in erp_stk_mov_item_typ,
        i_es_reserva  in boolean
    ) is
        r_deposito   t_deposito;
        r_producto   t_producto;
        r_lote       erp_stk_lote%rowtype;
        r_ubicacion  erp_stk_deposito_ubicacion%rowtype;
        v_sale       boolean := coalesce(i_item.cantidad, 0) < 0;
    begin
        r_deposito := obtener_deposito(i_deposito_id => i_item.deposito_id);
        r_producto := obtener_producto(i_producto_id => i_item.producto_id);

        if r_deposito.empresa_id <> g_ctx.empresa_id then
            raise_application_error(c_err_deposito_invalido,
                'El depósito ' || r_deposito.codigo || ' no pertenece a la empresa.');
        end if;
        if r_producto.empresa_id <> g_ctx.empresa_id then
            raise_application_error(c_err_producto_invalido,
                'El producto ' || r_producto.codigo || ' no pertenece a la empresa.');
        end if;
        if r_producto.tipo not in ('B', 'P') then
            raise_application_error(c_err_producto_invalido,
                'El producto ' || r_producto.codigo || ' no lleva stock (es un servicio o un kit).');
        end if;
        if r_deposito.tipo = 'T'
           and (i_es_reserva or (not g_ctx.es_reverso and g_ctx.tipo.debe_permitir_transito = 'N')) then
            raise_application_error(c_err_deposito_invalido,
                'El depósito ' || r_deposito.codigo || ' es de tránsito: solo lo mueven los traslados.');
        end if;
        if not g_ctx.es_reverso then
            if r_deposito.estado <> 'A' then
                raise_application_error(c_err_deposito_invalido, 'El depósito ' || r_deposito.codigo || ' está inactivo.');
            end if;
            if r_producto.estado <> 'A' then
                raise_application_error(c_err_producto_invalido, 'El producto ' || r_producto.codigo || ' está inactivo.');
            end if;
        end if;
        if i_item.cantidad <> round(i_item.cantidad, r_producto.decimales) then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                'La cantidad del producto ' || r_producto.codigo || ' admite hasta ' || r_producto.decimales || ' decimales.');
        end if;

        -- Lote / serie / vencimiento según el producto
        if r_producto.tiene_lote = 'S' or r_producto.tiene_serie = 'S' then
            if i_item.lote_id is null then
                raise_application_error(c_err_lote_invalido,
                    'El producto ' || r_producto.codigo || ' exige indicar el '
                    || case when r_producto.tiene_serie = 'S' then 'número de serie.' else 'lote.' end);
            end if;
            r_lote := obtener_lote(i_lote_id => i_item.lote_id);
            if r_lote.producto_id <> r_producto.producto_id then
                raise_application_error(c_err_lote_invalido,
                    'El lote ' || r_lote.codigo || ' no corresponde al producto ' || r_producto.codigo || '.');
            end if;
            if r_producto.tiene_vencimiento = 'S' and r_lote.fecha_vencimiento is null then
                raise_application_error(c_err_lote_invalido,
                    'El lote ' || r_lote.codigo || ' del producto ' || r_producto.codigo || ' no tiene fecha de vencimiento.');
            end if;
            if not g_ctx.es_reverso then
                if r_lote.estado = 'I' or (r_lote.estado = 'B' and (v_sale or i_es_reserva)) then
                    raise_application_error(c_err_lote_invalido,
                        'El lote ' || r_lote.codigo || ' del producto ' || r_producto.codigo || ' está bloqueado o inactivo.');
                end if;
                if v_sale and not i_es_reserva and g_ctx.tipo.debe_validar_vencimiento = 'S'
                   and r_lote.fecha_vencimiento < g_ctx.fecha then
                    raise_application_error(c_err_lote_vencido,
                        'El lote ' || r_lote.codigo || ' del producto ' || r_producto.codigo || ' venció el '
                        || to_char(r_lote.fecha_vencimiento, 'DD/MM/YYYY') || '.');
                end if;
            end if;
        elsif i_item.lote_id is not null then
            raise_application_error(c_err_lote_invalido,
                'El producto ' || r_producto.codigo || ' no maneja lote ni serie.');
        end if;

        -- Ubicación dentro del depósito
        if i_item.deposito_ubicacion_id is not null then
            r_ubicacion := obtener_ubicacion(i_deposito_ubicacion_id => i_item.deposito_ubicacion_id);
            if r_ubicacion.deposito_id <> r_deposito.deposito_id then
                raise_application_error(c_err_ubicacion_invalida,
                    'La ubicación ' || r_ubicacion.codigo || ' no pertenece al depósito ' || r_deposito.codigo || '.');
            end if;
            if not g_ctx.es_reverso then
                if r_ubicacion.estado <> 'A' then
                    raise_application_error(c_err_ubicacion_invalida, 'La ubicación ' || r_ubicacion.codigo || ' está inactiva.');
                end if;
                -- La cuarentena existe siempre; el resto de las ubicaciones es una funcionalidad activable.
                if r_ubicacion.tipo <> 'C' then
                    if g_ctx.es_ubicacion_activa is null then
                        g_ctx.es_ubicacion_activa := erp_gen_funcionalidad_api.es_activa_sn(
                                                         i_codigo => 'UBICACION', i_empresa_id => g_ctx.empresa_id);
                    end if;
                    if g_ctx.es_ubicacion_activa = 'N' then
                        raise_application_error(c_err_ubicacion_invalida,
                            'La empresa no tiene activa la funcionalidad de ubicaciones dentro del depósito.');
                    end if;
                end if;
            end if;
        end if;
    end validar_item;

    -- Agrega al mapa la fila de saldo de la línea (todavía sin bloquear).
    procedure agregar_clave (
        i_item     in erp_stk_mov_item_typ,
        io_saldos  in out nocopy erp_stk_saldo_ctr.t_saldo_mapa
    ) is
        v_clave  varchar2(80) := erp_stk_saldo_ctr.obtener_clave(
                                     i_deposito_id           => i_item.deposito_id,
                                     i_producto_id           => i_item.producto_id,
                                     i_lote_id               => i_item.lote_id,
                                     i_deposito_ubicacion_id => i_item.deposito_ubicacion_id);
        r_saldo  erp_stk_saldo%rowtype;
    begin
        if io_saldos.exists(v_clave) then
            return;
        end if;
        r_saldo.empresa_id            := g_ctx.empresa_id;
        r_saldo.deposito_id           := i_item.deposito_id;
        r_saldo.producto_id           := i_item.producto_id;
        r_saldo.lote_id               := i_item.lote_id;
        r_saldo.deposito_ubicacion_id := i_item.deposito_ubicacion_id;
        r_saldo.es_disponible         := case when i_item.deposito_ubicacion_id is null then 'S'
                                              else obtener_ubicacion(i_deposito_ubicacion_id => i_item.deposito_ubicacion_id).es_disponible
                                         end;
        io_saldos(v_clave) := r_saldo;
    end agregar_clave;

    -- Aplica la variación de reserva de una línea y controla el disponible.
    procedure aplicar_linea_saldo (
        i_item      in erp_stk_mov_item_typ,
        io_saldo    in out nocopy erp_stk_saldo%rowtype
    ) is
        r_deposito  t_deposito := obtener_deposito(i_deposito_id => i_item.deposito_id);
        r_producto  t_producto := obtener_producto(i_producto_id => i_item.producto_id);
        v_cantidad  number := coalesce(i_item.cantidad, 0);
        v_reserva   number := coalesce(i_item.reserva, 0);
        v_controla  boolean := r_deposito.debe_controlar_stock = 'S' or r_deposito.tipo = 'T';
        v_antes     number := io_saldo.cantidad - io_saldo.cantidad_reservada;
    begin
        if v_reserva > 0 and io_saldo.es_disponible = 'N' then
            raise_application_error(c_err_reserva_invalida,
                'No se puede reservar stock en cuarentena (producto ' || r_producto.codigo || ').');
        end if;
        io_saldo.cantidad           := io_saldo.cantidad + v_cantidad;
        io_saldo.cantidad_reservada := io_saldo.cantidad_reservada + v_reserva;
        if io_saldo.cantidad_reservada < 0 then
            raise_application_error(c_err_reserva_invalida,
                'Se intenta liberar más de lo reservado del producto ' || r_producto.codigo
                || ' en el depósito ' || r_deposito.codigo || '.');
        end if;
        if v_controla and (v_cantidad < 0 or v_reserva > 0)
           and (io_saldo.cantidad < 0
                or (io_saldo.es_disponible = 'S' and io_saldo.cantidad - io_saldo.cantidad_reservada < 0)) then
            raise_application_error(c_err_stock_insuficiente,
                'Stock insuficiente del producto ' || r_producto.codigo || ' en el depósito ' || r_deposito.codigo
                || ': disponible ' || formatear_cantidad(i_cantidad => v_antes - least(v_reserva, 0))
                || ', requerido ' || formatear_cantidad(i_cantidad => greatest(-v_cantidad, v_reserva)) || '.');
        end if;
    end aplicar_linea_saldo;

    -- Un número de serie no puede tener más de una unidad en existencia.
    procedure validar_series (
        i_saldos  in erp_stk_saldo_ctr.t_saldo_mapa
    ) is
        v_clave  varchar2(80) := i_saldos.first;
        r_lote   erp_stk_lote%rowtype;
        v_total  number;
    begin
        while v_clave is not null loop
            if i_saldos(v_clave).lote_id is not null then
                r_lote := obtener_lote(i_lote_id => i_saldos(v_clave).lote_id);
                if r_lote.tipo = 'S' then
                    select coalesce(sum(cantidad), 0)
                      into v_total
                      from erp_stk_saldo
                     where lote_id = r_lote.lote_id;
                    if i_saldos(v_clave).cantidad not in (0, 1) or v_total > 1 then
                        raise_application_error(c_err_lote_invalido,
                            'El número de serie ' || r_lote.codigo || ' solo puede tener una unidad en existencia.');
                    end if;
                end if;
            end if;
            v_clave := i_saldos.next(v_clave);
        end loop;
    end validar_series;

    -- ------------------------------------------------------------------ motor

    procedure generar_interno (
        i_items                    in  erp_stk_mov_item_tab,
        i_origen_modulo            in  varchar2,
        i_origen_tabla             in  varchar2,
        i_origen_id                in  number,
        i_motivo                   in  varchar2,
        i_observacion              in  varchar2,
        i_movimiento_id_reversado  in  number,
        o_movimiento_id            out number
    ) is
        t_saldos      erp_stk_saldo_ctr.t_saldo_mapa;
        t_filas       erp_stk_movimiento_item_ctr.t_item_tab;
        t_costo       t_numero_tab;
        t_costo_rep   t_numero_tab;
        r_movimiento  erp_stk_movimiento%rowtype;
        r_item        erp_stk_mov_item_typ;
        r_fila        erp_stk_movimiento_item%rowtype;
        v_clave       varchar2(80);
        v_lineas      pls_integer := 0;
        v_cantidad    number;
        v_costo       number;
        v_costo_rep   number;
        v_anterior    number;
        v_valor       number;
        v_metodo      varchar2(1);
        v_recalcula   boolean;
    begin
        if i_items is null or i_items.count = 0 then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'El movimiento no tiene líneas.');
        end if;
        if g_ctx.tipo.debe_exigir_motivo = 'S' and trim(i_motivo) is null then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                'El movimiento "' || g_ctx.tipo.nombre || '" exige indicar el motivo.');
        end if;
        erp_gen_periodo_api.validar_abierto(i_empresa_id => g_ctx.empresa_id, i_modulo => 'STK', i_fecha => g_ctx.fecha);

        -- 1) Validar líneas y reunir las filas de saldo
        for i in 1 .. i_items.count loop
            r_item := i_items(i);
            v_cantidad := coalesce(r_item.cantidad, 0);
            if v_cantidad = 0 and coalesce(r_item.reserva, 0) = 0 then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'La línea ' || i || ' no tiene cantidad.');
            end if;
            if not g_ctx.es_reverso
               and ((g_ctx.tipo.naturaleza = 'E' and v_cantidad < 0) or (g_ctx.tipo.naturaleza = 'S' and v_cantidad > 0)) then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                    'El movimiento "' || g_ctx.tipo.nombre || '" solo admite '
                    || case g_ctx.tipo.naturaleza when 'E' then 'entradas (cantidades positivas).' else 'salidas (cantidades negativas).' end);
            end if;
            if r_item.costo_unitario < 0 or r_item.costo_unitario_reporte < 0 then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'El costo de la línea ' || i || ' no puede ser negativo.');
            end if;
            if r_item.linea_costo is not null and (r_item.linea_costo < 1 or r_item.linea_costo >= i) then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido,
                    'La línea ' || i || ' toma el costo de una línea que no es anterior.');
            end if;
            validar_item(i_item => r_item, i_es_reserva => false);
            agregar_clave(i_item => r_item, io_saldos => t_saldos);
            if v_cantidad <> 0 then
                v_lineas := v_lineas + 1;
            end if;
        end loop;
        if v_lineas = 0 then
            raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'El movimiento no tiene líneas con cantidad.');
        end if;

        -- 2) Bloquear los saldos en orden (crea las filas que falten)
        erp_stk_saldo_ctr.bloquear(io_saldos => t_saldos);

        -- 3) Cabecera
        r_movimiento.empresa_id              := g_ctx.empresa_id;
        r_movimiento.tipo_movimiento_id      := g_ctx.tipo.tipo_movimiento_id;
        r_movimiento.fecha_movimiento        := g_ctx.fecha;
        r_movimiento.origen_modulo           := upper(coalesce(i_origen_modulo, 'STK'));
        r_movimiento.origen_tabla            := lower(i_origen_tabla);
        r_movimiento.origen_id               := i_origen_id;
        r_movimiento.motivo                  := trim(i_motivo);
        r_movimiento.observacion             := i_observacion;
        r_movimiento.es_reverso              := case when g_ctx.es_reverso then 'S' else 'N' end;
        r_movimiento.movimiento_id_reversado := i_movimiento_id_reversado;
        r_movimiento.estado                  := 'C';
        r_movimiento.creado_por              := erp_stk_comun_utl.obtener_usuario_auditoria;
        erp_stk_movimiento_ctr.insertar(i_movimiento => r_movimiento, o_movimiento_id => o_movimiento_id);

        -- 4) Aplicar cada línea, en el orden recibido, sobre los saldos en memoria
        v_lineas := 0;
        for i in 1 .. i_items.count loop
            r_item     := i_items(i);
            v_cantidad := coalesce(r_item.cantidad, 0);
            v_clave    := erp_stk_saldo_ctr.obtener_clave(
                              i_deposito_id           => r_item.deposito_id,
                              i_producto_id           => r_item.producto_id,
                              i_lote_id               => r_item.lote_id,
                              i_deposito_ubicacion_id => r_item.deposito_ubicacion_id);
            v_anterior := t_saldos(v_clave).cantidad;

            -- Costo de la línea
            if r_item.linea_costo is not null then
                v_costo     := t_costo(r_item.linea_costo);
                v_costo_rep := t_costo_rep(r_item.linea_costo);
                v_recalcula := true;
            elsif r_item.costo_unitario is not null then
                v_costo     := round(r_item.costo_unitario, 6);
                v_costo_rep := round(coalesce(r_item.costo_unitario_reporte, v_costo * obtener_cotizacion_reporte), 6);
                v_recalcula := true;
            else
                v_costo     := t_saldos(v_clave).costo_promedio;
                v_costo_rep := t_saldos(v_clave).costo_promedio_reporte;
                v_recalcula := false;
            end if;
            t_costo(i)     := v_costo;
            t_costo_rep(i) := v_costo_rep;

            aplicar_linea_saldo(i_item => r_item, io_saldo => t_saldos(v_clave));

            if v_cantidad <> 0 then
                -- Costo del saldo después de la línea
                if v_recalcula then
                    v_metodo := coalesce(obtener_producto(i_producto_id => r_item.producto_id).metodo_costo, g_ctx.metodo_defecto);
                    if v_cantidad > 0 then
                        if v_metodo = 'U' or v_anterior <= 0 then
                            t_saldos(v_clave).costo_promedio         := v_costo;
                            t_saldos(v_clave).costo_promedio_reporte := v_costo_rep;
                        else
                            t_saldos(v_clave).costo_promedio :=
                                round((v_anterior * t_saldos(v_clave).costo_promedio + v_cantidad * v_costo) / t_saldos(v_clave).cantidad, 6);
                            t_saldos(v_clave).costo_promedio_reporte :=
                                round((v_anterior * t_saldos(v_clave).costo_promedio_reporte + v_cantidad * v_costo_rep) / t_saldos(v_clave).cantidad, 6);
                        end if;
                    elsif v_metodo = 'P' and t_saldos(v_clave).cantidad > 0 then
                        -- Salida a un costo propio: retira ese valor y recalcula el promedio del resto.
                        v_valor := v_anterior * t_saldos(v_clave).costo_promedio + v_cantidad * v_costo;
                        if v_valor >= 0 then
                            t_saldos(v_clave).costo_promedio := round(v_valor / t_saldos(v_clave).cantidad, 6);
                        end if;
                        v_valor := v_anterior * t_saldos(v_clave).costo_promedio_reporte + v_cantidad * v_costo_rep;
                        if v_valor >= 0 then
                            t_saldos(v_clave).costo_promedio_reporte := round(v_valor / t_saldos(v_clave).cantidad, 6);
                        end if;
                    end if;
                end if;
                t_saldos(v_clave).fecha_ultimo_movimiento :=
                    greatest(coalesce(t_saldos(v_clave).fecha_ultimo_movimiento, g_ctx.fecha), g_ctx.fecha);

                r_fila := null;
                r_fila.movimiento_id          := o_movimiento_id;
                r_fila.empresa_id             := g_ctx.empresa_id;
                r_fila.linea                  := i;
                r_fila.fecha_movimiento       := g_ctx.fecha;
                r_fila.deposito_id            := r_item.deposito_id;
                r_fila.producto_id            := r_item.producto_id;
                r_fila.lote_id                := r_item.lote_id;
                r_fila.deposito_ubicacion_id  := r_item.deposito_ubicacion_id;
                r_fila.cantidad               := v_cantidad;
                r_fila.costo_unitario         := v_costo;
                r_fila.costo_unitario_reporte := v_costo_rep;
                r_fila.costo_total            := round(v_cantidad * v_costo, g_ctx.decimales);
                r_fila.costo_total_reporte    := round(v_cantidad * v_costo_rep, coalesce(g_ctx.decimales_reporte, 2));
                r_fila.saldo_cantidad         := t_saldos(v_clave).cantidad;
                r_fila.saldo_costo            := t_saldos(v_clave).costo_promedio;
                r_fila.origen_linea_id        := r_item.origen_linea_id;
                r_fila.creado_por             := r_movimiento.creado_por;
                v_lineas := v_lineas + 1;
                t_filas(v_lineas) := r_fila;
            end if;
        end loop;

        -- 5) Grabar líneas y saldos
        erp_stk_movimiento_item_ctr.insertar(i_items => t_filas);
        erp_stk_saldo_ctr.actualizar(i_saldos => t_saldos);
        validar_series(i_saldos => t_saldos);
    end generar_interno;

    procedure generar (
        i_empresa_id       in  erp_stk_movimiento.empresa_id%type,
        i_tipo_movimiento  in  erp_stk_tipo_movimiento.codigo%type,
        i_fecha            in  erp_stk_movimiento.fecha_movimiento%type,
        i_items            in  erp_stk_mov_item_tab,
        i_origen_modulo    in  erp_stk_movimiento.origen_modulo%type default 'STK',
        i_origen_tabla     in  erp_stk_movimiento.origen_tabla%type  default null,
        i_origen_id        in  erp_stk_movimiento.origen_id%type     default null,
        i_motivo           in  erp_stk_movimiento.motivo%type        default null,
        i_observacion      in  erp_stk_movimiento.observacion%type   default null,
        o_movimiento_id    out erp_stk_movimiento.movimiento_id%type
    ) is
    begin
        savepoint sp_erp_stk_movimiento;
        begin
            if i_empresa_id is null or i_fecha is null then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'Indique la empresa y la fecha del movimiento.');
            end if;
            iniciar_contexto(i_empresa_id => i_empresa_id, i_fecha => i_fecha);
            begin
                select *
                  into g_ctx.tipo
                  from erp_stk_tipo_movimiento
                 where codigo = upper(i_tipo_movimiento)
                   and estado = 'A';
            exception
                when no_data_found then
                    raise_application_error(erp_stk_comun_utl.c_err_no_existe,
                        'No existe el tipo de movimiento ' || upper(i_tipo_movimiento) || ' o está inactivo.');
            end;
            generar_interno(
                i_items                   => i_items,
                i_origen_modulo           => i_origen_modulo,
                i_origen_tabla            => i_origen_tabla,
                i_origen_id               => i_origen_id,
                i_motivo                  => i_motivo,
                i_observacion             => i_observacion,
                i_movimiento_id_reversado => null,
                o_movimiento_id           => o_movimiento_id);
        exception
            when others then
                rollback to sp_erp_stk_movimiento;
                raise;
        end;
    end generar;

    procedure generar_reverso (
        i_movimiento_id  in  erp_stk_movimiento.movimiento_id%type,
        i_fecha          in  erp_stk_movimiento.fecha_movimiento%type,
        i_motivo         in  erp_stk_movimiento.motivo%type,
        o_movimiento_id  out erp_stk_movimiento.movimiento_id%type
    ) is
        r_original  erp_stk_movimiento%rowtype;
        t_items     erp_stk_mov_item_tab := erp_stk_mov_item_tab();
    begin
        savepoint sp_erp_stk_movimiento;
        begin
            begin
                r_original := erp_stk_movimiento_ctr.bloquear(i_movimiento_id => i_movimiento_id);
            exception
                when no_data_found then
                    raise_application_error(erp_stk_comun_utl.c_err_no_existe, 'El movimiento indicado no existe.');
            end;
            if r_original.es_reverso = 'S' then
                raise_application_error(c_err_no_reversable, 'Un movimiento de reverso no se puede anular.');
            end if;
            if r_original.estado <> 'C' then
                raise_application_error(c_err_no_reversable, 'El movimiento ya fue anulado.');
            end if;
            if trim(i_motivo) is null then
                raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'Indique el motivo de la anulación.');
            end if;

            for r in (select deposito_id, producto_id, lote_id, deposito_ubicacion_id, cantidad,
                             costo_unitario, costo_unitario_reporte, origen_linea_id
                        from erp_stk_movimiento_item
                       where movimiento_id = i_movimiento_id
                       order by linea) loop
                t_items.extend;
                t_items(t_items.count) := erp_stk_mov_item_typ(
                                              deposito_id            => r.deposito_id,
                                              producto_id            => r.producto_id,
                                              cantidad               => -r.cantidad,
                                              lote_id                => r.lote_id,
                                              deposito_ubicacion_id  => r.deposito_ubicacion_id,
                                              costo_unitario         => r.costo_unitario,
                                              costo_unitario_reporte => r.costo_unitario_reporte,
                                              origen_linea_id        => r.origen_linea_id);
            end loop;

            iniciar_contexto(i_empresa_id => r_original.empresa_id, i_fecha => coalesce(i_fecha, current_date));
            g_ctx.es_reverso := true;
            select * into g_ctx.tipo from erp_stk_tipo_movimiento where tipo_movimiento_id = r_original.tipo_movimiento_id;
            g_ctx.tipo.debe_exigir_motivo := 'N';

            generar_interno(
                i_items                   => t_items,
                i_origen_modulo           => r_original.origen_modulo,
                i_origen_tabla            => r_original.origen_tabla,
                i_origen_id               => r_original.origen_id,
                i_motivo                  => i_motivo,
                i_observacion             => null,
                i_movimiento_id_reversado => i_movimiento_id,
                o_movimiento_id           => o_movimiento_id);
            erp_stk_movimiento_ctr.actualizar_estado(i_movimiento_id => i_movimiento_id, i_estado => 'R');
        exception
            when others then
                rollback to sp_erp_stk_movimiento;
                raise;
        end;
    end generar_reverso;

    procedure aplicar_reserva (
        i_empresa_id  in erp_stk_saldo.empresa_id%type,
        i_items       in erp_stk_mov_item_tab
    ) is
        t_saldos  erp_stk_saldo_ctr.t_saldo_mapa;
        r_item    erp_stk_mov_item_typ;
        v_clave   varchar2(80);
    begin
        savepoint sp_erp_stk_movimiento;
        begin
            if i_items is null or i_items.count = 0 then
                return;
            end if;
            iniciar_contexto(i_empresa_id => i_empresa_id, i_fecha => current_date);
            for i in 1 .. i_items.count loop
                r_item := i_items(i);
                r_item.cantidad := 0;
                if coalesce(r_item.reserva, 0) = 0 then
                    raise_application_error(erp_stk_comun_utl.c_err_dato_invalido, 'Indique la cantidad a reservar o liberar.');
                end if;
                validar_item(i_item => r_item, i_es_reserva => r_item.reserva > 0);
                agregar_clave(i_item => r_item, io_saldos => t_saldos);
            end loop;

            erp_stk_saldo_ctr.bloquear(io_saldos => t_saldos);

            for i in 1 .. i_items.count loop
                r_item := i_items(i);
                r_item.cantidad := 0;
                v_clave := erp_stk_saldo_ctr.obtener_clave(
                               i_deposito_id           => r_item.deposito_id,
                               i_producto_id           => r_item.producto_id,
                               i_lote_id               => r_item.lote_id,
                               i_deposito_ubicacion_id => r_item.deposito_ubicacion_id);
                aplicar_linea_saldo(i_item => r_item, io_saldo => t_saldos(v_clave));
            end loop;
            erp_stk_saldo_ctr.actualizar(i_saldos => t_saldos);
        exception
            when others then
                rollback to sp_erp_stk_movimiento;
                raise;
        end;
    end aplicar_reserva;

    function calcular_disponible (
        i_empresa_id             in erp_stk_saldo.empresa_id%type,
        i_deposito_id            in erp_stk_saldo.deposito_id%type,
        i_producto_id            in erp_stk_saldo.producto_id%type,
        i_lote_id                in erp_stk_saldo.lote_id%type               default null,
        i_deposito_ubicacion_id  in erp_stk_saldo.deposito_ubicacion_id%type default null
    ) return number is
        v_disponible  number;
    begin
        select coalesce(sum(s.cantidad - s.cantidad_reservada), 0)
          into v_disponible
          from erp_stk_saldo s
         where s.empresa_id    = i_empresa_id
           and s.deposito_id   = i_deposito_id
           and s.producto_id   = i_producto_id
           and s.es_disponible = 'S'
           and (i_lote_id is null or s.lote_id = i_lote_id)
           and (i_deposito_ubicacion_id is null or s.deposito_ubicacion_id = i_deposito_ubicacion_id)
           and not exists (select null
                             from erp_stk_deposito d
                            where d.deposito_id = s.deposito_id
                              and d.tipo = 'T');
        return v_disponible;
    end calcular_disponible;

    function calcular_metodo_costo (
        i_empresa_id    in number,
        i_metodo_costo  in erp_stk_producto.metodo_costo%type
    ) return varchar2 is
        v_metodo  varchar2(10);
    begin
        if i_metodo_costo is not null then
            return i_metodo_costo;
        end if;
        v_metodo := upper(erp_gen_parametro_api.obtener_texto(i_codigo     => 'ERP_STK_METODO_COSTO',
                                                               i_empresa_id => i_empresa_id,
                                                               i_defecto    => 'P'));
        return case when v_metodo = 'U' then 'U' else 'P' end;
    end calcular_metodo_costo;

end erp_stk_movimiento_reg;
/
