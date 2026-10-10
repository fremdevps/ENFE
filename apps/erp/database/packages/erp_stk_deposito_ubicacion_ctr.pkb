create or replace package body erp_stk_deposito_ubicacion_ctr
as

    procedure insertar (
        i_deposito_id            in  erp_stk_deposito_ubicacion.deposito_id%type,
        i_codigo                 in  erp_stk_deposito_ubicacion.codigo%type,
        i_nombre                 in  erp_stk_deposito_ubicacion.nombre%type,
        i_tipo                   in  erp_stk_deposito_ubicacion.tipo%type,
        i_es_disponible          in  erp_stk_deposito_ubicacion.es_disponible%type,
        o_deposito_ubicacion_id  out erp_stk_deposito_ubicacion.deposito_ubicacion_id%type
    ) is
    begin
        begin
            insert into erp_stk_deposito_ubicacion (deposito_id, codigo, nombre, tipo, es_disponible)
            values (i_deposito_id, upper(i_codigo), i_nombre, i_tipo, i_es_disponible)
            returning deposito_ubicacion_id into o_deposito_ubicacion_id;
        exception
            when dup_val_on_index then
                select deposito_ubicacion_id
                  into o_deposito_ubicacion_id
                  from erp_stk_deposito_ubicacion
                 where deposito_id = i_deposito_id
                   and codigo      = upper(i_codigo);
        end;
    end insertar;

end erp_stk_deposito_ubicacion_ctr;
/
