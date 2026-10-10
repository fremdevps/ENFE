create or replace package adm_aud_cambio_ctr
    authid definer
    accessible by (package adm_aud_cambio_api, trigger trg_adm_cam_bud)
as
-- =============================================================================
-- Paquete : adm_aud_cambio_ctr   (capa ctr)
-- Tabla   : adm_aud_cambio
-- Desc    : Inserción por lote del historial de cambios y borrado por retención.
--           NO es autónomo: si la transacción del usuario se deshace, su
--           historial también.
-- =============================================================================

    c_err_inmutable  constant pls_integer := -20040;

    -- Un cambio pendiente de insertar. cambios viaja como varchar2 (hasta 32767
    -- bytes) para no crear un LOB temporal por fila.
    type t_cambio is record (
        app_codigo         adm_aud_cambio.app_codigo%type,
        tabla              adm_aud_cambio.tabla%type,
        registro_id        adm_aud_cambio.registro_id%type,
        registro_padre_id  adm_aud_cambio.registro_padre_id%type,
        empresa_id         adm_aud_cambio.empresa_id%type,
        operacion          adm_aud_cambio.operacion%type,
        cambios            varchar2(32767)
    );
    type t_cambios is table of t_cambio index by pls_integer;

    -- Inserta todas las filas con un solo FORALL. Usuario, sesión APEX,
    -- transacción y módulo se toman una vez por lote.
    procedure insertar_lote (
        i_cambios  in t_cambios
    );

    -- Fila cuyo JSON supera los 32767 bytes (caso raro).
    procedure insertar (
        i_cambio   in t_cambio,
        i_cambios  in adm_aud_cambio.cambios%type
    );

    -- Purga: borra lo anterior a la fecha límite. Único delete permitido.
    procedure eliminar_anteriores (
        i_fecha_limite  in  adm_aud_cambio.fecha%type,
        o_filas         out number
    );

    -- La consulta trg_adm_cam_bud para dejar pasar solo el delete de la purga.
    function es_purga_activa return boolean;

end adm_aud_cambio_ctr;
/
