/**
* Name: Vierkaser_verification_students
* Author: Gudrun WALLENTIN
* Tags: agent movement, agent-agent interaction, agent-CA interaction, flocking, verification
*
* Description: Vierkaser model (behaviour: grazing on a biomass grid, flocking, a lead cow
*              that leaves for a better pasture when the grass around her is exhausted, and
*              followers that pick up her travelling from her observed movement alone),
*              with validation export.
*              Two randomly selected cows (Hansel_sim, Susi_sim) write their
*              location to CSV at the simulation steps closest to the real
*              GPS observation times in Hansel2025.gpx / Susi2025.gpx.
*
*              Simulation clock: 1 cycle = 15 min real time
*              Run period: 2025-06-06 09:00  to  2025-09-07 11:00  (8937 cycles)
*
*              Before first run: execute prepare_export_cycles.py to generate
*              hansel_export_cycles.csv and susi_export_cycles.csv in includes/.
*/

model verification_Vierkaser_verification_students

global  {

// Intergrating external files of the property ("vierkaser_") and of the grassland within it ("pasture_")
	file vierkaser_file <- file("../includes/pasture.geojson");
	file pasture_hirschanger_file <- file("../includes/hirschanger.geojson");
	file pasture_lower_file <- file("../includes/meadow.geojson");
	file pasture_cutback2020_file <- file("../includes/cleaned_areas_2020.geojson");
	file pasture_cutback2021_file <- file("../includes/cleaned_areas_2021.geojson");
	file pasture_cutback2022_file <- file("../includes/cleaned_areas_2022.geojson");
	file pasture_cutback2023_file <- file("../includes/cleaned_areas_2023.geojson");
	file pasture_cutback2024_file <- file("../includes/cleaned_areas_2024.geojson");
	file pasture_cutback2025_file <- file("../includes/cleaned_areas_2025.geojson");

	geometry shape <- envelope(vierkaser_file);
	geometry vierkaser_polygon; //entire area, where the farmer has pasture rights (grassland AND shrubs)
	geometry pasture_hirschanger;
	geometry pasture_lower;
	geometry pasture_cutback2020;
	geometry pasture_cutback2021;
	geometry pasture_cutback2022;
	geometry pasture_cutback2023;
	geometry pasture_cutback2024;
	geometry pasture_cutback2025;
	geometry pasture_polygon; //entire area, at which there is an actual pasture (i.e. grass, not shrubs)
	list<grass> pasture_cells;    //grid cells of the grassland only
	list<grass> vierkaser_cells;  //grid cells of the whole property, shrubs included

	//the individual pastures, for the biomass chart (the cutbacks are pooled,
	//except Schoenkopf - the big area in the east that was cleared in 2023)
	list<grass> cells_hirschanger;
	list<grass> cells_lower;
	list<grass> cells_schoenkopf;
	list<grass> cells_cutbacks;

	
	
//speeds are given in metres per hour; time step of model: 15 minutes
	float cow_amplitude <- 60.0 ;
	//step = the duration of 1 cycle
	float step <- 15 #minutes;
	date starting_date <- date("2025-06-06 09:00:00");
	
// Adding parameters to each type of cows	
	int no_of_calves <- 0 ; //Kalb
	int no_of_weaned_calves <- 9 ; //Jungvieh
	int no_of_suckler_cows <- 0 ; //säugende Mutterkuh
	int no_of_dry_cows <- 1 ; // trockene Mutterkühe

// flocking parameters
	float min_separation <- 15.0#m  min: 1.0  max: 150.0#m ;
	int max_separate_turn <- 15 min: 0 max: 50;
	int max_cohere_turn <- 15 min: 0 max: 50;
	int max_align_turn <- 16 min: 0 max: 50;
	float vision <- 300.0#m  min: 0.0  max: 500.0#m ; //perception area

// debug error1: cow_speed (m/s to m/h)
	float cow_speed <- 150.0 #m/#h;
	float speed_weight_flocking;
	float speed_weight_grazing;
	float speed_weight_following;
	float speed_weight_leading;
	float speed_weight_travelling;

	// a cow counts as "moving fast" if it covered more than this distance during the previous cycle
	// (set in init to 1.5 times the distance a cow covers in one cycle at base speed)
	float travel_threshold;

	// how far a cow senses the grass around it: as far as it could walk within one cycle if
	// it spent its whole speed budget on it (set in init). This is wider than the action_area
	// it actually reaches while grazing, and it is used to judge the quality of the pasture
	// the cow is standing on - never to pick the cell it moves to.
	float perception_radius;
	// below this biomass the lead cow considers the grass around her to be exhausted
	float grass_quality_threshold <- 1.5;
	// a new pasture has to be at least this far away to be worth travelling to
	float min_travel_distance <- 300.0#m;
	// the lead cow considers herself arrived within this distance of her target
	float arrival_distance <- 20.0#m;

	// DEBUG: pause when the lead cow sets off and when she arrives, and refresh the map every cycle
	bool pause_on_travel <- true;

	// the one cow that leads the herd to a new pasture (set once in init)
	cows lead_cow;

	// validation export: two tracked cows
	cows Hansel_sim;
	cows Susi_sim;

	// sorted cycle numbers at which each tracked cow exports its location
	list<int> hansel_export_cycles;
	list<int> susi_export_cycles;
	int hansel_idx <- 0;
	int susi_idx   <- 0;

	file hansel_cycles_file <- csv_file("../includes/hansel_export_cycles.csv", false);
	file susi_cycles_file   <- csv_file("../includes/susi_export_cycles.csv",   false);

	// output files of this run (set in init, so every run gets its own file)
	string hansel_out;
	string susi_out;

	// TRACE LOG: number of cycles that are traced (cycles 0 to 4, plus init)
	int trace_cycles <- 5;
	// TRACE LOG: running number of the trace entries - it shows the order in which the code runs
	int trace_seq <- 0;
	// TRACE LOG: output file of the detailed trace (set in init, so every run gets its own file)
	string trace_out;

	// TRACE LOG: records that a block of code starts running
	//   who      - the agent that runs the block
	//   kind     - init / reflex / phase / action / function
	//   what     - name of the block (with its arguments, if it has any)
	//   overview - true: also shown in the GAMA console; the CSV gets every entry
	action trace (agent who, string kind, string what, bool overview) {
		if cycle < trace_cycles {
			trace_seq <- trace_seq + 1;
			// short overview in the console
			if overview {
				write "[trace " + trace_seq + "] cycle " + cycle + " | " + who.name + " | " + kind + " " + what;
			}
			// detailed entry in the CSV: cows also log where they are and where they head
			if trace_out != nil {
				string x <- (who is cows) ? string(who.location.x) : "";
				string y <- (who is cows) ? string(who.location.y) : "";
				string h <- (who is cows) ? string(cows(who).heading) : "";
				save [trace_seq, cycle, string(current_date, "yyyy-MM-dd HH:mm:ss"), who.name, kind, what, x, y, h]
					to: trace_out format: "csv" rewrite: false header: false;
			}
		}
	}

	// VERIFICATION debug error2: number of cows that did not reach their chosen grass cell in this cycle
	// (reset at the start of movingHerd; should stay close to 0 now that choose_grass runs after moving)
	int missed_grass <- 0;
	// VERIFICATION debug error2: the misses of this cycle split by their likely cause
	int missed_shrubs <- 0;   // the cow stood in the shrubs, so move_to_grass walked her to the nearest grass instead
	int missed_edge <- 0;     // the chosen cell is an edge cell whose centre lies outside the pasture (bounds stop her)
	int missed_other <- 0;    // cow on the pasture, cell centre inside it: e.g. the straight path left the pasture
	// VERIFICATION debug error2: diagnostic file with one row per miss (set in init, every run gets its own file)
	string missed_out;

	// VERIFICATION debug error3: number of followers that travel in this cycle (correct model: only 0 or all 9)
	int travellers <- 0;
	// VERIFICATION debug error3: number of cycles so far in which only part of the followers travelled (correct model: 0)
	int split_cycles <- 0;
	// VERIFICATION debug error3: the travel decisions of this cycle, one row per follower (written to the CSV at the end of movingHerd)
	list<list> travel_rows <- [];
	// VERIFICATION debug error3: diagnostic file of the followers' travel decisions (set in init, every run gets its own file)
	string travel_out;
	// VERIFICATION debug error3: {cycle, number of travelling followers} for every cycle with travel - points in the travel chart
	list<point> traveller_points <- [];
	// VERIFICATION debug error3: {cycle, 10} for every cycle in which the lead cow travels - a marker row above the followers
	list<point> lead_points <- [];
	// VERIFICATION debug error3: did the lead cow travel to the new pasture (goto_other_pasture) in this cycle?
	bool lead_travelled <- false;

	// returns the first free file name: base.csv, base_1.csv, base_2.csv, ...
	string new_result_file (string base) {
		string file_name <- base + ".csv";
		int i <- 1;
		loop while: file_exists(file_name) {
			file_name <- base + "_" + i + ".csv";
			i <- i + 1;
		}
		return file_name;
	}

//create the agents and objects with their variables
	init {
		// TRACE LOG: open the trace file first, so that init itself is traced as well
		trace_out <- new_result_file("../results/trace_log");
		save ["seq", "cycle", "date", "agent", "kind", "block", "x", "y", "heading"]
			to: trace_out format: "csv" rewrite: true header: false;
		do trace(self, "init", "global init", true);

		// "fast" = more than 1.5 times the distance a cow covers in one cycle at base speed
		travel_threshold <- 1.5 * cow_speed * step;
		// a cow senses the grass as far as it could walk within one cycle
		perception_radius <- cow_speed * step;

		vierkaser_polygon <- geometry(vierkaser_file);
		pasture_hirschanger <- geometry(pasture_hirschanger_file);
		pasture_lower <- geometry(pasture_lower_file);
		pasture_cutback2020 <- geometry(pasture_cutback2020_file);
		pasture_cutback2021 <- geometry(pasture_cutback2021_file);
		pasture_cutback2022 <- geometry(pasture_cutback2022_file);
		pasture_cutback2023 <- geometry(pasture_cutback2023_file);
		pasture_cutback2024 <- geometry(pasture_cutback2024_file);
		pasture_cutback2025 <- geometry(pasture_cutback2025_file);
		pasture_polygon <- pasture_cutback2020 + pasture_cutback2021 + pasture_cutback2022 + pasture_cutback2023 + pasture_cutback2024 + pasture_cutback2025 + pasture_lower + pasture_hirschanger;
		vierkaser_cells <- grass overlapping(vierkaser_polygon);

		// Default cells of the property have shrubs which no biomass
		ask vierkaser_cells{
			landcover <- "shrubs";
			max_biomass <- 0.2;
		}
		// Overwirte shrub-free parts with other landcover qualities
		// note: every cell *overlapping* a pasture is assigned to it. The resulting rim of
		//       boundary cells is what keeps the separate pastures connected for
		//       "goto ... on: pasture_cells" - a stricter rule breaks the lead cow's routes
		ask (grass overlapping pasture_hirschanger) {
			landcover <- "hirschanger";
			max_biomass <- 4.0;
		}
		ask (grass overlapping pasture_lower) {
			landcover <- "lower_pasture";
			max_biomass <- 6.0;
		}
		ask (grass overlapping pasture_cutback2020) {
			landcover<-"cutback2020";
			max_biomass <- 7.0;
		}
		ask (grass overlapping pasture_cutback2021) {
			landcover<-"cutback2021";
			max_biomass <- 6.0;
		}
		ask (grass overlapping pasture_cutback2022) {
			landcover<-"cutback2022";
			max_biomass <- 7.0;
		}
		ask (grass overlapping pasture_cutback2023) {
			landcover<-"cutback2023";
			max_biomass <- 5.0;
		}
		ask (grass overlapping pasture_cutback2024) {
			landcover<-"cutback2024";
			max_biomass <- 6.0;
		}
		ask (grass overlapping pasture_cutback2025) {
			landcover<-"cutback2025";
			max_biomass <- 6.0;
		}

		// cells that overlap a pasture but do not lie completely inside it: the rims and the
		// connecting stretches between the pastures. Cows walk through them, they hardly graze
		// there - so they carry only 40% of the forage of a cell in the interior
		ask ((grass overlapping pasture_polygon) - (grass inside pasture_polygon)) {
			max_biomass <- max_biomass * 0.4;
		}

		ask vierkaser_cells {
			biomass <- max_biomass;
			color <- rgb([0, biomass * 15, 0]);	
		}

		pasture_cells <- vierkaser_cells where (each.landcover != "shrubs");

		cells_hirschanger <- pasture_cells where (each.landcover = "hirschanger");
		cells_lower       <- pasture_cells where (each.landcover = "lower_pasture");
		cells_schoenkopf  <- pasture_cells where (each.landcover = "cutback2023");
		cells_cutbacks    <- pasture_cells where (each.landcover in ["cutback2020", "cutback2021", "cutback2022", "cutback2024", "cutback2025"]);

		create cows number:no_of_dry_cows {
			location <- any_location_in(pasture_lower);
			life_stage <- "dry_cow";
			daily_requirement <- 12.0;
			icon_size <- int(daily_requirement) * 2;
			icon_colour <- #red;
		}
		create cows number:no_of_suckler_cows  {
			location <- any_location_in(pasture_lower);
			life_stage <- "suckler_cow";
			daily_requirement <- 16.0;
			icon_size <- int(daily_requirement) * 2;
			icon_colour <- #red;			
		}
		create cows number:no_of_weaned_calves  {
			location <- any_location_in(pasture_lower);
			life_stage <- "weaned_calf";
			daily_requirement <- 8.0;
			icon_size <- int(daily_requirement) * 2;
			icon_colour <- #orange;			
		}
		create cows number:no_of_calves  {
			location <- any_location_in(pasture_lower);
			life_stage <- "calf";
			daily_requirement <- 5.0;
			icon_size <- int(daily_requirement) * 2;
			icon_colour <- #yellow;			
		}
		
		//lead cows should only be cows with: life_stage = "dry cow"
		lead_cow <- one_of (cows where (each.life_stage = "dry_cow"));
		ask lead_cow {
			target_pasture <- one_of (pasture_cells where (each.biomass > 3 and (location distance_to each.location) > 200#m));
		}
		// load GPS-matched export cycle lists
		hansel_export_cycles <- (matrix(hansel_cycles_file) column_at 0) collect int(each);
		susi_export_cycles   <- (matrix(susi_cycles_file)   column_at 0) collect int(each);

		// pick two distinct random cows as the validation animals
		Hansel_sim <- one_of(cows);
		Susi_sim   <- one_of(cows - [Hansel_sim]);

		// pick a fresh file name for this run and write the header row
		hansel_out <- new_result_file("../results/Hansel_sim_locations");
		susi_out   <- new_result_file("../results/Susi_sim_locations");
		write "writing results to " + hansel_out + " and " + susi_out;

		save ["date", "x", "y"] to: hansel_out format: "csv" rewrite: true header: false;
		save ["date", "x", "y"] to: susi_out   format: "csv" rewrite: true header: false;

		// VERIFICATION debug error2: open the diagnostic file of the grass misses and write its header row
		missed_out <- new_result_file("../results/missed_grass");
		save ["cycle", "date", "cow", "miss_m", "in_shrubs_before", "cell_centre_outside_pasture", "cause"]
			to: missed_out format: "csv" rewrite: true header: false;

		// VERIFICATION debug error3: open the diagnostic file of the travel decisions and write its header row
		travel_out <- new_result_file("../results/travel_decisions");
		save ["cycle", "date", "cow", "displacement_seen", "travelling"]
			to: travel_out format: "csv" rewrite: true header: false;
	}
	
	reflex movingHerd {
		// TRACE LOG
		do trace(self, "reflex", "movingHerd", true);
		// VERIFICATION debug error2: start counting the misses of this cycle from 0
		missed_grass <- 0;
		missed_shrubs <- 0;
		missed_edge <- 0;
		missed_other <- 0;
		// VERIFICATION debug error3: start the travel count and the decision rows of this cycle from scratch
		travellers <- 0;
		travel_rows <- [];
		lead_travelled <- false;

		// debug error3: the lead cow's displacement was measured, and the followers decided on travelling, inside the
		//              grazing loop (ask shuffle(cows), after flocking and following). Followers that came before the
		//              lead cow in the shuffled order saw last cycle's displacement, those after her saw this cycle's -
		//              so only part of the herd set off, and travelling happened after flocking instead of before.
		//              Now (as in the conceptual design, steps 1 and 2) the displacement is measured once per cycle
		//              before any cow moves, and all followers decide on this same value before they flock

		// step 1: the lead cow measures how far she moved since the last cycle - this displacement is the only travel cue the followers get
		do trace(self, "phase", "1/6 lead cow: measure displacement", true);
		ask lead_cow {
			if previous_location = nil {
				last_displacement <- 0.0;
			}
			else {
				last_displacement <- previous_location distance_to location;
			}
			previous_location <- location;
		}

		// step 2: the followers react to the lead cow's displacement (each follower, random order)
		do trace(self, "phase", "2/6 followers: travel", true);
		ask shuffle(cows - lead_cow) {
			do travel;
			// VERIFICATION debug error3: remember which displacement this follower saw and what she decided
			travel_rows <- travel_rows + [[cycle, string(current_date, "yyyy-MM-dd HH:mm:ss"), name,
				lead_cow.last_displacement with_precision 2, travelling]];
			if travelling {
				travellers <- travellers + 1;
			}
		}

		// steps 3 and 4: flock and follow; each cow chooses her grass only afterwards, from where she then stands
		do trace(self, "phase", "3/6 all cows: flock", true);
		ask shuffle(cows) { do flock; }
		do trace(self, "phase", "4/6 followers: following", true);
		ask (cows - lead_cow) { do following; }

		// step 5: the lead cow goes to the new pasture; then every cow moves to the best grass
		do trace(self, "phase", "5/6 lead cow: goto_other_pasture; all: choose_grass, move_to_grass", true);
		ask shuffle(cows)  {
			if self = lead_cow {
				if look_for_new_pasture = true and max(flockmates collect (self distance_to each)) < 0.5 * vision {
					do goto_other_pasture;
					// VERIFICATION debug error3: mark this cycle as a travel cycle of the lead cow
					lead_travelled <- true;
				}
			}
			// debug error2: choose_grass was called at the start of movingHerd, before flocking, following and
			//              travelling moved the cows - so each cow picked her cell from an old position and the
			//              chosen cell could be out of reach. Now she perceives the grass from where she stands
			//              after moving, right before she walks to it (as in the UML activity diagram)
			do choose_grass;
			// VERIFICATION debug error2: was the cow on the pasture before moving? (decides which branch move_to_grass takes)
			bool on_pasture_before <- pasture_polygon covers location;
			// travelling and grazing are overlaid: whoever travelled above still grazes on the way
			do move_to_grass;
			// VERIFICATION debug error2: after moving, the cow should stand on the cell she chose (tolerance 1 m).
			//              Every miss is counted by its likely cause and written to missed_grass.csv
			if grazed_grass != nil {
				float miss <- location distance_to grazed_grass.location;
				if miss > 1.0#m {
					bool centre_outside <- not (pasture_polygon covers grazed_grass.location);
					string cause;
					if not on_pasture_before {
						cause <- "shrubs";
						missed_shrubs <- missed_shrubs + 1;
					}
					else {
						if centre_outside {
							cause <- "edge_cell";
							missed_edge <- missed_edge + 1;
						}
						else {
							cause <- "other";
							missed_other <- missed_other + 1;
						}
					}
					missed_grass <- missed_grass + 1;
					save [cycle, string(current_date, "yyyy-MM-dd HH:mm:ss"), name, miss with_precision 2,
						not on_pasture_before, centre_outside, cause]
						to: missed_out format: "csv" rewrite: false header: false;
				}
			}
		}
		do trace(self, "phase", "6/6 all cows: graze", true);
		ask shuffle(cows) { do graze; }

		// VERIFICATION debug error3: a cycle in which only part of the followers travel is a split decision
		if travellers > 0 and travellers < length(cows - lead_cow) {
			split_cycles <- split_cycles + 1;
		}
		// VERIFICATION debug error3: console line in every cycle with travel - shows the timing between the lead cow's
		//              trip and the followers' reaction (followers decide on the displacement measured at the start of the cycle)
		if lead_travelled or travellers > 0 {
			write "cycle " + cycle + ": lead cow travels: " + (lead_travelled ? "yes" : "no")
				+ " | displacement seen by the followers: " + (lead_cow.last_displacement with_precision 1) + " m"
				+ " (threshold " + (travel_threshold with_precision 2) + " m)"
				+ " | followers travelling: " + travellers + "/" + length(cows - lead_cow);
		}
		// VERIFICATION debug error3: chart points only for cycles with actual travel
		if travellers > 0 {
			traveller_points <- traveller_points + [{cycle, travellers}];
		}
		if lead_travelled {
			lead_points <- lead_points + [{cycle, 10}];
		}
		// VERIFICATION debug error3: write the decisions only in cycles where something happens
		// (someone travels, or the lead cow moved fast), so the CSV stays small
		if travellers > 0 or lead_cow.last_displacement > travel_threshold {
			loop r over: travel_rows {
				save r to: travel_out format: "csv" rewrite: false header: false;
			}
		}
	}

	reflex update_biomass {
		// TRACE LOG
		do trace(self, "reflex", "update_biomass", true);
		ask pasture_cells {
			if biomass < max_biomass {
				//regrowth of 1 unit in 7 days
				// debug error5: the regrowth was added whenever biomass was below max_biomass, so the last
				//              step could push a cell above its carrying capacity (by up to 1/672 unit).
				//              Now the regrowth is capped, so biomass grows only up to max_biomass
				biomass <- min(max_biomass, biomass + 1/(24*4*7));  // biomass growth every time step
				//only cells that actually changed need a new colour - grazed cells are recoloured in graze
				color <- rgb([0, biomass * 15, 0]);
			}
		}
		
		ask cows {
			// debug error4: metabolism subtracted 1.5 energy every cycle without a lower limit, so a cow that
			//              grazed too little ended up with negative energy, which has no meaning. Now energy
			//              never drops below 0 (nothing happens yet when a cow reaches 0 - energy is only recorded)
			energy <- max(0.0, energy - 1.5);
		}
	}
	// export tracked cow locations at GPS-matched cycles only
	reflex export_validation {
		// TRACE LOG
		do trace(self, "reflex", "export_validation", true);
		if hansel_idx < length(hansel_export_cycles) and hansel_export_cycles[hansel_idx] = cycle {
			ask Hansel_sim {
				point p <- CRS_transform(location, "EPSG:31258");
				save [string(current_date, "yyyy-MM-dd HH:mm:ss"), p.x, p.y]
					to: hansel_out format: "csv" rewrite: false header: false;
			}
			hansel_idx <- hansel_idx + 1;
		}
		if susi_idx < length(susi_export_cycles) and susi_export_cycles[susi_idx] = cycle {
			ask Susi_sim {
				point p <- CRS_transform(location, "EPSG:31258");
				save [string(current_date, "yyyy-MM-dd HH:mm:ss"), p.x, p.y]
					to: susi_out format: "csv" rewrite: false header: false;
			}
			susi_idx <- susi_idx + 1;
		}
	}

	// stop after the full study period (2025-09-07 11:00)
	reflex stop when: cycle >= 8936 {
		// TRACE LOG (only written if trace_cycles covers the end of the run)
		do trace(self, "reflex", "stop", true);
		do pause;
	}	
}

species cows skills: [moving] schedules: shuffle(cows) {
	
	float daily_requirement;
	string life_stage;
	geometry action_area;
	geometry perception_area;
	//the cell that the cow grazes on at a particular time step
	grass grazed_grass ;
	//energy is gained by feeding grass, and lost by metabolism every time step (minimum 0, see update_biomass)
	float energy <- 80.0;
	int icon_size;
	rgb icon_colour;
	bool look_for_new_pasture <- false;
	grass target_pasture ;

	// travelling variables (previous_location and last_displacement are only maintained for the lead cow)
	point previous_location;   // where she was when her displacement was last measured
	float last_displacement;   // how far she moved - this is what the others can see
	bool travelling <- false;  // am I travelling with the herd right now?

	// flocking variables
	list<cows> flockmates ; 	    
	cows nearest_neighbour;	
	int avg_head;
	int avg_twds_mates ;
	float flocking_heading; // heading at the end of the flocking move
	point destination -> location + {speed * cos(heading), speed * sin(heading)}; //needed to compute headings in the flocking algorithm (replaces the deprecated built-in statement)

	// TRACE LOG: records that a block of this cow starts running (hands it on to the global trace action)
	action trace_me (string kind, string what, bool overview) {
		if cycle < trace_cycles {
			ask world { do trace(myself, kind, what, overview); }
		}
	}

//*********FLOCKING***************

	//hungry lead cows that do not already go elsewhere: they checkthe grass quality - if it's bad they go elsewhere
	reflex check_grass_quality when: self = lead_cow and look_for_new_pasture = false {
		// TRACE LOG
		do trace_me("reflex", "check_grass_quality", true);
		//I sense the grass over a wider area than the one I can walk to while grazing
		perception_area <- circle(perception_radius);
		list<grass> in_sight <- pasture_cells overlapping perception_area;
		float grass_quality <- mean(in_sight collect each.biomass) ;

		if grass_quality < grass_quality_threshold {
			write "hungry, I go elsewhere - the grass is bad here: " + grass_quality;
			look_for_new_pasture <- true;
			icon_colour <- #magenta;
			//target_pasture <- one_of (shuffle(pasture_cells) where (each.max_biomass > 3 and (location distance_to each.location) > min_travel_distance));
			//I head for the best grass I know of, as long as it is far enough away to be worth the walk
			target_pasture <- (pasture_cells where ((location distance_to each.location) > min_travel_distance)) with_max_of each.biomass;
			current_path   <- nil;
			// DEBUG
			if pause_on_travel {
				write "cycle " + cycle + ": lead cow decides to leave. Distance of the others to her (m): "
					+ ((cows - self) collect int(self distance_to each));
				ask world { do pause; }
			}
		}
	}
	
	// flocking movement
	action flock {
		// TRACE LOG
		do trace_me("action", "flock", false);
		//write "I am flocking";
		// in case all flocking parameters are zero wander randomly  	
		if (max_separate_turn = 0 and max_cohere_turn = 0 and max_align_turn = 0 ) {
			do wander amplitude: cow_amplitude; // bounds:vierkaser_polygon;
		}
		// otherwise compute the heading for the next timestep in accordance to my flockmates
		else {
			// search for flockmates
			do find_flockmates ;
			// turn my heading to flock, if there are other agents in vision 
			if (not empty (flockmates)) {
				do find_nearest_neighbour;
				// the separate behaviour only relates to the nearest neighbour (adopted from NetLogo, which reflects also Hemelrijk & Hildenbrandt 2015)
				if (distance_to (self, nearest_neighbour) < min_separation) {
					do separate;
				}
				else {
					do align;
					do cohere;
				}
				// move forward in the new direction
				do move speed: cow_speed * speed_weight_flocking; // bounds:vierkaser_polygon;
				// move back, if cow would leave the property
				if (location overlaps vierkaser_polygon) = false {
					heading <- self towards (pasture_cells closest_to(self));
					do move speed: cow_speed * speed_weight_flocking;
				}
			}
			// wander randomly, if there are no other agents in vision
			else {
				do wander amplitude: 120.0 speed: cow_speed * speed_weight_flocking;// bounds:vierkaser_polygon;
			}
		}			
	}		
	
	//flockmates are defined spatially, within a buffer of vision
	action find_flockmates {
		// TRACE LOG
		do trace_me("action", "find_flockmates", false);
        flockmates <- ((cows overlapping (circle(vision))) - self);
	}
	
	//find nearest neighbour
	action find_nearest_neighbour {
		// TRACE LOG
		do trace_me("action", "find_nearest_neighbour", false);
        nearest_neighbour <- flockmates with_min_of(distance_to (self.location, each.location)); 
	}		
	
    // separate from the nearest neighbour of flockmates
    action separate  {
    	// TRACE LOG
    	do trace_me("action", "separate (from " + nearest_neighbour.name + ")", false);
    	do turn_away (int(nearest_neighbour towards self), max_separate_turn);
    }

    //Reflex to align the boid with the other boids in the range
    action align  {
    	// TRACE LOG
    	do trace_me("action", "align", false);
    	avg_head <- avg_mate_heading () ;
        do turn_towards (avg_head, max_align_turn);
    }

    //Reflex to apply the cohesion of the boids group in the range of the agent
    action cohere  {
		// TRACE LOG
		do trace_me("action", "cohere", false);
		avg_twds_mates <- avg_heading_towards_mates ();
		do turn_towards (avg_twds_mates, max_cohere_turn); 
    }
    
    //compute the mean vector of headings of my flockmates
    int avg_mate_heading {
		// TRACE LOG
		do trace_me("function", "avg_mate_heading", false);
		list<cows> flockmates_insideShape <- flockmates where (each.destination != nil);
		float x_component <- sum (flockmates_insideShape collect (each.destination.x - each.location.x));
		float y_component <- sum (flockmates_insideShape collect (each.destination.y - each.location.y));
		//if the flockmates vector is null, return my own, current heading
		if (x_component = 0 and y_component = 0) {
			return int(heading);
		}
		//else compute average heading of vector  		
		else {
			// note: 0-heading direction in GAMA is east instead of north! -> thus +90
			return int(-1 * atan2 (x_component, y_component) + 90);
		}	
    }  

    //compute the mean direction from me towards flockmates	    
    int avg_heading_towards_mates {
    	// TRACE LOG
    	do trace_me("function", "avg_heading_towards_mates", false);
    	float x_component <- mean (flockmates collect (cos (towards(self.location, each.location))));
    	float y_component <- mean (flockmates collect (sin (towards(self.location, each.location))));
    	//if the flockmates vector is null, return my own, current heading
    	if (x_component = 0 and y_component = 0) {
    		return int(heading);
    	}
		//else compute average direction towards flockmates
    	else {
    		// note: 0-heading direction in GAMA is east instead of north! -> thus +90
    		return int(-1 * atan2 (x_component, y_component) + 90);	
    	}
    } 	    
    
    // cohere
    action turn_towards (int new_heading, int max_turn) {
		// TRACE LOG
		do trace_me("action", "turn_towards (new_heading=" + new_heading + ", max_turn=" + max_turn + ")", false);
		int subtract_headings <- int(new_heading - heading);
		if (subtract_headings < -180) {subtract_headings <- subtract_headings + 360;}
		if (subtract_headings > 180) {subtract_headings <- subtract_headings - 360;}
    	do turn_at_most ((subtract_headings), max_turn);
    }

	// separate
    action turn_away (int new_heading, int max_turn) {
		// TRACE LOG
		do trace_me("action", "turn_away (new_heading=" + new_heading + ", max_turn=" + max_turn + ")", false);
		int subtract_headings <- int(heading - new_heading);
		if (subtract_headings < -180) {subtract_headings <- subtract_headings + 360;}
		if (subtract_headings > 180) {subtract_headings <- subtract_headings - 360;}
    	do turn_at_most ((-1 * subtract_headings), max_turn);
    }
    
    // align
    action turn_at_most (int turn, int max_turn) {
    	// TRACE LOG
    	do trace_me("action", "turn_at_most (turn=" + turn + ", max_turn=" + max_turn + ")", false);
    	if abs (turn) > max_turn {
    		if turn > 0 {
    			//right turn
    			heading <- heading + max_turn;
    		}
    		else {
    			//left turn
    			heading <- heading - max_turn;
    		}
    	}
    	else {
    		heading <- heading + turn;
    	} 
    }
    
	//each cow looks for the spot within reach that has the highest biomass
	action choose_grass {
		// TRACE LOG
		do trace_me("action", "choose_grass", false);
		float reach <- cow_speed * step * speed_weight_grazing;
		action_area <- circle(reach);
		//only cells the cow can reach in this cycle: the cell centre lies within her reach
		grazed_grass <- ((pasture_cells overlapping action_area) where (location distance_to each.location <= reach)) with_max_of each.biomass;
	}

	//after flocking each cow moves to the spot it has chosen
	action move_to_grass {
		// TRACE LOG
		do trace_me("action", "move_to_grass", false);
		//write "I am looking for grass";
		flocking_heading <- heading;
		if (pasture_polygon covers location) and grazed_grass != nil {
			//I am on the grass: I walk to the best bite within reach and stop there
			do move heading: (self towards grazed_grass) speed: min(cow_speed * speed_weight_grazing, (location distance_to grazed_grass.location) / step) bounds:pasture_polygon;
			heading <- flocking_heading;
		}
		else {
			//I am in the shrubs, or there is nothing to eat within reach: I head back to the nearest grass
			do move heading: self towards (pasture_cells closest_to(self)) speed: cow_speed * speed_weight_grazing ;
		}
	}	
	
	action goto_other_pasture {
		// TRACE LOG (also in the console: the lead cow travelling is a key event)
		do trace_me("action", "goto_other_pasture", true);
		//eat whatever is here
		grazed_grass <- first(pasture_cells overlapping self);
		do goto target: target_pasture speed: cow_speed * speed_weight_leading on: pasture_cells ;
		if self distance_to target_pasture < 20 {
			write "arrived at new pasture";
			look_for_new_pasture <- false;
			icon_colour <- #red;
			// DEBUG
			if pause_on_travel {
				write "cycle " + cycle + ": lead cow arrived. Distance of the others to her (m): "
					+ ((cows - self) collect int(self distance_to each));
				ask world { do pause; }
			}
		}
	}    
    
	// travel with the herd: fires when the lead cow is seen moving fast
	action travel {
		// TRACE LOG
		do trace_me("action", "travel", false);
		if lead_cow.last_displacement > travel_threshold {
			travelling <- true;
			// follow her along the grass: the followers see where she is, not where she is going
			do goto target: lead_cow on: pasture_cells speed: cow_speed * speed_weight_travelling;
		}
		else {
			travelling <- false;
		}
	}

    action following {
    	// TRACE LOG
    	do trace_me("action", "following", false);
    	do move heading: self towards lead_cow speed: cow_speed * speed_weight_following;
    }
    
   	//graze grass within reach
	action graze {
		// TRACE LOG
		do trace_me("action", "graze", false);
		// if there is grass on the spot
		if grazed_grass != nil {
			ask grazed_grass {
				// that has some minimum biomass
				if biomass >= 1 {
					biomass <- biomass - 1 ;
					//enjoy the food
					ask myself {energy <- energy + 2;}
					//recolour the cell
					color <- rgb([0, biomass * 15, 0]);
				}
			}
		}
	}
		
	//viz of cow agent	
	aspect base {
		// travelling cows turn blue, so the wave through the herd is visible
		if travelling {
			draw circle (5) color: #blue size: icon_size;
		}
		else {
			draw circle (5) color: icon_colour size: icon_size;
		}
	}
	aspect cow_3d{
		pair<float,point> r0 <-  -90::{1,0,0};	
		pair<float,point> pitch <-  0 ::{1,0,0}; 
		pair<float,point> roll <- 0 ::{0,1,0}; 
		pair<float,point> yaw <- heading::{0,0,1}; 
		draw obj_file("../includes/cow.obj", rotation_composition(r0,pitch,roll,yaw)) at: location + {0,0,3} size: icon_size color: icon_colour; //		
		//draw string(energy with_precision 2) size: 3 color: #black ;
		
	}	
 	aspect action_neighbourhood {
		draw action_area color: #orange ; 
 	}	
 	aspect vision_neighbourhood {
		draw perception_area color: #yellow ;
 	}

	//viz of the lead cow's navigation: where it wants to go, and how
	aspect navigation {
		if self = lead_cow and look_for_new_pasture and target_pasture != nil {
			// fixed-size marker at the target cell, hollow so the grass stays visible
			draw triangle(15) at: target_pasture.location border: #magenta width:1;
			// the actual route computed by goto ... on: pasture_cells
			if current_path != nil {
				draw current_path.shape color: #magenta width: 3;
			}
		}
	}
}


/* Build a Cellular Automaton (CA) labelled "pasture"
 * with the dimensions of 5 by 5 meters */
grid grass cell_width:5#m cell_height:5#m neighbors:8 {
	float biomass;
	float max_biomass;
	string landcover;
}

