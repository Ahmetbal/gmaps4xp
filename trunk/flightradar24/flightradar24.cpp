

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
#include <curl/curl.h>
#include <curl/easy.h>
#include "XPLMPlanes.h"
#include "XPLMDataAccess.h"
#include "XPLMProcessing.h"
#ifdef __arch64__
#define CURL_SIZEOF_LONG 8
#endif 
const	double	kMaxPlaneDistance = 5280.0 / 3.2 * 10.0;
const	double	kFullPlaneDist = 5280.0 / 3.2 * 3.0;

int getDataFromFlightRadar24(void);

// Aircraft class, allows access to an AI aircraft

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

	strcpy(x_str, "sim/multiplayer/position/planeX_x");
	strcpy(y_str,	"sim/multiplayer/position/planeX_y");
	strcpy(z_str,	"sim/multiplayer/position/planeX_z");
	strcpy(the_str,	"sim/multiplayer/position/planeX_the");
	strcpy(phi_str,	"sim/multiplayer/position/planeX_phi");
	strcpy(psi_str,	"sim/multiplayer/position/planeX_psi");
	strcpy(gear_deploy_str,	"sim/multiplayer/position/planeX_gear_deploy");
	strcpy(throttle_str, "sim/multiplayer/position/planeX_throttle");

	char cTemp = (AircraftNo + 0x30);
	x_str[30]			=	cTemp;
	y_str[30]			=	cTemp;
	z_str[30]			=	cTemp;
	the_str[30]			=	cTemp;
	phi_str[30]			=	cTemp;
	psi_str[30]			=	cTemp;
	gear_deploy_str[30] =	cTemp;
	throttle_str[30]	=	cTemp;

	dr_plane_x				= XPLMFindDataRef(x_str);
	dr_plane_y				= XPLMFindDataRef(y_str);
	dr_plane_z				= XPLMFindDataRef(z_str);
	dr_plane_the			= XPLMFindDataRef(the_str);
	dr_plane_phi			= XPLMFindDataRef(phi_str);
	dr_plane_psi			= XPLMFindDataRef(psi_str);
	dr_plane_gear_deploy	= XPLMFindDataRef(gear_deploy_str);
	dr_plane_throttle		= XPLMFindDataRef(throttle_str);
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

// Datarefs for the User Aircraft
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


// Create 7 instances of the Aircraft class.

Aircraft Aircraft1(1);
Aircraft Aircraft2(2);
Aircraft Aircraft3(3);
Aircraft Aircraft4(4);
Aircraft Aircraft5(5);
Aircraft Aircraft6(6);
Aircraft Aircraft7(7);

// Used to disable AI so we have control.

static float	MyFlightLoopCallback0(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon);    

// Used to update each aircraft every frame.

static float	MyFlightLoopCallback(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon);    


PLUGIN_API int XPluginStart(	char *		outName,
				char *		outSig,
				char *		outDesc){

	strcpy(outName, "DrawAircraft");
	strcpy(outSig, "xplanesdk.examples.drawaircraft");
	strcpy(outDesc, "A plugin that draws aircraft.");

	/* Prefetch the sim variables we will use. */
        gPlaneLat	= XPLMFindDataRef("sim/flightmodel/position/latitude");
        gPlaneLon	= XPLMFindDataRef("sim/flightmodel/position/longitude");
        gPlaneEl	= XPLMFindDataRef("sim/flightmodel/position/elevation");
	gPlaneX		= XPLMFindDataRef("sim/flightmodel/position/local_x");
	gPlaneY		= XPLMFindDataRef("sim/flightmodel/position/local_y");
	gPlaneZ		= XPLMFindDataRef("sim/flightmodel/position/local_z");
	gPlaneTheta	= XPLMFindDataRef("sim/flightmodel/position/theta");
	gPlanePhi	= XPLMFindDataRef("sim/flightmodel/position/phi");
	gPlanePsi	= XPLMFindDataRef("sim/flightmodel/position/psi");
	gOverRidePlanePosition = XPLMFindDataRef("sim/operation/override/override_planepath");
	gAGL = XPLMFindDataRef("sim/flightmodel/position/y_agl");

	XPLMRegisterFlightLoopCallback(		
			MyFlightLoopCallback0,	/* Callback */
			1.0,					/* Interval */
			NULL);					/* refcon not used. */

	XPLMRegisterFlightLoopCallback(		
			MyFlightLoopCallback,	/* Callback */
			1.0,					/* Interval */
			NULL);					/* refcon not used. */


	return 1;
}


