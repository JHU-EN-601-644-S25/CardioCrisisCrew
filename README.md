# CardioCrisisCrew
Project created as part of 601.444 Medical Device Cybersecurity at Johns Hopkins.

Authors: Jason Mihalopoulos, Madeline Estey, Casey Burhoe, and Lily Wheeler

## Project Overview
We developed the CC ECG as a secure medical device designed for first aid kits in public buildings, enabling faster diagnosis and treatment for patients experiencing cardiac emergencies.

### Overview of System Use
If someone experiences a cardiac emergency in a public space equipped with a first aid kit, they or a bystander can retrieve the CC ECG device. The three ECG electrodes are placed on the patient, and the device is powered on. When emergency medical personnel arrive, they can open the CC ECG app, connect to the device via Bluetooth, and instantly access the patient’s heart data to assess the situation and determine treatment. If needed, the data can also be transmitted to a hospital for further care.

### Patient Benefits
The product enables real-time visualization of cardiac irregularities, helping medical personnel respond quickly and accurately. It provides peace of mind for at-risk patients and, through data sharing with emergency departments, reduces response times and increases survival chances.

### Patient Risks
A device breach could jeopardize patient safety by delaying or blocking alerts to patients and emergency personnel. If attackers alter ECG data, a serious emergency could appear as a normal reading, risking improper or delayed treatment.

### System integration
The device will integrate with both a mobile app via Bluetooth, and a cloud platform (of the desired hospital) via WiFi. The device will not directly integrate with EHRs, but hospitals can manually do that on their own. 

### Hardware bill of materials
- Raspberry Pi 5
- AD8232 ECG sensor
- ADS1115 Analog-to-Digital Converter
- iPhone
- 40 PCS 20 CM Breadboard Jumper Wires
- Disposable Surface ECG Electrode
- Sensor Cable - Electrode Pads
- Raspberry Pi 27W Power Supply

### Firmware, Software, Services
- Raspberry Pi OS
- AWS Cloud platform
- Lambda, API Gateway, Cognito, DynamoDB
- SQLite database
- iOS application
- BLE - Gobbledegook library
- Tailscale

# System Setup

## App Setup

## Device Setup

# Security
