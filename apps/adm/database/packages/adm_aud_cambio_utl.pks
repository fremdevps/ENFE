create or replace package adm_aud_cambio_utl
    authid definer
as
-- =============================================================================
-- Paquete : adm_aud_cambio_utl   (capa utl)
-- Desc    : Utilitarios del historial de cambios (adm_aud_cambio). Sin DML.
--
--   1. generar_trigger: produce el código del trigger compound
--      trg_<app>_<abrev>_aiud de una tabla, leyendo el diccionario de datos.
--      El resultado se guarda en apps/<app>/database/triggers/ y se versiona
--      (tools/db/generar_trigger_historial.sql lo hace en un paso).
--   2. agregar_*: los usan los triggers generados para armar el detalle JSON
--      [{"col":…,"antes":…,"despues":…}] solo con las columnas que cambiaron.
--
--   Reglas del generador:
--   - App = primer tramo del nombre de la tabla; abreviatura = "Abrev: xxx"
--     del comentario de la tabla.
--   - La PK debe ser una sola columna numérica: va en registro_id (no en el JSON).
--   - empresa_id se registra si la tabla tiene esa columna.
--   - Nunca se auditan: creado_por, fecha_creacion, modificado_por,
--     fecha_modificacion, columnas LOB / de tipos no escalares, virtuales u
--     ocultas, ni las indicadas en i_columnas_excluidas.
--   - Columnas reservadas (el nombre contiene password, hash, token, clave,
--     secret o salt y son texto de más de 1 carácter, número o raw; más las de
--     i_columnas_reservadas): solo se registra QUE cambiaron, nunca el valor.
--   - Si la tabla tiene una FK on delete cascade (o set null), las bajas (o
--     modificaciones) se insertan fila por fila: Oracle no ejecuta la sección
--     "after statement" de la tabla hija cuando el cambio llega desde el padre.
--   - Fechas en ISO 8601; números como número JSON, sin máscara; raw en hexadecimal.
-- =============================================================================

    c_err_no_auditable  constant pls_integer := -20042;

    -- i_columna_padre     : columna numérica con la PK del registro padre (ej. usuario_id
    --                       en adm_seg_usuario_rol) -> registro_padre_id.
    -- i_columnas_excluidas: lista separada por comas de columnas que no interesa auditar
    --                       (ej. contadores o fechas que cambian en cada ingreso).
    -- i_columnas_reservadas: lista separada por comas de columnas sensibles adicionales.
    -- Devuelve un script completo (termina con "/").
    function generar_trigger (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2 default null,
        i_columnas_excluidas   in varchar2 default null,
        i_columnas_reservadas  in varchar2 default null
    ) return clob;

    -- Nombre del trigger de historial de una tabla: trg_<app>_<abrev>_aiud.
    function obtener_nombre_trigger (
        i_tabla  in varchar2
    ) return varchar2;

    -- Genera y compila el trigger en el esquema (DDL). Para pruebas y ambientes
    -- de desarrollo; lo normal es instalar el archivo versionado.
    procedure crear_trigger (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2 default null,
        i_columnas_excluidas   in varchar2 default null,
        i_columnas_reservadas  in varchar2 default null
    );

    -- Agregan {"col","antes","despues"} a io_detalle solo si el valor cambió
    -- (comparación segura con nulos). En un alta i_antes llega nulo y en una
    -- baja i_despues llega nulo, así que una misma llamada sirve para I, U y D.
    procedure agregar_texto (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in varchar2,
        i_despues   in varchar2
    );

    procedure agregar_numero (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in number,
        i_despues   in number
    );

    procedure agregar_fecha (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in date,
        i_despues   in date
    );

    procedure agregar_fecha_hora (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in timestamp,
        i_despues   in timestamp
    );

    procedure agregar_fecha_hora_tz (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in timestamp with time zone,
        i_despues   in timestamp with time zone
    );

    procedure agregar_binario (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in raw,
        i_despues   in raw
    );

    -- Columna reservada: {"col", "antes":null, "despues":null, "reservado":true}.
    -- La comparación la hace el trigger; el valor nunca sale de él.
    procedure agregar_reservado (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2
    );

end adm_aud_cambio_utl;
/
