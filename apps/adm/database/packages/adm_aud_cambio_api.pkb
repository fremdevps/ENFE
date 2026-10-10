create or replace package body adm_aud_cambio_api
as

    e_json_muy_grande  exception;
    pragma exception_init(e_json_muy_grande, -40478);

    procedure agregar (
        io_cambios           in out nocopy t_cambios,
        i_app_codigo         in adm_aud_cambio.app_codigo%type,
        i_tabla              in adm_aud_cambio.tabla%type,
        i_registro_id        in adm_aud_cambio.registro_id%type,
        i_registro_padre_id  in adm_aud_cambio.registro_padre_id%type,
        i_empresa_id         in adm_aud_cambio.empresa_id%type,
        i_operacion          in adm_aud_cambio.operacion%type,
        i_detalle            in json_array_t
    ) is
        r_cambio  adm_aud_cambio_ctr.t_cambio;
    begin
        if i_detalle is null or i_detalle.get_size = 0 then
            return;
        end if;

        r_cambio.app_codigo        := i_app_codigo;
        r_cambio.tabla             := i_tabla;
        r_cambio.registro_id       := i_registro_id;
        r_cambio.registro_padre_id := i_registro_padre_id;
        r_cambio.empresa_id        := i_empresa_id;
        r_cambio.operacion         := i_operacion;

        begin
            r_cambio.cambios := i_detalle.to_string;
        exception
            when e_json_muy_grande then
                -- Más de 32767 bytes: se inserta sola, como CLOB
                adm_aud_cambio_ctr.insertar(i_cambio => r_cambio, i_cambios => i_detalle.to_clob);
                return;
        end;

        io_cambios(io_cambios.count + 1) := r_cambio;
        if io_cambios.count >= c_filas_lote then
            registrar(io_cambios => io_cambios);
        end if;
    end agregar;

    procedure registrar (
        io_cambios  in out nocopy t_cambios
    ) is
    begin
        adm_aud_cambio_ctr.insertar_lote(i_cambios => io_cambios);
        io_cambios.delete;
    end registrar;

    procedure purgar (
        i_meses_retencion  in  number default c_meses_retencion,
        o_filas            out number
    ) is
    begin
        if i_meses_retencion is null or i_meses_retencion < 1 or i_meses_retencion <> trunc(i_meses_retencion) then
            raise_application_error(c_err_retencion,
                'La retención del historial de cambios debe ser un número entero de meses, mínimo 1.');
        end if;

        adm_aud_cambio_ctr.eliminar_anteriores(
            i_fecha_limite => add_months(trunc(sysdate, 'MM'), -i_meses_retencion),
            o_filas        => o_filas);
    end purgar;

    procedure ejecutar_purga (
        i_meses_retencion  in number default c_meses_retencion
    ) is
        v_filas  number;
    begin
        purgar(i_meses_retencion => i_meses_retencion, o_filas => v_filas);
        commit;
    exception
        when others then
            rollback;
            adm_gen_error_api.registrar(i_componente => 'adm_aud_cambio_api.ejecutar_purga');
            raise;
    end ejecutar_purga;

end adm_aud_cambio_api;
/
