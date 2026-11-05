/**
* Name: Farm
* Farm simulation, built step by step with AI assistance (Claude Code).
* Author: annapilar
* Version: 0.4
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
	// Speed of all cows (metres per step)
	float cow_speed <- 2.0;
	// Turning range of the cows' correlated random walk (degrees): the new heading is within ±45° of the current one
	float cow_amplitude <- 90.0;
	// Speed of all sheep (metres per step)
	float sheep_speed <- 1.0;
	// Direction in which all sheep walk (degrees): 0 = east, 90 = south (clockwise, y axis points down)
	float sheep_heading <- 90.0;
	// Speed of all goats (metres per step)
	float goat_speed <- 0.5;
	// Target the goats walk to: the origin {0, 0}, the top-left (north-west) corner of the world
	point goat_target <- {0, 0};

	// Initialisation: runs once when the simulation starts and creates the animals at random locations
	init {
		create cow number: nb_cows;
		create sheep number: nb_sheep;
		create goat number: nb_goats;
	}
}

// Species cow: a brown farm animal that moves with a correlated random walk (moving skill)
species cow skills: [moving] {
	// Size of the cow: radius of its circle in metres (2.0 m radius = 4 m wide)
	float size <- 2.0;
	// Colour of the cow: medium earthy brown (GAMA's #brown is too red)
	rgb color <- rgb(139, 90, 43);

	// Reflex move: every step the cow walks cow_speed metres and turns randomly within ±cow_amplitude/2 of its current heading (correlated random walk, stays inside the world)
	reflex move {
		do wander speed: cow_speed amplitude: cow_amplitude;
	}

	// Aspect base: draws the cow as a filled brown circle
	aspect base {
		draw circle(size) color: color;
	}
}

// Species sheep: a black farm animal that walks straight south (moving skill)
species sheep skills: [moving] {
	// Size of the sheep: radius of its circle in metres (1.5 m radius = 3 m wide)
	float size <- 1.5;
	// Colour of the sheep
	rgb color <- #black;

	// Reflex move: every step the sheep walks sheep_speed metres straight in direction sheep_heading (south); bounds keep it inside the world, so it stops at the south edge
	reflex move {
		do move speed: sheep_speed heading: sheep_heading bounds: world.shape;
	}

	// Aspect base: draws the sheep as a filled black circle
	aspect base {
		draw circle(size) color: color;
	}
}

// Species goat: a yellow farm animal that slowly walks to the origin (moving skill)
species goat skills: [moving] {
	// Size of the goat: radius of its circle in metres (1.5 m radius = 3 m wide)
	float size <- 1.5;
	// Colour of the goat: warm golden yellow like straw (GAMA's #yellow is too bright)
	rgb color <- rgb(230, 190, 60);

	// Reflex move: every step the goat walks goat_speed metres in a straight line towards goat_target; all goats end up on the same point
	reflex move {
		do goto target: goat_target speed: goat_speed;
	}

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
