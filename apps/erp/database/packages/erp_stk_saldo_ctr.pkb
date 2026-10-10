create or replace package body erp_stk_saldo_ctr
as

    type t_numero_tab is table of number index by pls_integer;
    type t_fecha_tab  is table of date index by pls_integer;

    function obtener_clave (
        i_deposito_id            in erp_stk_saldo.deposito_id%type,
        i_producto_id            in erp_stk_saldo.producto_id%type,
        i_lote_id                in erp_stk_saldo.lote_id%type,
        i_deposito_ubicacion_id  in erp_stk_saldo.deposito_ubicacion_id%type
    ) return varchar2 is
    begin
        -- Ancho fijo: el orden alfabético de la clave es el orden numérico.
        return to_char(i_deposito_id, 'fm0000000000000000000')
            || to_char(i_producto_id, 'fm0000000000000000000')
            || to_char(coalesce(i_lote_id, 0), 'fm0000000000000000000')
            || to_char(coalesce(i_deposito_ubicacion_id, 0), 'fm0000000000000000000');
    end obtener_clave;

    function bloquear_fila (
        i_saldo  in erp_stk_saldo%rowtype
    ) return erp_stk_saldo%rowtype is
        r_saldo  erp_stk_saldo%rowtype;
    begin
        select *
          into r_saldo
          from erp_stk_saldo
         where empresa_id  = i_saldo.empresa_id
           and deposito_id = i_saldo.deposito_id
           and producto_id = i_saldo.producto_id
           and coalesce(lote_id, 0) = coalesce(i_saldo.lote_id, 0)
           and coalesce(deposito_ubicacion_id, 0) = coalesce(i_saldo.deposito_ubicacion_id, 0)
           for update;
        return r_saldo;
    end bloquear_fila;

    procedure bloquear (
        io_saldos  in out nocopy t_saldo_mapa
    ) is
        v_clave  varchar2(80) := io_saldos.first;
        r_saldo  erp_stk_saldo%rowtype;
    begin
        while v_clave is not null loop
            r_saldo := io_saldos(v_clave);
            begin
                io_saldos(v_clave) := bloquear_fila(i_saldo => r_saldo);
            exception
                when no_data_found then
                    begin
                        insert into erp_stk_saldo (empresa_id, deposito_id, producto_id, lote_id, deposito_ubicacion_id,
                                                   cantidad, cantidad_reservada, costo_promedio, costo_promedio_reporte,
                                                   es_disponible)
                        values (r_saldo.empresa_id, r_saldo.deposito_id, r_saldo.producto_id, r_saldo.lote_id,
                                r_saldo.deposito_ubicacion_id, 0, 0, 0, 0, coalesce(r_saldo.es_disponible, 'S'));
                    exception
                        when dup_val_on_index then
                            null;   -- otra sesión la creó mientras esperábamos: se bloquea abajo
                    end;
                    io_saldos(v_clave) := bloquear_fila(i_saldo => r_saldo);
            end;
            v_clave := io_saldos.next(v_clave);
        end loop;
    end bloquear;

    procedure actualizar (
        i_saldos  in t_saldo_mapa
    ) is
        v_clave      varchar2(80) := i_saldos.first;
        v_n          pls_integer := 0;
        t_id         t_numero_tab;
        t_cantidad   t_numero_tab;
        t_reservada  t_numero_tab;
        t_costo      t_numero_tab;
        t_costo_rep  t_numero_tab;
        t_fecha      t_fecha_tab;
    begin
        while v_clave is not null loop
            v_n := v_n + 1;
            t_id(v_n)        := i_saldos(v_clave).saldo_id;
            t_cantidad(v_n)  := i_saldos(v_clave).cantidad;
            t_reservada(v_n) := i_saldos(v_clave).cantidad_reservada;
            t_costo(v_n)     := i_saldos(v_clave).costo_promedio;
            t_costo_rep(v_n) := i_saldos(v_clave).costo_promedio_reporte;
            t_fecha(v_n)     := i_saldos(v_clave).fecha_ultimo_movimiento;
            v_clave := i_saldos.next(v_clave);
        end loop;

        forall i in 1 .. v_n
            update erp_stk_saldo
               set cantidad                = t_cantidad(i),
                   cantidad_reservada      = t_reservada(i),
                   costo_promedio          = t_costo(i),
                   costo_promedio_reporte  = t_costo_rep(i),
                   fecha_ultimo_movimiento = t_fecha(i)
             where saldo_id = t_id(i);
    end actualizar;

end erp_stk_saldo_ctr;
/
