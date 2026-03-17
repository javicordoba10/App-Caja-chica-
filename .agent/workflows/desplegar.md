---
description: Cómo compilar y desplegar la aplicación en Firebase Hosting
---

Para aplicar los cambios realizados y actualizar la aplicación en vivo, sigue estos pasos desde una terminal situada en la carpeta raíz del proyecto (`petty_cash_app`):

1. **Limpiar la caché de construcción:**
   Esto asegura que no haya archivos viejos interfiriendo con los nuevos cambios quirúrgicos.
   ```bash
   flutter clean
   ```

2. **Compilar la versión para Web:**
   Este comando genera los archivos optimizados para el navegador.
   // turbo
   ```bash
   flutter build web --release --no-tree-shake-icons
   ```

3. **Desplegar en Firebase Hosting:**
   Este comando sube los archivos generados a tu URL pública.
   // turbo
   ```bash
   firebase deploy --only hosting --non-interactive --project pettycashapp-80f5e
   ```

4. **Verificar en el navegador:**
   Una vez completado, abre [https://pettycashapp-80f5e.web.app](https://pettycashapp-80f5e.web.app) y presiona **Ctrl + F5** para forzar la recarga del sitio y ver los botones nuevos y el borrado funcionando.
