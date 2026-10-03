-- =============================================================================
-- Instalación manual de objetos ADM (SQLcl / SQL Developer, conectado al
-- esquema del workspace). Es el MISMO orden que usan los Supporting Objects
-- de la app APEX. Ejecutar desde la carpeta apps/adm:
--     SQL> @install/install.sql
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

prompt == Triggers
@@../database/triggers/trg_adm_gen_empresa_bu.sql
@@../database/triggers/trg_adm_seg_aplicacion_bu.sql
@@../database/triggers/trg_adm_seg_modulo_bu.sql
@@../database/triggers/trg_adm_seg_permiso_bu.sql
@@../database/triggers/trg_adm_seg_rol_bu.sql
@@../database/triggers/trg_adm_seg_rol_permiso_bu.sql
@@../database/triggers/trg_adm_seg_usuario_bu.sql
@@../database/triggers/trg_adm_seg_usuario_rol_bu.sql

prompt == Vistas
@@../database/views/adm_seg_usuario_permiso_v.sql

prompt == Paquetes
@@../database/packages/adm_seguridad_reg.pks
@@../database/packages/adm_usuario_ctr.pks
@@../database/packages/adm_seguridad_reg.pkb
@@../database/packages/adm_usuario_ctr.pkb

prompt == Datos iniciales
@@../database/data/adm_seg_datos_iniciales.sql

prompt == Superadmin
@@../database/data/adm_seg_superadmin_bootstrap.sql

prompt == Objetos inválidos (debe estar vacío)
select object_name, object_type from user_objects
 where status = 'INVALID' and object_name like 'ADM\_%' escape '\';

prompt == Instalación ADM completa. Siguiente paso: @../database/data/adm_seg_password_admin.sql
