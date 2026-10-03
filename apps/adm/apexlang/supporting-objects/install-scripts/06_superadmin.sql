-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/data/adm_seg_superadmin_bootstrap.sql
-- =============================================================================
-- Superadmin permanente: garantiza que en TODA instalación exista el usuario
-- ADMIN con rol SUPERADMIN (acceso total a todas las apps).
-- - Idempotente: si ya existe, solo asegura el rol y que esté activo.
-- - Se crea con una contraseña ALEATORIA que nadie conoce y debe_cambiar = 'S'.
--   Quien hace el deploy fija la contraseña inicial con
--   apps/adm/database/data/adm_seg_password_admin.sql
-- =============================================================================
declare
    C_USERNAME  constant varchar2(30) := 'ADMIN';
    V_USUARIO_ID  adm_seg_usuario.usuario_id%type;
    V_ROL_ID      adm_seg_rol.rol_id%type;
begin
    select rol_id into V_ROL_ID from adm_seg_rol where codigo = 'SUPERADMIN';

    begin
        select usuario_id into V_USUARIO_ID from adm_seg_usuario where username = C_USERNAME;
        update adm_seg_usuario set estado = 'A' where usuario_id = V_USUARIO_ID and estado <> 'A';
    exception
        when no_data_found then
            adm_usuario_ctr.P_INSERTAR(
                I_USERNAME   => C_USERNAME,
                I_EMAIL      => 'admin@localhost',
                I_NOMBRES    => 'Super',
                I_APELLIDOS  => 'Administrador',
                I_PASSWORD   => 'Aa1' || dbms_random.string('x', 29),
                O_USUARIO_ID => V_USUARIO_ID);
    end;

    adm_usuario_ctr.P_ASIGNAR_ROL(I_USUARIO_ID => V_USUARIO_ID, I_ROL_ID => V_ROL_ID);
    commit;
end;
/
