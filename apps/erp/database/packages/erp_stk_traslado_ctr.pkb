create or replace package body erp_stk_traslado_ctr
as

    procedure insertar (
        i_traslado  in  erp_stk_traslado%rowtype,
        o_traslado_id  out erp_stk_traslado.traslado_id%type
    ) is
    begin
        insert into erp_stk_traslado values i_traslado
        returning traslado_id into o_traslado_id;
    end insertar;

    procedure actualizar (
        i_traslado  in erp_stk_traslado%rowtype
    ) is
    begin
        update erp_stk_traslado
           set row = i_traslado
         where traslado_id = i_traslado.traslado_id;
    end actualizar;

    function bloquear (
        i_traslado_id  in erp_stk_traslado.traslado_id%type
    ) return erp_stk_traslado%rowtype is
        r_traslado  erp_stk_traslado%rowtype;
    begin
        select *
          into r_traslado
          from erp_stk_traslado
         where traslado_id = i_traslado_id
           for update;
        return r_traslado;
    end bloquear;

end erp_stk_traslado_ctr;
/
