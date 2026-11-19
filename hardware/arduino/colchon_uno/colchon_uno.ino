/*
  Colchón Minuta — prototipo con Arduino UNO (USB hacia la PC).
  Mide peso (HX711), temperatura y humedad (AHT20); maneja un LED con brillo,
  un buzzer y dos botones. No habla con Internet: el puente de Python
  (hardware/bridge) lee este puerto serie. Protocolo: docs/hardware_protocolo.md

  Librerías (Administrar bibliotecas): "HX711" de Bogdan Necula,
  "Adafruit AHTX0" (instala también Adafruit BusIO).

  Conexiones (todo a 5 V del USB):
    HX711   DT -> D2, SCK -> D3, VCC -> 5V, GND -> GND
    AHT20   SDA -> A4, SCL -> A5, VCC -> 5V (o 3,3V según tu módulo), GND
    LED x4  D9, D10, D11, D6 -> 220 ohm -> LED -> GND   (PWM: brillo + patron giratorio)
    Buzzer  D8 -> buzzer ACTIVO -> GND
    Botón 1 D4 y GND (INPUT_PULLUP);  Botón 2 D5 y GND
  Si el buzzer toma más de 20 mA, usa un transistor 2N2222 + resistencia de 1 kΩ.
*/
#include <Wire.h>
#include <EEPROM.h>
#include <HX711.h>
#include <Adafruit_AHTX0.h>

const char FW_VERSION[] = "0.2.1";
const long BAUD = 115200;

const uint8_t PIN_HX_DT = 2, PIN_HX_SCK = 3;
const uint8_t PIN_LEDS[4] = {9, 10, 11, 6};  // todos con PWM
const uint8_t PIN_BUZZER = 8;
const uint8_t PIN_BTN[2] = {4, 5};

const unsigned long SAMPLE_EVERY_MS = 2000;
const unsigned long DEBOUNCE_MS = 40;
const unsigned int BUZZ_MAX_MS = 5000;

// EEPROM: [0] marca, [1..4] factor de escala (float).
const int EE_MAGIC_ADDR = 0, EE_SCALE_ADDR = 1;
const uint8_t EE_MAGIC = 0xA7;

HX711 scale;
Adafruit_AHTX0 aht;
bool ahtOk = false;
bool hxOk = false;  // false si el HX711 no responde (p. ej. placa sin balanza)

char lineBuf[48];
uint8_t lineLen = 0;
unsigned long lastSample = 0;
unsigned long buzzUntil = 0;
bool lightsOn = false;
uint8_t lightBrightness = 0;   // 0-100
uint8_t lightSpeed = 50;       // 0-100
uint8_t lightStep = 0;
unsigned long lastLightStep = 0;
bool btnState[2] = {false, false};
unsigned long btnChanged[2] = {0, 0};

void saveScale(float f) {
  EEPROM.update(EE_MAGIC_ADDR, EE_MAGIC);
  EEPROM.put(EE_SCALE_ADDR, f);
}

float loadScale() {
  if (EEPROM.read(EE_MAGIC_ADDR) != EE_MAGIC) return 1.0f;
  float f;
  EEPROM.get(EE_SCALE_ADDR, f);
  if (isnan(f) || f == 0.0f) return 1.0f;
  return f;
}

// Patron giratorio (RF-20, RF-21): un LED al brillo elegido y el anterior atenuado.
void drawLights() {
  uint8_t level = map(lightBrightness, 0, 100, 0, 255);
  for (uint8_t i = 0; i < 4; i++) {
    uint8_t v = 0;
    if (lightsOn) {
      if (i == lightStep) v = level;
      else if (i == (lightStep + 3) % 4) v = level / 4;
    }
    analogWrite(PIN_LEDS[i], v);
  }
}

void updateLights() {
  if (!lightsOn) return;
  // velocidad 0 -> 1000 ms por paso; 100 -> 80 ms por paso
  unsigned long interval = map(lightSpeed, 0, 100, 1000, 80);
  if (millis() - lastLightStep >= interval) {
    lastLightStep = millis();
    lightStep = (lightStep + 1) % 4;
    drawLights();
  }
}

void sendHello() {
  Serial.print(F("H,"));
  Serial.println(FW_VERSION);
}

void sendSample() {
  float weight = NAN, temp = NAN, hum = NAN;
  if (hxOk && scale.wait_ready_timeout(300)) weight = scale.get_units(5);  // kg tras calibrar
  if (ahtOk) {
    sensors_event_t h, t;
    if (aht.getEvent(&h, &t)) {
      temp = t.temperature;
      hum = h.relative_humidity;
    }
  }
  Serial.print(F("R,"));
  Serial.print(weight, 3);
  Serial.print(',');
  Serial.print(temp, 2);
  Serial.print(',');
  Serial.println(hum, 2);
}

