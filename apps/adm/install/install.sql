-- =============================================================================
-- Instalación de objetos ADM (SQLcl / SQL Developer, conectado al esquema del
-- workspace). Es la FUENTE de los Supporting Objects (tools/build-supporting-objects.ps1).
-- Ejecutar desde la carpeta apps/adm:   SQL> @install/install.sql
-- Orden de paquetes: utl -> ctr -> reg -> api (specs primero, luego bodies).
-- Los triggers de historial (trg_*_aiud) van después de los paquetes que usan.
-- =============================================================================
whenever sqlerror exit failure rollback
set define off

prompt == Tablas
@@../database/tables/adm_gen_empresa.sql
@@../database/tables/adm_seg_aplicacion.sql
@@../database/tables/adm_seg_modulo.sql
@@../database/tables/adm_seg_permiso.sql
@@../database/tables/adm_seg_rol.sql
@@../database/tables/adm_seg_rol_permiso.sql
@@../database/tables/adm_seg_usuario.sql
@@../database/tables/adm_seg_usuario_rol.sql
@@../database/tables/adm_aud_login.sql
@@../database/tables/adm_aud_error.sql
@@../database/tables/adm_gen_mensaje_error.sql
@@../database/tables/adm_aud_cambio.sql

prompt == Triggers
@@../database/triggers/trg_adm_emp_bu.sql
@@../database/triggers/trg_adm_apl_bu.sql
@@../database/triggers/trg_adm_mod_bu.sql
@@../database/triggers/trg_adm_per_bu.sql
@@../database/triggers/trg_adm_rol_bu.sql
@@../database/triggers/trg_adm_rope_bu.sql
@@../database/triggers/trg_adm_usu_bu.sql
@@../database/triggers/trg_adm_mse_bu.sql
@@../database/triggers/trg_adm_usro_bu.sql

prompt == Vistas
@@../database/views/adm_seg_usuario_permiso_v.sql
@@../database/views/adm_aud_cambio_v.sql
@@../database/views/adm_aud_cambio_det_v.sql

prompt == Paquetes (especificaciones)
@@../database/packages/adm_seg_password_utl.pks
@@../database/packages/adm_seg_usuario_ctr.pks
@@../database/packages/adm_seg_usuario_rol_ctr.pks
@@../database/packages/adm_aud_login_ctr.pks
@@../database/packages/adm_aud_error_ctr.pks
@@../database/packages/adm_gen_mensaje_error_ctr.pks
@@../database/packages/adm_seg_rol_ctr.pks
@@../database/packages/adm_seg_rol_permiso_ctr.pks
@@../database/packages/adm_seg_seguridad_reg.pks
@@../database/packages/adm_seg_usuario_reg.pks
@@../database/packages/adm_seg_usuario_api.pks
@@../database/packages/adm_seg_rol_api.pks
@@../database/packages/adm_gen_error_api.pks
@@../database/packages/adm_aud_cambio_utl.pks
@@../database/packages/adm_aud_cambio_ctr.pks
@@../database/packages/adm_aud_cambio_api.pks

prompt == Paquetes (cuerpos)
@@../database/packages/adm_seg_password_utl.pkb
@@../database/packages/adm_seg_usuario_ctr.pkb
@@../database/packages/adm_seg_usuario_rol_ctr.pkb
@@../database/packages/adm_aud_login_ctr.pkb
@@../database/packages/adm_aud_error_ctr.pkb
@@../database/packages/adm_gen_mensaje_error_ctr.pkb
@@../database/packages/adm_seg_rol_ctr.pkb
@@../database/packages/adm_seg_rol_permiso_ctr.pkb
@@../database/packages/adm_seg_seguridad_reg.pkb
@@../database/packages/adm_seg_usuario_reg.pkb
@@../database/packages/adm_seg_usuario_api.pkb
@@../database/packages/adm_seg_rol_api.pkb
@@../database/packages/adm_gen_error_api.pkb
@@../database/packages/adm_aud_cambio_utl.pkb
@@../database/packages/adm_aud_cambio_ctr.pkb
@@../database/packages/adm_aud_cambio_api.pkb

prompt == Triggers de historial
@@../database/triggers/trg_adm_cam_bud.sql
@@../database/triggers/trg_adm_emp_aiud.sql
@@../database/triggers/trg_adm_apl_aiud.sql
@@../database/triggers/trg_adm_mod_aiud.sql
@@../database/triggers/trg_adm_per_aiud.sql
@@../database/triggers/trg_adm_rol_aiud.sql
@@../database/triggers/trg_adm_rope_aiud.sql
@@../database/triggers/trg_adm_usu_aiud.sql
@@../database/triggers/trg_adm_usro_aiud.sql
@@../database/triggers/trg_adm_mse_aiud.sql

prompt == Jobs
@@../database/jobs/job_adm_purgar_cambio.sql

prompt == Datos iniciales
@@../database/data/adm_seg_datos_iniciales.sql
@@../database/data/adm_gen_mensajes_error.sql

prompt == Superadmin
@@../database/data/adm_seg_superadmin_bootstrap.sql

prompt == Objetos inválidos (debe estar vacío)
select object_name, object_type from user_objects
 where status = 'INVALID' and (object_name like 'ADM\_%' escape '\' or object_name like 'TRG\_ADM\_%' escape '\');

prompt == Instalación ADM completa. Siguiente paso (desde apps/adm): @database/data/adm_seg_password_admin.sql
