# UrbanSync - Smart City Resource Management System

## Overview

UrbanSync is a decentralized smart city resource management system designed to manage parking, waste, and energy services. It integrates IoT devices for real-time monitoring and supports payments, resource allocation, and service automation directly on-chain.

## Key Features

* **Parking Management**: Reserve parking spots, track occupancy, and process payments.
* **Waste Management**: IoT devices update waste bin fill levels, flagging bins for service when thresholds are exceeded.
* **Energy Management**: Allocate energy resources with on-chain payments, tracking consumption and availability.
* **IoT Device Integration**: Devices can be registered, deactivated, and monitored for real-time updates.
* **Resource Registration**: Admin can register new resources with validated location, capacity, and pricing.

## Contract Components

* **Error Codes**: Handle unauthorized access, invalid parameters, unavailable resources, and device errors.
* **Resource Types**: Parking, waste, and energy resources managed under unified logic.
* **Maps**:

  * `resources`: Stores registered city resources.
  * `parking-spots`: Tracks parking usage, vehicle IDs, and expiry.
  * `waste-bins`: Tracks bin levels, last collection, and service needs.
  * `energy-consumption`: Tracks energy allocations and usage per user.
  * `iot-devices`: Tracks IoT device registration, activity, and authorization.
* **Variables**:

  * `admin`: Contract administrator.
  * `resource-count`: Counter for resource IDs.
  * `min-parking-fee`: Minimum fee for parking.
  * `energy-rate`: Cost per kWh in microSTX.

## Functions

* **Resource Management**:

  * `register-resource`: Admin registers new city resources.
* **Parking**:

  * `reserve-parking`: Users reserve spots with payments.
* **Waste**:

  * `update-waste-level`: IoT devices update waste bin status.
* **Energy**:

  * `allocate-energy`: Users allocate energy by paying corresponding fees.
* **IoT Devices**:

  * `register-iot-device`: Admin registers devices to resources.
  * `deactivate-iot-device`: Admin deactivates devices.
  * `update-device-ping`: Devices update their last activity.
* **Read-only**:

  * `get-resource-details`, `get-parking-status`, `get-waste-bin-status`, `get-energy-usage`, `get-device-status`.

## Usage Flow

1. Admin registers city resources and IoT devices.
2. Users interact with resources by reserving parking, allocating energy, or indirectly through IoT updates.
3. IoT devices update system states such as waste fill levels and activity pings.
4. Resource availability, service status, and usage are tracked on-chain for transparency.
