-- =============================================================================
-- DESINSTALACIÓN de objetos ADM. ¡Borra TODOS los usuarios, roles y permisos!
-- Solo para desarrollo. Las demás apps dependen de estos objetos.
-- =============================================================================
begin
    dbms_scheduler.drop_job(job_name => '"' || sys_context('userenv', 'current_schema') || '".JOB_ADM_PURGAR_CAMBIO', force => true);
exception
    when others then
        null;   -- el job no existe
end;
/
drop package adm_aud_cambio_api;
drop package adm_aud_cambio_ctr;
drop package adm_aud_cambio_utl;
drop package adm_gen_error_api;
drop package adm_gen_mensaje_error_ctr;
drop package adm_aud_error_ctr;
drop package adm_seg_rol_api;
drop package adm_seg_rol_permiso_ctr;
drop package adm_seg_rol_ctr;
drop package adm_seg_usuario_api;
drop package adm_seg_usuario_reg;
drop package adm_seg_seguridad_reg;
drop package adm_aud_login_ctr;
drop package adm_seg_usuario_rol_ctr;
drop package adm_seg_usuario_ctr;
drop package adm_seg_password_utl;
drop view    adm_aud_cambio_det_v;
drop view    adm_aud_cambio_v;
drop view    adm_seg_usuario_permiso_v;
drop table   adm_aud_cambio purge;
drop table   adm_gen_mensaje_error purge;
drop table   adm_aud_error purge;
drop table   adm_aud_login purge;
drop table   adm_seg_usuario_rol purge;
drop table   adm_seg_usuario purge;
drop table   adm_seg_rol_permiso purge;
drop table   adm_seg_rol purge;
drop table   adm_seg_permiso purge;
drop table   adm_seg_modulo purge;
drop table   adm_seg_aplicacion purge;
drop table   adm_gen_empresa purge;
