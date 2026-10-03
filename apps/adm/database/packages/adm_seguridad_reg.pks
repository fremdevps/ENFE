create or replace package adm_seguridad_reg
authid definer
as
-- =============================================================================
-- Paquete : adm_seguridad_reg
-- Tipo    : reg (Reglas de negocio)
-- Desc    : Autenticación y autorización centralizada para TODAS las apps APEX.
--           - F_AUTENTICAR      -> Authentication Function (esquema Custom)
--           - F_TIENE_*         -> Authorization Schemes de cada app
-- Requiere: grant execute on dbms_crypto to <esquema>  (ver db/install/00_grants_admin.sql)
-- =============================================================================

    C_MAX_INTENTOS  constant pls_integer := 5;

    -- Password ----------------------------------------------------------------
    function F_GENERAR_SALT return raw;

    function F_HASH_PASSWORD (
        I_PASSWORD  in varchar2,
        I_SALT      in raw
    ) return raw;

    -- Lanza ORA-20010 si la contraseña no cumple la política.
    procedure P_VALIDAR_POLITICA_PASSWORD (
        I_PASSWORD  in varchar2
    );

    -- Cambio de contraseña por el propio usuario (valida la actual).
    procedure P_CAMBIAR_PASSWORD_USUARIO (
        I_USERNAME          in varchar2,
        I_PASSWORD_ACTUAL   in varchar2,
        I_PASSWORD_NUEVO    in varchar2
    );

    -- Autenticación -----------------------------------------------------------
    -- EXCEPCIÓN AL ESTÁNDAR: APEX invoca la función con los nombres fijos
    -- p_username / p_password, por eso no usan el prefijo I_.
    function F_AUTENTICAR (
        p_username  in varchar2,
        p_password  in varchar2
    ) return boolean;

    -- Autorización ------------------------------------------------------------
    function F_ES_SUPERADMIN (
        I_USERNAME  in varchar2
    ) return boolean;

    function F_TIENE_ACCESO_APP (
        I_USERNAME      in varchar2,
        I_APEX_APP_ID   in number
    ) return boolean;

    function F_TIENE_PERMISO (
        I_USERNAME          in varchar2,
        I_PERMISO_CODIGO    in varchar2,
        I_EMPRESA_ID        in number default null
    ) return boolean;

    function F_TIENE_ACCESO_PAGINA (
        I_USERNAME          in varchar2,
        I_APEX_APP_ID       in number,
        I_APEX_PAGINA_ID    in number
    ) return boolean;

    function F_DEBE_CAMBIAR_PASSWORD (
        I_USERNAME  in varchar2
    ) return boolean;

end adm_seguridad_reg;
/
