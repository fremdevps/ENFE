-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/triggers/trg_adm_cam_bud.sql
-- =============================================================================
-- Trigger : trg_adm_cam_bud
-- Tabla   : adm_aud_cambio
-- Desc    : Before Update/Delete (sentencia) - el historial es de solo inserción.
--           Rechaza todo update y todo delete que no sea la purga por retención
--           (adm_aud_cambio_api.purgar -> adm_aud_cambio_ctr.eliminar_anteriores).
-- =============================================================================
create or replace trigger trg_adm_cam_bud
    before update or delete on adm_aud_cambio
begin
    if updating or not adm_aud_cambio_ctr.es_purga_activa then
        raise_application_error(adm_aud_cambio_ctr.c_err_inmutable,
            'El historial de cambios no se puede modificar ni eliminar.');
    end if;
end trg_adm_cam_bud;
/

-- >>> apps/adm/database/triggers/trg_adm_emp_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_emp_aiud
-- Tabla   : adm_gen_empresa
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_gen_empresa _ _ _
-- No auditadas: empresa_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_emp_aiud
    for insert or update or delete on adm_gen_empresa
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'razon_social',                   :old.razon_social, :new.razon_social);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre_comercial',               :old.nombre_comercial, :new.nombre_comercial);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nro_documento',                  :old.nro_documento, :new.nro_documento);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'zona_horaria',                   :old.zona_horaria, :new.zona_horaria);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_GEN_EMPRESA',
            i_registro_id       => coalesce(:new.empresa_id, :old.empresa_id),
            i_registro_padre_id => null,
            i_empresa_id        => coalesce(:new.empresa_id, :old.empresa_id),
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_emp_aiud;
/

-- >>> apps/adm/database/triggers/trg_adm_apl_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_apl_aiud
-- Tabla   : adm_seg_aplicacion
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_aplicacion _ _ _
-- No auditadas: aplicacion_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_apl_aiud
    for insert or update or delete on adm_seg_aplicacion
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre',                         :old.nombre, :new.nombre);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'descripcion',                    :old.descripcion, :new.descripcion);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'apex_app_id',                    :old.apex_app_id, :new.apex_app_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'icono',                          :old.icono, :new.icono);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'orden',                          :old.orden, :new.orden);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_APLICACION',
            i_registro_id       => coalesce(:new.aplicacion_id, :old.aplicacion_id),
            i_registro_padre_id => null,
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_apl_aiud;
/

-- >>> apps/adm/database/triggers/trg_adm_mod_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_mod_aiud
-- Tabla   : adm_seg_modulo
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_modulo aplicacion_id _ _
-- No auditadas: modulo_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_mod_aiud
    for insert or update or delete on adm_seg_modulo
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'aplicacion_id',                  :old.aplicacion_id, :new.aplicacion_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre',                         :old.nombre, :new.nombre);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'descripcion',                    :old.descripcion, :new.descripcion);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'icono',                          :old.icono, :new.icono);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'orden',                          :old.orden, :new.orden);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_MODULO',
            i_registro_id       => coalesce(:new.modulo_id, :old.modulo_id),
            i_registro_padre_id => coalesce(:new.aplicacion_id, :old.aplicacion_id),
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_mod_aiud;
/

-- >>> apps/adm/database/triggers/trg_adm_per_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_per_aiud
-- Tabla   : adm_seg_permiso
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_permiso modulo_id _ _
-- No auditadas: permiso_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_per_aiud
    for insert or update or delete on adm_seg_permiso
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'modulo_id',                      :old.modulo_id, :new.modulo_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre',                         :old.nombre, :new.nombre);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'descripcion',                    :old.descripcion, :new.descripcion);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'tipo',                           :old.tipo, :new.tipo);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'apex_pagina_id',                 :old.apex_pagina_id, :new.apex_pagina_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_PERMISO',
            i_registro_id       => coalesce(:new.permiso_id, :old.permiso_id),
            i_registro_padre_id => coalesce(:new.modulo_id, :old.modulo_id),
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_per_aiud;
/

-- >>> apps/adm/database/triggers/trg_adm_rol_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_rol_aiud
-- Tabla   : adm_seg_rol
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_rol _ _ _
-- No auditadas: rol_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_rol_aiud
    for insert or update or delete on adm_seg_rol
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'aplicacion_id',                  :old.aplicacion_id, :new.aplicacion_id);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'nombre',                         :old.nombre, :new.nombre);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'descripcion',                    :old.descripcion, :new.descripcion);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'es_superadmin',                  :old.es_superadmin, :new.es_superadmin);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'estado',                         :old.estado, :new.estado);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_ROL',
            i_registro_id       => coalesce(:new.rol_id, :old.rol_id),
            i_registro_padre_id => null,
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_rol_aiud;
/