PLUGIN_API void	XPluginStop(void){
	XPLMUnregisterFlightLoopCallback(MyFlightLoopCallback0, NULL);
	XPLMUnregisterFlightLoopCallback(MyFlightLoopCallback, NULL);
}

PLUGIN_API void XPluginDisable(void){}
PLUGIN_API int XPluginEnable(void){ return 1; }

PLUGIN_API void XPluginReceiveMessage(	XPLMPluginID	inFromWho,
					int		inMessage,
					void 		*inParam){}

float	MyFlightLoopCallback0(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon){
	int AircraftIndex;

	// Disable AI for each aircraft.
	for (AircraftIndex=1; AircraftIndex<8; AircraftIndex++) XPLMDisableAIForPlane(AircraftIndex);    

	return 0;
}


float	MyFlightLoopCallback(
                                   float                inElapsedSinceLastCall,    
                                   float                inElapsedTimeSinceLastFlightLoop,    
                                   int                  inCounter,    
                                   void *               inRefcon){

	int	GearState;

	double	x,y,z,theta,phi,psi;

	float Heading = 0, Pitch = 0, Roll = 0, Altitude;

	// Get User Aircraft data
	x = XPLMGetDataf(gPlaneX);
	y = XPLMGetDataf(gPlaneY);
	z = XPLMGetDataf(gPlaneZ);
	theta = XPLMGetDataf(gPlaneTheta);
	phi = XPLMGetDataf(gPlanePhi);
	psi = XPLMGetDataf(gPlanePsi);
	Altitude = XPLMGetDataf(gAGL);

	// Copy it to each aircraft using different offsets for each aircraft.

	Aircraft1.plane_x = x + 50.0;
	Aircraft1.plane_y = y;
	Aircraft1.plane_z = z + 50.0;
	Aircraft1.plane_the = theta;
	Aircraft1.plane_phi = phi;
	Aircraft1.plane_psi = psi;

	Aircraft2.plane_x = x - 50.0;
	Aircraft2.plane_y = y;
	Aircraft2.plane_z = z - 50.0;
	Aircraft2.plane_the = theta;
	Aircraft2.plane_phi = phi;
	Aircraft2.plane_psi = psi;

	Aircraft3.plane_x = x + 50.0;
	Aircraft3.plane_y = y;
	Aircraft3.plane_z = z - 50.0;
	Aircraft3.plane_the = theta;
	Aircraft3.plane_phi = phi;
	Aircraft3.plane_psi = psi;

	Aircraft4.plane_x = x - 50.0;
	Aircraft4.plane_y = y;
	Aircraft4.plane_z = z + 50.0;
	Aircraft4.plane_the = theta;
	Aircraft4.plane_phi = phi;
	Aircraft4.plane_psi = psi;

	Aircraft5.plane_x = x + 100.0;
	Aircraft5.plane_y = y;
	Aircraft5.plane_z = z + 100.0;
	Aircraft5.plane_the = theta;
	Aircraft5.plane_phi = phi;
	Aircraft5.plane_psi = psi;

	Aircraft6.plane_x = x - 100.0;
	Aircraft6.plane_y = y;
	Aircraft6.plane_z = z - 100.0;
	Aircraft6.plane_the = theta;
	Aircraft6.plane_phi = phi;
	Aircraft6.plane_psi = psi;

	Aircraft7.plane_x = x + 100.0;
	Aircraft7.plane_y = y;
	Aircraft7.plane_z = z - 100.0;
	Aircraft7.plane_the = theta;
	Aircraft7.plane_phi = phi;
	Aircraft7.plane_psi = psi;

	// Raise the gear when above 200 feet.
	if (Altitude > 200)
		GearState = 0;
	else
		GearState = 1;

	/// Changed from 5 to 6 - Sandy Barbour 18/01/2005
	/// This will be changed to handle versions when the
	/// increase to 10 is implemented in the glue.
	for (int Gear=0; Gear<6; Gear++)
	{
		Aircraft1.plane_gear_deploy[Gear] = GearState;
		Aircraft2.plane_gear_deploy[Gear] = GearState;
		Aircraft3.plane_gear_deploy[Gear] = GearState;
		Aircraft4.plane_gear_deploy[Gear] = GearState;
		Aircraft5.plane_gear_deploy[Gear] = GearState;
		Aircraft6.plane_gear_deploy[Gear] = GearState;
		Aircraft7.plane_gear_deploy[Gear] = GearState;
	}

	// Now set the data in each instance.
	Aircraft1.SetAircraftData();
	Aircraft2.SetAircraftData();
	Aircraft3.SetAircraftData();
	Aircraft4.SetAircraftData();
	Aircraft5.SetAircraftData();
	Aircraft6.SetAircraftData();
	Aircraft7.SetAircraftData();

	//getDataFromFlightRadar24();

	return 10;
}


