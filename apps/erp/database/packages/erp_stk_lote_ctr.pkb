create or replace package body erp_stk_lote_ctr
as

    procedure insertar (
        i_lote     in  erp_stk_lote%rowtype,
        o_lote_id  out erp_stk_lote.lote_id%type
    ) is
    begin
        insert into erp_stk_lote (empresa_id, producto_id, codigo, tipo, fecha_elaboracion, fecha_vencimiento, estado)
        values (i_lote.empresa_id, i_lote.producto_id, i_lote.codigo, i_lote.tipo, i_lote.fecha_elaboracion,
                i_lote.fecha_vencimiento, i_lote.estado)
        returning lote_id into o_lote_id;
    end insertar;

    procedure actualizar (
        i_lote  in erp_stk_lote%rowtype
    ) is
    begin
        update erp_stk_lote
           set fecha_elaboracion = i_lote.fecha_elaboracion,
               fecha_vencimiento = i_lote.fecha_vencimiento,
               estado            = i_lote.estado
         where lote_id = i_lote.lote_id;
    end actualizar;

    function obtener (
        i_lote_id  in erp_stk_lote.lote_id%type
    ) return erp_stk_lote%rowtype is
        r_lote  erp_stk_lote%rowtype;
    begin
        select * into r_lote from erp_stk_lote where lote_id = i_lote_id;
        return r_lote;
    exception
        when no_data_found then
            return r_lote;
    end obtener;

end erp_stk_lote_ctr;
/
