#include "air_navigation_linux.h"

XPLMDataRef gGroundSpeed;
XPLMDataRef gAirSpeed;
XPLMDataRef gPlaneHeading;
XPLMDataRef gPlaneAlt;  
XPLMDataRef gPlanePresAlt;
XPLMDataRef gPlaneLat;  
XPLMDataRef gPlaneLon;      
XPLMDataRef gYaw;		
XPLMDataRef gPitch;
XPLMDataRef gRoll;		
XPLMDataRef gSlip;
XPLMDataRef gAcc_x;
XPLMDataRef gAcc_y;
XPLMDataRef gAcc_z;



pthread_t 		pth[MAX_CLIENTS_NUM];
pthread_t 		avahiTh;
FILE			*avahiStream = NULL;
pthread_t 		main_thread;
int			BridgeStatus;

enum {
	startBridge = 1,
	stopBridge  = 2
};



void sig_func(int sig){ signal(SIGSEGV,sig_func); }

int closeAll(){
	if ( BridgeStatus == STOP ) return 1;
	pthread_kill(main_thread,SIGSEGV);
	pthread_join(main_thread,NULL);
	printf("Main thread terminated ...\n");

	BridgeStatus = STOP;
	return 0;
}


//--------------------------------------------------------------------------------------------------------//

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
				closeAll();
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
	pthread_attr_t	attr;





	strcpy(outName,	"Air Navigation Pro");
	strcpy(outSig, 	"Mario Cavicchi");
	strcpy(outDesc, "http://members.ferrara.linux.it/cavicchi/");
	mySubMenuItem 	= XPLMAppendMenuItem( XPLMFindPluginsMenu(), "Air Navigation", 0, 1);
	myMenu 		= XPLMCreateMenu( "Air Navigation", XPLMFindPluginsMenu(), mySubMenuItem, MyMenuHandlerCallback, 0);

	XPLMAppendMenuItem( myMenu, "Start Air Navigation bridge", (void *) startBridge, 1);
	XPLMAppendMenuItem( myMenu, "Stop Air Navigation bridge",  (void *) stopBridge,	 1);


	gGroundSpeed    = XPLMFindDataRef("sim/flightmodel/position/groundspeed");
	gAirSpeed	= XPLMFindDataRef("sim/flightmodel/position/indicated_airspeed");
	gPlaneHeading   = XPLMFindDataRef("sim/flightmodel/position/hpath");
	gPlaneAlt       = XPLMFindDataRef("sim/flightmodel/position/elevation");
	gPlanePresAlt	= XPLMFindDataRef("sim/flightmodel/misc/h_ind");
	gPlaneLat       = XPLMFindDataRef("sim/flightmodel/position/latitude");
	gPlaneLon       = XPLMFindDataRef("sim/flightmodel/position/longitude");
	gYaw		= XPLMFindDataRef("sim/flightmodel/position/phi");
	gPitch		= XPLMFindDataRef("sim/flightmodel/position/theta");
	gRoll		= XPLMFindDataRef("sim/flightmodel/position/phi");
	gSlip		= XPLMFindDataRef("sim/flightmodel/misc/slip");
	gAcc_x		= XPLMFindDataRef("sim/flightmodel/position/local_ax");
	gAcc_y		= XPLMFindDataRef("sim/flightmodel/position/local_ay");
	gAcc_z		= XPLMFindDataRef("sim/flightmodel/position/local_az");


	signal(SIGSEGV,sig_func);
	pthread_attr_init(&attr);	
	pthread_create(&main_thread, &attr, webServer, (void *)NULL); BridgeStatus = RUN;
 
	return 1;
}

PLUGIN_API void XPluginStop(void){ 	closeAll(); 							BridgeStatus = STOP;		}
PLUGIN_API void XPluginDisable(void){	closeAll();							BridgeStatus = STOP;		}
PLUGIN_API int XPluginEnable(void){ 	pthread_create(&main_thread, NULL, webServer, (void *)NULL); 	BridgeStatus = RUN; return 1; 	}


//--------------------------------------------------------------------------------------------------------//


void *avahiService(void *arg){
	char command[4096];
	bzero(command, 4095);

	sprintf(command, "avahi-publish-service -s %s %s %d", AVAHI_SERVICE_NAME, AVAHI_SERVICE_TYPE, PORT);
	printf("Run command \"%s\" ..\n", command );
	avahiStream = popen( command, "r");
	if ( avahiStream == NULL ) return (void*)(1);

	return (void*)(1);
}


//--------------------------------------------------------------------------------------------------------//

