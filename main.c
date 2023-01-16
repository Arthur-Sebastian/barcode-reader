/*
	ECOAR - PROJECT

	Author: Artur Miller
*/
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>


#define SIZE_INPUT_BUF 128


/*
	Description:
		Reads code 39 barcode from 600x50 bitmap.
	Parameters:
		bitmap  [in] - pointer to bitmap data
		buf    [out] - barcode content buffer
	Returns:
		 0 - success
		-1 - read fail
*/
extern int readcode(uint8_t *bitmap, char *buf);


int main(int argc, char **argv)
{
	FILE *bmpfd;
	uint8_t *bitmap;
	size_t bmpSize;
	char *codeBuf;

	if (argc != 2) {
		puts("Invalid parameters!");
		return -1;
	}

	bmpfd = fopen(argv[1], "r");
	if (bmpfd == NULL) {
		puts("File read failed!");
		return -1;
	}
	fseek(bmpfd, 0, SEEK_END);
	bmpSize = ftell(bmpfd);
	rewind(bmpfd);
	bitmap = malloc(bmpSize);
	fread(bitmap, 1, bmpSize, bmpfd);
	fclose(bmpfd);

	codeBuf = malloc(SIZE_INPUT_BUF);
	memset(codeBuf, 0, SIZE_INPUT_BUF);

	if (readcode(bitmap, codeBuf) < 0) {
		printf("Buffer contents: %s\n", codeBuf);
		puts("Decoding failed!");
		return -1;
	}

	printf("Result: %s\n", codeBuf);

	free(bitmap);
	free(codeBuf);
	return 0;
}
