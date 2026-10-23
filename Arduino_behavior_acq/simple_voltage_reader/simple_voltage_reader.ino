//
//Voltage Sensor (licking) Data Acquisition for musical lever task - Arduino UNO
//
//Author: Grant W. Zempolich
//Last updated: 2022-07-15
//
//Description:
//Reads an analog voltage sensor and transmits the converted
//voltage to MATLAB over the serial connection to register licks
//
//Communication:
//Baud rate: 57600
//Output format: One voltage reading per line, terminated by '\n'.
//
//Hardware:
//Analog input: A4
//
//Notes:
// - Uses the default Arduino UNO analog reference (nominally 5 V).
// - Assumes a 10-bit ADC (raw readings from 0 to 1023).
// - Voltage conversion assumes the sensor signal is within the
//   ADC input range and the reference voltage is 5V.

// Variable configuration
const unsigned long SERIAL_BAUD_RATE = 57600;

const uint8_t SENSOR_PIN = A4;

const float ADC_REFERENCE_VOLTAGE = 5.0;
const float ADC_MAX_READING = 1023.0;

// Setup
void setup() {
  Serial.begin(SERIAL_BAUD_RATE);
}


void loop() {
  // Read the raw analog-to-digital converter (ADC) value.
  const int sensorReading = analogRead(SENSOR_PIN);

  // Convert the ADC reading to voltage.
  const float voltage =
      sensorReading * (ADC_REFERENCE_VOLTAGE / ADC_MAX_READING);

  // Transmit one voltage reading per line for MATLAB to parse.
  Serial.println(voltage);
}
