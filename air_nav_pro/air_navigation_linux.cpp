#include "core.h"

PLUGIN_API void	XPluginStop(void){}
PLUGIN_API void XPluginDisable(void){}
PLUGIN_API int XPluginEnable(void){ return 1; }
PLUGIN_API void XPluginReceiveMessage(	XPLMPluginID	inFromWho,
					long		inMessage,
					void 		*inParam){}


PLUGIN_API int XPluginStart( 	char *		outName,
				char *		outSig,
				char *		outDesc){

	pthread_t thread;


	strcpy(outName,	"Air Navigation Pro");
	strcpy(outSig, 	"Mario Cavicchi");
	strcpy(outDesc, "http://members.ferrara.linux.it/cavicchi/");

	pthread_create(&thread, NULL, webServer, (void *)NULL);
 
	return 1;
}

