# Cumplimiento fiscal: Paraguay y uso internacional

> Verificación del módulo General contra la norma, hecha el 2026-10-10.
> Marcas: **[OF]** fuente oficial leída · **[SEC]** fuente secundaria · **[NV]** no verificado.
> Lo marcado [SEC] o [NV] debe confirmarlo el contador antes de usarse en producción.

## 1. Estado de lo ya construido

| Tema | Estado | Detalle |
|---|---|---|
| IVA 10 % y 5 % | Correcto [OF] | Ley 6380/2019, art. 90. Al 5 %: alquiler de inmuebles para vivienda, enajenación de inmuebles, canasta familiar, productos agrícolas y pecuarios listados, medicamentos de uso humano. Al 10 %: todo lo demás |
| Vigencia de las tasas | Corregido | Rigen desde 2020-01-01 (Decreto 3107/2019). Para migrar documentos anteriores hay que cargar vigencias históricas |
| Gravado parcial | Corregido y probado [OF] | Inmuebles: base 30 % al 5 %. Bienes muebles de prestadores de servicios personales: 30 % al 10 %. Transporte internacional: 25 % al 10 % |
| Cálculo con IVA incluido y base parcial | **Corregido** [OF] | Fórmula de la DNIT: base = 100·M·P / (10000 + T·P). Ejemplo oficial probado en DEV: inmueble a 10.150.000 → base 3.000.000, IVA 150.000, exento 7.000.000 |
| Exento y exonerado | Correcto [OF] | Códigos de afectación SIFEN 3 y 2 |
| Dígito verificador del RUC | Correcto [OF] | Módulo 11. Coincide con el RUC de ejemplo del Manual Técnico (44444401-7) y con otros seis casos públicos |
| Tipos de documento de identidad | Correcto [OF] | Cédula, pasaporte, cédula extranjera, carnet de residencia, innominado, diplomática, otro. El innominado solo vale por debajo de Gs. 7.000.000 |
| Establecimiento y punto de expedición | Correcto [OF] | 3 dígitos cada uno, número de 7 (ejemplo oficial 001-002-0000250) |
| Monedas | Correcto [OF] | Guaraní sin decimales; códigos ISO 4217 |
| Plazos de documentos electrónicos | Correcto [OF] | Envío en 72 h; cancelación de factura en 48 h y de otros en 168 h; inutilización en los primeros 15 días del mes siguiente |
| "Departamento" de la empresa | Sin significado fiscal | Es una dimensión interna. En pantallas conviene distinguirlo del departamento geográfico |

## 2. Lo que falta o hay que cambiar

| # | Tema | Qué falta | Prioridad |
|---|---|---|---|
| 1 | **Retenciones** | El modelo actual (tasa + vigencia + monto mínimo) no alcanza. Ver §3 | Alta (fase de finanzas) |
| 2 | **Registro de comprobantes** | Hechauka fue reemplazado desde 2022 por el registro electrónico de comprobantes (RG 90/2021, en Marangatu). Los códigos de tipo de comprobante van en una tabla con vigencia | Alta (fase de documentos) |
| 3 | **Códigos oficiales por sistema** | Un solo código oficial no cubre SIFEN, el registro de comprobantes y las retenciones virtuales. Hace falta una tabla de equivalencias (entidad, sistema, código, vigencia) | Media |
| 4 | **Impuestos en cascada** | La base del IVA incluye el ISC. El motor hoy calcula cada impuesto por separado. Solo afecta a importadores y fabricantes de productos con ISC | Media |
| 5 | **Tipo de cambio por operación** | La norma pide el tipo comprador o vendedor del cierre del día hábil anterior, y el de Aduanas en importación y exportación. Hoy hay un único tipo por empresa | Media |
| 6 | **Feriados** | Rige la Ley 7544/2025, con feriados móviles que el Ejecutivo traslada por decreto. Falta el tipo de feriado (nacional, trasladado, extra) y la norma | Baja |
| 7 | **Geografía** | La tabla oficial de departamentos, distritos y ciudades es un archivo de la DNIT que no se pudo descargar. No se cargó nada sin verificar | Media |
| 8 | **Tipos de documento electrónico** | Reservar los códigos 2 (exportación), 3 (importación) y 8 (comprobante de retención), previstos por la DNIT | Baja |

