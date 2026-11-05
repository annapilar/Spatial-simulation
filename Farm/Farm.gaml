/**
* Name: Farm
* Farm simulation, built step by step with AI assistance (Claude Code).
* Author: annapilar
* Version: 0.6
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
	// Size of the cow: radius of its circle in metres (0.8 m radius = 1.6 m wide, small enough that the action area (radius 2 m) stays visible)
	float size <- 0.8;
	// Colour of the cow: medium earthy brown (GAMA's #brown is too red)
	rgb color <- rgb(139, 90, 43);
	// Action neighbourhood of the cow: where it can be in the next step = quarter circle (cow_amplitude = 90°, i.e. ±45° around the current heading) with radius cow_speed; recalculated whenever it is used
	geometry action_area -> circle(cow_speed) intersection cone(int(heading - cow_amplitude / 2), int(heading + cow_amplitude / 2));

	// Reflex move: every step the cow walks cow_speed metres and turns randomly within ±cow_amplitude/2 of its current heading (correlated random walk, stays inside the world)
	reflex move {
		do wander speed: cow_speed amplitude: cow_amplitude;
	}

	// Aspect base: draws the cow as a filled brown circle
	aspect base {
		draw circle(size) color: color;
	}

	// Aspect action_area: draws the cow's action neighbourhood (quarter circle) in white, so it contrasts with the cow and the meadow
	aspect action_area {
		if (action_area != nil) {
			draw action_area color: #white;
		}
	}
}

// Species sheep: a black farm animal that walks straight south (moving skill)
species sheep skills: [moving] {
	// Size of the sheep: radius of its circle in metres (0.5 m radius = 1 m wide, small so that the action area stays visible)
	float size <- 0.5;
	// Colour of the sheep
	rgb color <- #black;
	// Action neighbourhood of the sheep: it moves straight ahead, so the area is a line of length sheep_speed in direction sheep_heading; recalculated whenever it is used
	geometry action_area -> line(location, location + {cos(sheep_heading), sin(sheep_heading)} * sheep_speed);

	// Reflex move: every step the sheep walks sheep_speed metres straight in direction sheep_heading (south); bounds keep it inside the world, so it stops at the south edge
	reflex move {
		do move speed: sheep_speed heading: sheep_heading bounds: world.shape;
	}

	// Aspect base: draws the sheep as a filled black circle
	aspect base {
		draw circle(size) color: color;
	}

	// Aspect action_area: draws the sheep's action neighbourhood (line) in white, widened by 0.2 m on each side so it is visible
	aspect action_area {
		if (action_area != nil) {
			draw action_area + 0.2 color: #white;
		}
	}
}

// Species goat: a yellow farm animal that slowly walks to the origin (moving skill)
species goat skills: [moving] {
	// Size of the goat: radius of its circle in metres (0.5 m radius = 1 m wide, small so that the action area stays visible)
	float size <- 0.5;
	// Colour of the goat: warm golden yellow like straw (GAMA's #yellow is too bright)
	rgb color <- rgb(230, 190, 60);
	// Action neighbourhood of the goat: the part of the line towards goat_target that lies within goat_speed metres; recalculated whenever it is used
	geometry action_area -> line(location, goat_target) intersection circle(goat_speed);

	// Reflex move: every step the goat walks goat_speed metres in a straight line towards goat_target; all goats end up on the same point
	reflex move {
		do goto target: goat_target speed: goat_speed;
	}

	// Aspect base: draws the goat as a filled yellow circle
	aspect base {
		draw circle(size) color: color;
	}

	// Aspect action_area: draws the goat's action neighbourhood (line) in white, widened by 0.2 m on each side so it is visible; nothing is drawn once the goat has reached its target
	aspect action_area {
		if (action_area != nil) {
			draw action_area + 0.2 color: #white;
		}
	}
}

// Experiment with a graphical user interface to run and display the farm simulation
experiment Farm type: gui {
	// Output section: what is shown while the simulation runs
	output {
		// Main display showing the farm environment with all animals and their action neighbourhoods (50 % transparent) on a fresh meadow-green background
		display farm_display background: rgb(140, 190, 90) {
			species cow aspect: base;
			species cow aspect: action_area transparency: 0.5;
			species sheep aspect: base;
			species sheep aspect: action_area transparency: 0.5;
			species goat aspect: base;
			species goat aspect: action_area transparency: 0.5;
		}
	}
}