// ------------------------------------------------------------------------------- //

struct MemoryStruct {
        char *memory;
        size_t size;
};


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


float distAprox(float lat1, float lon1, float lat2, float lon2) {
        float  R       = 6372.795477598;
        float  dLat    = 0.0;
        float  dLon    = 0.0;
        float  a       = 0.0;
        float  c       = 0.0;

        dLat = (lat2-lat1) * ( M_PI / 180.0 );
        dLon = (lon2-lon1) * ( M_PI / 180.0 );

        a       = sin(dLat/2.0) * sin(dLat/2.0) + cos(lat1 * ( M_PI / 180.0 )) * cos(lat2 * ( M_PI / 180.0 )) * sin(dLon/2.0) * sin(dLon/2.0);
        c       = 2.0 * atan2(sqrt(a), sqrt(1-a));

        return( R * c  * 1000.0);
}


int getDataFromFlightRadar24(void){
	struct  	MemoryStruct chunk;
	CURL    	*curl_handle;
	CURLcode 	res;
	char		*token	= NULL;
	int		i 	= 0;
        float   	lat     = 0; 
        float   	lon     = 0;
        float   	el      = 0;


	float		plane_lat	= 0;
	float		plane_lon	= 0;
	float		plane_ele	= 0;
	float		plane_course	= 0;
	float		plane_speed	= 0;

	chunk.memory    = NULL;
        chunk.size      = 0;
	curl_handle	= curl_easy_init();

	curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 		0);
	curl_easy_setopt(curl_handle, CURLOPT_URL,		"http://db.flightradar24.com/zones/full_all.js");
	curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION,    WriteMemoryCallback);     
	curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA,        (void *)&chunk);

	res = curl_easy_perform(curl_handle);
        if (res != CURLE_OK) {
                fprintf(stderr, "Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
                return 1;
        }

// 0 pd_callback({"eecfc7":["400068"
// 1 26.3076
// 2 49.8746
// 3 241
// 4 1825
// 5 200

	lat     = XPLMGetDataf(gPlaneLat);
	lon     = XPLMGetDataf(gPlaneLon);
	el      = XPLMGetDataf(gPlaneEl);




	for ( token = strtok(chunk.memory, ","), i = 0; token != NULL; token = strtok(NULL, ",") ){

		if 	( i == 1 ) plane_lat 	= atof(token);
		else if ( i == 2 ) plane_lon 	= atof(token);
		else if ( i == 3 ) plane_course = atof(token);
		else if ( i == 4 ) plane_ele	= atof(token);
		else if ( i == 5 ) plane_speed	= atof(token);


		if ( i >= 17 ){
			float dist = distAprox(lat, lon, plane_lat, plane_lon);

			printf("%f %f - %f %f %f %f %f : %f\n", lat,lon, plane_lat, plane_lon, plane_ele, plane_course, plane_speed, dist);

			i = 0;
		} else i++;

	}
	return 0;
}


