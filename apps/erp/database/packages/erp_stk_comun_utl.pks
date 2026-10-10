create or replace package erp_stk_comun_utl
    authid definer
as
-- =============================================================================
-- Paquete : erp_stk_comun_utl   (capa utl)
-- Desc    : Utilitarios comunes del módulo de inventario: usuario de la
--           operación, verificación de permisos de ADM y errores compartidos.
--           Rango de errores de stk: -20160 … -20179 (docs/arquitectura-erp.md §10).
-- =============================================================================

    c_err_dato_invalido  constant pls_integer := -20160;
    c_err_sin_permiso    constant pls_integer := -20161;
    c_err_no_existe      constant pls_integer := -20179;

    -- Usuario de la sesión APEX. Fuera de APEX (jobs, REST, pruebas) devuelve el
    -- indicado con asignar_usuario, o null si no se indicó ninguno.
    function obtener_usuario return varchar2;

    -- Igual que obtener_usuario pero nunca null (usuario de base de datos).
    function obtener_usuario_auditoria return varchar2;

    -- Indica el usuario de negocio de una ejecución sin sesión APEX. Dentro de
    -- una sesión APEX no tiene efecto: siempre manda APP_USER.
    procedure asignar_usuario (
        i_username  in varchar2
    );

    -- Lanza c_err_sin_permiso si el usuario no tiene el permiso en la empresa.
    -- Sin usuario (job o script del propio esquema) no se verifica.
    procedure validar_permiso (
        i_permiso     in varchar2,
        i_empresa_id  in number
    );

end erp_stk_comun_utl;
/
