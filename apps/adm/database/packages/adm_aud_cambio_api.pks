create or replace package adm_aud_cambio_api
    authid definer
as
-- =============================================================================
-- Paquete : adm_aud_cambio_api   (capa api)
-- Desc    : Historial de cambios de datos (adm_aud_cambio) para todas las apps.
--
--   Registro : lo hacen los triggers trg_<app>_<abrev>_aiud generados con
--              adm_aud_cambio_utl.generar_trigger (agregar por fila + registrar
--              por sentencia). Nadie más debe llamarlos.
--   Consulta : vistas adm_aud_cambio_v (cabecera) y adm_aud_cambio_det_v
--              (una fila por campo: Campo / Antes / Después).
--   Purga    : job_adm_purgar_cambio ejecuta ejecutar_purga cada mes.
-- =============================================================================

    c_err_retencion    constant pls_integer := -20041;

    c_meses_retencion  constant pls_integer := 84;    -- 7 años
    c_filas_lote       constant pls_integer := 500;   -- filas por FORALL en sentencias masivas

    subtype t_cambios is adm_aud_cambio_ctr.t_cambios;

    -- Acumula el cambio de una fila. No hace nada si i_detalle está vacío (un
    -- update que no cambió ningún valor auditado no deja historial). Cada
    -- c_filas_lote filas inserta lo acumulado para acotar la memoria.
    procedure agregar (
        io_cambios           in out nocopy t_cambios,
        i_app_codigo         in adm_aud_cambio.app_codigo%type,
        i_tabla              in adm_aud_cambio.tabla%type,
        i_registro_id        in adm_aud_cambio.registro_id%type,
        i_registro_padre_id  in adm_aud_cambio.registro_padre_id%type,
        i_empresa_id         in adm_aud_cambio.empresa_id%type,
        i_operacion          in adm_aud_cambio.operacion%type,
        i_detalle            in json_array_t
    );

    -- Inserta lo acumulado (un solo lote) y vacía la colección.
    procedure registrar (
        io_cambios  in out nocopy t_cambios
    );

    -- Borra el historial anterior a i_meses_retencion meses completos.
    -- No hace commit (lo decide quien llama).
    procedure purgar (
        i_meses_retencion  in  number default c_meses_retencion,
        o_filas            out number
    );

    -- Para el job: purga, confirma y deja el error en la bitácora si falla.
    procedure ejecutar_purga (
        i_meses_retencion  in number default c_meses_retencion
    );

end adm_aud_cambio_api;
/
