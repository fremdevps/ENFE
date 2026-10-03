-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/packages/adm_seg_password_utl.pks
create or replace package adm_seg_password_utl
    authid definer
as
-- =============================================================================
-- Paquete : adm_seg_password_utl   (capa utl)
-- Desc    : Hash y política de contraseñas. Sin acceso a tablas.
--           PBKDF2-HMAC-SHA512 (1 bloque de 64 bytes) + salt aleatorio de 32 bytes.
-- Requiere: grant execute on dbms_crypto (install/00_prerequisitos_dba.sql)
-- =============================================================================

    c_err_politica  constant pls_integer := -20010;

    function generar_salt return raw;

    function calcular_hash (
        i_password  in varchar2,
        i_salt      in raw
    ) return raw;

    -- NULL-safe: password, salt o hash nulos nunca validan.
    function es_valido (
        i_password  in varchar2,
        i_salt      in raw,
        i_hash      in raw
    ) return boolean;

    -- Lanza c_err_politica si la contraseña no cumple la política.
    procedure validar_politica (
        i_password  in varchar2
    );

end adm_seg_password_utl;
/

-- >>> apps/adm/database/packages/adm_seg_usuario_ctr.pks
create or replace package adm_seg_usuario_ctr
    authid definer
    accessible by (package adm_seg_usuario_api,
                   package adm_seg_usuario_reg,
                   package adm_seg_seguridad_reg)
as
-- =============================================================================
-- Paquete : adm_seg_usuario_ctr   (capa ctr)
-- Tabla   : adm_seg_usuario
-- Desc    : DML de usuarios. No valida reglas ni hace COMMIT
--           (excepción: actualizar_intentos es autónomo, ver comentario).
-- =============================================================================

    c_err_no_existe  constant pls_integer := -20020;

    function obtener (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    ) return adm_seg_usuario%rowtype;

    -- Devuelve null en usuario_id si no existe.
    function obtener_por_username (
        i_username  in adm_seg_usuario.username%type
    ) return adm_seg_usuario%rowtype;

    procedure insertar (
        i_username               in  adm_seg_usuario.username%type,
        i_email                  in  adm_seg_usuario.email%type,
        i_nombres                in  adm_seg_usuario.nombres%type,
        i_apellidos              in  adm_seg_usuario.apellidos%type,
        i_tipo_autenticacion     in  adm_seg_usuario.tipo_autenticacion%type,
        i_password_hash          in  adm_seg_usuario.password_hash%type,
        i_password_salt          in  adm_seg_usuario.password_salt%type,
        i_debe_cambiar_password  in  adm_seg_usuario.debe_cambiar_password%type,
        i_empresa_id_defecto     in  adm_seg_usuario.empresa_id_defecto%type,
        o_usuario_id             out adm_seg_usuario.usuario_id%type
    );

    procedure actualizar (
        i_usuario_id          in adm_seg_usuario.usuario_id%type,
        i_email               in adm_seg_usuario.email%type,
        i_nombres             in adm_seg_usuario.nombres%type,
        i_apellidos           in adm_seg_usuario.apellidos%type,
        i_empresa_id_defecto  in adm_seg_usuario.empresa_id_defecto%type,
        i_estado              in adm_seg_usuario.estado%type
    );

    procedure actualizar_password (
        i_usuario_id             in adm_seg_usuario.usuario_id%type,
        i_password_hash          in adm_seg_usuario.password_hash%type,
        i_password_salt          in adm_seg_usuario.password_salt%type,
        i_debe_cambiar_password  in adm_seg_usuario.debe_cambiar_password%type
    );

    procedure actualizar_estado (
        i_usuario_id  in adm_seg_usuario.usuario_id%type,
        i_estado      in adm_seg_usuario.estado%type
    );

    -- Transacción AUTÓNOMA (confirma aunque el login se rechace).
    -- Éxito: reinicia intentos y registra último login. Fallo: suma un intento
    -- y bloquea (estado B) al llegar a i_max_intentos.
    procedure actualizar_intentos (
        i_usuario_id    in adm_seg_usuario.usuario_id%type,
        i_exitoso       in boolean,
        i_max_intentos  in pls_integer
    );

