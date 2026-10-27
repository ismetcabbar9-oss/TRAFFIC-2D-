class_name VehicleCatalog
## Vehicle types available to levels: model, footprint length and size limits.
## Swap models or add types here without touching gameplay code.

const MODEL_DIR := "res://assets/models/vehicles/"

## cells: footprint length in grid cells.
## max_stretch: how much the model may be lengthened (Z only) to fill its slot.
const TYPES := {
	"sedan": {"model": "sedan.glb", "cells": 2, "max_stretch": 1.15},
	"sedan_sports": {"model": "sedan-sports.glb", "cells": 2, "max_stretch": 1.15},
	"hatchback": {"model": "hatchback-sports.glb", "cells": 2, "max_stretch": 1.15},
	"suv": {"model": "suv.glb", "cells": 2, "max_stretch": 1.15},
	"suv_luxury": {"model": "suv-luxury.glb", "cells": 2, "max_stretch": 1.15},
	"taxi": {"model": "taxi.glb", "cells": 2, "max_stretch": 1.15},
	"police": {"model": "police.glb", "cells": 2, "max_stretch": 1.15},
	"van": {"model": "van.glb", "cells": 2, "max_stretch": 1.15},
	"pickup": {"model": "truck.glb", "cells": 2, "max_stretch": 1.15},
	"ambulance": {"model": "ambulance.glb", "cells": 3, "max_stretch": 1.5},
	"delivery": {"model": "delivery.glb", "cells": 3, "max_stretch": 1.5},
	"firetruck": {"model": "firetruck.glb", "cells": 3, "max_stretch": 1.5},
	"garbage": {"model": "garbage-truck.glb", "cells": 3, "max_stretch": 1.5},
}


static func has_type(type: String) -> bool:
	return TYPES.has(type)


static func cells(type: String) -> int:
	return TYPES[type]["cells"]


static func max_stretch(type: String) -> float:
	return TYPES[type]["max_stretch"]


static func load_model(type: String) -> PackedScene:
	return load(MODEL_DIR + TYPES[type]["model"]) as PackedScene