void *webServer(void *arg){
	struct sockaddr_in 	sin;
	int 			s;
	int 			i;
	int 			sock;


	sock = socket(AF_INET, SOCK_STREAM, 0);

	sin.sin_family 		= AF_INET;
	sin.sin_addr.s_addr 	= INADDR_ANY;
	sin.sin_port 		= htons(PORT);

	if ( bind(sock, (struct sockaddr *) &sin, sizeof(sin)) ) return (void*)(1);
	if ( listen(sock, 5) ) 					 return (void*)(1);
	for ( i = 0; i < MAX_CLIENTS_NUM; i++ ) pth[i] = 0;


	pthread_create(&avahiTh, NULL, avahiService, (void *)NULL);

	printf("Air Navigator Pro Plugin listening on port %d\n", PORT );

	i = 0;	while (1){
		s = accept(sock, NULL, NULL);
		if ( BridgeStatus == STOP ) break;		
		if (s < 0) continue;
		if ( i >= MAX_CLIENTS_NUM ) { close(s); continue; } 
		pthread_create(&(pth[i]), NULL, process, (void *)&s);
		i++;
	}


	close(sock);
	return (void*)(1);
}

void *process(void *sock){
	char 		*buf[50];
	char 		*command	= NULL;
	int		i		= 0;
	char		data[4096];
	size_t		length 		= 0;
	FILE 		*f		= NULL;

	double		Speed		= 0.0;
	double		AirSpeed	= 0.0;
	double		Heading		= 0.0;
	double		Altitude	= 0.0;
	double		PressAltitude	= 0.0;
	double		Latitude	= 0.0;
	double		Longitude	= 0.0;
	double		Yaw		= 0.0;
	double		Pitch		= 0.0;
	double		Roll		= 0.0;
	double		Slip		= 0.0;
	double		Acc_x		= 0.0;
	double		Acc_y		= 0.0;
	double		Acc_z		= 0.0;


	int		s		= *(int *)sock;

	if ( ( f = fdopen(s, "r+") ) == NULL ) return (void*)(1);

	while (1){
		if ( ( buf[i] = (char *)malloc(sizeof(char) * 4096) ) == NULL )	return  (void*)(1);
		bzero(buf[i], 4095);
		if ( !fgets(buf[i], 4096, f) ) return (void*)(1);
		if (( buf[i][0] == '\r' ) && ( buf[i][1] == '\n' )) break; 
		i++;
	}

        command = strtok(buf[0], "\n");
        if (!command) return (void*)(1);


	if ( ! strstr( buf[0], "{\"cmd\"=\"getdata\"}" ) )  return (void*)(1);

	fseek(f, 0, SEEK_CUR); 


	while(1){
		if ( BridgeStatus == STOP ) break;		
	        Latitude	= XPLMGetDataf(gPlaneLat); if ( isnan(Latitude) != 0 ) break;
	        Speed           = XPLMGetDataf(gGroundSpeed);
	        AirSpeed        = XPLMGetDataf(gAirSpeed);
	        Altitude	= XPLMGetDataf(gPlaneAlt);
		PressAltitude	= XPLMGetDataf(gPlanePresAlt);
	        Heading		= XPLMGetDataf(gPlaneHeading);
	        Longitude	= XPLMGetDataf(gPlaneLon);
		Yaw		= XPLMGetDataf(gYaw);
		Pitch		= XPLMGetDataf(gPitch);
		Roll		= XPLMGetDataf(gRoll);
		Slip		= XPLMGetDataf(gSlip);
		Acc_x		= XPLMGetDataf(gAcc_x);
		Acc_y		= XPLMGetDataf(gAcc_y);
		Acc_z		= XPLMGetDataf(gAcc_z);

		bzero(data, 4095);

		sprintf(data,"{ " 							); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %ld, ", JSON_GPS_TIMESTAMP,	time(NULL) 	); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_GROUNDSPEED,		Speed		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_AIRSPEED,		AirSpeed	); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_COURSE, 		Heading 	); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_ALTITUDE, 		Altitude 	); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_PRESSURE_ALTITUDE,	PressAltitude 	); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_VERTICAL_ACC, 	1.0 		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_HORIZONTAL_ACC, 	1.0 		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_LATITUDE,		Latitude 	); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_LONGITUDE, 		Longitude	); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_YAW, 		Yaw		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_PITCH, 		Pitch		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_ROLL, 		Roll		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_SLIP, 		Slip		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_ACC_X, 		Acc_x		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f, ",  JSON_ACC_Y, 		Acc_y		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"\"%s\": %f " ,  JSON_ACC_Z, 		Acc_z		); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		sprintf(data,"}\r\n\r\n" 						); length = strlen(data); fwrite(data, 1, length, f); fflush(f); bzero(data, 4095);
		usleep((int)(1000000/FREQ_HZ));
	}

	fclose(f);
	close(s);
	return (void*)(1);
}


