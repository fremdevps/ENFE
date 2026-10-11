create or replace package body erp_doc_numerador_ctr
as

    function obtener (
        i_numerador_id  in erp_doc_numerador.numerador_id%type
    ) return erp_doc_numerador%rowtype is
        r_numerador  erp_doc_numerador%rowtype;
    begin
        select *
          into r_numerador
          from erp_doc_numerador
         where numerador_id = i_numerador_id;
        return r_numerador;
    exception
        when no_data_found then
            return r_numerador;
    end obtener;

    function bloquear (
        i_numerador_id     in erp_doc_numerador.numerador_id%type,
        i_espera_segundos  in pls_integer
    ) return erp_doc_numerador%rowtype is
        r_numerador  erp_doc_numerador%rowtype;
    begin
        -- SQL dinámico solo porque la cláusula WAIT exige un literal; el identificador va por bind
        execute immediate
            'select * from erp_doc_numerador where numerador_id = :id for update wait '
            || to_char(greatest(trunc(coalesce(i_espera_segundos, 0)), 0))
            into r_numerador
            using i_numerador_id;
        return r_numerador;
    exception
        when no_data_found then
            return r_numerador;
    end bloquear;

    procedure actualizar_numero (
        i_numerador_id   in erp_doc_numerador.numerador_id%type,
        i_numero_actual  in erp_doc_numerador.numero_actual%type
    ) is
    begin
        update erp_doc_numerador
           set numero_actual = i_numero_actual
         where numerador_id = i_numerador_id;
    end actualizar_numero;

end erp_doc_numerador_ctr;
/
