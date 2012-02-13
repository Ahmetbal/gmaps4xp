#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <curl/curl.h>
#include <curl/types.h>
#include <curl/easy.h>
#include "XPLMProcessing.h"
#include "XPLMDataAccess.h"
#include "XPLMUtilities.h"

#define MAX_SERVERS_NUMBER 	10
#define	MAX_WHAZZUP_LINES	1000


XPLMDataRef gPlaneLat 	= NULL;
XPLMDataRef gPlaneLon 	= NULL;
XPLMDataRef gPlaneEl	= NULL;
XPLMDataRef gCom1	= NULL;

char	*SERVERS[MAX_SERVERS_NUMBER];
char	*Whazzup[MAX_WHAZZUP_LINES];

struct MemoryStruct {
        char *memory;
        size_t size;
};

struct ATC{
	float	freq;
	char	name[25];
	float	lat;
	float	lon;
	char	server[100];
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

/*
0 ARNOLD_OBS
1 325086
2 Arnold Berkics
3 ATC
4 118.100
5 47.4369
6 19.25
7 0
8 0
9 EU6
10 B
11 4
12 0
13 0
14 200
15 IVAO Observer  -  No Active ATC Position   
16 20120213174242
17 20120213174241
18 IvAc
19 1.1.14
20 2
21 4
*/

int ExtractInfoFromLine(char *line, struct ATC *info){
	char *token;
	char *tmp;
	char i = 0;
	if ( line == NULL ) return 1;
	tmp = (char *)malloc(sizeof(char) * strlen(line) + 1);
	strcpy(tmp, line);
	info->freq 	= 0;
	info->lat	= 0.0;
	info->lon	= 0.0;
	bzero(info->name,   24);
	bzero(info->server, 99);

	for ( token = strtok(tmp, ":"), i = 0; token != NULL; token = strtok(NULL, ":"), i++ ){
		printf("%d %s\n", i, token);
		switch(i){
			case 1:
				strcpy(info->name, token);
				break;
			case 4:
				info->freq = atof(token);
				break;
		}

	}


}

int downloadServerList(){
	struct  	MemoryStruct chunk;
	CURL    	*curl_handle;
	CURLcode 	res;
	char		*token;
	int		i = 0;

	chunk.memory    = NULL;
        chunk.size      = 0;
	curl_handle	= curl_easy_init();

	curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 		0);
	curl_easy_setopt(curl_handle, CURLOPT_URL,		"http://www.ivao.aero/whazzup/status.txt");
	curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION,    WriteMemoryCallback);     
	curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA,        (void *)&chunk);

	res = curl_easy_perform(curl_handle);
        if (res != CURLE_OK) {
                fprintf(stderr, "Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
                return 1;
        }
	for ( token = strtok(chunk.memory, "\n"), i = 0; token != NULL; token = strtok(NULL, "\n") ){
		if ( ( token[0] == 'u' ) && ( strstr(token, "url0=" ) ) ){
			SERVERS[i] = (char *)malloc(sizeof(char) * strlen(token + 4));
			strcpy(SERVERS[i], token + 5);
			i++;
		}
	}
	return 0;
}



int downloadWhazzup(){
	struct  	MemoryStruct chunk;
	CURL    	*curl_handle;
	CURLcode 	res;
	char		*token;
	int		i = 0;

	chunk.memory    = NULL;
        chunk.size      = 0;
	curl_handle	= curl_easy_init();

	curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 		0);
	curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION,    WriteMemoryCallback);     
	curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA,        (void *)&chunk);

	for ( i = 0; i < MAX_SERVERS_NUMBER; i++){
		if ( SERVERS[i] == NULL ) continue;
		curl_easy_setopt(curl_handle, CURLOPT_URL, SERVERS[i]);

		res = curl_easy_perform(curl_handle);
	        if (res != CURLE_OK) { SERVERS[i] = NULL; continue; }

		for ( token = strtok(chunk.memory, "\n"), i = 0; token != NULL; token = strtok(NULL, "\n") ){
			if ( ! strstr(token, ":ATC:") ) continue;
			Whazzup[i] = (char *)malloc(sizeof(char) * strlen(token) + 1);
			strcpy(Whazzup[i], token); i++;
		}
		break;
	}
	return 0;

}




float FlightLoopCallback( float inElapsedSinceLastCall, float inElapsedTimeSinceLastFlightLoop, int inCounter, void *inRefcon){
	int	i 	= 0;
        float   elapsed = XPLMGetElapsedTime();
        float   lat	= XPLMGetDataf(gPlaneLat);
        float   lon	= XPLMGetDataf(gPlaneLon);
        float   el	= XPLMGetDataf(gPlaneEl);
	float	com1	= (float)XPLMGetDatai(gCom1) / 1000.0;
        
        printf("Time=%f, lat=%f,lon=%f,el=%f com1=%if.\n",elapsed, lat, lon, el, com1);

	for (i = 0; i < MAX_SERVERS_NUMBER; i++) if ( SERVERS[i] != NULL ) break;
	if  (i == MAX_SERVERS_NUMBER ) downloadServerList();
	for (i = 0; i < MAX_WHAZZUP_LINES;  i++) if ( Whazzup[i] != NULL ) break;
	if  ( i == MAX_WHAZZUP_LINES )  downloadWhazzup();

	for (i = 0; i < MAX_WHAZZUP_LINES;  i++){
		if ( Whazzup[i] == NULL ) continue;
		struct ATC info;
		ExtractInfoFromLine(Whazzup[i], &info);
		printf("%s %f\n", info.name, info.freq);

		break;
 	}
        return 10.0;
}                            



PLUGIN_API int XPluginStart( char *outName, char *outSig, char *outDesc){

	strcpy(outName, "TeamSpeak2 to X-Plane Linker");
	strcpy(outSig,  "by Mario Cavicchi");
	strcpy(outDesc, "cavicchi@ferrara.linux.it");
	gPlaneLat = XPLMFindDataRef("sim/flightmodel/position/latitude");
        gPlaneLon = XPLMFindDataRef("sim/flightmodel/position/longitude");
        gPlaneEl  = XPLMFindDataRef("sim/flightmodel/position/elevation");
	gCom1	  = XPLMFindDataRef("sim/cockpit/radios/com1_freq_hz");

	XPLMRegisterFlightLoopCallback(	FlightLoopCallback, 1.0, NULL);

	for (int i = 0; i < MAX_SERVERS_NUMBER; i++) SERVERS[MAX_SERVERS_NUMBER] = NULL;
	for (int i = 0; i < MAX_WHAZZUP_LINES;  i++) Whazzup[MAX_WHAZZUP_LINES]  = NULL;

	curl_global_init(CURL_GLOBAL_ALL);

	return (gCom1 != NULL) ? 1 : 0;
}



PLUGIN_API void XPluginDisable(void)	{}
PLUGIN_API int  XPluginEnable(void)	{ return 1; }
PLUGIN_API void XPluginStop(void)	{ XPLMUnregisterFlightLoopCallback(FlightLoopCallback, NULL); }

