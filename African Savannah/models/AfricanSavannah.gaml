/**
* Name: AfricanSavannah
* Based on the internal empty template.
* Author: Anna Pilar
* Tags:
*/

model AfricanSavannah

// Global section
global {
	int my_variable <- 1;
	float my_speed <- 3.0;

	init {
		create lions number: 20 { //create 20 lions (agent)
			speed <- my_speed;
		}

		create zebras number: 20 { // create 20 zebras (agent)
			speed <- my_speed;
		}

	}

}

// Agents section
species lions skills: [moving] { //define lions skills

	reflex move { // create move reflex (function)
		do wander amplitude: 60.0; // random movement, amplitude: in a 60° radius in movement direction
	}

	reflex hunt { // create hunt reflex of lions, because they kill the zebras
		list<zebras> nearby_zebras <- zebras where (each distance_to self <= 3.0); // create a list of all zebras
		if !empty(nearby_zebras) { // if there are still zebras
			ask one_of(nearby_zebras) { // selects one zebra at random from the list, that is within 5.0 distance to a lion
				do die; // removes the zebra
			}

		}

	}

	aspect default { // visual representation of the lions
		draw circle(3) color: #orange; // circle, size 3, color orange
	}

}

species zebras skills: [moving] { // define zebras skills

	reflex move { // create move reflex (function)
		do wander amplitude: 60.0; // random movement in a 60° radius in movement direction
	}

	aspect default { // visual representation of the zebras
		draw triangle(2) color: #grey; // triangle, size 2, color grey
	}

}

// Cellular Automaton (CA) section
grid grassland { // create grid
	float biomass <- rnd(10.0); // define biomass with random values from 0 to 10kg per cell

	reflex grow { // create grow reflex
		biomass <- biomass + 0.1; // biomass grows by 0.1kg each time step
	}

	aspect default { // visual representation of the grassland
		draw shape color: rgb(0, 50 + int(biomass * 20), 0); // color only green, that gets greener each time it grows
	}

}

// Simulation section
experiment main_experiment type: gui { // define experiment (simulation) with type graphical user interface
	parameter "my Variable" var: my_variable; // configurable parameter "my variable" (no effect)
	parameter "my Speed" var: my_speed; // configurable paramtere "my Speed" 
	output { // define output of the experiment
		display map { // defines the visual window in which the simulation is shown: map
			species grassland aspect: default; //displays grassland using its default visual representation
			species lions aspect: default; // displays lions
			species zebras aspect: default; // displays zebras
		}

	}

}
