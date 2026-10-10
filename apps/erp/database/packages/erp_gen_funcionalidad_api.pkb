create or replace package body erp_gen_funcionalidad_api
as

    function es_activa_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number
    ) return varchar2 is
        v_cantidad  pls_integer;
    begin
        select count(*)
          into v_cantidad
          from erp_gen_funcionalidad f
          join erp_gen_empresa_func ef on ef.funcionalidad_id = f.funcionalidad_id
         where f.codigo      = upper(i_codigo)
           and f.estado      = 'A'
           and ef.empresa_id = i_empresa_id
           and ef.estado     = 'A';
        return case when v_cantidad > 0 then 'S' else 'N' end;
    end es_activa_sn;

    procedure crear_desde_rubro (
        i_empresa_id  in number
    ) is
    begin
        for r in (select rf.funcionalidad_id
                    from erp_gen_empresa_config ec
                    join erp_gen_rubro_func rf on rf.rubro_id = ec.rubro_id
                   where ec.empresa_id = i_empresa_id) loop
            erp_gen_empresa_func_ctr.insertar(i_empresa_id => i_empresa_id, i_funcionalidad_id => r.funcionalidad_id);
        end loop;
    end crear_desde_rubro;

end erp_gen_funcionalidad_api;
/
