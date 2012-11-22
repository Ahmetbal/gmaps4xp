#include "core.h"


XPLMDataRef gGroundSpeed;
XPLMDataRef gPlaneHeading;
XPLMDataRef gPlaneLat;
XPLMDataRef gPlaneLon;
XPLMDataRef gPlaneAlt;

void *webServer(void *arg){
	int 			sock;
	struct sockaddr_in 	sin;
	int 			s;
	FILE			*f;

	sock = socket(AF_INET, SOCK_STREAM, 0);

	sin.sin_family 		= AF_INET;
	sin.sin_addr.s_addr 	= INADDR_ANY;
	sin.sin_port 		= htons(PORT);

	bind(sock, (struct sockaddr *) &sin, sizeof(sin));
	listen(sock, 5);


	gGroundSpeed    = XPLMFindDataRef("sim/flightmodel/position/groundspeed");
	gPlaneHeading   = XPLMFindDataRef("sim/flightmodel/position/psi");
	gPlaneLat       = XPLMFindDataRef("sim/flightmodel/position/latitude");
	gPlaneLon       = XPLMFindDataRef("sim/flightmodel/position/longitude");
	gPlaneAlt       = XPLMFindDataRef("sim/flightmodel/position/elevation");


	printf("HTTP server listening on port %d\n", PORT );

	while (1){
		s = accept(sock, NULL, NULL);
		if (s < 0) break;
		f = fdopen(s, "r+");
		process(f);
		fclose(f);
		close(s);

	}

	close(sock);
	return (void*)(1);
}



void send_file(FILE *f, char *path){
	char	data[4096];
	double	Latitude	= 0.0;
	double	Longitude	= 0.0;
	double	Altitude	= 0.0;
	double	Heading		= 0.0;
	double	Speed		= 0.0;
	size_t	length 		= 0;

	
	bzero(data, 4095);

        Latitude	= XPLMGetDataf(gPlaneLat);
        Longitude	= XPLMGetDataf(gPlaneLon);
        Altitude	= XPLMGetDataf(gPlaneAlt);
        Heading		= XPLMGetDataf(gPlaneHeading);
        Speed           = XPLMGetDataf(gGroundSpeed);

	sprintf(data,"<infos><plane latitude=\"%f\" longitude=\"%f\" altitude=\"%f\" heading=\"%f\" speed=\"%f\" /></infos>", Latitude, Longitude, Altitude, Heading, Speed);
	length = strlen(data);
	fwrite(data, 1, length, f);
	fflush(f);

}

int process(FILE *f){
	char 		*buf[50];
	char 		*method		= NULL;
	char 		*path		= NULL;
	char 		*protocol	= NULL;
	int		i		= 0;

	//start:

	while (1){
		if ( ( buf[i] = (char *)malloc(sizeof(char) * 4096) ) == NULL )	return -1;
		bzero(buf[i], 4095);
		if ( !fgets(buf[i], 4096, f) )	return -1;
		if (( buf[i][0] == '\r' ) && ( buf[i][1] == '\n' )) break;
		i++;
	}

	//printf("%s", buf[0]);

	
	method		= strtok(buf[0], 	" ");
	path		= strtok(NULL, 		" ");
	protocol	= strtok(NULL, 		" ");


	if (!method || !path || !protocol) return -1;
	for (i = 0; i < (int)strlen(protocol); i++ ) protocol[i] = ( ( (int)protocol[i] == 13 ) || ( (int)protocol[i] == 10 ) || ( (int)protocol[i] == 32 ) ) ? '\0' : protocol[i];

	fseek(f, 0, SEEK_CUR); 


	send_file(f, path);
	
	//goto start;

	return 0;

}


