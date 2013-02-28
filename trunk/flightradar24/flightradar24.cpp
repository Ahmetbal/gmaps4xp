

/*
	DrawAircraft example
	Written by Sandy Barbour - 11/02/2003

	Modified by Sandy Barbour - 07/12/2009
	Combined source files and fixed a few bugs.
	
	This examples Draws 7 AI aircraft around the user aicraft.
	It also uses an Aircraft class to simplify things.

	This is a very simple example intended to show how to use the AI datarefs.
	In a production plugin Aircraft Aquisition and Release would have to be handled.
	Also loading the approriate aircraft model would also have to be done.
	This example may be updated to do that at a later time.

	NOTE
	Set the aircraft number to 8 in the XPlane Aircraft & Situations settings screen.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <curl/curl.h>
#include <curl/easy.h>
#include "XPLMPlanes.h"
#include "XPLMDataAccess.h"
#include "XPLMProcessing.h"
#include "XPLMGraphics.h"

#ifdef __arch64__
#define CURL_SIZEOF_LONG 8
#endif 

#define FREE			0
#define	USED			1
#define FALSE			0
#define	TRUE			1
#define CODE_LENGHT		128
#define MAX_AIR_CRAFT_NUM 	19
#define MAX_AIR_CRAFT_DIST	50 // Km

XPLMDataRef	gPlaneLat;
XPLMDataRef 	gPlaneLon;
XPLMDataRef 	gPlaneEl;
XPLMDataRef	gPlaneX;
XPLMDataRef	gPlaneY;
XPLMDataRef	gPlaneZ;
XPLMDataRef	gPlaneTheta;
XPLMDataRef	gPlanePhi;
XPLMDataRef	gPlanePsi;
XPLMDataRef	gOverRidePlanePosition;
XPLMDataRef	gAGL;

struct MemoryStruct {
        char *memory;
        size_t size;
};


void *getDataFromFlightRadar24(void *arg);

// -------------------------------------------------------------------------------------------------- //

class Aircraft {
	private:
		XPLMDataRef	dr_plane_x;
		XPLMDataRef	dr_plane_y;
		XPLMDataRef	dr_plane_z;
		XPLMDataRef	dr_plane_the;
		XPLMDataRef	dr_plane_phi;
		XPLMDataRef	dr_plane_psi;
		XPLMDataRef	dr_plane_gear_deploy;
		XPLMDataRef	dr_plane_throttle;
	public:
		float		plane_x;
		float		plane_y;
		float		plane_z;
		float		plane_the;
		float		plane_phi;
		float		plane_psi;
		float		plane_gear_deploy[5];
		float		plane_throttle[8];
		Aircraft(int AircraftNo);
		void GetAircraftData(void);
		void SetAircraftData(void);
};

Aircraft::Aircraft(int AircraftNo){
	char	x_str[80];
	char	y_str[80];
	char	z_str[80];
	char	the_str[80];
	char	phi_str[80];
	char	psi_str[80];
	char	gear_deploy_str[80];
	char	throttle_str[80];

	strcpy(x_str, 		"sim/multiplayer/position/planeX_x");
	strcpy(y_str,		"sim/multiplayer/position/planeX_y");
	strcpy(z_str,		"sim/multiplayer/position/planeX_z");
	strcpy(the_str,		"sim/multiplayer/position/planeX_the");
	strcpy(phi_str,		"sim/multiplayer/position/planeX_phi");
	strcpy(psi_str,		"sim/multiplayer/position/planeX_psi");
	strcpy(gear_deploy_str,	"sim/multiplayer/position/planeX_gear_deploy");
	strcpy(throttle_str, 	"sim/multiplayer/position/planeX_throttle");

	char cTemp = (AircraftNo + 0x30);
	x_str[30]		=	cTemp;
	y_str[30]		=	cTemp;
	z_str[30]		=	cTemp;
	the_str[30]		=	cTemp;
	phi_str[30]		=	cTemp;
	psi_str[30]		=	cTemp;
	gear_deploy_str[30] 	=	cTemp;
	throttle_str[30]	=	cTemp;

	dr_plane_x		= XPLMFindDataRef(x_str);
	dr_plane_y		= XPLMFindDataRef(y_str);
	dr_plane_z		= XPLMFindDataRef(z_str);
	dr_plane_the		= XPLMFindDataRef(the_str);
	dr_plane_phi		= XPLMFindDataRef(phi_str);
	dr_plane_psi		= XPLMFindDataRef(psi_str);
	dr_plane_gear_deploy	= XPLMFindDataRef(gear_deploy_str);
	dr_plane_throttle	= XPLMFindDataRef(throttle_str);
}

void Aircraft::GetAircraftData(void){
	plane_x = XPLMGetDataf(dr_plane_x);
	plane_y = XPLMGetDataf(dr_plane_y);
	plane_z = XPLMGetDataf(dr_plane_z);
	plane_the = XPLMGetDataf(dr_plane_the);
	plane_phi = XPLMGetDataf(dr_plane_phi);
	plane_psi = XPLMGetDataf(dr_plane_psi);
	XPLMGetDatavf(dr_plane_gear_deploy, plane_gear_deploy, 0, 5);
	XPLMGetDatavf(dr_plane_throttle, plane_throttle, 0, 8);
}

void Aircraft::SetAircraftData(void){
	XPLMSetDataf(dr_plane_x, plane_x);
	XPLMSetDataf(dr_plane_y, plane_y);
	XPLMSetDataf(dr_plane_z, plane_z);
	XPLMSetDataf(dr_plane_the, plane_the);
	XPLMSetDataf(dr_plane_phi, plane_phi);
	XPLMSetDataf(dr_plane_psi, plane_psi);
	XPLMSetDatavf(dr_plane_gear_deploy, plane_gear_deploy, 0, 5);
	XPLMSetDatavf(dr_plane_throttle, plane_throttle, 0, 8);
}


struct AircraftData{
	double		lat;
	double		lon;
	double		course;
	double		ele;
	double		speed;
	double		vspeed;
	int		status;
	char		*name;
	int		time;
	Aircraft	*obj;

};

struct AirplaneData{
	double		x;
	double		y;
	double		z;
	double		theta;
	double		phi;
	double		psi;
        double   	lat; 
        double   	lon;
        double   	ele;
        double   	alt;
	double		elapsed;

};


struct AircraftData *AircraftDataArray;
struct AirplaneData myPlaneInfo;

// -------------------------------------------------------------------------------------------------- //


// Aircraft Aircraft1(1);

static float	MyFlightLoopCallback0(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon);    

static float	MyFlightLoopCallback1(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon);    

static float	MyFlightLoopCallback(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon);    


PLUGIN_API int XPluginStart(	char *		outName,
				char *		outSig,
				char *		outDesc){

	strcpy(outName, "Flightradar24");
	strcpy(outSig, "xplanesdk.examples.drawaircraft");
	strcpy(outDesc, "A plugin that draws aircraft.");

	/* Prefetch the sim variables we will use. */
        gPlaneLat		= XPLMFindDataRef("sim/flightmodel/position/latitude");
        gPlaneLon		= XPLMFindDataRef("sim/flightmodel/position/longitude");
        gPlaneEl		= XPLMFindDataRef("sim/flightmodel/position/elevation");
	gPlaneX			= XPLMFindDataRef("sim/flightmodel/position/local_x");
	gPlaneY			= XPLMFindDataRef("sim/flightmodel/position/local_y");
	gPlaneZ			= XPLMFindDataRef("sim/flightmodel/position/local_z");
	gPlaneTheta		= XPLMFindDataRef("sim/flightmodel/position/theta");
	gPlanePhi		= XPLMFindDataRef("sim/flightmodel/position/phi");
	gPlanePsi		= XPLMFindDataRef("sim/flightmodel/position/psi");
	gOverRidePlanePosition 	= XPLMFindDataRef("sim/operation/override/override_planepath");
	gAGL 			= XPLMFindDataRef("sim/flightmodel/position/y_agl");

	XPLMRegisterFlightLoopCallback(		
			MyFlightLoopCallback,	/* Callback */
			1.0,			/* Interval */
			NULL);			/* refcon not used. */


	XPLMRegisterFlightLoopCallback(		
			MyFlightLoopCallback0,	/* Callback */
			1.0,			/* Interval */
			NULL);			/* refcon not used. */



	XPLMRegisterFlightLoopCallback(		
			MyFlightLoopCallback1,	/* Callback */
			1.0,			/* Interval */
			NULL);			/* refcon not used. */


	AircraftDataArray = (struct AircraftData *)malloc(sizeof( struct AircraftData ) * MAX_AIR_CRAFT_NUM );
	if ( AircraftDataArray == NULL ) return 0;
	for ( int i = 0; i < MAX_AIR_CRAFT_NUM; i++ ) {
		AircraftDataArray[i].status 	= FREE;
		AircraftDataArray[i].name	= (char *)malloc(sizeof(char) * CODE_LENGHT); bzero(AircraftDataArray[i].name, CODE_LENGHT - 1);
		AircraftDataArray[i].obj	= NULL;
	}

	myPlaneInfo.x		= 0;
	myPlaneInfo.y		= 0;
	myPlaneInfo.z		= 0;
	myPlaneInfo.theta	= 0;
	myPlaneInfo.phi		= 0;
	myPlaneInfo.psi		= 0;
	myPlaneInfo.lat     	= 0;
	myPlaneInfo.lon     	= 0;
	myPlaneInfo.ele      	= 0;
	myPlaneInfo.alt		= 0;
	myPlaneInfo.elapsed 	= 0;	

	return 1;
}