end adm_seg_usuario_ctr;
/

-- >>> apps/adm/database/packages/adm_seg_usuario_rol_ctr.pks
create or replace package adm_seg_usuario_rol_ctr
    authid definer
    accessible by (package adm_seg_usuario_api)
as
-- =============================================================================
-- Paquete : adm_seg_usuario_rol_ctr   (capa ctr)
-- Tabla   : adm_seg_usuario_rol
-- =============================================================================

    function existe (
        i_usuario_id  in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id      in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id  in adm_seg_usuario_rol.empresa_id%type
    ) return boolean;

    procedure insertar (
        i_usuario_id   in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id       in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id   in adm_seg_usuario_rol.empresa_id%type,
        i_fecha_desde  in adm_seg_usuario_rol.fecha_desde%type,
        i_fecha_hasta  in adm_seg_usuario_rol.fecha_hasta%type
    );

    procedure actualizar (
        i_usuario_id   in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id       in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id   in adm_seg_usuario_rol.empresa_id%type,
        i_fecha_desde  in adm_seg_usuario_rol.fecha_desde%type,
        i_fecha_hasta  in adm_seg_usuario_rol.fecha_hasta%type
    );

    procedure eliminar (
        i_usuario_id  in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id      in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id  in adm_seg_usuario_rol.empresa_id%type
    );

end adm_seg_usuario_rol_ctr;
/

-- >>> apps/adm/database/packages/adm_aud_login_ctr.pks
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

-- >>> apps/adm/database/packages/adm_aud_error_ctr.pks
create or replace package adm_aud_error_ctr
    authid definer
    accessible by (package adm_gen_error_api)
as
-- =============================================================================
-- Paquete : adm_aud_error_ctr   (capa ctr)
-- Tabla   : adm_aud_error
-- Desc    : insertar es AUTÓNOMO: el incidente queda registrado aunque la
--           transacción del usuario haga rollback.
-- =============================================================================

    procedure insertar (
        i_apex_app_id     in  adm_aud_error.apex_app_id%type,
        i_apex_pagina_id  in  adm_aud_error.apex_pagina_id%type,
        i_username        in  adm_aud_error.username%type,
        i_componente      in  adm_aud_error.componente%type,
        i_mensaje         in  adm_aud_error.mensaje%type,
        i_ora_sqlcode     in  adm_aud_error.ora_sqlcode%type,
        i_ora_sqlerrm     in  adm_aud_error.ora_sqlerrm%type,
        i_error_backtrace in  adm_aud_error.error_backtrace%type,
        o_error_id        out adm_aud_error.error_id%type
    );

end adm_aud_error_ctr;
/

-- >>> apps/adm/database/packages/adm_gen_mensaje_error_ctr.pks
create or replace package adm_gen_mensaje_error_ctr
    authid definer
    accessible by (package adm_gen_error_api)
as
-- =============================================================================
-- Paquete : adm_gen_mensaje_error_ctr   (capa ctr)
-- Tabla   : adm_gen_mensaje_error
-- =============================================================================

    -- Mensaje para un constraint; null si no está registrado.
    function obtener_mensaje (
        i_codigo  in adm_gen_mensaje_error.codigo%type
    ) return adm_gen_mensaje_error.mensaje%type;

end adm_gen_mensaje_error_ctr;
/

-- >>> apps/adm/database/packages/adm_seg_seguridad_reg.pks
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

-- >>> apps/adm/database/packages/adm_seg_usuario_reg.pks
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

-- >>> apps/adm/database/packages/adm_seg_usuario_api.pks
create or replace package adm_seg_usuario_api
    authid definer
