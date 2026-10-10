create or replace package body adm_aud_cambio_utl
as

    c_nl                 constant varchar2(1)   := chr(10);
    c_patron_reservado   constant varchar2(100) := 'PASSWORD|HASH|TOKEN|CLAVE|SECRET|SALT';
    c_formato_fecha      constant varchar2(40)  := 'YYYY-MM-DD"T"HH24:MI:SS';
    c_formato_fecha_hora constant varchar2(40)  := 'YYYY-MM-DD"T"HH24:MI:SS.FF6';
    c_formato_tz         constant varchar2(40)  := 'YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM';

    -- Datos de la tabla que necesita el generador.
    type t_tabla is record (
        nombre      varchar2(128),      -- en mayúsculas
        app         varchar2(30),
        abreviatura varchar2(30),
        nombre_trigger varchar2(128),   -- en minúsculas
        pk          varchar2(128),
        tiene_empresa boolean
    );

    -- ------------------------------------------------------------------ privados
    function esta_en_lista (
        i_lista    in varchar2,
        i_columna  in varchar2
    ) return boolean is
    begin
        return instr(',' || replace(upper(i_lista), ' ') || ',', ',' || upper(i_columna) || ',') > 0;
    end esta_en_lista;

    function obtener_tabla (
        i_tabla  in varchar2
    ) return t_tabla is
        r_tabla       t_tabla;
        v_comentario  user_tab_comments.comments%type;
        v_cantidad    pls_integer;
        v_tipo        user_tab_cols.data_type%type;
    begin
        r_tabla.nombre := upper(trim(i_tabla));

        begin
            select c.comments
              into v_comentario
              from user_tables t
              left join user_tab_comments c on c.table_name = t.table_name
             where t.table_name = r_tabla.nombre;
        exception
            when no_data_found then
                raise_application_error(c_err_no_auditable, 'No existe la tabla ' || lower(r_tabla.nombre) || '.');
        end;

        r_tabla.app         := regexp_substr(r_tabla.nombre, '^[^_]+');
        r_tabla.abreviatura := upper(regexp_substr(v_comentario, 'Abrev:\s*(\w+)', 1, 1, 'i', 1));
        if r_tabla.abreviatura is null then
            raise_application_error(c_err_no_auditable,
                'La tabla ' || lower(r_tabla.nombre) || ' no tiene abreviatura en su comentario ("Abrev: xxx").');
        end if;

        r_tabla.nombre_trigger := lower('trg_' || r_tabla.app || '_' || r_tabla.abreviatura || '_aiud');
        if length(r_tabla.nombre_trigger) > 30 then
            raise_application_error(c_err_no_auditable,
                'El nombre ' || r_tabla.nombre_trigger || ' supera los 30 caracteres.');
        end if;

        select count(*), max(cc.column_name)
          into v_cantidad, r_tabla.pk
          from user_constraints k
          join user_cons_columns cc on cc.constraint_name = k.constraint_name
         where k.table_name = r_tabla.nombre
           and k.constraint_type = 'P';
        if v_cantidad <> 1 then
            raise_application_error(c_err_no_auditable,
                'La tabla ' || lower(r_tabla.nombre) || ' debe tener una clave primaria de una sola columna.');
        end if;

        select c.data_type
          into v_tipo
          from user_tab_cols c
         where c.table_name = r_tabla.nombre
           and c.column_name = r_tabla.pk;
        if v_tipo <> 'NUMBER' then
            raise_application_error(c_err_no_auditable,
                'La clave primaria de ' || lower(r_tabla.nombre) || ' debe ser numérica.');
        end if;

        select count(*)
          into v_cantidad
          from user_tab_cols c
         where c.table_name = r_tabla.nombre
           and c.column_name = 'EMPRESA_ID'
           and c.data_type = 'NUMBER';
        r_tabla.tiene_empresa := v_cantidad = 1;

        return r_tabla;
    end obtener_tabla;

    -- Código del trigger, sin el "/" final.
    function generar_codigo (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2,
        i_columnas_excluidas   in varchar2,
        i_columnas_reservadas  in varchar2
    ) return clob is
        r_tabla       t_tabla := obtener_tabla(i_tabla);
        v_padre       varchar2(128) := upper(trim(i_columna_padre));
        v_cantidad    pls_integer;
        v_lineas      clob;             -- llamadas agregar_* (una por columna)
        v_reservadas  varchar2(4000);
        v_omitidas    varchar2(4000);
        v_codigo      clob;
        v_col         varchar2(128);
        v_proc        varchar2(30);
        v_llamada     varchar2(400);
        v_registro    varchar2(300);
        v_cascada     pls_integer;      -- FK on delete cascade / set null hacia un padre

        procedure escribir (i_linea in varchar2 default null) is
        begin
            v_codigo := v_codigo || i_linea || c_nl;
        end escribir;

        procedure anotar (io_lista in out nocopy varchar2, i_texto in varchar2) is
        begin
            io_lista := substr(io_lista || case when io_lista is not null then ', ' end || i_texto, 1, 4000);
        end anotar;
    begin
        if v_padre is not null then
            select count(*)
              into v_cantidad
              from user_tab_cols c
             where c.table_name = r_tabla.nombre
               and c.column_name = v_padre
               and c.data_type = 'NUMBER';
            if v_cantidad = 0 then
                raise_application_error(c_err_no_auditable,
                    'La columna padre ' || lower(v_padre) || ' no existe en ' || lower(r_tabla.nombre) || ' o no es numérica.');
            end if;
        end if;

        for r_col in (select c.column_name, c.data_type, c.char_length
                        from user_tab_cols c
                       where c.table_name = r_tabla.nombre
                         and c.hidden_column = 'NO'
                         and c.virtual_column = 'NO'
                       order by c.column_id) loop
            v_col := lower(r_col.column_name);

            if r_col.column_name = r_tabla.pk then
                anotar(v_omitidas, v_col || ' (PK: va en registro_id)');
                continue;
            elsif r_col.column_name in ('CREADO_POR', 'FECHA_CREACION', 'MODIFICADO_POR', 'FECHA_MODIFICACION') then
                continue;
            elsif esta_en_lista(i_columnas_excluidas, r_col.column_name) then
                anotar(v_omitidas, v_col || ' (excluida)');
                continue;
            end if;

            v_proc := case
                          when r_col.data_type in ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') then 'agregar_texto'
                          when r_col.data_type in ('NUMBER', 'FLOAT', 'BINARY_FLOAT', 'BINARY_DOUBLE') then 'agregar_numero'
                          when r_col.data_type = 'DATE' then 'agregar_fecha'
                          when r_col.data_type like 'TIMESTAMP%TIME ZONE' then 'agregar_fecha_hora_tz'
                          when r_col.data_type like 'TIMESTAMP%' then 'agregar_fecha_hora'
                          when r_col.data_type = 'RAW' then 'agregar_binario'
                      end;
            if v_proc is null then
                anotar(v_omitidas, v_col || ' (' || lower(r_col.data_type) || ')');
                continue;
            end if;

            if esta_en_lista(i_columnas_reservadas, r_col.column_name)
               or (regexp_like(r_col.column_name, c_patron_reservado)
                   and (v_proc in ('agregar_numero', 'agregar_binario')
                        or (v_proc = 'agregar_texto' and r_col.char_length > 1))) then
                anotar(v_reservadas, v_col);
                v_lineas := v_lineas
                    || '        if (:old.' || v_col || ' is null and :new.' || v_col || ' is not null)' || c_nl
                    || '           or (:old.' || v_col || ' is not null and :new.' || v_col || ' is null)' || c_nl
                    || '           or :old.' || v_col || ' <> :new.' || v_col || ' then' || c_nl
                    || '            adm_aud_cambio_utl.agregar_reservado(v_detalle, ''' || v_col || ''');' || c_nl
                    || '        end if;' || c_nl;
            else
                v_llamada := '        adm_aud_cambio_utl.' || rpad(v_proc || '(v_detalle,', 34)
                    || rpad('''' || v_col || ''',', 34) || ':old.' || v_col || ', :new.' || v_col || ');';
                v_lineas := v_lineas || v_llamada || c_nl;
            end if;
        end loop;

        if v_lineas is null then
            raise_application_error(c_err_no_auditable,
                'La tabla ' || lower(r_tabla.nombre) || ' no tiene columnas para auditar.');
        end if;

        -- Un borrado en cascada (o un set null) que llega desde la tabla padre ejecuta
        -- la sección de fila de este trigger pero NO su "after statement".
        -- 0 = ninguna, 1 = cascade, 2 o 3 = set null
        select sign(count(case when k.delete_rule = 'CASCADE' then 1 end))
               + 2 * sign(count(case when k.delete_rule = 'SET NULL' then 1 end))
          into v_cascada
          from user_constraints k
         where k.table_name = r_tabla.nombre
           and k.constraint_type = 'R'
           and k.delete_rule in ('CASCADE', 'SET NULL');

        v_registro := 'coalesce(:new.' || lower(r_tabla.pk) || ', :old.' || lower(r_tabla.pk) || ')';

        escribir('-- =============================================================================');
        escribir('-- Trigger : ' || r_tabla.nombre_trigger);
        escribir('-- Tabla   : ' || lower(r_tabla.nombre));
        escribir('-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).');
        escribir('--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):');
        escribir('--             @tools/db/generar_trigger_historial.sql ' || lower(r_tabla.nombre)
                 || ' ' || coalesce(lower(v_padre), '_')
                 || ' ' || coalesce(lower(replace(i_columnas_excluidas, ' ')), '_')
                 || ' ' || coalesce(lower(replace(i_columnas_reservadas, ' ')), '_'));
        if v_reservadas is not null then
            escribir('-- Reservadas (solo se registra que cambiaron): ' || v_reservadas);
        end if;
        if v_omitidas is not null then
            escribir('-- No auditadas: ' || v_omitidas || ' y las columnas de auditoría.');
        end if;
        escribir('-- =============================================================================');
        escribir('create or replace trigger ' || r_tabla.nombre_trigger);
        escribir('    for insert or update or delete on ' || lower(r_tabla.nombre));
        escribir('    compound trigger');
        escribir;
        escribir('    v_cambios  adm_aud_cambio_api.t_cambios;');
        escribir;
        escribir('    after each row is');
        escribir('        v_detalle  json_array_t := json_array_t();');
        escribir('    begin');
        v_codigo := v_codigo || v_lineas;
        escribir;
        escribir('        adm_aud_cambio_api.agregar(');
        escribir('            io_cambios          => v_cambios,');
        escribir('            i_app_codigo        => ''' || r_tabla.app || ''',');
        escribir('            i_tabla             => ''' || r_tabla.nombre || ''',');
        escribir('            i_registro_id       => ' || v_registro || ',');
        escribir('            i_registro_padre_id => ' || case when v_padre is null then 'null'
                     else 'coalesce(:new.' || lower(v_padre) || ', :old.' || lower(v_padre) || ')' end || ',');
        escribir('            i_empresa_id        => ' || case when r_tabla.tiene_empresa
                     then 'coalesce(:new.empresa_id, :old.empresa_id)' else 'null' end || ',');
        escribir('            i_operacion         => case when inserting then ''I'' when updating then ''U'' else ''D'' end,');
        escribir('            i_detalle           => v_detalle);');
        if v_cascada > 0 then
            escribir;
            escribir('        -- La tabla tiene una FK ' || case when v_cascada >= 2 then 'on delete set null' else 'on delete cascade' end
                     || ': cuando el cambio llega desde la tabla padre');
            escribir('        -- no se ejecuta "after statement", así que se inserta en el momento.');
            if v_cascada >= 2 then
                escribir('        if deleting or updating then');
            else
                escribir('        if deleting then');
            end if;
            escribir('            adm_aud_cambio_api.registrar(io_cambios => v_cambios);');
            escribir('        end if;');
        end if;
        escribir('    end after each row;');
        escribir;
        escribir('    after statement is');
        escribir('    begin');
        escribir('        adm_aud_cambio_api.registrar(io_cambios => v_cambios);');
        escribir('    end after statement;');
        escribir;
        v_codigo := v_codigo || 'end ' || r_tabla.nombre_trigger || ';';
        return v_codigo;
    end generar_codigo;

    -- Agrega el elemento ya convertido a texto (o número) al detalle.
    procedure agregar_elemento (
        io_detalle        in out nocopy json_array_t,
        i_columna         in varchar2,
        i_antes           in varchar2,
        i_despues         in varchar2
    ) is
        v_elemento  json_object_t := json_object_t();
    begin
        v_elemento.put('col', i_columna);
        if i_antes is null then
            v_elemento.put_null('antes');
        else
            v_elemento.put('antes', i_antes);
        end if;
        if i_despues is null then
            v_elemento.put_null('despues');
        else
            v_elemento.put('despues', i_despues);
        end if;
        io_detalle.append(v_elemento);
    end agregar_elemento;

    -- ------------------------------------------------------------------ públicos
    function generar_trigger (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2 default null,
        i_columnas_excluidas   in varchar2 default null,
        i_columnas_reservadas  in varchar2 default null
    ) return clob is
    begin
        return generar_codigo(
                   i_tabla               => i_tabla,
                   i_columna_padre       => i_columna_padre,
                   i_columnas_excluidas  => i_columnas_excluidas,
                   i_columnas_reservadas => i_columnas_reservadas) || c_nl || '/' || c_nl;
    end generar_trigger;

    function obtener_nombre_trigger (
        i_tabla  in varchar2
    ) return varchar2 is
    begin
        return obtener_tabla(i_tabla => i_tabla).nombre_trigger;
    end obtener_nombre_trigger;

    procedure crear_trigger (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2 default null,
        i_columnas_excluidas   in varchar2 default null,
        i_columnas_reservadas  in varchar2 default null
    ) is
    begin
        execute immediate generar_codigo(
                              i_tabla               => i_tabla,
                              i_columna_padre       => i_columna_padre,
                              i_columnas_excluidas  => i_columnas_excluidas,
                              i_columnas_reservadas => i_columnas_reservadas);
    end crear_trigger;

    procedure agregar_texto (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in varchar2,
        i_despues   in varchar2
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna, i_antes, i_despues);
    end agregar_texto;

    procedure agregar_numero (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in number,
        i_despues   in number
    ) is
        v_elemento  json_object_t;
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        -- Número JSON (sin máscara ni separadores de la sesión)
        v_elemento := json_object_t();
        v_elemento.put('col', i_columna);
        if i_antes is null then
            v_elemento.put_null('antes');
        else
            v_elemento.put('antes', i_antes);
        end if;
        if i_despues is null then
            v_elemento.put_null('despues');
        else
            v_elemento.put('despues', i_despues);
        end if;
        io_detalle.append(v_elemento);
    end agregar_numero;

    procedure agregar_fecha (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in date,
        i_despues   in date
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna,
                         to_char(i_antes, c_formato_fecha), to_char(i_despues, c_formato_fecha));
    end agregar_fecha;

    procedure agregar_fecha_hora (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in timestamp,
        i_despues   in timestamp
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna,
                         to_char(i_antes, c_formato_fecha_hora), to_char(i_despues, c_formato_fecha_hora));
    end agregar_fecha_hora;

    procedure agregar_fecha_hora_tz (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in timestamp with time zone,
        i_despues   in timestamp with time zone
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna,
                         to_char(i_antes, c_formato_tz), to_char(i_despues, c_formato_tz));
    end agregar_fecha_hora_tz;

    procedure agregar_binario (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in raw,
        i_despues   in raw
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna, rawtohex(i_antes), rawtohex(i_despues));
    end agregar_binario;

    procedure agregar_reservado (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2
    ) is
        v_elemento  json_object_t := json_object_t();
    begin
        v_elemento.put('col', i_columna);
        v_elemento.put_null('antes');
        v_elemento.put_null('despues');
        v_elemento.put('reservado', true);
        io_detalle.append(v_elemento);
    end agregar_reservado;

end adm_aud_cambio_utl;
/
