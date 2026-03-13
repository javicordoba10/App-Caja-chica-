# Propuesta de Proyecto: Aplicación "Control de Caja Chica"

## 1. Resumen Ejecutivo
El presente documento describe el proyecto de desarrollo de la aplicación **"Control de Caja Chica"** para **Agropecuaria Las Marías**. El objetivo principal de este sistema es digitalizar, centralizar y optimizar la gestión de los fondos de caja chica, permitiendo un seguimiento en tiempo real de los ingresos y egresos, mejorando la transparencia, la seguridad de la información y la eficiencia de los procesos administrativos y operativos.

## 2. Descripción del Problema
Actualmente, el control y la rendición de los gastos menores y fondos fijos (Caja Chica) pueden presentar desafíos relacionados con la carga manual de datos, la pérdida de comprobantes físicos, la dificultad para conciliar saldos en tiempo real y la falta de un sistema centralizado que permita a la administración auditar los movimientos de manera ágil y segura.

## 3. Solución Propuesta
Desarrollo de una solución tecnológica multiplataforma (Accesible desde Dispositivos Móviles Android y Navegadores Web) que permita a los colaboradores registrar sus gastos de manera instantánea, adjuntar sus comprobantes directamente desde la cámara o galería, y a la administración visualizar y controlar estos movimientos en tiempo real.

### 3.1. Objetivos del Sistema
1. **Digitalización Integral**: Eliminar el uso de planillas manuales para el control de efectivo y dinero en cuentas vinculadas a la caja chica.
2. **Automatización de Carga**: Incorporar tecnología de lectura inteligente de comprobantes (OCR) para extraer montos, números de factura e impuestos automáticamente desde fotos o PDFs, reduciendo el error humano.
3. **Visibilidad en Tiempo Real**: Proveer paneles de control (Dashboards) con saldos actualizados al instante.
4. **Respaldo de Documentación**: Almacenamiento seguro en la nube de todos los comprobantes físicos digitalizados, permitiendo su consulta y descarga en cualquier momento.
5. **Seguridad y Control de Acceso**: Implementar un sistema de roles para asegurar que cada usuario actúe según sus permisos.

## 4. Características y Funcionalidades Principales

### Para los Usuarios Generales (Colaboradores/Cuentadantes)
* **Autenticación Segura**: Ingreso al sistema mediante correo electrónico y contraseña corporativos.
* **Panel de Control Personal**: Visualización de su saldo actual discriminado por "Efectivo" y "Débito/Transferencia".
* **Registro de Ingresos/Egresos**: Formulario intuitivo para asentar entradas o salidas de dinero, seleccionando tipo de comprobante, centro de costos y método de pago (Efectivo/Transferencia).
* **Asistente Inteligente (OCR)**: Lector automático de Facturas (PDF y PNG). El sistema extrae automáticamente el Sub-total, IVA y Total, agilizando la carga.
* **Adjunto de Comprobantes**: Posibilidad de subir la comprobación del gasto, el cual quedará permanentemente ligado al registro.
* **Historial de Movimientos**: Visor de los últimos movimientos realizados para control y seguimiento.
* **Funcionamiento Sin Conexión**: Capacidad de registrar datos temporalmente incluso sin internet (por ejemplo en el campo), sincronizándose automáticamente al recuperar la señal.

### Para la Administración (Rol Administrador)
* Todas las funcionalidades del usuario general, más:
* **Supervisión Global**: Permisos elevados para visualizar y auditar los registros y movimientos de todos los usuarios de distintas áreas de la empresa.
* **Gestión de Registros**: Capacidad exclusiva de editar o eliminar registros erróneos para mantener la integridad contable, con recálculo automático de saldos.
* **Visor de Respaldo Documental**: Acceso instantáneo al visor integrado de comprobantes (PDF/PNG) adjuntos a cada gasto para auditorías inmediatas.

## 5. Plataforma y Tecnología
* **Dispositivos Móviles (Aplicación Nativa)**: App instalable en dispositivos Android para uso en campo y movimiento.
* **Portal Web**: Acceso vía navegador (Chrome, Edge, etc.) ideal para el equipo de administración en la oficina.
* **Backend y Base de Datos (Google Firebase)**: 
  * *Cloud Firestore*: Base de datos rápida, segura y sincronizada en tiempo real.
  * *Firebase Storage*: Almacenamiento redundante y seguro para todos los comprobantes e imágenes subidos.
  * *Firebase Auth (Proyectado)*: Para fortalecer la seguridad de los accesos.
* **Tecnología OCR**: 
  * *Google ML Kit*: Integrado directamente en la app móvil para una lectura extremadamente rápida y sin consumir datos de facturas.
  * *Tesseract.js*: Alternativa web para el análisis de escritorio.

## 6. Identidad Visual y Diseño
La interfaz de usuario está diseñada siguiendo lineamientos modernos ("Material Design"), adaptando la paleta de colores corporativa de **Agropecuaria Las Marías**, garantizando que la aplicación sea no solo funcional, sino también intuitiva, profesional y de rápida adopción por parte del personal sin conocimientos técnicos avanzados.

## 7. Beneficios Esperados
* **Reducción de Tiempos**: Menor carga administrativa en tareas repetitivas de carga de datos gracias a los sistemas de autocompletado e integración de inteligencia artificial.
* **Transparencia**: Trazabilidad completa de cada centavo gestionado en la institución.
* **Eliminación del Papel**: Menor riesgo de pérdida de documentación respaldatoria importante.
* **Toma de Decisiones**: Acceso inmediato a la información financiera menor sobre la disponibilidad de liquidez en el campo o sucursales.

## 8. Flujo de Autenticación Final (V15 & V16)
Este es el diseño definitivo para el flujo de acceso, manteniendo la proporción 30/70, el degradado vibrante y la identidad agropecuaria completa.

````carousel
![Pantalla de Ingreso Final (V15)](file:///C:/Users/JCORDOBA-NTBK/.gemini/antigravity/brain/dca170f6-9529-4b9c-aee0-bdbb0a936528/alm_final_login_v15_1773416343000_1773415167246.png)
<!-- slide -->
![Pantalla de Registro (V16)](file:///C:/Users/JCORDOBA-NTBK/.gemini/antigravity/brain/dca170f6-9529-4b9c-aee0-bdbb0a936528/alm_registration_v16_1773416343000_1773415182049.png)
````

---
**Elaborado para:** Dirección/Gerencia - Agropecuaria Las Marías.
**Proyecto:** Desarrollo de Software In-House "Control de Caja Chica".

---
**Elaborado para:** Dirección/Gerencia - Agropecuaria Las Marías.
**Proyecto:** Desarrollo de Software In-House "Control de Caja Chica".
