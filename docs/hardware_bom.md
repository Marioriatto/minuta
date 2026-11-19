# Hardware de bajo costo — Colchón Minuta (prototipo)

Fecha de la investigación: 19-nov-2026.

> **Sobre los precios:** son orientativos, en USD, tomados de tiendas de otros países
> (AliExpress/Amazon/tiendas europeas e indias). **No incluyen envío ni impuestos a Costa Rica y no
> verifiqué precios locales.** Úsalos para comparar componentes entre sí, no como presupuesto final.

## 1. Lista recomendada (prototipo mínimo)

| Función (SRS) | Componente recomendado | Precio aprox. | Por qué |
|---|---|---|---|
| Cerebro + Wi-Fi (§2.1, §2.4) | **ESP32 DevKit V1** (se programa con el IDE de Arduino) | $3 – 8 | Wi-Fi integrado; cuesta casi lo mismo que un ESP8266 y tiene más memoria y pines |
| Peso (RF-11) | **HX711 + 4 celdas de carga half-bridge**, mejor de **10 kg** que de 50 kg | $14 – 20 el kit de 50 kg; las de 10 kg suelen costar parecido | Las 4 celdas bajo la base del colchón forman un puente completo |
| Temperatura y humedad ambiente (RF-16, RF-17) | **AHT20** (I2C) | $1 – 2 | ±0,3 °C y ±2 % HR; mejor y más rápido que el DHT22 por el mismo precio o menos |
| Temperatura del biberón (RF-23) | **DS18B20 sonda sellada** (1-Wire) | $4 – 11 | ±0,5 °C, una sola línea de datos |
| Alerta sonora local (RNF-05) | **Buzzer activo** de 3,3–5 V | $0,75 – 1 | Suena con solo encenderlo; ideal para alarmas |
| Luces (RF-20/21/22) | **Anillo WS2812B de 8 LED** *(o 4–8 LED simples + resistencias)* | $4 – 6 *(o <$1)* | Brillo y patrón giratorio por software con un solo pin |
| Botones (RF-27, juguete) | **Pulsadores táctiles de 4 patas** (6×6 mm) | centavos *(estimación mía)* | Se leen con `INPUT_PULLUP`, sin resistencias externas |
| Alimentación | **Adaptador de pared de 5 V certificado** (CE/UL), ≥ 2 A | $3 – 6 *(estimación mía)* | Evita cablear la red eléctrica a mano |

**Total del prototipo núcleo (colchón + cuna en una placa): ≈ US$ 25 – 50 + envío**, sumando los
rangos de arriba.

## 2. Decisiones que cambian el costo o el resultado

### Peso: celdas de 10 kg, no de 50 kg
Los kits baratos de 4 celdas de 50 kg + HX711 declaran una exactitud típica de **50 – 100 g**. Para un
bebé (5,84 kg, cambios de ~120 g como en el diseño) eso es demasiado grueso. Con celdas de menor
capacidad el rango es de 40 kg (4 × 10 kg) y la resolución mejora *(razonamiento mío, hay que
comprobarlo con calibración)*. Cuida que la base del colchón pese bastante menos que ese rango.
Hay reseñas de kits de 10 kg usados con ESP32 a 3,3 V sin problemas.

### Sensor de ambiente: AHT20, no DHT22
Fuentes recientes tratan el DHT22 como de uso heredado y recomiendan AHT20 o SHT41. El DHT11 (±2 °C,
±5 % HR) queda descartado. Si algún día necesitas más precisión: SHT41 ($1 – 3).
Evita el BME280 si no necesitas presión: cuesta más, y los BMP280 (sin humedad) se venden a veces
etiquetados como BME280.
Coloca el sensor **lejos del ESP32** (se calienta y falsea la temperatura).

### Sonda del biberón: calibrar y cuidar el contacto
Un estudio citado por atomic14 encontró que casi todas las sondas DS18B20 de eBay/AliExpress son
falsificaciones, con errores mayores que ±0,5 °C. Plan: comprar 2, compararlas contra un
termómetro conocido y guardar el ajuste (offset) en el firmware. No la sumerjas en la leche sin
confirmar que el acero es apto para alimentos; lo más seguro es medir en la pared del biberón.

### Altavoz: un buzzer NO puede reproducir la voz (RF-19 / CUNA-002)
- **Buzzer** → alarmas y pitidos. Cubre las alertas sonoras locales de emergencia (RNF-05).
- **Voz del padre/madre en tiempo real** → necesita amplificador I2S + parlante:
  **MAX98357A** ($3 – 9) + parlante de 4–8 Ω ($2). Un buzzer usado como parlante suena muy mal.
- Además, **transmitir audio en tiempo real a un ESP32 (WebRTC) es difícil y no lo verifiqué**.
  Riesgo técnico alto: conviene decidir con tiempo si RF-19 se hace con otra técnica (por ejemplo
  audio por WebSocket) o con una placa más capaz (ESP32-S3).

### LED: simples vs. direccionables
- **LED simples**: lo más barato. Cada uno usa un pin y una resistencia (220 – 330 Ω); con 4–8 LED
  se hace un patrón giratorio. Alternativa: un registro de desplazamiento 74HC595 para manejar 8 LED
  con 3 pines.
