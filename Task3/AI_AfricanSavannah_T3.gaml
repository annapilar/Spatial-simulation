/**
* Name: AI_AfricanSavannah_T3
* Version: 3.4
* Description: A simple African Savannah.
* Step 1 – 20 lions (orange circles, diameter 3) walking around randomly with a 40° amplitude.
* Step 2 – 20 zebras (grey triangles, side 2) walking around randomly with a 60° amplitude.
* Step 3 – a lion that runs into a zebra (within 2.5) kills it with "die", one zebra per step; a monitor shows the zebras left.
* Step 4 – grassland CA (100 x 100 cells) with random biomass 0–10 kg, linear growth of 0.1 kg per step, coloured by biomass.
* Step 5 – zebras eat 2.5 kg of grass per step from the cell they stand on; biomass never drops below 0.
* Step 6 – lions lose 0.1 energy per metre moved, gain 5 per zebra eaten and starve at 0; starting energy adjustable (1–50); monitors for lions and their average energy.
*/

model AI_AfricanSavannah_T3

// Global section
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
	// Energy every lion starts with
	float lion_start_energy <- 10.0;
	// List of age values: all possible lion ages from 0 to 60 years (60 included), assigned to the lions later
	list<int> lion_ages <- range(60);
	// Maximum age of a lion (years): lions older than this die
	int max_lion_age <- 60;

	// Initialisation: creates the lions and zebras at random locations in the environment
	init {
		create lion number: nb_lions;
		create zebra number: nb_zebras;
		// Replace the possible age values by the actual ages of all lions
		lion_ages <- [];
		ask lion {
			add age to: lion_ages;
		}
	}

	// Reflex run every cycle: reports the number of age values in the list and their minimum, mean and maximum
	reflex report_lion_ages {
		if (empty(lion_ages)) {
			// No lions left: there are no values to calculate
			write "Cycle " + cycle + ": no lion ages in the list";
		} else {
			write "Cycle " + cycle + ": n = " + length(lion_ages)
				+ ", min = " + min(lion_ages)
				+ ", mean = " + mean(lion_ages)
				+ ", max = " + max(lion_ages);
		}
	}
}

// Agents section
// Lion species: an agent that walks around randomly in the savannah
species lion skills: [moving] {
	// Size (diameter) of the lion's circle
	float size <- 3.0;
	// Colour of the lion: shade of red from the current mean age of the population (light red = young, dark red = 60 years or more)
	rgb color -> blend(rgb(139, 0, 0), rgb(255, 200, 200), empty(lion_ages) ? 0.0 : min(mean(lion_ages) / 60.0, 1.0));
	// Maximum change of direction per step (degrees)
	float wander_amplitude <- 40.0;
	// Current energy of the lion: decreases when moving, increases when eating a zebra
	float energy <- lion_start_energy;
	// Energy lost per metre the lion moves
	float energy_loss_per_metre <- 0.1;
	// Energy gained from eating one zebra
	float energy_gain <- 5.0;
	// Age of the lion (years): picked at random from the list of possible age values
	int age <- one_of(lion_ages);

	// Reflex run every cycle: the lion moves one step at the lion speed, turning only within the given amplitude
	reflex walk_randomly {
		do wander speed: lion_speed amplitude: wander_amplitude;
		// Moving costs energy: the further the lion moves (higher speed), the more energy it loses
		energy <- energy - energy_loss_per_metre * lion_speed;
	}

	// Distance at which the lion touches a zebra and kills it (lion radius 1.5 + about half a zebra 1.0)
	float kill_distance <- 2.5;

	// Reflex run every cycle after walking: kills one zebra the lion has run into, if there is one
	reflex kill_zebra {
		// One zebra within reach, or nil (0) if no zebra is close enough
		zebra prey <- one_of(zebra at_distance kill_distance);
		if (prey != nil) {
			ask prey {
				do die;
			}
			// Eating the zebra gives the lion energy
			energy <- energy + energy_gain;
		}
	}

	// Reflex run every cycle: the lion removes its previous age from the list, gets one year older and adds its current age
	reflex update_age_in_list {
		remove age from: lion_ages;
		// Ageing: the lion gets one year older each time step
		age <- age + 1;
		add age to: lion_ages;
	}

	// Reflex run every cycle after ageing: the lion dies of old age when it is older than the maximum age
	reflex die_of_old_age when: age > max_lion_age {
		// Remove the lion's age from the list before it dies
		remove age from: lion_ages;
		do die;
	}

	// Reflex run every cycle after hunting: the lion dies of starvation when it has no energy left
	reflex starve when: energy <= 0 {
		// Remove the lion's age from the list before it dies
		remove age from: lion_ages;
		do die;
	}

	// Default aspect: draws the lion as a red circle with a diameter of 'size' (/2 because size uses the radius)
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
	// Maximum change of direction per step (degrees)
	float wander_amplitude <- 60.0;

	// Reflex run every cycle: the zebra moves one step at the zebra speed, turning only within the given amplitude
	reflex walk_randomly {
		do wander speed: zebra_speed amplitude: wander_amplitude;
	}

	// Amount of grass the zebra eats per time step (kg)
	float eat_amount <- 2.5;

	// Reflex run every cycle after walking: the zebra eats grass from the cell it is standing on
	reflex eat_grass {
		// Grass cell the zebra is currently standing on
		grassland my_cell <- grassland closest_to self;
		// The zebra cannot eat more than the cell contains, so biomass never drops below 0
		float eaten <- min(eat_amount, my_cell.biomass);
		my_cell.biomass <- my_cell.biomass - eaten;
	}

	// Default aspect: draws the zebra as a grey triangle of the given size
	aspect default {
		draw triangle(size) color: color;
	}
}

