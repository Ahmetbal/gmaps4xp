#include "core.h"

pthread_t 	main_thread;
int		BridgeStatus;

enum {
	startBridge = 1,
	stopBridge  = 2
};


PLUGIN_API void XPluginReceiveMessage(	XPLMPluginID	inFromWho,
					long		inMessage,
					void 		*inParam){}


void MyMenuHandlerCallback(void *inMenuRef, void *inItemRef){
	switch((int) inItemRef){
		case startBridge:
			printf("Starting Air Navigation bridge ...\n");
			if ( BridgeStatus == STOP ){
				pthread_create(&main_thread, NULL, webServer, (void *)NULL);
				BridgeStatus = RUN;
			} else printf("Plugin is already running ...\n");
			break;
		case stopBridge:
			printf("Stopping Air Navigation bridge ...\n");
			if ( BridgeStatus == RUN ){
				pthread_kill(main_thread, SIGKILL);
				system("killall -9 avahi-publish-service");

				BridgeStatus = STOP;
			} else printf("Plugin is already stopped ...\n");
			break;

	}

}


PLUGIN_API int XPluginStart( 	char *		outName,
				char *		outSig,
				char *		outDesc){

	int		mySubMenuItem;
	XPLMMenuID	myMenu;
	

	strcpy(outName,	"Air Navigation Pro");
	strcpy(outSig, 	"Mario Cavicchi");
	strcpy(outDesc, "http://members.ferrara.linux.it/cavicchi/");
	mySubMenuItem 	= XPLMAppendMenuItem( XPLMFindPluginsMenu(), "Air Navigation", 0, 1);
	myMenu 		= XPLMCreateMenu( "Air Navigation", XPLMFindPluginsMenu(), mySubMenuItem, MyMenuHandlerCallback, 0);

	XPLMAppendMenuItem( myMenu, "Start Air Navigation bridge", (void *) startBridge, 1);
	XPLMAppendMenuItem( myMenu, "Stop Air Navigation bridge",  (void *) stopBridge,	 1);


	pthread_create(&main_thread, NULL, webServer, (void *)NULL); BridgeStatus = RUN;
 
	return 1;
}

PLUGIN_API void XPluginStop(void){ 	pthread_kill(main_thread, SIGKILL); system("killall -9 avahi-publish-service"); BridgeStatus = STOP;					}
PLUGIN_API void XPluginDisable(void){	pthread_kill(main_thread, SIGKILL); system("killall -9 avahi-publish-service");	BridgeStatus = STOP;					}
PLUGIN_API int XPluginEnable(void){ 	pthread_create(&main_thread, NULL, webServer, (void *)NULL); BridgeStatus = RUN; return 1; 	}




