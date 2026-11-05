/**
* Name: Farm
* Farm simulation, built step by step with AI assistance (Claude Code).
* Author: annapilar
* Version: 0.0
* Tags: farm
*/

model Farm

// Global section
// Global context of the model: holds global variables and creates the initial agents
global {
	// Initialisation: runs once when the simulation starts (agents will be created here in later steps)
	init {
	}
}

// Experiment with a graphical user interface to run and display the farm simulation
experiment Farm type: gui {
	// Output section: what is shown while the simulation runs
	output {
		// Main display showing the farm environment (species will be added to it in later steps)
		display farm_display {
		}
	}
}
