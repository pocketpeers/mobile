import 'package:flutter/material.dart';

/// Alto de una tarjeta de métrica, en píxeles, según el tamaño de letra activo.
///
/// Sustituye a `childAspectRatio`, que es la causa de los desbordes de unos
/// pocos píxeles que aparecen en unos teléfonos y en otros no.
///
/// **Por qué `childAspectRatio` falla.** Ata el alto de la tarjeta a su
/// *ancho*, y el ancho depende del tamaño de la pantalla. Pero lo que llena la
/// tarjeta es texto, y el texto crece por otros dos motivos que la proporción
/// no ve: que la etiqueta se parta en dos líneas por ser larga —«Pagos en
/// grupo» lo hace y «Score» no— y que la persona tenga subido el tamaño de
/// letra del sistema. Cuando el contenido pasa del alto calculado, la columna
/// desborda; y como el margen sobrante depende del ancho del teléfono, en uno
/// sobra un píxel y en otro falta.
///
/// Atar el alto al texto, y no al ancho, quita las dos causas de golpe.
///
/// Accesibilidad aparte: en Android el tamaño de letra se puede subir bastante,
/// y es una opción que usa justamente la gente con menos vista. Una pantalla
/// que se rompe al subirlo deja fuera a parte del público de esta aplicación.
double metricCardExtent(BuildContext context, {int labelLines = 1}) {
  // Alto del contenido con el tamaño de letra por defecto: el relleno de la
  // tarjeta, las lineas de la etiqueta, el valor y el aire entre ambos.
  const padding = 32.0;
  const labelLineHeight = 20.0;
  const valueHeight = 30.0;
  const breathingRoom = 10.0;
  final base = padding + labelLines * labelLineHeight + valueHeight + breathingRoom;

  // textScaler convierte un tamaño de fuente, asi que se le pide el factor
  // escalando un valor conocido en vez de suponerlo.
  final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
  return base * scale;
}
