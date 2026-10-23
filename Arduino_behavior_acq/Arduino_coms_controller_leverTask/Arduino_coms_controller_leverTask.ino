//
//Musical Lever Task - Arduino UNO (code used to read lever movements and deliver TTLs as used in Zempolich et al., 2026)
//
//Author: Grant W. Zempolich
//Last updated: 2023-01-16
//
//Description:
//Receives single-byte commands from a MATLAB GUI over serial
//and controls auditory feedback, indicator LEDs, alignment
//outputs, a laser output, and a solenoid valve.
//
//Communication:
//Baud rate: 57600
//Protocol: One command per byte; commands are numeric byte values,
//            not ASCII-encoded decimal strings.
//
//Dependencies:
//- Arduino AVR core
//- toneAC library
//- communication with MATLAB

#include <toneAC.h>

// Serial communication setup

const unsigned long SERIAL_BAUD_RATE = 57600;

// Primary task tones (Hz).
const unsigned int TONE_IN_HZ  = 16000;  // Input tone (tuningTone2)
const unsigned int TONE_OUT_HZ = 8000;   // Output tone (tuningTone4)

// Calibration / tuning tones (Hz).
const unsigned int TUNING_TONE_1_HZ = 2000;
const unsigned int TUNING_TONE_3_HZ = 24000;
const unsigned int TUNING_TONE_5_HZ = 12000;
const unsigned int TUNING_TONE_6_HZ = 4000;
const unsigned int TUNING_TONE_7_HZ = 20000;

// Tone playback settings.
const unsigned int TONE_DURATION_MS = 50;
const uint8_t TONE_VOLUME = 9;  // toneAC volume range: 1–10

// Hardware pin assignments

// Indicator outputs.
const uint8_t GREEN_PIN       = A4;
const uint8_t BLUE_PIN        = A3;
const uint8_t REWARD_LED_PIN  = 7;
const uint8_t ZONE_IN_LED_PIN = 5;
const uint8_t ZONE_OUT_LED_PIN = 13;

// The active tone implementation uses toneAC(), not built-in tone().
const uint8_t TONE_PIN = A5;

// Alignment outputs
const uint8_t TONE_IN_ALIGNMENT_PIN  = 4;
const uint8_t TONE_OUT_ALIGNMENT_PIN = 6;
const uint8_t HOME_IN_ALIGNMENT_PIN  = 3;
const uint8_t HOME_OUT_ALIGNMENT_PIN = 8;
const uint8_t NEGATIVE_PE_ALIGNMENT_PIN = 12;

// Other hardware outputs
const uint8_t LASER_PIN          = 2;
const uint8_t SOLENOID_VALVE_PIN = 11;

// Command protocol - integers that Arduino receives via serial com. from MATLAB and converts to TTLs

// Command | Action
// --------|--------------------------------------------------
//    1    | Play input tone (16,000 Hz)
//    2    | Play output tone (8,000 Hz)
//    3    | Set input-tone alignment HIGH
//    4    | Set input-tone alignment LOW
//    5    | Set reward LED HIGH
//    6    | Set reward LED LOW
//    7    | Set input-zone LED HIGH
//    8    | Set input-zone LED LOW
//   11    | Set laser output HIGH
//   12    | Set laser output LOW
//   13    | Set solenoid valve HIGH
//   14    | Set solenoid valve LOW
//   15    | Set output-zone LED HIGH
//   16    | Set output-zone LED LOW
//   19    | Set input-home alignment HIGH
//   20    | Set input-home alignment LOW
//   21    | Play tuning tone 1 (2,000 Hz)
//   22    | Play tuning tone 3 (24,000 Hz)
//   23    | Play tuning tone 5 (12,000 Hz)
//   24    | Play tuning tone 6 (4,000 Hz)
//   25    | Play tuning tone 7 (20,000 Hz)
//   26    | Set negative-PE alignment HIGH
//   27    | Set negative-PE alignment LOW
//   28    | Set output-home alignment HIGH
//   29    | Set output-home alignment LOW
//   30    | Pulse green output HIGH for 100 ms, then LOW
//   31    | Pulse blue output HIGH for 100 ms, then LOW
//   37    | Set output-tone alignment HIGH
//   38    | Set output-tone alignment LOW

// Initialization

