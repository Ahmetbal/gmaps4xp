#include "air_navigation_linux.h"

XPLMDataRef gGroundSpeed;
XPLMDataRef gAirSpeed;
XPLMDataRef gVertSpeed;
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



pthread_t 	pth[MAX_CLIENTS_NUM];
pthread_t 	avahiTh;
pthread_t	main_thread;
int		BridgeStatus;
pid_t		avahi_publish_service_pid;

enum {
	startBridge = 1,
	stopBridge  = 2
};


int closeAll(){
	struct sockaddr_in 	pin;
	int			sd;

	if ( BridgeStatus == STOP ) return 1;
	BridgeStatus = STOP;

	memset(&pin, 0, sizeof(pin));
	pin.sin_family 		= AF_INET;
	pin.sin_addr.s_addr 	= inet_addr("127.0.0.1");
	pin.sin_port 		= htons(PORT);

	if ((sd = socket(AF_INET, SOCK_STREAM, 0)) == -1) 		return 1;
	if (connect(sd,(struct sockaddr *)  &pin, sizeof(pin)) == -1 ) 	return 1;

	send(sd, "stop", 4, 0); // Not important the message
	close(sd);
	if ( kill(avahi_publish_service_pid, SIGINT) == - 1 ) printf("Unable to kill avahi-publish-service process!\n");
	printf("Closed Air Navigation Bridge at port %d ...\n", PORT );

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


	strcpy(outName,	"Air Navigation Pro");
	strcpy(outSig, 	"Mario Cavicchi");
	strcpy(outDesc, "http://members.ferrara.linux.it/cavicchi/");
	mySubMenuItem 	= XPLMAppendMenuItem( XPLMFindPluginsMenu(), "Air Navigation", 0, 1);
	myMenu 		= XPLMCreateMenu( "Air Navigation", XPLMFindPluginsMenu(), mySubMenuItem, MyMenuHandlerCallback, 0);

	if ( system("avahi-publish-service --version") == -1 ) return 1;


	XPLMAppendMenuItem( myMenu, "Start Air Navigation bridge", (void *) startBridge, 1);
	XPLMAppendMenuItem( myMenu, "Stop Air Navigation bridge",  (void *) stopBridge,	 1);


	gGroundSpeed    = XPLMFindDataRef("sim/flightmodel/position/groundspeed");
	gAirSpeed	= XPLMFindDataRef("sim/flightmodel/position/indicated_airspeed");
	gVertSpeed	= XPLMFindDataRef("sim/flightmodel/position/vh_ind");
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
	BridgeStatus	= STOP; 	// The plugin starts off
	avahi_publish_service_pid = 0;	

	return 1;
}

PLUGIN_API void XPluginStop(void){ 	closeAll(); BridgeStatus = STOP; }
PLUGIN_API void XPluginDisable(void){	closeAll(); BridgeStatus = STOP; }
PLUGIN_API int XPluginEnable(void){ return 1; }


//--------------------------------------------------------------------------------------------------------//


void *avahiService(void *arg){
	pid_t pid;

	char port[10];
	bzero(port, 9); sprintf(port, "%d", PORT );

	printf("Run command avahi-publish-service -s %s %s %s ..\n", AVAHI_SERVICE_NAME, AVAHI_SERVICE_TYPE, port );

	pid = fork();
	if 	( pid <  0 ) return (void*)(1);
	else if	( pid == 0 ) {
		if ( execlp("avahi-publish-service", "avahi-publish-service", "-s", AVAHI_SERVICE_NAME, AVAHI_SERVICE_TYPE, port, NULL) == -1 )	{
			printf("Unable to publish avahi service: %s\n", strerror( errno ) );
			return (void*)(1);
		}
	}

	printf("Started avahi-publish-service with pid %d ...\n", pid);
	avahi_publish_service_pid = pid;

	return (void*)(1);
}


//--------------------------------------------------------------------------------------------------------//

void *webServer(void *arg){
	struct sockaddr_in 	sin;
	int 			s;
	int 			i = 1;
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
	
	close(s);
	close(sock);
	return (void*)(1);
}

