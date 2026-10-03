create or replace package adm_seg_usuario_reg
    authid definer
as
-- =============================================================================
-- Paquete : adm_seg_usuario_reg   (capa reg)
-- Desc    : Reglas de negocio de usuarios.
-- =============================================================================

    c_err_password_actual  constant pls_integer := -20011;
    c_err_password_igual   constant pls_integer := -20012;
    c_err_no_local         constant pls_integer := -20013;
    c_err_confirmacion     constant pls_integer := -20014;

    -- Valida un cambio de contraseña hecho por el propio usuario.
    procedure validar_cambio_password (
        i_usuario_id        in adm_seg_usuario.usuario_id%type,
        i_password_actual   in varchar2,
        i_password_nuevo    in varchar2,
        i_password_confirma in varchar2
    );

    -- Valida que el usuario use autenticación local (tiene contraseña propia).
    procedure validar_es_local (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    );

end adm_seg_usuario_reg;
/
