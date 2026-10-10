-- =============================================================================
-- Pruebas del historial de cambios (adm_aud_cambio y triggers trg_*_aiud).
-- Repetible: no deja datos (rollback al final de cada parte) y borra su tabla
-- de trabajo. Imprime OK / FALLA por caso y termina con error si alguno falla.
--
-- Uso (SQLcl, desde la raíz del repositorio, con el esquema de las apps como
-- current_schema):   @tests/sql/adm/historial.sql
--
-- Parte 1: casos funcionales sobre las tablas de ADM (sin DDL).
-- Parte 2: sentencias masivas, fila grande y rendimiento sobre una tabla de
--          trabajo (adm_gen_prueba_hist), con y sin trigger.
-- =============================================================================
set serveroutput on size unlimited feedback off verify off define off
whenever sqlerror exit failure rollback

prompt == Parte 1: casos funcionales
declare
    v_fallas      pls_integer := 0;
    v_base        number;          -- último cambio_id antes de cada caso
    v_n           number;
    v_json        clob;
    v_texto       varchar2(4000);
    v_empresa_id  number;
    v_usuario_id  number;
    v_rol_id      number;
    v_permiso_id  number;
    v_usro_id     number;
    v_tx          varchar2(100);
    v_filas       number;
    c_hash_1      constant raw(64) := hextoraw(rpad('A1B2C3D4', 128, '9'));
    c_hash_2      constant raw(64) := hextoraw(rpad('E5F6A7B8', 128, '7'));
    c_salt_1      constant raw(32) := hextoraw(rpad('0F1E2D3C', 64, '5'));
    c_salt_2      constant raw(32) := hextoraw(rpad('4B5A6978', 64, '3'));

    procedure verificar (i_caso in varchar2, i_ok in boolean, i_detalle in varchar2 default null) is
    begin
        if i_ok then
            dbms_output.put_line('OK     ' || i_caso);
        else
            v_fallas := v_fallas + 1;
            dbms_output.put_line('FALLA  ' || i_caso || case when i_detalle is not null then ' -> ' || i_detalle end);
        end if;
    end verificar;

    procedure marcar is
    begin
        select coalesce(max(cambio_id), 0) into v_base from adm_aud_cambio;
    end marcar;

    function contar (i_tabla in varchar2, i_operacion in varchar2 default null) return number is
        v_cantidad  number;
    begin
        select count(*) into v_cantidad
          from adm_aud_cambio
         where cambio_id > v_base and tabla = i_tabla and operacion = coalesce(i_operacion, operacion);
        return v_cantidad;
    end contar;
    -- Los métodos de ítem ($.size(), .type()) se evalúan en SQL
    function tamano (i_json in clob) return number is
        v_tamano  number;
    begin
        select json_value(i_json, '$.size()' returning number) into v_tamano from dual;
        return v_tamano;
    end tamano;

    function tipo_primero (i_json in clob) return varchar2 is
        v_tipo  varchar2(30);
    begin
        select json_value(i_json, '$[0].despues.type()') into v_tipo from dual;
        return v_tipo;
    end tipo_primero;
