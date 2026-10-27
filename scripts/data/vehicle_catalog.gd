class_name VehicleCatalog
## Vehicle types available to levels: model, footprint length and size limits.
## Swap models or add types here without touching gameplay code.

const MODEL_DIR := "res://assets/models/vehicles/"

## cells: footprint length in grid cells.
## max_stretch: how much the model may be lengthened (Z only) to fill its slot.
## Sound profile per type: engine sample, horn, optional siren and a base
## pitch (lower for heavier vehicles). Tyre sounds use the same sample for all
## vehicles and only lean slightly toward the base pitch.
const TYPES := {
	"sedan": {"model": "sedan.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "car_go", "horn": "horn_sedan", "pitch": 1.0},
	"sedan_sports": {"model": "sedan-sports.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "engine_sports", "horn": "horn_small", "pitch": 1.08},
	"hatchback": {"model": "hatchback-sports.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "engine_sports", "horn": "horn_small", "pitch": 1.14},
	"suv": {"model": "suv.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "car_go", "horn": "horn", "pitch": 0.95},
	"suv_luxury": {"model": "suv-luxury.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "car_go", "horn": "horn", "pitch": 0.98},
	"taxi": {"model": "taxi.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "car_go", "horn": "horn_double", "pitch": 1.03},
	"police": {"model": "police.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "car_go", "horn": "horn", "siren": "siren_police", "pitch": 1.0},
	"van": {"model": "van.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "car_go", "horn": "horn", "pitch": 0.93},
	"pickup": {"model": "truck.glb", "cells": 2, "max_stretch": 1.15,
		"engine": "car_go", "horn": "horn", "pitch": 0.9},
	"ambulance": {"model": "ambulance.glb", "cells": 3, "max_stretch": 1.5,
		"engine": "engine_truck", "horn": "horn_truck", "siren": "siren_ambulance", "pitch": 0.92},
	"delivery": {"model": "delivery.glb", "cells": 3, "max_stretch": 1.5,
		"engine": "engine_truck", "horn": "horn_truck", "pitch": 0.88},
	"firetruck": {"model": "firetruck.glb", "cells": 3, "max_stretch": 1.5,
		"engine": "engine_truck", "horn": "horn_air", "siren": "horn_air", "pitch": 0.85},
	"garbage": {"model": "garbage-truck.glb", "cells": 3, "max_stretch": 1.5,
		"engine": "engine_truck", "horn": "horn_truck", "pitch": 0.82},
}


static func has_type(type: String) -> bool:
	return TYPES.has(type)


static func cells(type: String) -> int:
	return TYPES[type]["cells"]


static func max_stretch(type: String) -> float:
	return TYPES[type]["max_stretch"]


## Sound names (see Sfx) and base pitch for a vehicle type.
static func engine_sound(type: String) -> String:
	return TYPES[type]["engine"]


static func horn_sound(type: String) -> String:
	return TYPES[type]["horn"]


## Siren (or signature horn) played as the vehicle leaves; "" for none.
static func siren_sound(type: String) -> String:
	return TYPES[type].get("siren", "")


static func pitch(type: String) -> float:
	return TYPES[type]["pitch"]


static func load_model(type: String) -> PackedScene:
	return load(MODEL_DIR + TYPES[type]["model"]) as PackedScene
