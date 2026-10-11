create or replace package body erp_stk_traslado_item_ctr
as

    procedure insertar (
        i_item  in  erp_stk_traslado_item%rowtype,
        o_traslado_item_id  out erp_stk_traslado_item.traslado_item_id%type
    ) is
    begin
        insert into erp_stk_traslado_item values i_item
        returning traslado_item_id into o_traslado_item_id;
    end insertar;

    procedure actualizar (
        i_item  in erp_stk_traslado_item%rowtype
    ) is
    begin
        update erp_stk_traslado_item
           set row = i_item
         where traslado_item_id = i_item.traslado_item_id;
    end actualizar;

    procedure eliminar (
        i_traslado_item_id  in erp_stk_traslado_item.traslado_item_id%type
    ) is
    begin
        delete from erp_stk_traslado_item
         where traslado_item_id = i_traslado_item_id;
    end eliminar;

end erp_stk_traslado_item_ctr;
/
