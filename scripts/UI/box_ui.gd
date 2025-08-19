extends Control

@onready var slots: Array[SubViewport] = [
	$SubViewport,
	$SubViewport2,
	$SubViewport3
]

func set_truck_boxes(box_indices: Array[int]):
	# box_indices is like [0, 1, -1] (-1 = empty slot)
	for i in range(slots.size()):
		if i < box_indices.size():
			var box_preview = slots[i].get_script()  # get the BoxPreview script
			if box_preview:
				box_preview.set_box(box_indices[i])
		else:
			var box_preview = slots[i].get_script()
			if box_preview:
				box_preview.set_box(-1)