as
-- =============================================================================
-- Paquete : adm_seg_usuario_api   (capa api)
-- Desc    : Fachada de gestión de usuarios para APEX, REST y scripts.
--           No hace COMMIT (en APEX confirma APEX; en scripts, el script).
-- =============================================================================

    procedure crear (
        i_username            in  adm_seg_usuario.username%type,
        i_email               in  adm_seg_usuario.email%type,
        i_nombres             in  adm_seg_usuario.nombres%type,
        i_apellidos           in  adm_seg_usuario.apellidos%type default null,
        i_tipo_autenticacion  in  adm_seg_usuario.tipo_autenticacion%type default 'LOCAL',
        i_password            in  varchar2 default null,
        i_empresa_id_defecto  in  adm_seg_usuario.empresa_id_defecto%type default null,
        o_usuario_id          out adm_seg_usuario.usuario_id%type
    );

    procedure modificar (
        i_usuario_id          in adm_seg_usuario.usuario_id%type,
        i_email               in adm_seg_usuario.email%type,
        i_nombres             in adm_seg_usuario.nombres%type,
        i_apellidos           in adm_seg_usuario.apellidos%type,
        i_empresa_id_defecto  in adm_seg_usuario.empresa_id_defecto%type,
        i_estado              in adm_seg_usuario.estado%type
    );

    -- Un administrador fija una contraseña temporal: el usuario deberá cambiarla
    -- y queda desbloqueado.
    procedure resetear_password (
        i_usuario_id      in adm_seg_usuario.usuario_id%type,
        i_password_nuevo  in varchar2
    );

    -- El propio usuario cambia su contraseña.
    procedure cambiar_password (
        i_username           in adm_seg_usuario.username%type,
        i_password_actual    in varchar2,
        i_password_nuevo     in varchar2,
        i_password_confirma  in varchar2
    );

    procedure desbloquear (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    );

    -- Asigna (o actualiza la vigencia de) un rol. i_empresa_id null = todas.
    procedure asignar_rol (
        i_usuario_id   in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id       in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id   in adm_seg_usuario_rol.empresa_id%type default null,
        i_fecha_desde  in adm_seg_usuario_rol.fecha_desde%type default trunc(current_date),
        i_fecha_hasta  in adm_seg_usuario_rol.fecha_hasta%type default null
    );

    procedure quitar_rol (
        i_usuario_id  in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id      in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id  in adm_seg_usuario_rol.empresa_id%type default null
    );

end adm_seg_usuario_api;
/

-- >>> apps/adm/database/packages/adm_gen_error_api.pks
create or replace package adm_gen_error_api
    authid definer
as
-- =============================================================================
-- Paquete : adm_gen_error_api   (capa api)
-- Desc    : Manejo de errores central para TODAS las apps APEX y el PL/SQL.
--
--   APEX  -> Application > Error Handling Function Name: adm_gen_error_api.manejar_error_apex
--   PL/SQL-> en bloques when others que deban registrar y re-lanzar:
--                exception when others then
--                    adm_gen_error_api.registrar(i_componente => 'erp_fin_factura_api.emitir');
--                    raise;
--
--   Reglas (recomendación Oracle, APEX_ERROR):
--   - Constraint (ORA-00001/02290/02291/02292): mensaje de adm_gen_mensaje_error
--     por nombre de constraint; si no existe, mensaje genérico + incidente.
--   - Negocio (ORA-20000..20999): se muestra el texto tal cual (ya es para el usuario).
--   - Interno / inesperado: se registra en adm_aud_error y el usuario ve solo
--     "Código de incidente N". Nunca se muestra el error técnico.
-- =============================================================================

    -- EXCEPCIÓN AL ESTÁNDAR: APEX exige el parámetro p_error.
    function manejar_error_apex (
        p_error  in apex_error.t_error
    ) return apex_error.t_error_result;

    -- Registra el error actual (sqlcode/sqlerrm/backtrace) y devuelve el nro. de incidente.
    function registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    ) return number;

    procedure registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    );

end adm_gen_error_api;
/