begin
    -- 1. INSERT ---------------------------------------------------------------
    marcar;
    insert into adm_gen_empresa (codigo, razon_social, zona_horaria)
    values ('ZZHIST1', 'Empresa de prueba "historial" \ ñandú', 'America/Asuncion')
    returning empresa_id into v_empresa_id;

    select count(*), max(dbms_lob.substr(cambios, 4000, 1)), max(transaccion_id) into v_n, v_json, v_tx
      from adm_aud_cambio
     where cambio_id > v_base and tabla = 'ADM_GEN_EMPRESA' and operacion = 'I'
       and registro_id = v_empresa_id and empresa_id = v_empresa_id and app_codigo = 'ADM';
    verificar('01 insert genera 1 fila I con registro_id, empresa_id y app', v_n = 1, 'filas=' || v_n);
    verificar('02 insert: valores nuevos en "despues", "antes" nulo; comillas, barra y acentos bien escapados',
              json_value(v_json, '$[0].col') = 'codigo' and json_value(v_json, '$[0].despues') = 'ZZHIST1'
              and json_value(v_json, '$[0].antes') is null
              and json_value(v_json, '$[1].despues') = 'Empresa de prueba "historial" \ ñandú', dbms_lob.substr(v_json, 300));
    verificar('03 insert: solo columnas con valor (4: codigo, razon_social, zona_horaria, estado); sin PK ni auditoría',
              tamano(v_json) = 4
              and v_json not like '%creado_por%' and v_json not like '%fecha_creacion%' and v_json not like '%"empresa_id"%',
              dbms_lob.substr(v_json, 300));
    select count(*) into v_n from adm_aud_cambio
     where cambio_id > v_base and (usuario is null or fecha is null or transaccion_id is null or modulo is null);
    verificar('04 contexto: usuario, fecha, transacción y módulo completos', v_n = 0 and v_tx is not null);

    -- 2. UPDATE ---------------------------------------------------------------
    marcar;
    update adm_gen_empresa set razon_social = 'Empresa modificada', nro_documento = '80012345-6'
     where empresa_id = v_empresa_id;
    select count(*), max(dbms_lob.substr(cambios, 4000, 1)) into v_n, v_json
      from adm_aud_cambio where cambio_id > v_base and tabla = 'ADM_GEN_EMPRESA' and operacion = 'U' and registro_id = v_empresa_id;
    verificar('05 update genera 1 fila U', v_n = 1 and contar('ADM_GEN_EMPRESA') = 1, 'filas=' || v_n);
    verificar('06 update: solo las 2 columnas cambiadas, con antes y después',
              tamano(v_json) = 2
              and json_value(v_json, '$[0].col') = 'razon_social'
              and json_value(v_json, '$[0].antes') = 'Empresa de prueba "historial" \ ñandú'
              and json_value(v_json, '$[0].despues') = 'Empresa modificada'
              and json_value(v_json, '$[1].col') = 'nro_documento'
              and json_value(v_json, '$[1].antes') is null
              and json_value(v_json, '$[1].despues') = '80012345-6', dbms_lob.substr(v_json, 300));

    -- 3. UPDATE sin cambios reales ---------------------------------------------
    marcar;
    update adm_gen_empresa set razon_social = razon_social, estado = 'A' where empresa_id = v_empresa_id;
    verificar('07 update sin cambios reales no genera fila', contar('ADM_GEN_EMPRESA') = 0);

    -- 4. Valor -> nulo -----------------------------------------------------------
    marcar;
    update adm_gen_empresa set nro_documento = null where empresa_id = v_empresa_id;
    select max(dbms_lob.substr(cambios, 4000, 1)) into v_json from adm_aud_cambio where cambio_id > v_base;
    verificar('08 update de valor a nulo: antes con valor, después null',
              json_value(v_json, '$[0].antes') = '80012345-6' and v_json like '%"despues":null%', dbms_lob.substr(v_json, 300));

    -- 5. Usuario: contraseña, columnas excluidas ----------------------------------
    marcar;
    insert into adm_seg_usuario (username, email, nombres, tipo_autenticacion, password_hash, password_salt, empresa_id_defecto)
    values ('ZZHIST_USUARIO', 'zzhist@prueba.local', 'Prueba', 'LOCAL', c_hash_1, c_salt_1, v_empresa_id)
    returning usuario_id into v_usuario_id;
    update adm_seg_usuario
       set password_hash = c_hash_2, password_salt = c_salt_2, debe_cambiar_password = 'N', fecha_cambio_password = systimestamp
     where usuario_id = v_usuario_id;
    verificar('09 usuario: alta y cambio de contraseña generan 2 filas', contar('ADM_SEG_USUARIO') = 2);

    select count(*) into v_n
      from adm_aud_cambio
     where cambio_id > v_base
       and (   instr(upper(cambios), rawtohex(c_hash_1)) > 0 or instr(upper(cambios), rawtohex(c_hash_2)) > 0
            or instr(upper(cambios), rawtohex(c_salt_1)) > 0 or instr(upper(cambios), rawtohex(c_salt_2)) > 0
            or instr(upper(cambios), substr(rawtohex(c_hash_1), 1, 16)) > 0);
    verificar('10 el hash y el salt de la contraseña NUNCA aparecen en el historial', v_n = 0, 'filas con hash=' || v_n);

    select max(dbms_lob.substr(cambios, 4000, 1)) into v_json from adm_aud_cambio where cambio_id > v_base and operacion = 'U';
    select count(*), min(antes || '/' || despues) into v_n, v_texto
      from adm_aud_cambio_det_v
     where cambio_id > v_base and operacion = 'U' and columna in ('password_hash', 'password_salt') and es_reservado = 'S';
    verificar('11 contraseña: solo queda que cambió (reservado), sin valores',
              v_n = 2 and v_texto = '(reservado)/(reservado)' and v_json like '%"col":"password_hash","antes":null,"despues":null,"reservado":true%',
              dbms_lob.substr(v_json, 400));
    verificar('12 columnas con "password" que no son secretas sí guardan su valor (debe_cambiar_password S -> N)',
              v_json like '%"col":"debe_cambiar_password","antes":"S","despues":"N"%', dbms_lob.substr(v_json, 400));
    select max(despues) into v_texto from adm_aud_cambio_det_v
     where cambio_id > v_base and operacion = 'U' and columna = 'fecha_cambio_password';
    verificar('13 fecha y hora en ISO 8601 con zona',
              regexp_like(v_texto, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}[+-]\d{2}:\d{2}$'), v_texto);

    marcar;
    update adm_seg_usuario set intentos_fallidos = intentos_fallidos + 1, fecha_ultimo_login = systimestamp
     where usuario_id = v_usuario_id;
    verificar('14 columnas excluidas (intentos_fallidos, fecha_ultimo_login): un ingreso no genera historial',
              contar('ADM_SEG_USUARIO') = 0);

    -- 6. Hijas: registro padre, números y fechas -------------------------------------
    marcar;
    insert into adm_seg_rol (codigo, nombre) values ('ZZHIST_ROL', 'Rol de prueba') returning rol_id into v_rol_id;
    select min(permiso_id) into v_permiso_id from adm_seg_permiso;
    insert into adm_seg_rol_permiso (rol_id, permiso_id) values (v_rol_id, v_permiso_id);
    insert into adm_seg_usuario_rol (usuario_id, rol_id, empresa_id, fecha_desde)
    values (v_usuario_id, v_rol_id, v_empresa_id, date '2026-03-15')
    returning usuario_rol_id into v_usro_id;

    select count(*), max(dbms_lob.substr(cambios, 4000, 1)) into v_n, v_json
      from adm_aud_cambio
     where cambio_id > v_base and tabla = 'ADM_SEG_USUARIO_ROL' and operacion = 'I'
       and registro_id = v_usro_id and registro_padre_id = v_usuario_id and empresa_id = v_empresa_id;
    verificar('15 tabla hija: registro_padre_id = usuario y empresa_id de la fila', v_n = 1);
    verificar('16 número como número JSON (sin máscara) y fecha en ISO 8601',
              tipo_primero(v_json) = 'number'
              and json_value(v_json, '$[0].despues' returning number) = v_usuario_id
              and json_value(v_json, '$[3].col') = 'fecha_desde'
              and json_value(v_json, '$[3].despues') = '2026-03-15T00:00:00', dbms_lob.substr(v_json, 300));
    select count(*) into v_n from adm_aud_cambio
     where cambio_id > v_base and tabla = 'ADM_SEG_ROL_PERMISO' and registro_padre_id = v_rol_id;
    verificar('17 rol_permiso: registro_padre_id = rol', v_n = 1);

    -- 7. Vista de detalle ---------------------------------------------------------------
    select count(*), max(case when columna = 'fecha_desde' then campo end)
      into v_n, v_texto
      from adm_aud_cambio_det_v
     where tabla = 'ADM_SEG_USUARIO_ROL' and registro_id = v_usro_id;
    verificar('18 vista de detalle: una fila por campo (4) y etiqueta tomada del comentario de la columna',
              v_n = 4 and v_texto = 'Inicio de vigencia (fecha del usuario)', 'filas=' || v_n || ' campo=' || v_texto);
    select count(*), max(entidad || '|' || operacion_desc || '|' || campos || '|' || empresa) into v_n, v_texto
      from adm_aud_cambio_v where tabla = 'ADM_SEG_USUARIO_ROL' and registro_id = v_usro_id;
    verificar('19 vista de cabecera: entidad, operación, cantidad de campos y empresa',
              v_n = 1 and v_texto = 'Roles por usuario con vigencia|Alta|4|Empresa modificada', v_texto);

    -- 8. DELETE (fila completa) y borrado en cascada ----------------------------------------
    marcar;
    delete from adm_seg_usuario where usuario_id = v_usuario_id;
    select count(*), max(dbms_lob.substr(cambios, 4000, 1)) into v_n, v_json
      from adm_aud_cambio where cambio_id > v_base and tabla = 'ADM_SEG_USUARIO' and operacion = 'D' and registro_id = v_usuario_id;
    verificar('20 delete genera 1 fila D con la fila completa en "antes" (después null)',
              v_n = 1 and v_json like '%"col":"username","antes":"ZZHIST_USUARIO","despues":null%'
              and v_json like '%"col":"email","antes":"zzhist@prueba.local"%' and v_json like '%"col":"estado","antes":"A"%'
              and v_json like '%"col":"password_hash","antes":null,"despues":null,"reservado":true%', dbms_lob.substr(v_json, 600));
    select count(*) into v_n from adm_aud_cambio
     where cambio_id > v_base and tabla = 'ADM_SEG_USUARIO_ROL' and operacion = 'D' and registro_padre_id = v_usuario_id;
    verificar('21 borrado en cascada (on delete cascade) de la hija también queda registrado', v_n = 1, 'filas=' || v_n);

    marcar;
    delete from adm_seg_rol where rol_id = v_rol_id;
    verificar('22 delete de rol: 1 fila del rol y 1 de su permiso (cascada)',
              contar('ADM_SEG_ROL', 'D') = 1 and contar('ADM_SEG_ROL_PERMISO', 'D') = 1);

    -- 9. Sentencia de varias filas ------------------------------------------------------------
    marcar;
    insert into adm_gen_mensaje_error (codigo, mensaje)
    select 'ZZHIST_' || level, 'Mensaje ' || level from dual connect by level <= 25;
    update adm_gen_mensaje_error set mensaje = mensaje || ' (editado)' where codigo like 'ZZHIST\_%' escape '\';
    select count(*), count(distinct transaccion_id), max(cambio_id) - min(cambio_id) + 1
      into v_n, v_filas, v_texto
      from adm_aud_cambio where cambio_id > v_base and tabla = 'ADM_GEN_MENSAJE_ERROR';
    verificar('23 insert y update de 25 filas en una sentencia: 25 + 25 filas, misma transacción',
              v_n = 50 and v_filas = 1 and contar('ADM_GEN_MENSAJE_ERROR', 'U') = 25, 'filas=' || v_n);

    -- 10. JSON válido y expandible ---------------------------------------------------------------
    select count(*), count(case when cambios is not json then 1 end), sum(json_value(cambios, '$.size()' returning number))
      into v_n, v_filas, v_texto
      from adm_aud_cambio where transaccion_id = v_tx;
    select count(*) into v_usro_id from adm_aud_cambio_det_v where transaccion_id = v_tx;
    verificar('24 todo el JSON de la prueba es válido y la vista lo expande completo (' || v_n || ' filas, ' || v_usro_id || ' campos)',
              v_n > 50 and v_filas = 0 and to_number(v_texto) = v_usro_id, 'no json=' || v_filas || ' size=' || v_texto);

    -- 11. El historial no se modifica ni se borra ---------------------------------------------------
    begin
        update adm_aud_cambio set usuario = 'OTRO' where transaccion_id = v_tx;
        verificar('25 update directo sobre adm_aud_cambio es rechazado', false, 'no dio error');
    exception when others then
        verificar('25 update directo sobre adm_aud_cambio es rechazado', sqlcode = -20040, sqlerrm);
    end;
    begin
        delete from adm_aud_cambio where transaccion_id = v_tx;
        verificar('26 delete directo sobre adm_aud_cambio es rechazado', false, 'no dio error');
    exception when others then
        verificar('26 delete directo sobre adm_aud_cambio es rechazado', sqlcode = -20040, sqlerrm);
    end;

    -- 12. Purga por retención --------------------------------------------------------------------------
    begin
        adm_aud_cambio_api.purgar(i_meses_retencion => 0, o_filas => v_filas);
        verificar('27 purga con retención menor a 1 mes es rechazada', false, 'no dio error');
    exception when others then
        verificar('27 purga con retención menor a 1 mes es rechazada', sqlcode = -20041, sqlerrm);
    end;
    insert into adm_aud_cambio (app_codigo, tabla, registro_id, operacion, cambios, fecha)
    values ('ADM', 'ZZHIST_ANTIGUA', 1, 'I', '[{"col":"x","antes":null,"despues":"1"}]', add_months(systimestamp, -85));
    insert into adm_aud_cambio (app_codigo, tabla, registro_id, operacion, cambios, fecha)
    values ('ADM', 'ZZHIST_ANTIGUA', 2, 'I', '[{"col":"x","antes":null,"despues":"1"}]', add_months(systimestamp, -83));
    select count(*) into v_n from adm_aud_cambio where transaccion_id = v_tx;
    adm_aud_cambio_api.purgar(i_meses_retencion => 84, o_filas => v_filas);
    select count(*) into v_usro_id from adm_aud_cambio where transaccion_id = v_tx;
    select count(*) into v_rol_id from adm_aud_cambio where tabla = 'ZZHIST_ANTIGUA';
    verificar('28 purga a 84 meses: borra la fila de 85 meses, conserva la de 83 y lo reciente',
              v_filas >= 1 and v_rol_id = 1 and v_usro_id = v_n, 'borradas=' || v_filas || ' quedan antiguas=' || v_rol_id);
    begin
        delete from adm_aud_cambio where tabla = 'ZZHIST_ANTIGUA';
        verificar('29 después de la purga el delete directo sigue rechazado', false, 'no dio error');
    exception when others then
        verificar('29 después de la purga el delete directo sigue rechazado', sqlcode = -20040, sqlerrm);
    end;
    begin
        insert into adm_aud_cambio (app_codigo, tabla, registro_id, operacion, cambios) values ('ADM', 'ZZHIST', 1, 'U', '{no es json');
        verificar('30 check is json rechaza un JSON inválido', false, 'no dio error');
    exception when others then
        verificar('30 check is json rechaza un JSON inválido', sqlcode = -2290, sqlerrm);
    end;

    -- 13. Rollback deshace el historial -----------------------------------------------------------------
    rollback;
    select count(*) into v_n from adm_aud_cambio where transaccion_id = v_tx or tabla like 'ZZHIST%';
    select count(*) into v_filas from adm_gen_empresa where codigo = 'ZZHIST1';
    verificar('31 rollback deshace los datos y también su historial (no es autónomo)', v_n = 0 and v_filas = 0, 'quedaron=' || v_n);

    -- 14. Generador: validaciones ---------------------------------------------------------------------------
    begin
        v_json := adm_aud_cambio_utl.generar_trigger(i_tabla => 'adm_no_existe');
        verificar('32 generador: tabla inexistente da error claro', false, 'no dio error');
    exception when others then
        verificar('32 generador: tabla inexistente da error claro', sqlcode = -20042, sqlerrm);
    end;
    v_json := adm_aud_cambio_utl.generar_trigger(i_tabla => 'adm_seg_usuario', i_columnas_excluidas => 'intentos_fallidos, fecha_ultimo_login');
    verificar('33 generador: el hash nunca se pasa a agregar_*; solo agregar_reservado',
              v_json like '%agregar_reservado(v_detalle, ''password_hash'')%'
              and v_json not like '%''password_hash'',%:old.password_hash, :new.password_hash)%'
              and v_json not like '%intentos_fallidos'',%' and v_json like '%trigger trg_adm_usu_aiud%');
    select count(*) into v_n
      from all_triggers
     where owner = sys_context('userenv', 'current_schema')
       and trigger_name in ('TRG_ADM_EMP_AIUD', 'TRG_ADM_APL_AIUD', 'TRG_ADM_MOD_AIUD', 'TRG_ADM_PER_AIUD', 'TRG_ADM_ROL_AIUD',
                            'TRG_ADM_ROPE_AIUD', 'TRG_ADM_USU_AIUD', 'TRG_ADM_USRO_AIUD', 'TRG_ADM_MSE_AIUD', 'TRG_ADM_CAM_BUD')
       and status = 'ENABLED';
    verificar('34 los 9 triggers de historial de ADM y el de protección están instalados y habilitados', v_n = 10, 'hay ' || v_n);
    select count(*) into v_n from all_scheduler_jobs
     where owner = sys_context('userenv', 'current_schema') and job_name = 'JOB_ADM_PURGAR_CAMBIO' and enabled = 'TRUE';
    verificar('35 job de purga mensual creado y habilitado', v_n = 1);

    rollback;
    dbms_output.put_line('-----');
    dbms_output.put_line('Parte 1: ' || v_fallas || ' caso(s) con falla.');
    if v_fallas > 0 then
        raise_application_error(-20999, v_fallas || ' caso(s) con falla en el historial de cambios (parte 1)');
    end if;
end;
/

prompt == Parte 2: sentencias masivas, fila grande y rendimiento (10.000 filas)
whenever sqlerror continue
begin
    execute immediate 'drop table adm_gen_prueba_hist purge';
exception when others then
    if sqlcode <> -942 then raise; end if;
end;
/
whenever sqlerror exit failure rollback

create table adm_gen_prueba_hist (
    prueba_hist_id      number generated by default on null as identity,
    codigo              varchar2(30)   not null,
    nombre              varchar2(200),
    monto               number(18,2),
    fecha_proceso       date,
    estado              varchar2(1)    default on null 'A' not null,
    texto_1             varchar2(4000),
    texto_2             varchar2(4000),
    texto_3             varchar2(4000),
    texto_4             varchar2(4000),
    texto_5             varchar2(4000),
    texto_6             varchar2(4000),
    texto_7             varchar2(4000),
    texto_8             varchar2(4000),
    texto_9             varchar2(4000),
    nota                clob,
    creado_por          varchar2(100)  default on null user not null,
    fecha_creacion      timestamp with local time zone default on null systimestamp not null,
    constraint pk_adm_prh primary key (prueba_hist_id)
);
comment on table adm_gen_prueba_hist is 'Tabla de trabajo de tests/sql/adm/historial.sql. Abrev: prh';

variable fallas_parte_2 number
whenever sqlerror continue

declare
    c_filas       constant pls_integer := 10000;
    v_fallas      pls_integer := 0;
    v_inicio      timestamp with time zone;
    v_ejec_antes  number;
    v_n           number;
    v_lotes       number;
    v_tx          number;
    v_min         number;
    v_json        clob;
    v_ms_fila_sin   number;
    v_ms_fila_con   number;
    v_ms_masivo_sin number;
    v_ms_masivo_con number;

    procedure verificar (i_caso in varchar2, i_ok in boolean, i_detalle in varchar2 default null) is
    begin
        if i_ok then
            dbms_output.put_line('OK     ' || i_caso);
        else
            v_fallas := v_fallas + 1;
            dbms_output.put_line('FALLA  ' || i_caso || case when i_detalle is not null then ' -> ' || i_detalle end);
        end if;
    end verificar;

    function ms (i_desde in timestamp with time zone) return number is
        v_dif  interval day to second := systimestamp - i_desde;
    begin
        return round(extract(day from v_dif) * 86400000 + extract(hour from v_dif) * 3600000
                     + extract(minute from v_dif) * 60000 + extract(second from v_dif) * 1000);
    end ms;
    -- Ejecuciones acumuladas del insert del historial (null si no hay acceso a v$sql)
    function ejecuciones_insert return number is
        v_ejecuciones  number;
    begin
        execute immediate
            q'[select coalesce(sum(executions), 0) from v$sql
                where sql_text like 'INSERT INTO ADM_AUD_CAMBIO%' and sql_text like '%:B%'
                  and parsing_schema_name = sys_context('userenv', 'current_schema')]'
            into v_ejecuciones;
        return v_ejecuciones;
    exception
        when others then
            return null;
    end ejecuciones_insert;