void handleCommand(char *line) {
  char *arg = strchr(line, ',');
  if (arg) *arg++ = '\0';

  if (!strcmp(line, "LIGHT")) {
    // LIGHT,<encendido 0|1>,<brillo 0-100>,<velocidad 0-100>
    char *b = arg ? strchr(arg, ',') : NULL;
    char *v = b ? strchr(b + 1, ',') : NULL;
    if (!b || !v) {
      Serial.println(F("E,light_invalid"));
    } else {
      *b = '\0';
      *v = '\0';
      lightsOn = atoi(arg) != 0;
      lightBrightness = constrain(atoi(b + 1), 0, 100);
      lightSpeed = constrain(atoi(v + 1), 0, 100);
      drawLights();
      Serial.println(F("K,LIGHT"));
    }
  } else if (!strcmp(line, "BUZ")) {
    unsigned int ms = constrain(arg ? atoi(arg) : 300, 1, BUZZ_MAX_MS);
    digitalWrite(PIN_BUZZER, HIGH);
    buzzUntil = millis() + ms;
    Serial.println(F("K,BUZ"));
  } else if (!hxOk && (!strcmp(line, "TARE") || !strcmp(line, "RAW") ||
                       !strcmp(line, "CAL"))) {
    // Sin HX711, tare/get_value esperarían para siempre: se responde error.
    Serial.println(F("E,hx711_not_found"));
  } else if (!strcmp(line, "TARE")) {
    scale.tare(10);
    Serial.println(F("K,TARE"));
  } else if (!strcmp(line, "RAW")) {
    // Promedio crudo menos el cero: la PC calcula el factor con un peso conocido.
    Serial.print(F("X,"));
    Serial.println(scale.get_value(10), 1);
  } else if (!strcmp(line, "CAL")) {
    float f = arg ? atof(arg) : 0.0f;
    if (f != 0.0f && !isnan(f)) {
      scale.set_scale(f);
      saveScale(f);
      Serial.println(F("K,CAL"));
    } else {
      Serial.println(F("E,cal_invalid"));
    }
  } else if (!strcmp(line, "PING")) {
    sendHello();
  } else {
    Serial.println(F("E,unknown_command"));
  }
}

void readSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\r') continue;
    if (c == '\n') {
      lineBuf[lineLen] = '\0';
      if (lineLen > 0) handleCommand(lineBuf);
      lineLen = 0;
    } else if (lineLen < sizeof(lineBuf) - 1) {
      lineBuf[lineLen++] = c;
    } else {
      lineLen = 0;  // línea demasiado larga: se descarta
      Serial.println(F("E,line_too_long"));
    }
  }
}

void readButtons() {
  for (uint8_t i = 0; i < 2; i++) {
    bool pressed = digitalRead(PIN_BTN[i]) == LOW;
    if (pressed != btnState[i] && millis() - btnChanged[i] > DEBOUNCE_MS) {
      btnChanged[i] = millis();
      btnState[i] = pressed;
      if (pressed) {
        Serial.print(F("B,"));
        Serial.println(i + 1);
        if (i == 0) {  // el botón 1 silencia el buzzer en el sitio
          digitalWrite(PIN_BUZZER, LOW);
          buzzUntil = 0;
        }
      }
    }
  }
}

void setup() {
  Serial.begin(BAUD);
  for (uint8_t i = 0; i < 4; i++) {
    pinMode(PIN_LEDS[i], OUTPUT);
    analogWrite(PIN_LEDS[i], 0);
  }
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);
  for (uint8_t i = 0; i < 2; i++) pinMode(PIN_BTN[i], INPUT_PULLUP);

  scale.begin(PIN_HX_DT, PIN_HX_SCK);
  scale.set_scale(loadScale());
  // tare() espera sin límite a que el HX711 responda: sin balanza conectada el
  // Arduino se quedaría colgado aquí. Solo se tara si responde a tiempo.
  hxOk = scale.wait_ready_timeout(1000);
  if (hxOk) scale.tare(10);  // el colchón debe estar vacío al encender

  ahtOk = aht.begin();
  sendHello();
  if (!hxOk) Serial.println(F("E,hx711_not_found"));
  if (!ahtOk) Serial.println(F("E,aht20_not_found"));
}

void loop() {
  readSerial();
  readButtons();
  updateLights();
  if (buzzUntil && (long)(millis() - buzzUntil) >= 0) {
    digitalWrite(PIN_BUZZER, LOW);
    buzzUntil = 0;
  }
  if (millis() - lastSample >= SAMPLE_EVERY_MS) {
    lastSample = millis();
    sendSample();
  }
}
