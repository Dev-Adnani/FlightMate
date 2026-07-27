# FlightMate

## Purpose

FlightMate is a native macOS companion for Aerofly FS 4.

It connects to Aerofly using UDP telemetry.

The app understands the current flight and provides AI-powered contextual assistance.

## Primary Goal

Help users learn aviation and improve their flight simulation experience.

## What FlightMate IS

- Live telemetry dashboard
- AI instructor
- Flight phase detection
- Aircraft-specific checklists
- Airport information
- Flight history

## What FlightMate IS NOT

- Flight simulator
- ATC replacement
- Moving map clone
- Weather injector
- Autopilot
- Plugin

## Architecture

SwiftUI

MVVM

Network.framework

SwiftData

Feature-first architecture

Dependency Injection

## Coding Rules

- Never use UIKit.
- Never use singletons.
- Never hardcode airport data.
- Keep files under 300 lines.
- Every service must be testable.
- Prefer protocol-oriented design.
- UI must not contain business logic.

always read this file before making changes.
