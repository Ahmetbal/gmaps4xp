#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>  
#include <unistd.h>



 
#include <curl/curl.h>
#include <curl/types.h>
#include <curl/easy.h>


#define USER_AGENT	"Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2.2) Gecko/20100316 Firefox/3.6.2 GTB7.0"
#define	TOKEN_STRING	"mSatelliteToken"
 
struct MemoryStruct {
	char *memory;
	size_t size;
};
 
static void *myrealloc(void *ptr, size_t size);
 
static void *myrealloc(void *ptr, size_t size){
	if(ptr)	return realloc(ptr, size);
	else	return malloc(size);
}
 
static size_t WriteMemoryCallback(void *ptr, size_t size, size_t nmemb, void *data){
	size_t realsize			= size * nmemb;
	struct MemoryStruct *mem	= (struct MemoryStruct *)data;
 
	mem->memory = (char *)myrealloc(mem->memory, mem->size + realsize + 1);
	if (mem->memory) {
		memcpy(&(mem->memory[mem->size]), ptr, realsize);
		mem->size += realsize;
		mem->memory[mem->size] = 0;
	}
	return realsize;
}

int initCurlHandle(CURL    *curl_handle){
	int	i, j;
	int	offset			= 0;
	char 	key[]			= TOKEN_STRING;
	char	*token			= NULL;
	char	*SatelliteToken 	= NULL;
	char	nline[256]		= {};
	struct	MemoryStruct chunk;
	struct	curl_slist *cookie	= NULL;
	struct	curl_slist *cursor	= NULL;
	struct	curl_slist *headers	= NULL; 
	CURLcode res;

	chunk.memory	= NULL; 
	chunk.size	= 0;    


	headers = curl_slist_append(headers, "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8");
	headers = curl_slist_append(headers, "Accept-Language: en-us,en;q=0.5");
	headers = curl_slist_append(headers, "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7");
	headers = curl_slist_append(headers, "Keep-Alive: 115");
	headers = curl_slist_append(headers, "Connection: keep-alive");

	curl_easy_setopt(curl_handle, CURLOPT_VERBOSE, 		0);				// Verbose NO
	curl_easy_setopt(curl_handle, CURLOPT_URL,		"http://maps.google.com");	// URL
	curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION,	WriteMemoryCallback);		// Headler to function to write in memory
	curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA,	(void *)&chunk);		// Pointer to memory where write
	curl_easy_setopt(curl_handle, CURLOPT_USERAGENT,	USER_AGENT);			// Modifed User agent
	curl_easy_setopt(curl_handle, CURLOPT_COOKIELIST,	"ALL");  			// Clean cookie list
	curl_easy_setopt(curl_handle, CURLOPT_COOKIEFILE, 	"");				// Set where store cookie 
	curl_easy_setopt(curl_handle, CURLOPT_HTTPHEADER,	headers);			// Modifed header like firefox 3.6


	res = curl_easy_perform(curl_handle);
	if (res != CURLE_OK) {
		fprintf(stderr, "Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
		return 1;
	}

  
	//------------------------------------------------------------------


	// Search satellite key	
	for (i = 0 ; i < chunk.size; i++){
		if ( chunk.memory[i] != key[0] ) continue;
		offset = i;
		for (j = 1, i++ ; j < strlen(key) ; j++, i++){
			if ( chunk.memory[i] != key[j] ) break;
		}
		if ( j == strlen(key) ) break;
	}

	// if not found iterator is equal to size
	if ( i == chunk.size ) return 1;

	for ( token = strtok(chunk.memory+offset, "\""), i = 0; token != NULL; token = strtok(NULL, "\""), i++ ){
		if ( i == 1 ){ // First after the variable name
			SatelliteToken = (char *)malloc(sizeof(char) * (strlen(token)+1));
			strcpy(SatelliteToken, token);
			break;
		}
	}

	if(chunk.memory)  free(chunk.memory);
	
	//------------------------------------------------------------------
	curl_easy_setopt(curl_handle, CURLOPT_COOKIELIST, "ALL");  // Clean cookie list
	cursor = cookie, i = 1;  
	while (cursor) {  
		curl_easy_setopt(curl_handle, CURLOPT_COOKIELIST, cursor->data);
		cursor = cursor->next;  
		i++;  
	}  

	snprintf(nline, 256, "%s\t%s\t%s\t%s\t%d\t%s\t%s",  ".google.com", "TRUE", "/vt/lbw",		"FALSE", 0, "khcookie", SatelliteToken);  
	res = curl_easy_setopt(curl_handle, CURLOPT_COOKIELIST, nline);  
	if (res != CURLE_OK) {  fprintf(stderr, "Curl curl_easy_setopt failed: %s\n", curl_easy_strerror(res)); return 1; }  

	snprintf(nline, 256, "%s\t%s\t%s\t%s\t%d\t%s\t%s",  ".google.com", "TRUE", "/maptilecompress",	"FALSE", 0, "khcookie", SatelliteToken);  
	res = curl_easy_setopt(curl_handle, CURLOPT_COOKIELIST, nline);  
	if (res != CURLE_OK) {  fprintf(stderr, "Curl curl_easy_setopt failed: %s\n", curl_easy_strerror(res)); return 1; }  

	snprintf(nline, 256, "%s\t%s\t%s\t%s\t%d\t%s\t%s",  ".google.com", "TRUE", "/kh",		"FALSE", 0, "khcookie", SatelliteToken);  
	res = curl_easy_setopt(curl_handle, CURLOPT_COOKIELIST, nline);  
	if (res != CURLE_OK) {  fprintf(stderr, "Curl curl_easy_setopt failed: %s\n", curl_easy_strerror(res)); return 1; }  


	curl_slist_free_all(cookie);  
	curl_slist_free_all(cursor);  
	return 0;
}

