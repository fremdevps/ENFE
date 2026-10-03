create or replace package adm_aud_login_ctr
    authid definer
    accessible by (package adm_seg_seguridad_reg)
as
-- =============================================================================
-- Paquete : adm_aud_login_ctr   (capa ctr)
-- Tabla   : adm_aud_login
-- Desc    : Bitácora de logins. insertar es AUTÓNOMO: queda registrado aunque
--           el intento de login se rechace.
-- =============================================================================

    procedure insertar (
        i_username   in adm_aud_login.username%type,
        i_resultado  in adm_aud_login.resultado%type
    );

end adm_aud_login_ctr;
/