PLUGIN_API void	XPluginStop(void){
	XPLMUnregisterFlightLoopCallback(MyFlightLoopCallback0, NULL);
	XPLMUnregisterFlightLoopCallback(MyFlightLoopCallback1, NULL);
	XPLMUnregisterFlightLoopCallback(MyFlightLoopCallback, NULL);
}

PLUGIN_API void XPluginDisable(void){}
PLUGIN_API int XPluginEnable(void){ return 1; }

PLUGIN_API void XPluginReceiveMessage(	XPLMPluginID	inFromWho,
					int		inMessage,
					void 		*inParam){}

// -------------------------------------------------------------------------------------------------- //



static void *myrealloc(void *ptr, size_t size){
        if(ptr) return realloc(ptr, size);
        else    return malloc(size);
}


static size_t WriteMemoryCallback(void *ptr, size_t size, size_t nmemb, void *data){
        size_t realsize                 = size * nmemb;
        struct MemoryStruct *mem        = (struct MemoryStruct *)data;

        mem->memory = (char *)myrealloc(mem->memory, mem->size + realsize + 1);
        if (mem->memory) {
                memcpy(&(mem->memory[mem->size]), ptr, realsize);
                mem->size += realsize;
                mem->memory[mem->size] = 0;
        }
        return realsize;
}


