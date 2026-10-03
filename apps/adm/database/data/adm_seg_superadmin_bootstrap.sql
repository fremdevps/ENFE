-- =============================================================================
-- Superadmin permanente: garantiza que en TODA instalación exista el usuario
-- ADMIN con rol SUPERADMIN (acceso total a todas las apps).
-- - Idempotente: si ya existe, solo asegura que esté activo y con el rol.
-- - Se crea con una contraseña ALEATORIA que nadie conoce y debe cambiarla.
--   Quien hace el deploy fija la contraseña inicial con
--   apps/adm/database/data/adm_seg_password_admin.sql
-- =============================================================================
declare
    c_username    constant varchar2(30) := 'ADMIN';
    v_usuario_id  adm_seg_usuario.usuario_id%type;
    v_rol_id      adm_seg_rol.rol_id%type;
begin
    select rol_id into v_rol_id from adm_seg_rol where codigo = 'SUPERADMIN';

    begin
        select usuario_id into v_usuario_id from adm_seg_usuario where username = c_username;
        adm_seg_usuario_api.desbloquear(i_usuario_id => v_usuario_id);
    exception
        when no_data_found then
            adm_seg_usuario_api.crear(
                i_username   => c_username,
                i_email      => 'admin@localhost',
                i_nombres    => 'Super',
                i_apellidos  => 'Administrador',
                i_password   => 'Aa1' || dbms_random.string('x', 29),
                o_usuario_id => v_usuario_id);
    end;

    adm_seg_usuario_api.asignar_rol(i_usuario_id => v_usuario_id, i_rol_id => v_rol_id);
    commit;
end;
/
