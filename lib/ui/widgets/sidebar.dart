import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class Sidebar extends StatelessWidget {
  final String currentRoute;
  final Function(String) onItemSelected;

  const Sidebar({
    super.key,
    required this.currentRoute,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: AppTheme.sidebarDark,
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'T',
                      style: TextStyle(
                        color: AppTheme.sidebarDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AGROPECUARIA',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      'LAS MARÍAS',
                      style: GoogleFonts.montserrat(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Navigation Items
          _SidebarItem(
            icon: Icons.grid_view_rounded,
            label: 'Panel',
            isSelected: currentRoute == 'dashboard',
            onTap: () => onItemSelected('dashboard'),
          ),
          _SidebarItem(
            icon: Icons.add_circle_outline,
            label: 'Nuevo Registro',
            isSelected: currentRoute == 'new',
            onTap: () => onItemSelected('new'),
          ),
          _SidebarItem(
            icon: Icons.list_alt_rounded,
            label: 'Historial',
            isSelected: currentRoute == 'history',
            onTap: () => onItemSelected('history'),
          ),
          const Spacer(),
          // Footer
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CAJA CHICA',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registro de gastos e ingresos',
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
