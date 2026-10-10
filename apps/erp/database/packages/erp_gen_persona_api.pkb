create or replace package body erp_gen_persona_api
as

    -- Arma, normaliza y valida el registro antes de insertar/actualizar.
    function preparar (
        i_persona_id             in number,
        i_tipo_persona           in varchar2,
        i_tipo_doc_identidad_id  in number,
        i_nro_documento          in varchar2,
        i_dv                     in varchar2,
        i_razon_social           in varchar2,
        i_nombres                in varchar2,
        i_apellidos              in varchar2,
        i_nombre_fantasia        in varchar2,
        i_es_contribuyente       in varchar2,
        i_pais_id                in number,
        i_fecha_nacimiento       in date,
        i_email                  in varchar2,
        i_telefono               in varchar2,
        i_observacion            in varchar2,
        i_estado                 in varchar2
    ) return erp_gen_persona%rowtype is
        r_persona  erp_gen_persona%rowtype;
    begin
        r_persona.persona_id            := i_persona_id;
        r_persona.tipo_persona          := i_tipo_persona;
        r_persona.tipo_doc_identidad_id := i_tipo_doc_identidad_id;
        r_persona.nro_documento         := i_nro_documento;
        r_persona.dv                    := i_dv;
        r_persona.nombres               := trim(i_nombres);
        r_persona.apellidos             := trim(i_apellidos);
        r_persona.razon_social          := coalesce(trim(i_razon_social),
                                                    trim(r_persona.nombres || ' ' || r_persona.apellidos));
        r_persona.nombre_fantasia       := trim(i_nombre_fantasia);
        r_persona.es_contribuyente      := coalesce(i_es_contribuyente, 'N');
        r_persona.pais_id               := i_pais_id;
        r_persona.fecha_nacimiento      := i_fecha_nacimiento;
        r_persona.email                 := lower(trim(i_email));
        r_persona.telefono              := trim(i_telefono);
        r_persona.observacion           := i_observacion;
        r_persona.estado                := coalesce(i_estado, 'A');

        erp_gen_persona_reg.aplicar_formato_documento(io_nro_documento => r_persona.nro_documento,
                                                      io_dv            => r_persona.dv);
        erp_gen_persona_reg.validar_documento(i_tipo_doc_identidad_id => r_persona.tipo_doc_identidad_id,
                                              i_nro_documento         => r_persona.nro_documento,
                                              i_dv                    => r_persona.dv);
        return r_persona;
    end preparar;

    procedure crear (
        i_tipo_persona           in  erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in  erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in  erp_gen_persona.nro_documento%type,
        i_dv                     in  erp_gen_persona.dv%type,
        i_razon_social           in  erp_gen_persona.razon_social%type,
        i_nombres                in  erp_gen_persona.nombres%type,
        i_apellidos              in  erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in  erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in  erp_gen_persona.es_contribuyente%type,
        i_pais_id                in  erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in  erp_gen_persona.fecha_nacimiento%type,
        i_email                  in  erp_gen_persona.email%type,
        i_telefono               in  erp_gen_persona.telefono%type,
        i_observacion            in  erp_gen_persona.observacion%type,
        i_estado                 in  erp_gen_persona.estado%type,
        o_persona_id             out erp_gen_persona.persona_id%type
    ) is
    begin
        erp_gen_persona_ctr.insertar(
            i_persona    => preparar(
                                i_persona_id            => null,
                                i_tipo_persona          => i_tipo_persona,
                                i_tipo_doc_identidad_id => i_tipo_doc_identidad_id,
                                i_nro_documento         => i_nro_documento,
                                i_dv                    => i_dv,
                                i_razon_social          => i_razon_social,
                                i_nombres               => i_nombres,
                                i_apellidos             => i_apellidos,
                                i_nombre_fantasia       => i_nombre_fantasia,
                                i_es_contribuyente      => i_es_contribuyente,
                                i_pais_id               => i_pais_id,
                                i_fecha_nacimiento      => i_fecha_nacimiento,
                                i_email                 => i_email,
                                i_telefono              => i_telefono,
                                i_observacion           => i_observacion,
                                i_estado                => i_estado),
            o_persona_id => o_persona_id);
    end crear;

    procedure modificar (
        i_persona_id             in erp_gen_persona.persona_id%type,
        i_tipo_persona           in erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type,
        i_razon_social           in erp_gen_persona.razon_social%type,
        i_nombres                in erp_gen_persona.nombres%type,
        i_apellidos              in erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in erp_gen_persona.es_contribuyente%type,
        i_pais_id                in erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in erp_gen_persona.fecha_nacimiento%type,
        i_email                  in erp_gen_persona.email%type,
        i_telefono               in erp_gen_persona.telefono%type,
        i_observacion            in erp_gen_persona.observacion%type,
        i_estado                 in erp_gen_persona.estado%type
    ) is
    begin
        erp_gen_persona_ctr.actualizar(
            i_persona => preparar(
                             i_persona_id            => i_persona_id,
                             i_tipo_persona          => i_tipo_persona,
                             i_tipo_doc_identidad_id => i_tipo_doc_identidad_id,
                             i_nro_documento         => i_nro_documento,
                             i_dv                    => i_dv,
                             i_razon_social          => i_razon_social,
                             i_nombres               => i_nombres,
                             i_apellidos             => i_apellidos,
                             i_nombre_fantasia       => i_nombre_fantasia,
                             i_es_contribuyente      => i_es_contribuyente,
                             i_pais_id               => i_pais_id,
                             i_fecha_nacimiento      => i_fecha_nacimiento,
                             i_email                 => i_email,
                             i_telefono              => i_telefono,
                             i_observacion           => i_observacion,
                             i_estado                => i_estado));
    end modificar;

    procedure validar_documento (
        i_tipo_doc_identidad_id  in number,
        i_nro_documento          in varchar2,
        i_dv                     in varchar2
    ) is
    begin
        erp_gen_persona_reg.validar_documento(i_tipo_doc_identidad_id => i_tipo_doc_identidad_id,
                                              i_nro_documento         => i_nro_documento,
                                              i_dv                    => i_dv);
    end validar_documento;

    function obtener_dv_ruc (
        i_numero  in varchar2
    ) return varchar2 is
    begin
        return erp_gen_persona_reg.calcular_dv_ruc(i_numero => i_numero);
    end obtener_dv_ruc;

end erp_gen_persona_api;
/
