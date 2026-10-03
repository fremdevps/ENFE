create or replace package adm_usuario_ctr
authid definer
as
-- =============================================================================
-- Paquete : adm_usuario_ctr
-- Tipo    : ctr (Control - DML y persistencia)
-- Desc    : Altas, cambios, contraseñas y asignación de roles de usuarios.
-- =============================================================================

    procedure P_INSERTAR (
        I_USERNAME              in  varchar2,
        I_EMAIL                 in  varchar2,
        I_NOMBRES               in  varchar2,
        I_APELLIDOS             in  varchar2 default null,
        I_TIPO_AUTENTICACION    in  varchar2 default 'LOCAL',
        I_PASSWORD              in  varchar2 default null,
        I_EMPRESA_ID_DEFECTO    in  number   default null,
        O_USUARIO_ID            out number
    );

    procedure P_ACTUALIZAR (
        I_USUARIO_ID            in number,
        I_EMAIL                 in varchar2,
        I_NOMBRES               in varchar2,
        I_APELLIDOS             in varchar2,
        I_EMPRESA_ID_DEFECTO    in number,
        I_ESTADO                in varchar2
    );

    -- I_DEBE_CAMBIAR = 'S' cuando lo resetea un administrador.
    procedure P_CAMBIAR_PASSWORD (
        I_USUARIO_ID        in number,
        I_PASSWORD_NUEVO    in varchar2,
        I_DEBE_CAMBIAR      in varchar2 default 'S'
    );

    procedure P_DESBLOQUEAR (
        I_USUARIO_ID  in number
    );

    procedure P_ASIGNAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null,
        I_FECHA_DESDE   in date   default trunc(sysdate),
        I_FECHA_HASTA   in date   default null
    );

    procedure P_QUITAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null
    );

end adm_usuario_ctr;
/
