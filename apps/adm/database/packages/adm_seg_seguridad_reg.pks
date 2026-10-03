create or replace package adm_seg_seguridad_reg
    authid definer
as
-- =============================================================================
-- Paquete : adm_seg_seguridad_reg   (capa reg)
-- Desc    : Autenticación y autorización central de TODAS las apps APEX.
--           Excepción documentada (ESTANDAR §4.1): APEX lo invoca directamente
--           desde el esquema de autenticación y los authorization schemes.
-- =============================================================================

    c_max_intentos  constant pls_integer := 5;

    -- Authentication Function de APEX. EXCEPCIÓN AL ESTÁNDAR: APEX la invoca con
    -- los nombres fijos p_username / p_password.
    function autenticar (
        p_username  in varchar2,
        p_password  in varchar2
    ) return boolean;

    function es_superadmin (
        i_username  in varchar2
    ) return boolean;

    function tiene_acceso_app (
        i_username     in varchar2,
        i_apex_app_id  in number
    ) return boolean;

    function tiene_permiso (
        i_username        in varchar2,
        i_permiso_codigo  in varchar2,
        i_empresa_id      in number default null
    ) return boolean;

    function tiene_acceso_pagina (
        i_username        in varchar2,
        i_apex_app_id     in number,
        i_apex_pagina_id  in number
    ) return boolean;

    function debe_cambiar_password (
        i_username  in varchar2
    ) return boolean;

end adm_seg_seguridad_reg;
/
