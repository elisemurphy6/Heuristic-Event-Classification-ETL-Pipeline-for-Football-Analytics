# Automated Soccer Event Tagging Pipeline (Python + PostgreSQL)

This repository contains a complete workflow for ingesting, structuring, and auto‑tagging soccer event data. It combines a PostgreSQL database, mock competition data, and a Python-based heuristic tagging engine.

The project was originally built as a personal analytics tool to explore ETL design, event classification, and rule‑based tagging.

---

## Project Components

### **1. PostgreSQL Integrable Database**
A relational schema containing:
- Competitions  
- Clubs  
- Matches  
- Players  
- Zones  
- Event Types  
- Lineups  
- Events  

The mock data originates from a structured Excel file (`VSC365_MockData.xlsx`).  
The SQL schema + data population scripts were originally written manually, but the project later transitioned to direct Excel → PostgreSQL import.  
The older insert scripts are included only for reference and are not required nor recommended for running the pipeline.

### **2. Python Auto‑Tagging Engine**
Located in `auto_tag.py`, this script:
- Reads raw event rows from CSV  
- Classifies event types using regex heuristics  
- Applies tactical tags (pressing, switches, overloads, second phase, etc.)  
- Computes a confidence score  
- Resolves zone IDs from the database  
- Inserts structured events + tags into PostgreSQL  

This component is fully functional and represents the core logic of the project.

### **3. Legacy Data‑Load Scripts (Optional / Deprecated)**
Before learning direct Excel → SQL import, the project used SQL commands to insert each table row manually.  
These commands are kept only as historical artifacts showing the early ETL approach.  
They are not required for the current workflow.

---

## Features

- Rule‑based event classification  
- Tactical tagging system  
- Confidence scoring  
- JSON metadata stored per event  
- PostgreSQL relational modeling  
- Extensible heuristics for football analytics  
- Clean separation between raw data, database, and tagging logic  

---

## Event Classification Overview

Event types are detected using regex patterns such as:

- `shot`, `header`, `chance` → **SHOT**  
- `turnover`, `lost ball` → **TURNOVER**  
- `corner` → **SETPIECE_CORNER**  
- `free kick`, `fk` → **SETPIECE_FREEKICK**  
- `press`, `trap` → **PRESS_TRIG**  
- `pass`, `switch`, `through` → **PASS** (default)

Tags are applied similarly, based on tactical keywords.

Confidence scores increase when:
- strong signals appear in the raw note  
- the event type is high‑certainty (e.g., set pieces)  
- multiple tags are detected  

---

## Database Schema

The project uses a normalized relational schema with foreign keys linking:
- Matches → Clubs  
- Players → Clubs  
- Events → Players, Clubs, Zones, EventTypes  
- EventTags → Events  

Zone lookup is performed dynamically during event insertion.

---