float distAprox(float lon1, float lat1, float lon2, float lat2) {
        float  R       = 6372.795477598;
        float  dLat    = 0.0;
        float  dLon    = 0.0;
        float  a       = 0.0;
        float  c       = 0.0;

        dLat = (lat2-lat1) * ( M_PI / 180.0 );
        dLon = (lon2-lon1) * ( M_PI / 180.0 );

        a       = sin(dLat/2.0) * sin(dLat/2.0) + cos(lat1 * ( M_PI / 180.0 )) * cos(lat2 * ( M_PI / 180.0 )) * sin(dLon/2.0) * sin(dLon/2.0);
        c       = 2.0 * atan2(sqrt(a), sqrt(1-a));

        return( R * c);
}

float	MyFlightLoopCallback0(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon){

	// Disable AI for each aircraft.
	for (int AircraftIndex = 1; AircraftIndex < MAX_AIR_CRAFT_NUM ; AircraftIndex++) XPLMDisableAIForPlane(AircraftIndex);    


	return 0;
}

float	MyFlightLoopCallback1(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon){

	pthread_t thread;
	pthread_create(&thread, NULL, getDataFromFlightRadar24, (void *)NULL);

	return 30.0;
}




float	MyFlightLoopCallback(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon){

	int	GearState;
	double	elapsed	= 0;
	double	outX, outY, outZ;
	double	tmp;	
	Aircraft *aircraft = NULL;

	// Get User Aircraft data
	myPlaneInfo.x		= XPLMGetDataf(gPlaneX);
	myPlaneInfo.y		= XPLMGetDataf(gPlaneY);
	myPlaneInfo.z		= XPLMGetDataf(gPlaneZ);
	myPlaneInfo.theta	= XPLMGetDataf(gPlaneTheta);
	myPlaneInfo.phi		= XPLMGetDataf(gPlanePhi);
	myPlaneInfo.psi		= XPLMGetDataf(gPlanePsi);
	myPlaneInfo.lat     	= XPLMGetDataf(gPlaneLat);
	myPlaneInfo.lon     	= XPLMGetDataf(gPlaneLon);
	myPlaneInfo.ele      	= XPLMGetDataf(gPlaneEl);
	myPlaneInfo.alt		= XPLMGetDataf(gAGL);
	elapsed			= XPLMGetElapsedTime();
	elapsed			= elapsed - myPlaneInfo.elapsed;
	myPlaneInfo.elapsed 	= XPLMGetElapsedTime();

	for ( int j = 0; j < MAX_AIR_CRAFT_NUM; j++) {
		if ( AircraftDataArray[j].status == FREE ) continue;

		aircraft = AircraftDataArray[j].obj;

		if ( AircraftDataArray[j].ele > 200 ) XPLMWorldToLocal( AircraftDataArray[j].lat, AircraftDataArray[j].lon, AircraftDataArray[j].ele, &outX, &outY, &outZ );
		else {
			outX = aircraft->plane_x;
			outY = aircraft->plane_y;
			outZ = aircraft->plane_z;
		}


		if ( ( (int)aircraft->plane_x == (int)outX ) && ( (int)aircraft->plane_y == (int)outY ) && ( (int)aircraft->plane_z == (int)outZ ) ){
			outX = outX + cos( (float)(( (int)AircraftDataArray[j].course - 90 ) % 360 ) * M_PI / 180.0  ) * ( AircraftDataArray[j].speed * elapsed);
			outZ = outZ + sin( (float)(( (int)AircraftDataArray[j].course - 90 ) % 360 ) * M_PI / 180.0  ) * ( AircraftDataArray[j].speed * elapsed);
			outY = outY + ( AircraftDataArray[j].vspeed * elapsed );

			XPLMLocalToWorld(outX, outY, outZ, &(AircraftDataArray[j].lat), &(AircraftDataArray[j].lon), &(AircraftDataArray[j].ele));
		}

		aircraft->plane_x 	= outX;
		aircraft->plane_y 	= outY;
		aircraft->plane_z 	= outZ;
		aircraft->plane_the	= 0.0;
		aircraft->plane_phi	= 0.0;
		aircraft->plane_psi	= AircraftDataArray[j].course;

	
		if (AircraftDataArray[j].ele > 200 ) 	GearState = 0;
		else					GearState = 1;
		for (int Gear=0; Gear<5; Gear++) aircraft->plane_gear_deploy[Gear]	= GearState;
		for (int Thro=0; Thro<8; Thro++) aircraft->plane_throttle[Thro]		= 1;
		

		aircraft->SetAircraftData();

	}

	return 0.1;
}


