package ui

list :: proc(
	uid: Id,
	size: Vec2,
	items_count: int,
	item_height: f32,
	ud: rawptr,
	item: proc(i: int, ud: rawptr),
) {
	scope(size, {.Clip})

	offset := get(id(uid, "offset"), f32)
	container := get_scope()
	bind(.Scroll_Y, offset)

	skip := max(int(offset^ / item_height), 0)
	visible := int(size.y / item_height) + 1
	container.cursor += {0, f32(skip) * item_height}

	draw_rect(0, 0, size.x, size.y, {30, 80, 30, 255})
	for i in skip ..< min(skip + visible, items_count) {
		scope({size.x, item_height})
		item(i, ud)
		container.cursor += {0, item_height}
	}

	container.content_size = {0, f32(items_count * items_count)}
}

