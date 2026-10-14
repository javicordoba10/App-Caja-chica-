import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LegalTermsScreen extends StatelessWidget {
  final int initialTabIndex;
  const LegalTermsScreen({super.key, this.initialTabIndex = 0});

  static void showLegalDialog(BuildContext context, {int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: LegalTermsScreen(initialTabIndex: initialTab),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Marco Legal y Privacidad',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
          ),
          backgroundColor: AppTheme.pureBlack,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.primaryOrange,
            indicatorWeight: 3,
            labelColor: AppTheme.primaryOrange,
            unselectedLabelColor: Colors.white70,
            labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: 'Términos de Servicio', icon: Icon(Icons.description_outlined, size: 20)),
              Tab(text: 'Política de Privacidad', icon: Icon(Icons.shield_outlined, size: 20)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TermsOfServiceView(),
            _PrivacyPolicyView(),
          ],
        ),
      ),
    );
  }
}

class _TermsOfServiceView extends StatelessWidget {
  const _TermsOfServiceView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildSectionHeader('1. Ámbito y Propósito del Software'),
        _buildParagraph(
          'La presente aplicación de "Caja Chica" es una plataforma SaaS destinada exclusivamente a la gestión, rendición de gastos, administración de fondos fijos corporativos y carga de comprobantes de pago para organizaciones comerciales y productivas autorizadas.',
        ),
        _buildSectionHeader('2. Responsabilidad sobre la Carga de Datos y Comprobantes'),
        _buildParagraph(
          'Cada usuario es único y directo responsable de la veracidad, autenticidad e integridad de la información volcada en el sistema, incluyendo montos brutos, descripciones de erogaciones, fechas y fotografías o documentos en PDF correspondientes a facturas, recibos o tickets emitidos a nombre de la empresa o establecimiento asignado.',
        ),
        _buildSectionHeader('3. Exclusión de Responsabilidad Fiscal y Contable (OCR / ARCA)'),
        _buildParagraph(
          'Los módulos de digitalización por reconocimiento óptico de caracteres (OCR) y sugerencias automáticas de alícuotas o percepciones tributarias (ARCA / AFIP) constituyen herramientas de asistencia operativa automatizada. '
          'Bajo ninguna circunstancia sustituyen el asesoramiento, auditoría o dictamen de un profesional contable matriculado ni constituyen una certificación tributaria oficial. '
          'La empresa usuaria asume la total obligación de revisar y validar cada asiento antes de su aprobación definitiva y cierre de período.',
        ),
        _buildSectionHeader('4. Propiedad Intelectual y Licencia de Uso'),
        _buildParagraph(
          'El diseño, arquitectura, código fuente, algoritmos y marcas registradas asociadas al sistema son propiedad exclusiva del desarrollador. Se concede una licencia limitada, revocable y no transferible para su uso operativo en el marco del contrato o acuerdo de servicio celebrado con cada organización cliente.',
        ),
        _buildSectionHeader('5. Cancelación y Baja de Servicios'),
        _buildParagraph(
          'La administración central de cada organización o el titular de la cuenta se reserva el derecho de revocar accesos en caso de incumplimiento de las políticas internas de gastos, uso indebido de fondos corporativos o violación a las condiciones presentes.',
        ),
        const SizedBox(height: 32),
        _buildFooterNote(),
      ],
    );
  }
}

class _PrivacyPolicyView extends StatelessWidget {
  const _PrivacyPolicyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildSectionHeader('1. Marco Regulatorio y Compromiso'),
        _buildParagraph(
          'En estricto cumplimiento de la Ley de Protección de Datos Personales N° 25.326 de la República Argentina y estándares internacionales de seguridad en la nube, garantizamos que los datos recolectados se tratan de forma lícita, confidencial y con medidas de seguridad técnicas idóneas.',
        ),
        _buildSectionHeader('2. Información Recolectada'),
        _buildParagraph(
          'Para el funcionamiento del servicio, se tratan únicamente datos de identificación y autenticación (nombre y apellido, correo electrónico corporativo, rol laboral) y registros de operaciones financieras corporativas (gastos, comprobantes, fondos fijos y métodos de pago utilizados).',
        ),
        _buildSectionHeader('3. Política de Cookies y Almacenamiento Local'),
        _buildParagraph(
          'En su versión web y PWA, la plataforma utiliza únicamente almacenamiento local (LocalStorage / IndexedDB) y tokens de sesión técnicos indispensables para:\n'
          '• Mantener activa su sesión autenticada de manera segura.\n'
          '• Permitir el funcionamiento ágil y la persistencia de datos en memoria caché.\n'
          '• Recordar la empresa o sucursal seleccionada.\n\n'
          'Esta aplicación NO utiliza cookies publicitarias, rastreadores de marketing de terceros ni comparte sus hábitos de navegación con plataformas externas.',
        ),
        _buildSectionHeader('4. Seguridad y Cifrado de Comprobantes'),
        _buildParagraph(
          'Las imágenes de comprobantes y datos de transacciones se transmiten bajo protocolos cifrados TLS/HTTPS y se almacenan en repositorios protegidos con reglas de acceso basadas en roles (RBAC). El acceso a los comprobantes está estrictamente restringido a usuarios autenticados con permisos legítimos en la respectiva organización.',
        ),
        _buildSectionHeader('5. Derechos ARCO y Eliminación de Cuentas'),
        _buildParagraph(
          'De acuerdo con la legislación vigente, todo usuario tiene derecho a conocer, actualizar, rectificar y solicitar la supresión de sus datos personales ("Derecho al Olvido").\n'
          'Cualquier usuario puede iniciar la solicitud de baja de su cuenta y eliminación de datos personales directamente desde la sección "Mi Perfil" de la aplicación o contactando al administrador del sistema.',
        ),
        const SizedBox(height: 32),
        _buildFooterNote(),
      ],
    );
  }
}

Widget _buildSectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppTheme.textDark,
      ),
    ),
  );
}

Widget _buildParagraph(String text) {
  return Text(
    text,
    style: GoogleFonts.montserrat(
      fontSize: 12.5,
      height: 1.55,
      color: Colors.black87,
      fontWeight: FontWeight.w400,
    ),
  );
}

Widget _buildFooterNote() {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(
      children: [
        const Icon(Icons.verified_user_outlined, color: AppTheme.primaryOrange, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Última actualización: Versión 2026. Cumplimiento Ley 25.326 y estándares normativos comerciales.',
            style: GoogleFonts.montserrat(fontSize: 11, color: AppTheme.textGrey, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