// ------------------------------------------------------------------------------- //

void *getDataFromFlightRadar24(void *arg){
	struct  	MemoryStruct chunk;
	CURL    	*curl_handle;
	CURLcode 	res;
	char		*token	= NULL;
	int		i 	= 0;
	int		j 	= 0;
        float   	lat     = 0; 
        float   	lon     = 0;
        float   	el      = 0;
	float		dist	= 0;

	char		*plane_code	= NULL;
	float		plane_lat	= 0;
	float		plane_lon	= 0;
	float		plane_ele	= 0;
	float		plane_course	= 0;
	float		plane_speed	= 0;
	int		plane_time	= 0;

	if ( myPlaneInfo.elapsed == 0 ) return (void*)(1);
	chunk.memory    = NULL;
        chunk.size      = 0;
	curl_handle	= curl_easy_init();

	// http://db.flightradar24.com/zones/full_all.js
	curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 		0);
	curl_easy_setopt(curl_handle, CURLOPT_URL,		"http://db.flightradar24.com/zones/italy_all.js");
	curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION,    WriteMemoryCallback);     
	curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA,        (void *)&chunk);
	printf("Downloading Flightradar24 information ...\n");
	res = curl_easy_perform(curl_handle);
        if (res != CURLE_OK) {
                fprintf(stderr, "Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
                return (void*)(1);
        }

// 0 pd_callback({"eecfc7":["400068"
// 1 26.3076
// 2 49.8746
// 3 241
// 4 1825
// 5 200
	plane_code = (char *)malloc(sizeof(char ) *  CODE_LENGHT);

	for ( token = strtok(chunk.memory, ","), i = 0, bzero(plane_code, CODE_LENGHT - 1); token != NULL; token = strtok(NULL, ",") ){
		if 	( i == 0  ) plane_code 		= strcpy(plane_code, token);
		else if	( i == 1  ) plane_lat 		= atof(token);
		else if ( i == 2  ) plane_lon 		= atof(token);
		else if ( i == 3  ) plane_course	= atof(token);
		else if ( i == 4  ) plane_ele		= atof(token) * 0.3048; 	// Convert feets to meters
		else if ( i == 5  ) plane_speed		= atof(token) * 0.514444444;	// knots to metes/sec;
		else if ( i == 10 ) plane_time		= atoi(token);

		if ( i >= 17 ){
			dist = distAprox(myPlaneInfo.lon, myPlaneInfo.lat, plane_lon, plane_lat);
			for ( j = 0; j < MAX_AIR_CRAFT_NUM; j++) {
				if ( ! strcmp(AircraftDataArray[j].name, plane_code) && ( AircraftDataArray[j].status == USED )) break;
			}

			if ( dist <= MAX_AIR_CRAFT_DIST ) {

				if ( j != MAX_AIR_CRAFT_NUM ){

					AircraftDataArray[j].lat	= plane_lat;
					AircraftDataArray[j].lon	= plane_lon;
					AircraftDataArray[j].course	= plane_course;
					AircraftDataArray[j].vspeed	= ( plane_ele - AircraftDataArray[j].ele ) / ( plane_time - AircraftDataArray[j].time );
					AircraftDataArray[j].ele	= plane_ele;
					AircraftDataArray[j].speed	= plane_speed;
					AircraftDataArray[j].time	= plane_time;
					AircraftDataArray[j].status	= USED;
					printf("Old Aircraft %d: Coord: %f / %f, Course: %d, Speed: %f, Alt: %f, Dist: %f\n", j, 	AircraftDataArray[j].lat, 	AircraftDataArray[j].lon, (int)AircraftDataArray[j].course,
																	AircraftDataArray[j].speed, 	AircraftDataArray[j].ele, dist );
	
					
				} else {
					for ( j = 0; j < MAX_AIR_CRAFT_NUM; j++) { if ( AircraftDataArray[j].status == FREE ) break; }
					if ( j == MAX_AIR_CRAFT_NUM ) return (void*)(1);
					
					AircraftDataArray[j].lat	= plane_lat;
					AircraftDataArray[j].lon	= plane_lon;
					AircraftDataArray[j].course	= plane_course;
					AircraftDataArray[j].ele	= plane_ele;
					AircraftDataArray[j].speed	= plane_speed;
					AircraftDataArray[j].vspeed	= 0.0;
					AircraftDataArray[j].time	= plane_time;
					AircraftDataArray[j].status	= USED;
					if ( AircraftDataArray[j].obj == NULL )	AircraftDataArray[j].obj = new Aircraft(j);
					strcpy(AircraftDataArray[j].name, plane_code);
					printf("New Aircraft %d: Coord: %f / %f, Course: %d, Speed: %f, Alt: %f, Dist: %f\n", j, 	AircraftDataArray[j].lat, 	AircraftDataArray[j].lon, (int)AircraftDataArray[j].course,
																	AircraftDataArray[j].speed, 	AircraftDataArray[j].ele, dist );
				
				}
			} else {
				if ( j != MAX_AIR_CRAFT_NUM ) AircraftDataArray[j].status = FREE;
			}

			i = 0; bzero(plane_code, CODE_LENGHT - 1);
		} else i++;

	}
        return (void*)(1);
}


