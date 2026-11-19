/*
  Colchón Minuta — CUNA sin colchón (Arduino UNO por USB hacia la PC).

  Mide temperatura y humedad (AHT20), hace pitidos con un buzzer activo y
  maneja 4 LED con brillo y patrón giratorio. No necesita la balanza (HX711):
  envía el peso como "nan" y el puente lo ignora.
  Mismo protocolo serie que colchon_uno.ino (docs/hardware_protocolo.md), así
  que funciona con el mismo puente de Python sin cambios.

  Librerías (Herramientas > Administrar bibliotecas):
    "Adafruit AHTX0" (instala también "Adafruit BusIO").

  Conexiones (todo a 5 V del USB):
    AHT20   VCC -> 5V (o 3,3V según tu módulo), GND -> GND, SDA -> A4, SCL -> A5
    Buzzer  D8 -> (+) buzzer ACTIVO (-) -> GND
    LED x4  D9, D10, D11, D6 -> resistencia 220 ohm -> LED (pata larga) ; pata corta -> GND
    Botón 1 D4 <-> GND (silencia el buzzer)   Botón 2 D5 <-> GND   (INPUT_PULLUP)
  Si el buzzer consume más de 20 mA, usa un transistor 2N2222 + resistencia de 1 kΩ.

  Mensajes al PC:  H,<fw>  R,<kg>,<°C>,<%>  B,<n>  K,<cmd>  E,<código>
  Comandos del PC: LIGHT,<0|1>,<brillo>,<velocidad>  BUZ,<ms>  PING
*/
#include <Wire.h>
#include <Adafruit_AHTX0.h>

const char FW_VERSION[] = "cuna-0.1.0";
const long BAUD = 115200;

const uint8_t PIN_LEDS[4] = {9, 10, 11, 6};  // todos con PWM
const uint8_t PIN_BUZZER = 8;
const uint8_t PIN_BTN[2] = {4, 5};

const unsigned long SAMPLE_EVERY_MS = 2000;
const unsigned long DEBOUNCE_MS = 40;
const unsigned int BUZZ_MAX_MS = 5000;

Adafruit_AHTX0 aht;
bool ahtOk = false;
unsigned long lastAhtRetry = 0;

char lineBuf[48];
uint8_t lineLen = 0;
unsigned long lastSample = 0;
unsigned long buzzUntil = 0;
bool lightsOn = false;
uint8_t lightBrightness = 0;  // 0-100
uint8_t lightSpeed = 50;      // 0-100
uint8_t lightStep = 0;
unsigned long lastLightStep = 0;
bool btnState[2] = {false, false};
unsigned long btnChanged[2] = {0, 0};

// ---------- Luces (RF-20, RF-21): un LED al brillo elegido y el anterior atenuado.
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

// ---------- Buzzer: pitido de duración fija, sin bloquear el loop.
void startBuzz(unsigned int ms) {
  digitalWrite(PIN_BUZZER, HIGH);
  buzzUntil = millis() + ms;
}

void stopBuzz() {
  digitalWrite(PIN_BUZZER, LOW);
  buzzUntil = 0;
}

void updateBuzzer() {
  if (buzzUntil && (long)(millis() - buzzUntil) >= 0) stopBuzz();
}

// ---------- Mensajes
void sendHello() {
  Serial.print(F("H,"));
  Serial.println(FW_VERSION);
}

void sendSample() {
  // Si el sensor se desconectó o no arrancó, se reintenta cada 10 s.
  if (!ahtOk && millis() - lastAhtRetry >= 10000) {
    lastAhtRetry = millis();
    ahtOk = aht.begin();
  }
  float temp = NAN, hum = NAN;
  if (ahtOk) {
    sensors_event_t h, t;
    if (aht.getEvent(&h, &t)) {
      temp = t.temperature;
      hum = h.relative_humidity;
    } else {
      ahtOk = false;
      Serial.println(F("E,aht20_read_failed"));
    }
  }
  Serial.print(F("R,nan,"));  // sin balanza en la cuna
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
      return;
    }
    *b = '\0';
    *v = '\0';
    lightsOn = atoi(arg) != 0;
    lightBrightness = constrain(atoi(b + 1), 0, 100);
    lightSpeed = constrain(atoi(v + 1), 0, 100);
    drawLights();
    Serial.println(F("K,LIGHT"));
  } else if (!strcmp(line, "BUZ")) {
    startBuzz(constrain(arg ? atoi(arg) : 300, 1, BUZZ_MAX_MS));
    Serial.println(F("K,BUZ"));
  } else if (!strcmp(line, "PING")) {
    sendHello();
  } else if (!strcmp(line, "TARE") || !strcmp(line, "RAW") || !strcmp(line, "CAL")) {
    Serial.println(F("E,no_scale"));  // esta placa no tiene balanza
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
        if (i == 0) stopBuzz();  // el botón 1 silencia el buzzer en el sitio
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
  stopBuzz();
  for (uint8_t i = 0; i < 2; i++) pinMode(PIN_BTN[i], INPUT_PULLUP);

  ahtOk = aht.begin();
  lastAhtRetry = millis();

  // Pitido corto al encender: confirma que el buzzer está bien conectado.
  startBuzz(120);

  sendHello();
  if (!ahtOk) Serial.println(F("E,aht20_not_found"));
}

void loop() {
  readSerial();
  readButtons();
  updateLights();
  updateBuzzer();
  if (millis() - lastSample >= SAMPLE_EVERY_MS) {
    lastSample = millis();
    sendSample();
  }
}
