create or replace package body erp_gen_periodo_ctr
as

    function obtener (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type
    ) return erp_gen_periodo%rowtype is
        r_periodo  erp_gen_periodo%rowtype;
    begin
        select *
          into r_periodo
          from erp_gen_periodo
         where empresa_id = i_empresa_id
           and modulo     = upper(i_modulo)
           and anio       = i_anio
           and mes        = i_mes;
        return r_periodo;
    exception
        when no_data_found then
            return r_periodo;
    end obtener;

    procedure insertar (
        i_empresa_id  in erp_gen_periodo.empresa_id%type,
        i_modulo      in erp_gen_periodo.modulo%type,
        i_anio        in erp_gen_periodo.anio%type,
        i_mes         in erp_gen_periodo.mes%type,
        i_estado      in erp_gen_periodo.estado%type
    ) is
    begin
        merge into erp_gen_periodo t
        using (select i_empresa_id empresa_id, upper(i_modulo) modulo, i_anio anio, i_mes mes from dual) s
           on (t.empresa_id = s.empresa_id and t.modulo = s.modulo and t.anio = s.anio and t.mes = s.mes)
         when not matched then
            insert (empresa_id, modulo, anio, mes, estado)
            values (s.empresa_id, s.modulo, s.anio, s.mes, i_estado);
    end insertar;

    procedure actualizar (
        i_periodo_id    in erp_gen_periodo.periodo_id%type,
        i_estado        in erp_gen_periodo.estado%type,
        i_fecha_cierre  in erp_gen_periodo.fecha_cierre%type,
        i_cerrado_por   in erp_gen_periodo.cerrado_por%type
    ) is
    begin
        update erp_gen_periodo
           set estado       = i_estado,
               fecha_cierre = i_fecha_cierre,
               cerrado_por  = i_cerrado_por
         where periodo_id = i_periodo_id;
    end actualizar;

end erp_gen_periodo_ctr;
/
