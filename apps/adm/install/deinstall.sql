-- =============================================================================
-- DESINSTALACIÓN de objetos ADM. ¡Borra TODOS los usuarios, roles y permisos!
-- Solo para desarrollo. Las demás apps dependen de estos objetos.
-- =============================================================================
drop package adm_seg_usuario_api;
drop package adm_seg_usuario_reg;
drop package adm_seg_seguridad_reg;
drop package adm_aud_login_ctr;
drop package adm_seg_usuario_rol_ctr;
drop package adm_seg_usuario_ctr;
drop package adm_seg_password_utl;
drop view    adm_seg_usuario_permiso_v;
drop table   adm_aud_login purge;
drop table   adm_seg_usuario_rol purge;
drop table   adm_seg_usuario purge;
drop table   adm_seg_rol_permiso purge;
drop table   adm_seg_rol purge;
drop table   adm_seg_permiso purge;
drop table   adm_seg_modulo purge;
drop table   adm_seg_aplicacion purge;
drop table   adm_gen_empresa purge;
