#ifndef _CORE_H
#define _CORE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <netdb.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include "XPLMDisplay.h"
#include "XPLMGraphics.h"
#include "XPLMDataAccess.h"
#include "XPLMMenus.h"

#define RUN			0
#define STOP			1
#define MAX_CLIENTS_NUM 	50
#define AVAHI_SERVICE_NAME 	"air_nav_fsx"
#define AVAHI_SERVICE_TYPE 	"_air_nav_fsx._tcp"
#define FREQ_HZ			5

// http://www.xsquawkbox.net/xpsdk/docs/DataRefs.html
/* Timestamp, usually a double representing seconds elapsed since 1.1.1970 (unix time) */

#define JSON_GPS_TIMESTAMP 	"ts"	// function time

/* Ground and Air speeds in meters per second */

#define JSON_GROUNDSPEED	"gs" 	// sim/flightmodel/position/groundspeed
#define JSON_AIRSPEED 		"as" 	// sim/flightmodel/position/indicated_airspeed

/* Degrees, true north oriented */

#define JSON_COURSE 		"tc" 	// sim/flightmodel/position/psi

/* Altitude in meters */

#define JSON_ALTITUDE 		"alt" 	// sim/flightmodel/position/elevation
#define JSON_PRESSURE_ALTITUDE 	"palt"	// sim/flightmodel/misc/h_ind

/* GPS accuracy in meters */

#define JSON_VERTICAL_ACC 	"vacc"	// 
#define JSON_HORIZONTAL_ACC 	"hacc"	//

/* GPS Coordinates WGS84 */

#define JSON_LATITUDE		"lat"	// sim/flightmodel/position/latitude
#define JSON_LONGITUDE		"lon"	// sim/flightmodel/position/longitude 

/* Attitude angles, degrees */

#define JSON_YAW		"yaw"	// sim/flightmodel/position/beta
#define JSON_PITCH		"pitch"	// sim/flightmodel/position/theta
#define JSON_ROLL		"roll"	// sim/flightmodel/position/phi

/* Airplane acceleration in G's */

#define JSON_SLIP		"slip"

#define JSON_ACC_X		"acc_x"	// sim/flightmodel/position/local_ax
#define JSON_ACC_Y		"acc_y" // sim/flightmodel/position/local_ay
#define JSON_ACC_Z		"acc_z" // sim/flightmodel/position/local_az


#define PORT            8080

void *webServer(void *);
void *process(void *);


#endif
