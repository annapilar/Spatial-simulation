/**
* Name: AI_AfricanSavannah
* Description: Step 1 – a simple African Savannah with 20 lions walking around randomly.
*/

model AI_AfricanSavannah

// Global context of the model: holds global variables and creates the initial agents
global {
	// Number of lions created when the simulation starts
	int nb_lions <- 20;
	// Number of zebras created when the simulation starts
	int nb_zebras <- 20;

	// Initialisation: creates the lions and zebras at random locations in the environment
	init {
		create lion number: nb_lions;
		create zebra number: nb_zebras;
	}
}

// Lion species: an agent that walks around randomly in the savannah
species lion skills: [moving] {
	// Size (diameter) of the lion's circle
	float size <- 3.0;
	// Colour used to draw the lion
	rgb color <- #orange;
	// Maximum change of direction per step (degrees); the new heading is picked within ±amplitude/2 of the current one
	float wander_amplitude <- 40.0;

	// Reflex run every cycle: the lion moves one step, turning only within the given amplitude
	reflex walk_randomly {
		do wander amplitude: wander_amplitude;
	}

	// Default aspect: draws the lion as an orange circle with a diameter of 'size'
	aspect default {
		draw circle(size / 2) color: color;
	}
}

// Zebra species: an agent that walks around randomly in the savannah
species zebra skills: [moving] {
	// Size of the zebra: side length of its triangle
	float size <- 2.0;
	// Colour used to draw the zebra
	rgb color <- #grey;
	// Maximum change of direction per step (degrees); the new heading is picked within ±amplitude/2 of the current one
	float wander_amplitude <- 60.0;

	// Reflex run every cycle: the zebra moves one step, turning only within the given amplitude
	reflex walk_randomly {
		do wander amplitude: wander_amplitude;
	}

	// Default aspect: draws the zebra as a grey triangle of the given size
	aspect default {
		draw triangle(size) color: color;
	}
}

// GUI experiment that shows the savannah and its lions
experiment savannah type: gui {
	output {
		// 2D display of the environment with all lions drawn in it
		display savannah_map {
			species lion aspect: default;
			species zebra aspect: default;
		}
	}
}
