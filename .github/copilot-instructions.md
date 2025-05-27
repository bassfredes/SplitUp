## Instrucciones para GitHub Copilot

### Cobertura de Pruebas
- Cada función, método y getter/setter público en el código debe tener pruebas unitarias que lo cubran.
- El objetivo es mantener un alto nivel de cobertura de pruebas, idealmente cercano al 100% para la lógica de negocio crítica.
- Ejecuta las pruebas relevantes después de realizar cambios para asegurar que no se hayan introducido regresiones.

### Formato de Mensajes de Commit
Adherirse al formato de commits semánticos. **Todos los mensajes de commit deben estar en inglés.**

**Formato:**
```
<type>(<scope>): <subject>
```

- **`<type>`**: Describe la naturaleza del cambio. Los tipos comunes incluyen:
    - `feat`: Una nueva característica (feature).
    - `fix`: Una corrección de un error (bug fix).
    - `docs`: Cambios únicamente en la documentación.
    - `style`: Cambios que no afectan el significado del código (espacios en blanco, formato, puntos y comas faltantes, etc.).
    - `refactor`: Un cambio en el código que no corrige un error ni añade una característica.
    - `perf`: Un cambio en el código que mejora el rendimiento.
    - `test`: Añadir pruebas faltantes o corregir pruebas existentes.
    - `build`: Cambios que afectan el sistema de compilación o dependencias externas (ejemplos: scopes de gulp, npm).
    - `ci`: Cambios en nuestros archivos y scripts de configuración de CI (ejemplos: Travis, Circle, BrowserStack, SauceLabs).
    - `chore`: Otros cambios que no modifican el código fuente o los archivos de prueba (ejemplo: actualización de dependencias).
    - `revert`: Revierte un commit anterior.

- **`<scope>`** (opcional): Especifica el lugar del codebase afectado por el cambio (nombre del componente, módulo, archivo, etc.).
    - Ejemplo: `feat(auth): implement OAuth login`
    - Ejemplo: `fix(parser): correctly handle block comments`

- **`<subject>`**: Una descripción concisa del cambio.
    - Usa el imperativo, tiempo presente: "change" no "changed" ni "changes".
    - No capitalizar la primera letra.
    - Sin punto (.) al final.

**Convenciones Adicionales:**
- El `type`, `scope` (si se usa), y `subject` deben estar en minúsculas, a menos que se refieran a nombres de componentes, clases, o entidades que convencionalmente usan mayúsculas (por ejemplo, `feat(UserModel): add age field`).

**Ejemplos:**
```
feat: allow user to update profile picture
```
```
fix(payment_service): correct tax calculation for international orders
```
```
docs: update contribution guide with semantic commit information
```
```
style(api): apply code formatter to controllers
```
```
refactor(user_repository): simplify user data fetching logic
```
```
test(auth_bloc): add tests for forgot password state
```

### Comentarios en el Código
- Todos los comentarios en los archivos de código (Dart, TypeScript, etc.) deben estar **en inglés**.
- Para funciones, métodos, clases y variables complejas, utiliza comentarios de documentación que sigan el estilo JSDoc (para JavaScript/TypeScript) o DartDoc (para Dart).

**Ejemplo JSDoc (para archivos `.js` o `.ts`):**
```javascript
/**
 * Calculates the total price of items in a shopping cart.
 * @param {Array<Object>} items - The list of items in the cart.
 * @param {number} items[].price - The price of an individual item.
 * @param {number} items[].quantity - The quantity of an individual item.
 * @param {number} [discount=0] - An optional discount percentage to apply.
 * @returns {number} The total calculated price.
 * @throws {Error} If items array is empty or contains invalid data.
 */
function calculateTotalPrice(items, discount = 0) {
  // ... implementation ...
}
```

**Ejemplo DartDoc (para archivos `.dart`):**
```dart
/// Calculates the total price of items in a shopping cart.
///
/// The [items] parameter is a list of maps, where each map represents an item
/// and must contain \'price\' and \'quantity\' keys.
///
/// The optional [discount] parameter is a percentage (e.g., 10 for 10%)
/// that will be applied to the total. Defaults to 0.
///
/// Returns the total calculated price.
/// Throws an [ArgumentError] if [items] is empty or contains invalid data.
double calculateTotalPrice(List<Map<String, dynamic>> items, {double discount = 0}) {
  // ... implementation ...
}
```
