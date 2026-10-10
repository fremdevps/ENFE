create or replace package body erp_gen_persona_ctr
as

    procedure insertar (
        i_persona  in  erp_gen_persona%rowtype,
        o_persona_id out erp_gen_persona.persona_id%type
    ) is
    begin
        insert into erp_gen_persona (
            tipo_persona, tipo_doc_identidad_id, nro_documento, dv, razon_social, nombres, apellidos,
            nombre_fantasia, es_contribuyente, pais_id, fecha_nacimiento, email, telefono, observacion, estado)
        values (
            i_persona.tipo_persona, i_persona.tipo_doc_identidad_id, i_persona.nro_documento, i_persona.dv,
            i_persona.razon_social, i_persona.nombres, i_persona.apellidos, i_persona.nombre_fantasia,
            i_persona.es_contribuyente, i_persona.pais_id, i_persona.fecha_nacimiento, i_persona.email,
            i_persona.telefono, i_persona.observacion, i_persona.estado)
        returning persona_id into o_persona_id;
    end insertar;

    procedure actualizar (
        i_persona  in erp_gen_persona%rowtype
    ) is
    begin
        update erp_gen_persona
           set tipo_persona          = i_persona.tipo_persona,
               tipo_doc_identidad_id = i_persona.tipo_doc_identidad_id,
               nro_documento         = i_persona.nro_documento,
               dv                    = i_persona.dv,
               razon_social          = i_persona.razon_social,
               nombres               = i_persona.nombres,
               apellidos             = i_persona.apellidos,
               nombre_fantasia       = i_persona.nombre_fantasia,
               es_contribuyente      = i_persona.es_contribuyente,
               pais_id               = i_persona.pais_id,
               fecha_nacimiento      = i_persona.fecha_nacimiento,
               email                 = i_persona.email,
               telefono              = i_persona.telefono,
               observacion           = i_persona.observacion,
               estado                = i_persona.estado
         where persona_id = i_persona.persona_id;
    end actualizar;

end erp_gen_persona_ctr;
/