void setup() {
  Serial.begin(SERIAL_BAUD_RATE);

  // Indicator outputs.
  pinMode(GREEN_PIN, OUTPUT);
  pinMode(BLUE_PIN, OUTPUT);
  pinMode(REWARD_LED_PIN, OUTPUT);
  pinMode(ZONE_IN_LED_PIN, OUTPUT);
  pinMode(ZONE_OUT_LED_PIN, OUTPUT);

  // Tone output pin retained for compatibility with the original sketch.
  pinMode(TONE_PIN, OUTPUT);

  // Alignment outputs
  pinMode(TONE_IN_ALIGNMENT_PIN, OUTPUT);
  pinMode(TONE_OUT_ALIGNMENT_PIN, OUTPUT);
  pinMode(HOME_IN_ALIGNMENT_PIN, OUTPUT);
  pinMode(HOME_OUT_ALIGNMENT_PIN, OUTPUT);
  pinMode(NEGATIVE_PE_ALIGNMENT_PIN, OUTPUT);

  // Other hardware outputs
  pinMode(LASER_PIN, OUTPUT);
  pinMode(SOLENOID_VALVE_PIN, OUTPUT);
}

// Serial command handling

void loop() {
  // Process all command bytes currently available in the serial buffer
  while (Serial.available() > 0) {
    const int command = Serial.read();

    // Serial.read() returns -1 if no byte is available
    if (command < 0) {
      continue;
    }

    switch (command) {

      // Primary task tones
      case 1:
        toneAC(TONE_IN_HZ, TONE_VOLUME, TONE_DURATION_MS);
        break;

      case 2:
        toneAC(TONE_OUT_HZ, TONE_VOLUME, TONE_DURATION_MS);
        break;

      // Input-tone alignment.
      case 3:
        digitalWrite(TONE_IN_ALIGNMENT_PIN, HIGH);
        break;

      case 4:
        digitalWrite(TONE_IN_ALIGNMENT_PIN, LOW);
        break;

      // Reward LED.
      case 5:
        digitalWrite(REWARD_LED_PIN, HIGH);
        break;

      case 6:
        digitalWrite(REWARD_LED_PIN, LOW);
        break;

      // Input-zone LED.
      case 7:
        digitalWrite(ZONE_IN_LED_PIN, HIGH);
        break;

      case 8:
        digitalWrite(ZONE_IN_LED_PIN, LOW);
        break;

      // Laser output.
      case 11:
        digitalWrite(LASER_PIN, HIGH);
        break;

      case 12:
        digitalWrite(LASER_PIN, LOW);
        break;

      // Solenoid valve.
      case 13:
        digitalWrite(SOLENOID_VALVE_PIN, HIGH);
        break;

      case 14:
        digitalWrite(SOLENOID_VALVE_PIN, LOW);
        break;

      // Output-zone LED.
      case 15:
        digitalWrite(ZONE_OUT_LED_PIN, HIGH);
        break;

      case 16:
        digitalWrite(ZONE_OUT_LED_PIN, LOW);
        break;

      // Input-home alignment.
      case 19:
        digitalWrite(HOME_IN_ALIGNMENT_PIN, HIGH);
        break;

      case 20:
        digitalWrite(HOME_IN_ALIGNMENT_PIN, LOW);
        break;

      // Calibration / tuning tones.
      case 21:
        toneAC(TUNING_TONE_1_HZ, TONE_VOLUME, TONE_DURATION_MS);
        break;

      case 22:
        toneAC(TUNING_TONE_3_HZ, TONE_VOLUME, TONE_DURATION_MS);
        break;

      case 23:
        toneAC(TUNING_TONE_5_HZ, TONE_VOLUME, TONE_DURATION_MS);
        break;

      case 24:
        toneAC(TUNING_TONE_6_HZ, TONE_VOLUME, TONE_DURATION_MS);
        break;

      case 25:
        toneAC(TUNING_TONE_7_HZ, TONE_VOLUME, TONE_DURATION_MS);
        break;

      // Negative-PE alignment.
      case 26:
        digitalWrite(NEGATIVE_PE_ALIGNMENT_PIN, HIGH);
        break;

      case 27:
        digitalWrite(NEGATIVE_PE_ALIGNMENT_PIN, LOW);
        break;

      // Output-home alignment.
      case 28:
        digitalWrite(HOME_OUT_ALIGNMENT_PIN, HIGH);
        break;

      case 29:
        digitalWrite(HOME_OUT_ALIGNMENT_PIN, LOW);
        break;

      // Green indicator pulse
      case 30:
        digitalWrite(GREEN_PIN, HIGH);
        delay(100);
        digitalWrite(GREEN_PIN, LOW);
        break;

      // Blue indicator pulse
      case 31:
        digitalWrite(BLUE_PIN, HIGH);
        delay(100);
        digitalWrite(BLUE_PIN, LOW);
        break;

      // Output-tone alignment
      case 37:
        digitalWrite(TONE_OUT_ALIGNMENT_PIN, HIGH);
        break;

      case 38:
        digitalWrite(TONE_OUT_ALIGNMENT_PIN, LOW);
        break;

      // Ignore unsupported or unrecognized command bytes.
      default:
        break;
    }
  }
}
