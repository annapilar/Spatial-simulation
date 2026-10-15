/**
* Name: NewModel
* Based on the internal empty template. 
* Author: annap
* Tags: 
*/


model NewModel

global{ 
int my_variable <-1;
float my_speed <-3.0;
init{
create my_agents number:5 {
speed <-5.0 ;
}
}
}

species my_agents skills:[moving]{
reflex move{
do wander;
}
aspect default{
draw triangle(2) color: #blue ;
}
}

experiment main_experiment type:gui{
parameter "my Variable" var: my_variable;
parameter "my Speed" var: my_speed;
output {
display map {
species my_agents aspect:default;
}
}
}