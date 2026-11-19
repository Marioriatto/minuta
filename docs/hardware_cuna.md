# Armar la cuna (sin colchón)

Sketch: `hardware/arduino/cuna_uno/cuna_uno.ino` (firmware `cuna-0.1.0`). Mismo protocolo serie que
`colchon_uno.ino`, así que funciona con el puente sin cambios. Envía el peso como `nan` (el puente lo
ignora). Si más adelante conectas la balanza, usa `colchon_uno.ino` (desde la v0.2.1 ya no se cuelga
si falta el HX711).

## Materiales
| Cant. | Componente |
|---|---|
| 1 | Arduino UNO + cable USB |
| 1 | Módulo AHT20 (I2C), con pines soldados |
| 1 | Buzzer **activo** de 5 V (si consume > 20 mA: 2N2222 + 1 kΩ) |
| 4 | LED de 5 mm + 4 resistencias de 220 Ω *(opcional, para el sistema de luces)* |
| 2 | Pulsadores 6×6 mm *(opcional)* |
| — | Protoboard y cables dupont macho-macho / macho-hembra |

## Conexiones
| Componente | Pin del componente | Arduino UNO |
|---|---|---|
| AHT20 | VCC | 5V (o 3,3 V según el módulo) |
| AHT20 | GND | GND |
| AHT20 | SDA | A4 |
| AHT20 | SCL | A5 |
| Buzzer activo | + (pata larga) | D8 |
| Buzzer activo | − | GND |
| LED 1–4 | ánodo (pata larga) vía 220 Ω | D9, D10, D11, D6 |
| LED 1–4 | cátodo (pata corta) | GND |
| Botón 1 / 2 | una pata | D4 / D5 |
| Botón 1 / 2 | otra pata | GND |

## Puesta en marcha
1. Arduino IDE → *Administrar bibliotecas* → instalar **Adafruit AHTX0** (instala Adafruit BusIO).
2. Abrir `cuna_uno.ino`, placa **Arduino Uno**, subir. Al encender suena un pitido corto (prueba del buzzer).
3. Monitor serie a 115200: deben aparecer `H,cuna-0.1.0` y una línea `R,nan,<°C>,<%>` cada 2 s.
   Si ves `E,aht20_not_found`, revisa SDA/SCL y la alimentación del sensor. Cierra el monitor antes del paso 4.
4. Poner el puerto COM en `hardware/bridge/bridge.toml` y ejecutar `python -m colchon_bridge run`.
5. En la app: Ampliaciones → Vincular, con el código de `hardware/claim_codes/claim_sn-proto-cradle.png`
   (y el de luces si conectaste los LED).
6. En la pantalla de la cuna, **Hacer sonar la cuna** envía un pitido de 1 s (llega en ~3 s).
   El botón 1 lo silencia en el sitio.
