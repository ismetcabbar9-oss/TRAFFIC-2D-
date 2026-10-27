class_name MechanicStyle
## Colors shared by everything that belongs to one key group (key car, locked
## cars, gates), so players can match them at a glance.

const GROUP_COLORS: Array[Color] = [
	Color("e5484d"), # red
	Color("3e7bfa"), # blue
	Color("f5b700"), # yellow
	Color("8e5cd9"), # purple
]


static func group_color(group: int) -> Color:
	return GROUP_COLORS[group % GROUP_COLORS.size()]
