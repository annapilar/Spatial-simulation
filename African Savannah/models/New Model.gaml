/**
* Name: AfricanSavannah
* Based on the internal empty template. 
* Author: Anna Pilar
* Tags: 
*/


model AfricanSavannah

// Global section
global{ 
int my_variable <-1;
float my_speed <-3.0;
init{
create lions number:20 {
speed <-5.0 ;
}
create zebras number:20 {
speed <-5.0 ;
}
}
}

// agents section
species lions skills:[moving]{
reflex move{
do wander;
}

reflex eat {
        list<zebras> nearby_zebras <- zebras where (each distance_to self <= 5.0);

        if !empty(nearby_zebras) {
            ask one_of(nearby_zebras) {
                do die;
            }
        }
    }

aspect default{
draw circle(3) color: #orange ;
}
}

species zebras skills:[moving]{
reflex move{
do wander;
}
aspect default{
draw triangle(2) color: #grey ;
}
}

// CA section
grid grassland {
	
	float biomass <- rnd(10.0);
	
	reflex grow {
		biomass <- biomass + 0.1;
	}
	
	aspect default {
		 draw shape color: rgb(0, 50 + int(biomass * 20), 0);
	}
}

// simulation setion
experiment main_experiment type:gui{
parameter "my Variable" var: my_variable;
parameter "my Speed" var: my_speed;
output {
display map {
species grassland aspect:default;
species lions aspect:default;
species zebras aspect:default;
}
}
}