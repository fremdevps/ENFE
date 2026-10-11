create or replace package body erp_stk_numerador_ctr
as

    procedure actualizar_siguiente (
        i_empresa_id   in  erp_stk_numerador.empresa_id%type,
        i_sucursal_id  in  erp_stk_numerador.sucursal_id%type,
        i_codigo       in  erp_stk_numerador.codigo%type,
        o_numero       out erp_stk_numerador.ultimo_numero%type
    ) is
    begin
        update erp_stk_numerador
           set ultimo_numero = ultimo_numero + 1
         where empresa_id  = i_empresa_id
           and sucursal_id = i_sucursal_id
           and codigo      = upper(i_codigo)
        returning ultimo_numero into o_numero;
        if sql%rowcount = 0 then
            begin
                insert into erp_stk_numerador (empresa_id, sucursal_id, codigo, ultimo_numero)
                values (i_empresa_id, i_sucursal_id, upper(i_codigo), 1)
                returning ultimo_numero into o_numero;
            exception
                when dup_val_on_index then
                    -- otra sesión lo creó a la vez: ya existe, se toma el siguiente
                    update erp_stk_numerador
                       set ultimo_numero = ultimo_numero + 1
                     where empresa_id  = i_empresa_id
                       and sucursal_id = i_sucursal_id
                       and codigo      = upper(i_codigo)
                    returning ultimo_numero into o_numero;
            end;
        end if;
    end actualizar_siguiente;

end erp_stk_numerador_ctr;
/
