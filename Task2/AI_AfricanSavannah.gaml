/**
* Name: AI_AfricanSavannah
* Description: A simple African Savannah.
* Step 1 – 20 lions (orange circles, diameter 3) walking around randomly with a 40° amplitude.
* Step 2 – 20 zebras (grey triangles, side 2) walking around randomly with a 60° amplitude.
* Step 3 – a lion that runs into a zebra (within 2.5) kills it with "die", one zebra per step; a monitor shows the zebras left.
*/

model AI_AfricanSavannah

// Global context of the model: holds global variables and creates the initial agents
global {
	// Number of lions created when the simulation starts
	int nb_lions <- 20;
	// Number of zebras created when the simulation starts
	int nb_zebras <- 20;
	// Speed of all lions (metres per step)
	float lion_speed <- 1.0;
	// Speed of all zebras (metres per step)
	float zebra_speed <- 1.0;

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

	// Reflex run every cycle: the lion moves one step at the lion speed, turning only within the given amplitude
	reflex walk_randomly {
		do wander speed: lion_speed amplitude: wander_amplitude;
	}

	// Distance at which the lion touches a zebra and kills it (lion radius 1.5 + about half a zebra 1.0)
	float kill_distance <- 2.5;

	// Reflex run every cycle after walking: kills one zebra the lion has run into, if there is one
	reflex kill_zebra {
		// One zebra within reach, or nil if no zebra is close enough
		zebra prey <- one_of(zebra at_distance kill_distance);
		if (prey != nil) {
			ask prey {
				do die;
			}
		}
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

	// Reflex run every cycle: the zebra moves one step at the zebra speed, turning only within the given amplitude
	reflex walk_randomly {
		do wander speed: zebra_speed amplitude: wander_amplitude;
	}

	// Default aspect: draws the zebra as a grey triangle of the given size
	aspect default {
		draw triangle(size) color: color;
	}
}

// GUI experiment that shows the savannah and its lions
experiment savannah type: gui {
	// Slider to adjust the speed of the lions
	parameter "Lion speed" var: lion_speed min: 0.0 max: 5.0 category: "Lions";
	// Slider to adjust the speed of the zebras
	parameter "Zebra speed" var: zebra_speed min: 0.0 max: 5.0 category: "Zebras";

	output {
		// 2D display of the environment with all lions drawn in it
		display savannah_map {
			species lion aspect: default;
			species zebra aspect: default;
		}
		// Monitor showing how many zebras are still alive
		monitor "Number of zebras" value: length(zebra);
	}
}