## 3. Retenciones: qué necesita el modelo

Reglas vigentes (Decreto 3107/2019 y modificatorios; Decreto 3182/2019) [OF]:

| Caso | % | Base | Carácter |
|---|---|---|---|
| Sector público a proveedores | 30 | IVA del comprobante | A cuenta |
| Exportador, operación al 10 % | 70 | IVA | A cuenta |
| Exportador, tasa menor o transporte de productos agrícolas | 30 | IVA | A cuenta |
| Productos agrícolas | 10 | IVA | A cuenta |
| Agente designado | 30 | IVA | A cuenta |
| Procesadoras de tarjetas (IVA) | 0,90909 | Total de la operación | A cuenta |
| Pagos al exterior | 100 | IVA | Único y definitivo |
| Sector público, renta | 3 | Precio total | Anticipo |
| No residentes | 15 | Renta presunta (30, 50, 70 o 100 % del bruto) | Definitivo |
| Dividendos | 8 residente / 15 no residente | Dividendo | Definitivo |

El mínimo de IVA no es un monto fijo: no se retiene si las compras del mes al proveedor, sin IVA, son menores a **10 jornales mínimos** vigentes a la fecha de pago.

Lo que hay que agregar al modelo:
- **Base de cálculo**: impuesto del documento, total sin impuesto, total con impuesto, o renta presunta con su porcentaje.
- **Mínimo en unidad** (jornal, salario mínimo o moneda), cantidad y ámbito (mensual por proveedor, o por día y proveedor).
- **Tabla de índices con vigencia** para el jornal y el salario mínimo.
- **Carácter** (a cuenta o definitivo), tipo de agente, condición (tasa del ítem, producto agrícola, transporte) y concepto del comprobante de retención virtual.
- El indicador actual "es agente de retención" pasa a ser un **tipo de agente** con fecha desde.

## 4. Para usar el mismo modelo en otros países

Lo que ya sirve: varios impuestos por ítem, tasas con vigencia, categorías fiscales, persona con tipo de documento por país.

Lo que faltaría (solo lo estructural):
- percepciones calculadas e impuestos por jurisdicción subnacional (estado o provincia);
- régimen fiscal de la persona por país, que determina el tipo de comprobante;
- dígito verificador con algoritmo configurable por tipo de documento y de hasta 2 caracteres;
- niveles geográficos por país y código postal;
- esquema de numeración por país y un conector de factura electrónica por país detrás del mismo modelo;
- clasificación arancelaria del producto.

## 5. Datos de prueba verificados

RUC con dígito verificador correcto: 80002201-7, 80000519-8, 80009735-1, 80028061-0, 2660-3, 80000035-8, 44444401-7 (el del manual). Inválido para pruebas: 80053249-2.

## 6. Fuentes

- Ley 6380/2019: https://www.dnit.gov.py/documents/20123/399318/LEY+6380-2019.pdf/7437353b-7f7e-28e6-c41a-da57f1af1439
- Decreto 3107/2019 (IVA): https://impuestospy.com/impuestos/decreto-n-3-107-2019/
- Decreto 3182/2019 (IRE): https://impuestospy.com/impuestos/decreto-n-3-182-2019/
- SIFEN, documentación técnica: https://www.dnit.gov.py/web/e-kuatia/documentacion-tecnica
- DNIT, IVA en transferencia de inmuebles: https://www.dnit.gov.py/web/portal-institucional/w/iva-transferencia-de-inmueble
- RG 90/2021 (registro de comprobantes): https://www.dnit.gov.py/web/portal-institucional/w/resolucion-general-n-90-21
- Retenciones virtuales: https://www.dnit.gov.py/web/portal-institucional/tesaka
- Ley 7544/2025 (feriados): https://ferrere.com/en/news/paraguay-promulga-ley-sobre-feriados-nacionales/
