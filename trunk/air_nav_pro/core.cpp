#include "core.h"

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

void *webServer(void *arg){
	int 			sock;
	struct sockaddr_in 	sin;
	int 			s;

	sock = socket(AF_INET, SOCK_STREAM, 0);

	sin.sin_family 		= AF_INET;
	sin.sin_addr.s_addr 	= INADDR_ANY;
	sin.sin_port 		= htons(PORT);

	if ( bind(sock, (struct sockaddr *) &sin, sizeof(sin)) ) return (void*)(1);
	if ( listen(sock, 5) ) 					 return (void*)(1);


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


	printf("Air Navigator Pro Plugin listening on port %d\n", PORT );

	while (1){
		s = accept(sock, NULL, NULL);
		if (s < 0) continue;
		pthread_t pth;
		pthread_create(&pth, NULL, process, (void *)&s);
		if ( BridgeStatus == STOP ) break;
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
		usleep(250000);
	}

	fclose(f);
	close(s);
	return (void*)(1);
}


