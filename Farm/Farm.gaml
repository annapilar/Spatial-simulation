/**
* Name: Farm
* Farm simulation, built step by step with AI assistance (Claude Code).
* Author: annapilar
* Version: 0.1
* Tags: farm
*/

model Farm

// Global section
// Global context of the model: holds global variables and creates the initial agents
global {
	// Number of cows created when the simulation starts
	int nb_cows <- 5;
	// Number of sheep created when the simulation starts
	int nb_sheep <- 3;
	// Number of goats created when the simulation starts
	int nb_goats <- 2;

	// Initialisation: runs once when the simulation starts and creates the animals at random locations
	init {
		create cow number: nb_cows;
		create sheep number: nb_sheep;
		create goat number: nb_goats;
	}
}

// Species cow: a brown farm animal (no behaviour yet)
species cow {
	// Size of the cow: radius of its circle in metres (2.0 m radius = 4 m wide)
	float size <- 2.0;
	// Colour of the cow: medium earthy brown (GAMA's #brown is too red)
	rgb color <- rgb(139, 90, 43);

	// Aspect base: draws the cow as a filled brown circle
	aspect base {
		draw circle(size) color: color;
	}
}

// Species sheep: a black farm animal (no behaviour yet)
species sheep {
	// Size of the sheep: radius of its circle in metres (1.5 m radius = 3 m wide)
	float size <- 1.5;
	// Colour of the sheep
	rgb color <- #black;

	// Aspect base: draws the sheep as a filled black circle
	aspect base {
		draw circle(size) color: color;
	}
}

// Species goat: a yellow farm animal (no behaviour yet)
species goat {
	// Size of the goat: radius of its circle in metres (1.5 m radius = 3 m wide)
	float size <- 1.5;
	// Colour of the goat: warm golden yellow like straw (GAMA's #yellow is too bright)
	rgb color <- rgb(230, 190, 60);

	// Aspect base: draws the goat as a filled yellow circle
	aspect base {
		draw circle(size) color: color;
	}
}

// Experiment with a graphical user interface to run and display the farm simulation
experiment Farm type: gui {
	// Output section: what is shown while the simulation runs
	output {
		// Main display showing the farm environment with all animals
		display farm_display {
			species cow aspect: base;
			species sheep aspect: base;
			species goat aspect: base;
		}
	}
}
