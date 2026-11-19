# Armar la cuna (sin colchón)

Sketch: `hardware/arduino/cuna_uno/cuna_uno.ino` (firmware `cuna-0.2.0`, sensor **DHT22 / AM2302**).
Mismo protocolo serie que `colchon_uno.ino`, así que funciona con el puente sin cambios. Envía el peso
como `nan` (el puente lo ignora). Si más adelante conectas la balanza, usa `colchon_uno.ino`
(usa AHT20; desde la v0.2.1 ya no se cuelga si falta el HX711).

## Materiales
| Cant. | Componente |
|---|---|
| 1 | Arduino UNO + cable USB |
| 1 | Sensor **DHT22 / AM2302** (temperatura y humedad) |
| 1 | Resistencia de **10 kΩ** *(solo si el DHT22 es el sensor suelto de 4 patas)* |
| 1 | Buzzer **activo** de 5 V (si consume > 20 mA: 2N2222 + 1 kΩ) |
| 4 | LED de 5 mm + 4 resistencias de 220 Ω *(opcional, para el sistema de luces)* |
| 2 | Pulsadores 6×6 mm *(opcional)* |
| — | Protoboard y cables dupont macho-macho / macho-hembra |

## Conexiones
| Componente | Pin del componente | Arduino UNO |
|---|---|---|
| DHT22 | VCC / + (pata 1) | 5V |
| DHT22 | DATA / out (pata 2) | **D7** |
| DHT22 | GND / − (pata 4; la 3 no se usa) | GND |
| DHT22 suelto | resistencia 10 kΩ entre DATA y 5V | — |
| Buzzer activo | + (pata larga) | D8 |
| Buzzer activo | − | GND |
| LED 1–4 | ánodo (pata larga) vía 220 Ω | D9, D10, D11, D6 |
| LED 1–4 | cátodo (pata corta) | GND |
| Botón 1 / 2 | una pata | D4 / D5 |
| Botón 1 / 2 | otra pata | GND |

Patas del DHT22 suelto: con la rejilla de frente y las patas hacia abajo, de izquierda a derecha
1 (VCC), 2 (DATA), 3 (sin uso), 4 (GND). El AM2302 con cables o en módulo de 3 pines ya trae la
resistencia: rojo = VCC, amarillo = DATA, negro = GND (verifícalo en la serigrafía).

## Puesta en marcha
1. Arduino IDE → *Administrar bibliotecas* → instalar **DHT sensor library** (Adafruit); acepta
   instalar también **Adafruit Unified Sensor**.
2. Abrir `cuna_uno.ino`, placa **Arduino Uno**, subir. Al encender suena un pitido corto (prueba del buzzer).
3. Monitor serie a 115200: deben aparecer `H,cuna-0.2.0` y, cada 2 s, `R,nan,<°C>,<%>`.
   Si ves `R,nan,nan,nan` y `E,dht22_read_failed`, revisa DATA en D7, la alimentación y la
   resistencia de 10 kΩ. Cierra el monitor antes del paso 4.
4. Poner el puerto COM en `hardware/bridge/bridge.toml` y ejecutar `python -m colchon_bridge run`.
5. En la app: Ampliaciones → Vincular, con el código de `hardware/claim_codes/claim_sn-proto-cradle.png`
   (y el de luces si conectaste los LED).
6. En la pantalla de la cuna, **Hacer sonar la cuna** envía un pitido de 1 s (llega en ~3 s).
   El botón 1 lo silencia en el sitio.

Precisión del DHT22: ±0,5 °C y ±2–5 % HR; entrega un dato nuevo cada 2 s como mucho.
