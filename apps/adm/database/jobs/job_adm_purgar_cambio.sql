-- =============================================================================
-- Job  : job_adm_purgar_cambio
-- Desc : Purga mensual del historial de cambios (adm_aud_cambio): día 1 a las
--        03:00, borra lo anterior a la retención (argumento 1, en meses; 84 por
--        defecto). Idempotente: si el job ya existe no lo toca, así se conserva
--        la retención configurada. Para cambiarla:
--          begin
--              dbms_scheduler.set_job_argument_value('JOB_ADM_PURGAR_CAMBIO', 1, '120');
--          end;
--        Se crea en el esquema actual (current_schema), no en el del usuario
--        conectado, para que funcione igual instalando como DBA.
-- =============================================================================
declare
    c_esquema  constant varchar2(128) := sys_context('userenv', 'current_schema');
    c_job      constant varchar2(300) := '"' || c_esquema || '".JOB_ADM_PURGAR_CAMBIO';
    v_existe   pls_integer;
begin
    select count(*)
      into v_existe
      from all_scheduler_jobs j
     where j.owner = c_esquema
       and j.job_name = 'JOB_ADM_PURGAR_CAMBIO';

    if v_existe = 0 then
        dbms_scheduler.create_job(
            job_name            => c_job,
            job_type            => 'STORED_PROCEDURE',
            job_action          => 'ADM_AUD_CAMBIO_API.EJECUTAR_PURGA',
            number_of_arguments => 1,
            start_date          => systimestamp,
            repeat_interval     => 'FREQ=MONTHLY;BYMONTHDAY=1;BYHOUR=3;BYMINUTE=0;BYSECOND=0',
            enabled             => false,
            auto_drop           => false,
            comments            => 'Purga mensual del historial de cambios (adm_aud_cambio) por retención');
        dbms_scheduler.set_job_argument_value(
            job_name          => c_job,
            argument_position => 1,
            argument_value    => '84');
        dbms_scheduler.enable(name => c_job);
    end if;
end;
/