//run the simulation
experiment Simulation type:gui {
    parameter "Flocking weight" var: speed_weight_flocking <- 0.35 min: 0.0 max: 1.0;
    parameter "Grazing weight" var: speed_weight_grazing <- 0.55 min: 0.0 max: 1.0;
    parameter "Following weight" var: speed_weight_following <- 0.10 min: 0.0 max: 1.0;
    parameter "Leading weight" var: speed_weight_leading <- 3.0 min: 0.0 max: 10.0;
    parameter "Travelling weight" var: speed_weight_travelling <- 3.0 min: 0.0 max: 10.0;
    parameter "DEBUG: pause when the lead cow leaves / arrives" var: pause_on_travel;

	output {
		// DEBUG: with pause_on_travel the map is redrawn every cycle, so you can step through a trip
		display VierkaserMap type: opengl refresh: pause_on_travel or every(10#cycles) {

			grid grass ;

			//grid my_dem elevation: true triangulation: true;
			species cows aspect:base refresh:true ;
			species cows aspect: navigation refresh: true ;
			// VERIFICATION debug error2: reach circle of each cow, drawn where she chose her grass - the chosen cell must lie inside it
			// (transparency 0.8: the grass under the reach circles stays visible)
			species cows aspect:action_neighbourhood refresh:true transparency:0.8;
//			species cows aspect:vision_neighbourhood refresh:true transparency:0.5;	
		}
			
		display charts type:2d refresh: every(10#cycles) {
			chart "energy" type: series position:{0,0} size:{1,0.5} {
				data "lead cow" value: lead_cow.energy color: #magenta thickness: 4.0 marker: false;
				data "cow1" value:  cows[0].energy color:#lightblue marker_shape: marker_empty ;
				data "cow2" value:  cows[1].energy color:#lightseagreen marker_shape: marker_empty ;
				data "cow3" value:  cows[2].energy color:#aquamarine marker_shape: marker_empty ;
				data "cow4" value:  cows[3].energy color:#skyblue marker_shape: marker_empty;
				data "cow5" value:  cows[4].energy color:#lightgreen marker_shape: marker_empty;
				data "cow6" value:  cows[5].energy color:#cornflowerblue marker_shape: marker_empty;
				data "cow7" value:  cows[6].energy color:#silver marker_shape: marker_empty;
				data "cow8" value:  cows[7].energy color:#plum marker_shape: marker_empty;
				data "cow9" value:  cows[8].energy color:#violet marker_shape: marker_empty;
				data "cow10" value:  cows[9].energy color:#burlywood marker_shape: marker_empty;
			}			
			chart "mean biomass per pasture" type: series position:{0,0.5} size:{1,0.5} {
				data "Hirschanger"     value: mean(cells_hirschanger collect each.biomass) color: #orange;
				data "lower pasture"   value: mean(cells_lower collect each.biomass) color: #dodgerblue;
				data "Schoenkopf 2023" value: mean(cells_schoenkopf collect each.biomass) color: #red;
				data "other cutbacks"  value: mean(cells_cutbacks collect each.biomass) color: #green;
			}
			//OBSERVATION widget: clock
			overlay 
				position: {5 #px, 5 #px} size: {220 #px, 40 #px}
           		background: #black transparency: 0.4 {
       				draw string(starting_date + step*cycle, "dd MMM yyyy") at: {12 #px, 26 #px}
           			color: #white font: font("Helvetica", 14, #bold);
           		}
		}

		// VERIFICATION debug error2: how many cows missed their chosen grass cell, every cycle, in total and per cause
		display verification type:2d refresh: every(1#cycles) {
			chart "cows that missed their chosen grass cell" type: series position:{0,0} size:{1,0.5} {
				data "total" value: missed_grass color: #black marker: false;
				data "in the shrubs" value: missed_shrubs color: #orange marker: false;
				data "edge cell (centre outside pasture)" value: missed_edge color: #blue marker: false;
				data "other (e.g. path left the pasture)" value: missed_other color: #red marker: false;
			}
			// VERIFICATION debug error3: travel events only - a blue point per cycle with travelling followers
			// (correct model: always at 9), and a magenta marker at 10 for every cycle the lead cow travels
			chart "travel events" type: scatter position:{0,0.5} size:{1,0.5} x_label: "cycle" y_label: "travelling followers" {
				data "followers travelling" value: traveller_points color: #blue marker_shape: marker_circle line_visible: false accumulate_values: false;
				data "lead cow travelling (row at 10)" value: lead_points color: #magenta marker_shape: marker_down_triangle line_visible: false accumulate_values: false;
			}
		}

		// VERIFICATION debug error2: current number of cows that missed their chosen grass cell
		monitor "cows that missed their grass cell" value: missed_grass;
		// VERIFICATION debug error3: cycles so far in which only part of the followers travelled (correct model: 0)
		monitor "split travel decisions (cycles)" value: split_cycles;

		//monitor "Days" value: days;
		//monitor "Hour" value: counter;		
	}
}

