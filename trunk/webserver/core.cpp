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

	}

	close(sock);
	return (void*)(1);
}


void send_headers(FILE *f, int status, const char *title, const char *extra, const char *mime, int length){
	time_t	now;
	char	timebuf[128];

	now = time(NULL);
	strftime(timebuf, sizeof(timebuf), RFC1123FMT, gmtime(&now));

			fprintf(f, "%s %d %sr\n",		PROTOCOL, status, title);
			fprintf(f, "Date: %s\r\n",		timebuf);
			fprintf(f, "Server: %s\r\n",		SERVER);
			fprintf(f, "Keep-Alive: timeout=15, max=100\r\n");
			fprintf(f, "Connection: Keep-Alive\r\n");
	if (mime)	fprintf(f, "Content-Type: %s\r\n", 	mime);
	if (length >= 0)fprintf(f, "Content-Length: %d\r\n", 	length);
	if (extra)	fprintf(f, "%s\r\n", 			extra);
			fprintf(f, "\r\n");

}


void send_error(FILE *f, int status, const char *title, const char *extra, const char *text){
	send_headers(f, status, title, extra, "text/html", -1);
	fprintf(f, "<html><head><title>%d %s</title></head>\r\n", status, title);
	fprintf(f, "<body><h4>%d %s</h4>\r\n", status, title);
	fprintf(f, "%s\r\n", text);
	fprintf(f, "</body></html>\r\n");

}

void send_file(FILE *f, char *path){
	char	data[4096];
	double	Latitude	= 0.0;
	double	Longitude	= 0.0;
	double	Altitude	= 0.0;
	double	Heading		= 0.0;
	double	Speed		= 0.0;
	int	length 		= 0;

	
	bzero(data, 4095);

        Latitude	= XPLMGetDataf(gPlaneLat);
        Longitude	= XPLMGetDataf(gPlaneLon);
        Altitude	= XPLMGetDataf(gPlaneAlt);
        Heading		= XPLMGetDataf(gPlaneHeading);
        Speed           = XPLMGetDataf(gGroundSpeed);

	sprintf(data,"<info><plane latitude='%f' longitude='%f' altitude='%'f heading='%f' speed='%f' /></info>\n", Latitude, Longitude, Altitude, Heading, Speed);


	length = strlen(data);
	send_headers(f, 200, "OK", NULL, "text/xml", length);
	fwrite(data, 1, length, f);

}

int process(FILE *f){
	char 		*buf[50];
	char 		*method		= NULL;
	char 		*path		= NULL;
	char 		*protocol	= NULL;
	int		i		= 0;

	while (1){
		if ( ( buf[i] = (char *)malloc(sizeof(char) * 4096) ) == NULL )	return -1;
		bzero(buf[i], 4095);
		if ( !fgets(buf[i], 4096, f) )	return -1;
		if (( buf[i][0] == '\r' ) && ( buf[i][1] == '\n' )) break; 
		i++;
	}
	
	method		= strtok(buf[0], 	" ");
	path		= strtok(NULL, 		" ");
	protocol	= strtok(NULL, 		"\n");


	if (!method || !path || !protocol) return -1;

	fseek(f, 0, SEEK_CUR); 

	if 	(strcmp(method, "GET") != 0)		send_error(f, 501, "Not supported",  NULL, "Method is not supported.");
	else						send_file(f, path);
	
	return 0;

}


