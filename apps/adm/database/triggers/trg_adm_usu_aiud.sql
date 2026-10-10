-- =============================================================================
-- Trigger : trg_adm_usu_aiud
-- Tabla   : adm_seg_usuario
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_usuario _ intentos_fallidos,fecha_ultimo_login _
-- Reservadas (solo se registra que cambiaron): password_hash, password_salt
-- No auditadas: usuario_id (PK: va en registro_id), intentos_fallidos (excluida), fecha_ultimo_login (excluida) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_usu_aiud
    for insert or update or delete on adm_seg_usuario
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'username',                       :old.username, :new.username);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'email',                          :old.email, :new.email);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombres',                        :old.nombres, :new.nombres);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'apellidos',                      :old.apellidos, :new.apellidos);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'tipo_autenticacion',             :old.tipo_autenticacion, :new.tipo_autenticacion);
        if (:old.password_hash is null and :new.password_hash is not null)
           or (:old.password_hash is not null and :new.password_hash is null)
           or :old.password_hash <> :new.password_hash then
            adm_aud_cambio_utl.agregar_reservado(v_detalle, 'password_hash');
        end if;
        if (:old.password_salt is null and :new.password_salt is not null)
           or (:old.password_salt is not null and :new.password_salt is null)
           or :old.password_salt <> :new.password_salt then
            adm_aud_cambio_utl.agregar_reservado(v_detalle, 'password_salt');
        end if;
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'debe_cambiar_password',          :old.debe_cambiar_password, :new.debe_cambiar_password);
        adm_aud_cambio_utl.agregar_fecha_hora_tz(v_detalle,  'fecha_cambio_password',          :old.fecha_cambio_password, :new.fecha_cambio_password);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'empresa_id_defecto',             :old.empresa_id_defecto, :new.empresa_id_defecto);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_USUARIO',
            i_registro_id       => coalesce(:new.usuario_id, :old.usuario_id),
            i_registro_padre_id => null,
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_usu_aiud;
/