- **WS2812B**: un solo pin, brillo y giro por software. Consume hasta 60 mA por LED a blanco total
  (≈ 0,5 A un anillo de 8), así que **limita el brillo en el código**. Con ESP32 (3,3 V) funciona en
  la mayoría de los casos; ponle una resistencia de 330–470 Ω en la línea de datos y un capacitor de
  470–1000 µF en la alimentación. Si parpadea, añade un adaptador de nivel (74AHCT125).

### ¿Arduino UNO o ESP32?
El UNO no tiene Wi-Fi (habría que añadir un módulo) y cuesta más que un ESP32. El SRS exige
conexión Wi-Fi a Internet, así que ESP32.

## 3. Pines sugeridos (ESP32 DevKit V1)

| Componente | Pines |
|---|---|
| HX711 | VCC 3,3 V, GND, DT = GPIO 16, SCK = GPIO 4 |
| AHT20 (I2C) | SDA = GPIO 21, SCL = GPIO 22, VCC 3,3 V |
| DS18B20 | Datos = GPIO 5 + resistencia de 4,7 kΩ a 3,3 V |
| Buzzer activo | GPIO 18 |
| WS2812B | DIN = GPIO 13 vía 330 Ω, 5 V del adaptador, GND común |
| 4 botones | GPIO 25, 26, 27, 32 con `INPUT_PULLUP` y el otro lado a GND |

Evita los pines 34–39 (solo entrada, sin pull-up) y los de arranque (0, 2, 12, 15).

## 4. Seguridad (SRS §2.4: aislamiento térmico y protección contra sobrecargas)
- Todo a **5 V** con adaptador certificado; nada de red eléctrica dentro de la cuna.
- Caja cerrada, cables sujetos y sin partes expuestas al alcance del bebé; fusible reseteable (PTC) en
  la entrada de 5 V.
- Sensores y la electrónica fuera del colchón; las celdas de carga bajo una base rígida.
- Recuerda: el sistema **no es un dispositivo médico** (SRS §1.2).

## 5. Qué comprar primero
1. 1 ESP32 DevKit V1 (mejor 2, por si quemas una).
2. Kit HX711 con 4 celdas de **10 kg** (confirmar que sean half-bridge de 3 cables).
3. 1 AHT20, 2 DS18B20 selladas, 1 buzzer activo, 1 anillo WS2812B de 8 LED.
4. 10 pulsadores de 4 patas, resistencias (330 Ω, 4,7 kΩ), un capacitor de 470–1000 µF, protoboard y cables.
5. Adaptador de 5 V / 2 A.
6. Más adelante, si se hace voz: MAX98357A + parlante pequeño.

## 6. Pendientes de hardware que no investigué
Cámara (ESP32-CAM, RF-32), sensor del **grado** de apertura de la puerta (RF-31), detección de movimiento
en la habitación (HAB-001) y bomba/calentador del biberón (RF-25).

## Fuentes
- ESP32 vs ESP8266 (precios y diferencias): https://circuit.rocks/pages/esp32-vs-esp8266 · https://www.pcbonline.com/blog/esp32-and-esp8266-microcontrollers.html · https://iotbyhvm.ooo/esp32-vs-esp8266-what-is-esp32-and-esp8266
- Arduino UNO vs ESP32: https://circuit.rocks/pages/arduino-uno-vs-esp32
- Celdas de carga y HX711: https://www.desertcart.sn/products/70091936-4-pcs-50kg-load-weighting-sensor-amplifier-1pcs-hx711-ad · https://www.fruugo.co.nz/hx711-4pcs-weight-sensor-module-set-50kg-half-bridge-strain-gauge-load-cell-amplifier-for-precision-weighing-and-measurement/p-425089239-893361981 · https://www.desertcart.co/products/425161126-2-sets-50kg-load-cell-e-shaped-weighing-sensor-strain · https://shillehtek.com/blogs/news/arduino-hx711-load-cells-calibrated-scale
- Temperatura/humedad: https://www.atomic14.com/esp32/sensors/temperature-sensors/ · https://www.atomic14.com/esp32/sensors/aht20/ · https://www.atomic14.com/esp32/sensors/sht4x/ · https://zbotic.in/aht20-vs-bme280-best-budget-temperature-humidity-sensor-for-arduino-projects/ · https://microcontrollerslab.com/best-temperature-humidity-sensors-for-embedded-devices-buying-guide/
- DS18B20: https://www.atomic14.com/esp32/sensors/ds18b20/ · https://thepihut.com/collections/adafruit-sensors/products/waterproof-ds18b20-digital-temperature-sensor-extras · https://www.adafruit.com/products/381
- Audio (buzzer, MAX98357A): https://applied-ee.github.io/ee-notebook/docs/fundamentals/electromechanical-devices/speakers-and-buzzers · https://dmccreary.github.io/learning-micropython/posters/sound-output/ · https://soldered.com/collections/audio-sound
- LED WS2812B: https://shillehtek.com/blogs/shillehtek-product-manuals/ws2812-16-led-addressable-rgb-ring-manual · https://docs.circuit.rocks/displays/ws2812b/ · https://kobee.com.au/products/8-led-rgb-neopixel-ring-ws2812b