begin
    insert into adm_gen_prueba_hist (codigo, nombre, monto, fecha_proceso)
    select 'P' || level, 'Nombre ' || level, level + 0.25, date '2026-01-01' + mod(level, 300)
      from dual connect by level <= c_filas;
    select min(prueba_hist_id) into v_min from adm_gen_prueba_hist;

    -- Sin trigger -----------------------------------------------------------------
    v_inicio := systimestamp;
    for i in 0 .. c_filas - 1 loop
        update adm_gen_prueba_hist set nombre = 'Sin trigger ' || i, monto = monto + 1 where prueba_hist_id = v_min + i;
    end loop;
    v_ms_fila_sin := ms(v_inicio);

    v_inicio := systimestamp;
    update adm_gen_prueba_hist set nombre = 'Masivo sin trigger', monto = monto + 1;
    v_ms_masivo_sin := ms(v_inicio);

    -- Con trigger (DDL: confirma los datos de la tabla de trabajo; aún no hay historial) --
    adm_aud_cambio_utl.crear_trigger(i_tabla => 'adm_gen_prueba_hist');
    select count(*) into v_n from all_triggers
     where owner = sys_context('userenv', 'current_schema') and trigger_name = 'TRG_ADM_PRH_AIUD' and status = 'ENABLED';
    verificar('36 crear_trigger compila el trigger generado (trg_adm_prh_aiud); la columna CLOB queda fuera', v_n = 1);

    v_inicio := systimestamp;
    for i in 0 .. c_filas - 1 loop
        update adm_gen_prueba_hist set nombre = 'Con trigger ' || i, monto = monto + 1 where prueba_hist_id = v_min + i;
    end loop;
    v_ms_fila_con := ms(v_inicio);
    select count(*) into v_n from adm_aud_cambio where tabla = 'ADM_GEN_PRUEBA_HIST';
    verificar('37 ' || c_filas || ' updates de una fila generan ' || c_filas || ' filas de historial', v_n = c_filas, 'filas=' || v_n);

    v_ejec_antes := ejecuciones_insert;
    v_inicio := systimestamp;
    update adm_gen_prueba_hist set nombre = 'Masivo con trigger', monto = monto + 1;
    v_ms_masivo_con := ms(v_inicio);
    v_lotes := ejecuciones_insert - v_ejec_antes;
    select count(*) - c_filas, count(distinct transaccion_id) into v_n, v_tx from adm_aud_cambio where tabla = 'ADM_GEN_PRUEBA_HIST';
    verificar('38 update masivo de ' || c_filas || ' filas en una sentencia genera ' || c_filas || ' filas de historial',
              v_n = c_filas and v_tx = 1, 'filas=' || v_n);

    -- Lotes: el insert del historial se ejecuta por FORALL, c_filas_lote filas por ejecución
    if v_lotes is null then
        dbms_output.put_line('OMITIDO 38b cantidad de lotes: sin acceso a v$sql (ejecutar como DBA para verificarlo)');
    else
        verificar('38b las ' || c_filas || ' filas se insertaron por lotes: ' || v_lotes || ' ejecuciones del insert ('
                  || adm_aud_cambio_api.c_filas_lote || ' filas por lote), no una por fila',
                  -- margen: v$sql es global y otra sesión puede insertar historial al mismo tiempo
                  v_lotes between ceil(c_filas / adm_aud_cambio_api.c_filas_lote) and ceil(c_filas / adm_aud_cambio_api.c_filas_lote) + 10,
                  'ejecuciones=' || v_lotes);
    end if;

    v_inicio := systimestamp;
    update adm_gen_prueba_hist set estado = 'I' where prueba_hist_id < v_min + 37;
    select count(*) into v_n from adm_aud_cambio where tabla = 'ADM_GEN_PRUEBA_HIST' and json_value(cambios, '$[0].col') = 'estado' and json_value(cambios, '$[0].despues') = 'I';
    verificar('39 update de 37 filas (menos de un lote) genera exactamente 37 filas', v_n = 37, 'filas=' || v_n);

    -- Fila grande: más de 32767 bytes de JSON -> se guarda como CLOB ------------------------
    update adm_gen_prueba_hist
       set texto_1 = rpad('a', 4000, 'a'), texto_2 = rpad('b', 4000, 'b'), texto_3 = rpad('c', 4000, 'c'),
           texto_4 = rpad('d', 4000, 'd'), texto_5 = rpad('e', 4000, 'e'), texto_6 = rpad('f', 4000, 'f'),
           texto_7 = rpad('g', 4000, 'g'), texto_8 = rpad('h', 4000, 'h'), texto_9 = rpad('i', 4000, 'i'),
           nota = 'no auditado'
     where prueba_hist_id = v_min;
    select cambios, case when cambios is json then 1 else 0 end into v_json, v_lotes
      from adm_aud_cambio
     where cambio_id = (select max(cambio_id) from adm_aud_cambio where tabla = 'ADM_GEN_PRUEBA_HIST' and registro_id = v_min);
    select count(*) into v_n from adm_aud_cambio_det_v
     where tabla = 'ADM_GEN_PRUEBA_HIST' and registro_id = v_min and columna like 'texto%' and length(despues) = 4000;
    verificar('40 fila con más de 32K de cambios: JSON válido de ' || length(v_json) || ' caracteres, expandible; el CLOB no se audita',
              length(v_json) > 32767 and v_lotes = 1 and v_n = 9 and v_json not like '%nota%', 'campos=' || v_n);

    rollback;
    select count(*) into v_n from adm_aud_cambio where tabla = 'ADM_GEN_PRUEBA_HIST';
    verificar('41 rollback deja el historial de la tabla de trabajo en cero', v_n = 0, 'quedaron=' || v_n);

    dbms_output.put_line('-----');
    dbms_output.put_line('Rendimiento (' || c_filas || ' filas, 2 columnas cambiadas por fila):');
    dbms_output.put_line('  ' || c_filas || ' updates de 1 fila   sin trigger: ' || v_ms_fila_sin || ' ms   con trigger: ' || v_ms_fila_con
                         || ' ms   costo: ' || round((v_ms_fila_con - v_ms_fila_sin) / c_filas * 1000) || ' microsegundos por fila');
    dbms_output.put_line('  1 update de ' || c_filas || ' filas  sin trigger: ' || v_ms_masivo_sin || ' ms   con trigger: ' || v_ms_masivo_con
                         || ' ms   costo: ' || round((v_ms_masivo_con - v_ms_masivo_sin) / c_filas * 1000) || ' microsegundos por fila');
    dbms_output.put_line('Parte 2: ' || v_fallas || ' caso(s) con falla.');
    :fallas_parte_2 := v_fallas;
end;
/

-- La tabla de trabajo se borra siempre, también si la parte 2 falló
rollback;
drop table adm_gen_prueba_hist purge;

whenever sqlerror exit failure rollback
begin
    if coalesce(:fallas_parte_2, 1) > 0 then
        raise_application_error(-20999, 'Falla en el historial de cambios (parte 2)');
    end if;
end;
/
prompt == Fin de las pruebas del historial de cambios
