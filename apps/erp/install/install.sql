-- =============================================================================
-- Instalación de objetos ERP. Requiere ADM instalado previamente.
-- Mismo orden que los Supporting Objects de la app APEX ERP.
--     SQL> @install/install.sql   (desde apps/erp)
-- =============================================================================
whenever sqlerror exit failure rollback
set define off

prompt == Registro en seguridad central
@@../database/data/erp_seg_registro.sql

prompt == Instalación ERP completa