void *process(void *sock){
	char 		*buf[50];
	char 		*command	= NULL;
	int		i		= 0;
	int		error		= 0;
	char		data[4096];
	struct sockaddr_in addr;

	double		Speed		= 0.0;
	double		AirSpeed	= 0.0;
	double		VertSpeed	= 0.0;
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

	signal(SIGPIPE, SIG_IGN);

	socklen_t socklen = sizeof(addr); 
	socklen_t len	  = sizeof(error);
	if ( getpeername(s, (struct sockaddr*) &addr, &socklen) < 0) 	printf("Accept new connection from unknown ...\n");
	else 								printf("Accept new connection from %s:%d ...\n", inet_ntoa(addr.sin_addr), ntohs(addr.sin_port));


	while (1){
		if ( i >= 50 ) break;
		if ( ( buf[i] = (char *)malloc(sizeof(char) * 4096) ) == NULL )	{ close(s); return  (void*)(1); }
		bzero(buf[i], 4095);
		ssize_t bytes_recieved = recv(s, buf[i], 4096, 0);
		buf[i][bytes_recieved] = '\0';
		if ( bytes_recieved <= 0  ) return (void*)(1);
		if (( buf[i][0] == '\r' ) && ( buf[i][1] == '\n' )) break; 
		i++;
	}

        command = strtok(buf[0], "\n");
       	if (!command) { close(s); return (void*)(1); }
	if ( ! strstr( buf[0], "{\"cmd\"=\"getdata\"}" ) ) { close(s); return (void*)(1); }


	while(1){
		if ( BridgeStatus == STOP ) break;		
		if ( getsockopt (s, SOL_SOCKET, SO_ERROR, &error, &len ) != 0 ) break;

	        Latitude	= XPLMGetDataf(gPlaneLat); if ( isnan(Latitude) != 0 ) break;
	        Speed           = XPLMGetDataf(gGroundSpeed);
	        AirSpeed        = XPLMGetDataf(gAirSpeed);
		VertSpeed	= XPLMGetDataf(gVertSpeed);
	        Altitude	= XPLMGetDataf(gPlaneAlt);
		PressAltitude	= XPLMGetDataf(gPlanePresAlt) * 0.3048; // Conversion from feets to meters
	        Heading		= XPLMGetDataf(gPlaneHeading);
	        Longitude	= XPLMGetDataf(gPlaneLon);
		Yaw		= XPLMGetDataf(gYaw);
		Pitch		= XPLMGetDataf(gPitch);
		Roll		= XPLMGetDataf(gRoll);
		Slip		= XPLMGetDataf(gSlip);
		Acc_x		= XPLMGetDataf(gAcc_x) / 9.80665; // Conversion to mtr/sec2 to G
		Acc_y		= XPLMGetDataf(gAcc_y) / 9.80665;
		Acc_z		= XPLMGetDataf(gAcc_z) / 9.80665;

		bzero(data, 4095);
		sprintf(data,"{ " 								); 
		sprintf(data,"%s \"%s\": %ld, ", data, JSON_GPS_TIMESTAMP,	time(NULL) 	); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_GROUNDSPEED,	Speed		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_AIRSPEED,		AirSpeed	);
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_COURSE, 		Heading 	); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_ALTITUDE, 		Altitude 	); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_PRESSURE_ALTITUDE,	PressAltitude 	); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_VERTICAL_ACC, 	1.0 		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_HORIZONTAL_ACC, 	1.0 		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_LATITUDE,		Latitude 	); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_LONGITUDE, 		Longitude	); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_YAW, 		Yaw		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_PITCH, 		Pitch		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_ROLL, 		Roll		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_SLIP, 		Slip		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_ACC_X, 		Acc_x		); 
		sprintf(data,"%s \"%s\": %f, ",  data, JSON_ACC_Y, 		Acc_y		); 
		sprintf(data,"%s \"%s\": %f " ,  data, JSON_ACC_Z, 		Acc_z		); 
		sprintf(data,"%s }\r\n\r\n", 	 data 		      				); 

		if ( send(s,  data,strlen(data), 0) <= 0 ) break;

		usleep((int)(1000000/FREQ_HZ));
	}
	printf("Close connection ... \n");

	close(s);
	return (void*)(1);
}