// Callular automaton (CA) section
// Grassland: a cellular automaton (CA) of 100 x 100 grass cells covering the savannah
grid grassland width: 100 height: 100 {
	// Amount of grass in the cell (kg), random between 0 and 10 kg at the start
	float biomass <- rnd(10.0);
	// Amount of grass added to the cell each time step (kg), linear growth
	float growth_rate <- 0.1;
	// Maximum amount of grass a cell can hold (kg)
	float max_biomass <- 10.0;
	// Colour of the cell: light yellow-brown = little grass, dark green = much grass
	rgb color <- blend(#darkgreen, #khaki, min(biomass / 10.0, 1.0)) update: blend(#darkgreen, #khaki, min(biomass / 10.0, 1.0));

	// Reflex run every cycle: the grass grows linearly by the growth rate, up to the maximum biomass
	reflex grow {
		biomass <- min(biomass + growth_rate, max_biomass);
	}
}


// Simulation section
// GUI experiment that shows the savannah with its grassland, lions and zebras
experiment savannah type: gui {
	// Slider to adjust the speed of the lions
	parameter "Lion speed" var: lion_speed min: 0.0 max: 5.0 category: "Lions";
	// Slider to adjust the starting energy of the lions (applies when the simulation is (re)started)
	parameter "Lion starting energy" var: lion_start_energy min: 1.0 max: 50.0 category: "Lions";
	// Slider to adjust the speed of the zebras
	parameter "Zebra speed" var: zebra_speed min: 0.0 max: 5.0 category: "Zebras";

	output {
		// 2D display of the environment with the grassland, lions and zebras drawn in it
		display savannah_map {
			// Grass cells of the grassland, coloured by their biomass
			grid grassland;
			species lion aspect: default;
			species zebra aspect: default;
		}
		// Monitor showing how many zebras are still alive
		monitor "Number of zebras" value: length(zebra);
		// Monitor showing how many lions are still alive
		monitor "Number of lions" value: length(lion);
		// Monitor showing the average energy of the living lions (0 when no lion is left)
		monitor "Average lion energy" value: empty(lion) ? 0.0 : mean(lion collect each.energy); 
		//condition: no lions left: yes -> 0.0, no -> mean of the energy from the lions that are left
		// Monitor showing the number of values in the list of lion ages
		monitor "Number of lion ages" value: length(lion_ages);
		// Monitor showing the minimum lion age in the list (0 when the list is empty)
		monitor "Minimum lion age" value: empty(lion_ages) ? 0 : min(lion_ages);
		// Monitor showing the mean lion age in the list (0 when the list is empty)
		monitor "Mean lion age" value: empty(lion_ages) ? 0.0 : mean(lion_ages);
		// Monitor showing the maximum lion age in the list (0 when the list is empty)
		monitor "Maximum lion age" value: empty(lion_ages) ? 0 : max(lion_ages);
	}
}