size_t downloadItem(CURL *curl_handle, const char *url, unsigned char **itemData){

	CURLcode	res;
	struct		MemoryStruct buffer;
	size_t		size = 0;

	buffer.memory	= NULL; 
	buffer.size	= 0;    


	curl_easy_setopt(curl_handle, CURLOPT_WRITEFUNCTION,	WriteMemoryCallback);	// Headler to function to write in memory
	curl_easy_setopt(curl_handle, CURLOPT_WRITEDATA,	(void *)&buffer);	// Pointer to memory where write
	curl_easy_setopt(curl_handle, CURLOPT_URL,		url);			// Set url to download
	res = curl_easy_perform(curl_handle);
	if (res != CURLE_OK) {
		fprintf(stderr, "Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
		return 0;
	}
	size 	  = buffer.size;
	(*itemData) = (unsigned char *)malloc(size);

	memcpy((*itemData), buffer.memory, size);
	if(buffer.memory)  free(buffer.memory);

	return size;

}


 
int main(int argc, char **argv){
	CURL	*curl_handle;
	int 	i, j;
	struct	curl_slist *cookie	= NULL;
	struct	curl_slist *cursor	= NULL;
	FILE	*file; 
	CURLcode res;
	char	tmp[255];
	char	fileout[255];
	int	size	= 0;
	unsigned char *image = NULL;


	curl_global_init(CURL_GLOBAL_ALL);

	/* init the curl session */ 
	curl_handle = curl_easy_init();
	initCurlHandle(curl_handle);

	/*
	//------------------------------------------------------------------
	printf("Print cookies list:\n");
	res = curl_easy_getinfo(curl_handle, CURLINFO_COOKIELIST, &cookie);
	if (res != CURLE_OK) {
		fprintf(stderr, "Curl curl_easy_getinfo failed: %s\n", curl_easy_strerror(res));
		return 1;
	}


	cursor = cookie, i = 1;  
	while (cursor) {  
		printf("[%d]: %s\n", i, cursor->data);  
		cursor = cursor->next;  
		i++;  
	}  
	if (i == 1) {  
		printf("(none)\n");  
	}  
	//------------------------------------------------------------------
	*/

	for ( i = 8725; i < 8725+10; i++){
		for ( j = 5905; j < 5905+10; j++){
			sprintf(tmp, "http://khm%d.google.com/kh/v=58&x=%d&y=%d&z=14&s=", j%4, i, j);
			printf("%s\n", tmp);

			if ( ( size = downloadItem(curl_handle, tmp, &image)) == 0 ){
				fprintf(stderr, "Error: download problem\n");
				return 1;

			}
			sprintf(fileout, "tile-%d-%d.jpg",  i,j);
			printf("%s\n", fileout);
	
			file = fopen(fileout, "w"); 
			if(file == NULL) {
				fprintf(stderr, "Error: can't create file.\n");
				return 1;
			}
			fwrite(image, 1, size, file);	
		
			fclose(file);
			sleep(1);
		}
	}



	//------------------------------------------------


	curl_slist_free_all(cookie);  
	curl_slist_free_all(cursor);  
	curl_easy_cleanup(curl_handle);
	curl_global_cleanup();

	return 0;
}

