package ui

init :: proc {
	init_context,
}

deinit :: proc {
	deinit_context,
}

next :: proc {
	wrap_next,
	stack_next,
	flex_next,
}

measure :: proc {
	measure_fixed,
	measure_dynamic,
	measure_text,
	measure_padding,
}