-- >>> apps/adm/database/triggers/trg_adm_rope_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_rope_aiud
-- Tabla   : adm_seg_rol_permiso
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_rol_permiso rol_id _ _
-- No auditadas: rol_permiso_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_rope_aiud
    for insert or update or delete on adm_seg_rol_permiso
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'rol_id',                         :old.rol_id, :new.rol_id);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'permiso_id',                     :old.permiso_id, :new.permiso_id);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_ROL_PERMISO',
            i_registro_id       => coalesce(:new.rol_permiso_id, :old.rol_permiso_id),
            i_registro_padre_id => coalesce(:new.rol_id, :old.rol_id),
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);

        -- La tabla tiene una FK on delete cascade: cuando el cambio llega desde la tabla padre
        -- no se ejecuta "after statement", así que se inserta en el momento.
        if deleting then
            adm_aud_cambio_api.registrar(io_cambios => v_cambios);
        end if;
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_rope_aiud;
/

-- >>> apps/adm/database/triggers/trg_adm_usu_aiud.sql
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

-- >>> apps/adm/database/triggers/trg_adm_usro_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_usro_aiud
-- Tabla   : adm_seg_usuario_rol
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_seg_usuario_rol usuario_id _ _
-- No auditadas: usuario_rol_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_usro_aiud
    for insert or update or delete on adm_seg_usuario_rol
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'usuario_id',                     :old.usuario_id, :new.usuario_id);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'rol_id',                         :old.rol_id, :new.rol_id);
        adm_aud_cambio_utl.agregar_numero(v_detalle,         'empresa_id',                     :old.empresa_id, :new.empresa_id);
        adm_aud_cambio_utl.agregar_fecha(v_detalle,          'fecha_desde',                    :old.fecha_desde, :new.fecha_desde);
        adm_aud_cambio_utl.agregar_fecha(v_detalle,          'fecha_hasta',                    :old.fecha_hasta, :new.fecha_hasta);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_SEG_USUARIO_ROL',
            i_registro_id       => coalesce(:new.usuario_rol_id, :old.usuario_rol_id),
            i_registro_padre_id => coalesce(:new.usuario_id, :old.usuario_id),
            i_empresa_id        => coalesce(:new.empresa_id, :old.empresa_id),
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);

        -- La tabla tiene una FK on delete cascade: cuando el cambio llega desde la tabla padre
        -- no se ejecuta "after statement", así que se inserta en el momento.
        if deleting then
            adm_aud_cambio_api.registrar(io_cambios => v_cambios);
        end if;
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_usro_aiud;
/

-- >>> apps/adm/database/triggers/trg_adm_mse_aiud.sql
-- =============================================================================
-- Trigger : trg_adm_mse_aiud
-- Tabla   : adm_gen_mensaje_error
-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).
--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):
--             @tools/db/generar_trigger_historial.sql adm_gen_mensaje_error _ _ _
-- No auditadas: mensaje_error_id (PK: va en registro_id) y las columnas de auditoría.
-- =============================================================================
create or replace trigger trg_adm_mse_aiud
    for insert or update or delete on adm_gen_mensaje_error
    compound trigger

    v_cambios  adm_aud_cambio_api.t_cambios;

    after each row is
        v_detalle  json_array_t := json_array_t();
    begin
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'codigo',                         :old.codigo, :new.codigo);
        adm_aud_cambio_utl.agregar_texto(v_detalle,          'mensaje',                        :old.mensaje, :new.mensaje);

        adm_aud_cambio_api.agregar(
            io_cambios          => v_cambios,
            i_app_codigo        => 'ADM',
            i_tabla             => 'ADM_GEN_MENSAJE_ERROR',
            i_registro_id       => coalesce(:new.mensaje_error_id, :old.mensaje_error_id),
            i_registro_padre_id => null,
            i_empresa_id        => null,
            i_operacion         => case when inserting then 'I' when updating then 'U' else 'D' end,
            i_detalle           => v_detalle);
    end after each row;

    after statement is
    begin
        adm_aud_cambio_api.registrar(io_cambios => v_cambios);
    end after statement;

end trg_adm_mse_aiud;
/
